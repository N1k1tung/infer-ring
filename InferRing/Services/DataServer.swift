import Foundation
import NIO
import NIOHTTP1
import Logging
import NIOFoundationCompat
import Ring

final class FileServerHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    @Inject
    private var ringCoordinator: RingCoordinator?

    @Inject
    private var modelManager: ModelManager?

    @Inject
    private var hardwareMonitor: HardwareMonitor?

    private var currentRequestHead: HTTPRequestHead?
    private var requestBodyBuffer: ByteBuffer?

    private lazy var fileIO = NonBlockingFileIO(threadPool: .singleton)

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)

        switch part {
        case .head(let request):
            currentRequestHead = request
            requestBodyBuffer = nil

        case .body(var chunk):
            if requestBodyBuffer == nil {
                requestBodyBuffer = context.channel.allocator.buffer(capacity: chunk.readableBytes)
            }
            requestBodyBuffer?.writeBuffer(&chunk)

        case .end:
            defer {
                currentRequestHead = nil
                requestBodyBuffer = nil
            }

            guard let request = currentRequestHead,
                  let url = URL(string: request.uri) else {
                sendText(context: context, body: "Bad Request", status: .badRequest)
                return
            }

            let path = url.path
            let remoteIP = context.remoteAddress?.ipAddress
            let eventLoop = context.eventLoop
            let loopBoundContext = NIOLoopBound(context, eventLoop: eventLoop)
            let loopBoundSelf = NIOLoopBound(self, eventLoop: eventLoop)

            if path.hasPrefix("/download") {
                // Extract modelId and fileName from path: /download/{modelId}/{fileName}
                let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
                guard components.count >= 3,
                      components[0] == "download",
                      let modelId = components[1].removingPercentEncoding,
                      let fileName = components[2].removingPercentEncoding else {
                    sendText(context: context, body: "Bad Request: Invalid download path", status: .badRequest)
                    return
                }

                guard let modelCard = ModelCards.allModels[modelId] else {
                    sendText(context: context, body: "Model not found", status: .notFound)
                    return
                }

                let fileURL = modelCard.cacheDirectory.appendingPathComponent(fileName)
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    sendText(context: context, body: "File not found", status: .notFound)
                    return
                }

                sendFile(context: context, path: fileURL.path)
            }
            else if path.hasPrefix("/elect") {
                guard let data = getData(context: context) else { return }
                guard let message = parseBody(data: data, context: context, type: ElectionMessage.self)
                else { return }
                ringCoordinator?.handleElectionRequest(message)
                sendText(context: context, body: "OK", status: .ok)
            }
            else if path.hasPrefix("/ping") {
                sendData(context: context, body: Ping(isAlive: true), status: .ok)
            }
            else if path.hasPrefix("/loadModel") {
                guard let data = getData(context: context) else { return }
                guard let request = parseBody(data: data, context: context, type: ModelLoadRequest.self)
                else { return }

                Task {
                    let response = await modelManager?.handleModelLoadRequest(request, remoteHost: remoteIP) ?? ModelLoadResponse(
                        requestID: request.requestID,
                        success: false,
                        errorMessage: "ModelManager not available",
                        timestamp: Date()
                    )
                    eventLoop.execute {
                        loopBoundSelf.value.sendData(context: loopBoundContext.value, body: response, status: .ok)
                    }
                }
            }
            else if path.hasPrefix("/startGeneration") {
                guard let data = getData(context: context) else { return }
                guard let request = parseBody(data: data, context: context, type: GenerationRequest.self)
                else { return }

                Task {
                    let response = await modelManager?.handleGenerationRequest(request) ?? GenerationResponse(
                        requestID: request.requestID,
                        success: false,
                        errorMessage: "ModelManager not available",
                        timestamp: Date()
                    )
                    eventLoop.execute {
                        loopBoundSelf.value.sendData(context: loopBoundContext.value, body: response, status: .ok)
                    }
                }
            }
            else if path.hasPrefix("/resetChat") {
                guard let data = getData(context: context) else { return }
                guard let request = parseBody(data: data, context: context, type: ChatResetRequest.self)
                else { return }

                Task {
                    let response = await modelManager?.handleChatResetRequest(request) ?? ChatResetResponse(
                        requestID: request.requestID,
                        success: false,
                        errorMessage: "ModelManager not available",
                        timestamp: Date()
                    )
                    eventLoop.execute {
                        loopBoundSelf.value.sendData(context: loopBoundContext.value, body: response, status: .ok)
                    }
                }
            }
            else if path.hasPrefix("/getHardwareProfile") {
                guard let data = getData(context: context) else { return }
                guard let _ = parseBody(data: data, context: context, type: HardwareProfileRequest.self)
                else { return }

                let response = HardwareProfileResponse(
                    hardwareProfile: hardwareMonitor?.currentProfile ?? .init(totalRAM: 0, recommendedUsageRAM: 0, idiom: .current),
                    timestamp: Date()
                )

                sendData(context: context, body: response, status: .ok)
            }
            else if path.hasPrefix("/v1/models") {
                handleModels(context: context)
            }
            else if path.hasPrefix("/v1/chat/completions") {
                guard let data = getData(context: context) else { return }
                handleChatCompletions(context: loopBoundContext, data: data)
            }
            else {
                sendText(context: context, body: "Not Found", status: .notFound)
            }
        }
    }

    private func getData(context: ChannelHandlerContext) -> Data? {
        guard let buffer = requestBodyBuffer else {
            sendText(context: context, body: "Bad Request: Empty Body", status: .badRequest)
            return nil
        }
        return buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) ?? Data() // allow empty
    }

    private func parseBody<T: Decodable>(data: Data, context: ChannelHandlerContext, type: T.Type) -> T? {
        do {
            return try JSONDecoder.default.decode(type.self, from: data)
        }
        catch {
            dprint(error)
            if context.eventLoop.inEventLoop {
                sendText(context: context, body: "Bad Request: Invalid JSON", status: .badRequest)
            }
            else {
                let eventLoop = context.eventLoop
                let loopBoundSelf = NIOLoopBound(self, eventLoop: eventLoop)
                let loopBoundContext = NIOLoopBound(context, eventLoop: eventLoop)
                eventLoop.execute {
                    loopBoundSelf.value.sendText(context: loopBoundContext.value, body: "Bad Request: Invalid JSON", status: .badRequest)
                }
            }

            return nil
        }
    }

    private func sendFile(context: ChannelHandlerContext, path: String) {
        dprint("Sending file \(path)")
        let eventLoop = context.eventLoop
        let loopBoundContext = NIOLoopBound(context, eventLoop: eventLoop)
        let loopBoundSelf = NIOLoopBound(self, eventLoop: eventLoop)
        let fileHandleAndRegion = fileIO.openFile(_deprecatedPath: path, eventLoop: context.eventLoop)
        fileHandleAndRegion.whenFailure { [weak self] in
            self?.sendText(context: context, body: "File Not Found: \($0)", status: .notFound)
        }

        fileHandleAndRegion.whenSuccess { (file, region) in
            let context = loopBoundContext.value
            let loopBoundFile = NIOLoopBound(file, eventLoop: eventLoop)

            var headers = HTTPHeaders()
            headers.add(name: "Content-Length", value: "\(region.endIndex)")
            headers.add(name: "Content-Type", value: "application/octet-stream")
            let responseHead = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
            context.write(Self.wrapOutboundOut(.head(responseHead)), promise: nil)

            loopBoundSelf.value.fileIO.readChunked(
                fileRegion: region,
                chunkSize: 128 * 1024,
                allocator: context.channel.allocator,
                eventLoop: context.eventLoop
            ) { buffer in
                loopBoundContext.value.writeAndFlush(Self.wrapOutboundOut(.body(.byteBuffer(buffer))))
            }.flatMap { () -> EventLoopFuture<Void> in
                let context = loopBoundContext.value
                let p = context.eventLoop.makePromise(of: Void.self)
                context.writeAndFlush(Self.wrapOutboundOut(.end(nil)), promise: p)
                return p.futureResult
            }.flatMapError { error in
                loopBoundContext.value.close()
            }.whenComplete { (_: Result<Void, Error>) in
                _ = try? loopBoundFile.value.close()
            }
        }


    }

    private func sendText(context: ChannelHandlerContext, body: String, status: HTTPResponseStatus) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Length", value: "\(body.utf8.count)")
        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)

        var buffer = context.channel.allocator.buffer(capacity: body.utf8.count)
        buffer.writeString(body)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)

        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func sendData<T: Encodable>(context: ChannelHandlerContext, body: T, status: HTTPResponseStatus) {
        guard let data = try? JSONEncoder.default.encode(body) else { return }
        var headers = HTTPHeaders()
        headers.add(name: "Content-Length", value: "\(data.count)")
        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)

        let buffer = context.channel.allocator.buffer(data: data)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)

        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func handleModels(context: ChannelHandlerContext) {
        let models: [OpenAPIModel]
        if let card = modelManager?.currentModelCard {
            models = [
                OpenAPIModel(
                    id: card.shortId,
                    object: "model",
                    created: Int(Date().timeIntervalSince1970),
                    ownedBy: "unknown"
                )
            ]
        }
        else {
            models = []
        }

        let response = OpenAPIModelResponse(object: "list", data: models)
        sendData(context: context, body: response, status: .ok)
    }

    private func handleChatCompletions(context: NIOLoopBound<ChannelHandlerContext>, data: Data) {
        guard let request = parseBody(data: data, context: context.value, type: OpenAPIChatCompletionRequest.self) else {
            dprint(String(data: data, encoding: .utf8))
            return
        }

        let eventLoop = context.eventLoop
        let loopBoundSelf = NIOLoopBound(self, eventLoop: eventLoop)

        Task {
            let selectedTools = request.selectedTools
            if request.stream == true {
                eventLoop.execute {
                    loopBoundSelf.value.startSSE(context: context.value)
                }

                let stream = await modelManager?.streamResponse(to: request.messages, tools: selectedTools)

                do {
                    var toolCallCount = 0
                    if let stream {
                        for try await chunk in stream {
                            let responseChunk: OpenAPIChatCompletionChunk
                            switch chunk {
                            case .text(let text):
                                responseChunk = OpenAPIChatCompletionChunk(
                                    id: "chatcmpl-\(UUID().uuidString)",
                                    object: "chat.completion.chunk",
                                    created: Int(Date().timeIntervalSince1970),
                                    model: request.model ?? "unknown",
                                    choices: [
                                        OpenAPIChoice(
                                            index: 0,
                                            delta: OpenAPIDelta(role: .assistant, content: text, toolCalls: nil),
                                            finishReason: nil
                                        )
                                    ]
                                )
                            case .toolCall(let toolCall):
                                responseChunk = OpenAPIChatCompletionChunk(
                                    id: "chatcmpl-\(UUID().uuidString)",
                                    object: "chat.completion.chunk",
                                    created: Int(Date().timeIntervalSince1970),
                                    model: request.model ?? "unknown",
                                    choices: [
                                        OpenAPIChoice(
                                            index: 0,
                                            delta: OpenAPIDelta(
                                                role: .assistant,
                                                content: nil,
                                                toolCalls: [toolCall.delta(index: toolCallCount)]
                                            ),
                                            finishReason: nil
                                        )
                                    ]
                                )
                                toolCallCount += 1
                            }

                            if let data = try? JSONEncoder().encode(responseChunk),
                               let jsonString = String(data: data, encoding: .utf8) {
                                eventLoop.execute {
                                    loopBoundSelf.value.sendSSEData(
                                        context: context.value,
                                        string: "data: \(jsonString)\n\n"
                                    )
                                }
                            }
                        }
                    }
                    let chunk = OpenAPIChatCompletionChunk(
                        id: "chatcmpl-\(UUID().uuidString)",
                        object: "chat.completion.chunk",
                        created: Int(Date().timeIntervalSince1970),
                        model: request.model ?? "unknown",
                        choices: [
                            OpenAPIChoice(
                                index: 0,
                                delta: OpenAPIDelta(role: nil, content: nil, toolCalls: nil),
                                finishReason: toolCallCount > 0 ? "tool_calls" : "stop"
                            )
                        ]
                    )

                    eventLoop.execute {
                        if let data = try? JSONEncoder().encode(chunk), let jsonString = String(data: data, encoding: .utf8) {
                            loopBoundSelf.value.sendSSEData(context: context.value, string: "data: \(jsonString)\n\n")
                        }
                        loopBoundSelf.value.sendSSEData(context: context.value, string: "data: [DONE]\n\n")
                        loopBoundSelf.value.endSSE(context: context.value)
                    }
                }
                catch {
                    eventLoop.execute {
                        loopBoundSelf.value.endSSE(context: context.value)
                    }
                }
            }
            else {
                var fullText = ""
                var toolCalls: [OpenAPIToolCall] = []
                let stream = await modelManager?.streamResponse(to: request.messages, tools: selectedTools)
                if let stream {
                    try? await {
                        for try await chunk in stream {
                            switch chunk {
                            case .text(let text):
                                fullText += text
                            case .toolCall(let toolCall):
                                toolCalls.append(toolCall.openAPIToolCall)
                            }
                        }
                    }()
                }

                let response = OpenAPIChatCompletionResponse(
                    id: "chatcmpl-\(UUID().uuidString)",
                    object: "chat.completion",
                    created: Int(Date().timeIntervalSince1970),
                    model: request.model ?? "unknown",
                    choices: [
                        OpenAPIChoiceFull(
                            index: 0,
                            message: OpenAPIMessage(
                                role: .assistant,
                                content: fullText.isEmpty ? nil : .text(fullText),
                                name: nil,
                                toolCalls: toolCalls.isEmpty ? nil : toolCalls,
                                toolCallId: nil
                            ),
                            finishReason: toolCalls.isEmpty ? "stop" : "tool_calls"
                        )
                    ]
                )
                eventLoop.execute {
                    loopBoundSelf.value.sendData(context: context.value, body: response, status: .ok)
                }
            }
        }
    }

    private func startSSE(context: ChannelHandlerContext) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/event-stream")
        headers.add(name: "Cache-Control", value: "no-cache")
        headers.add(name: "Connection", value: "keep-alive")
        let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
        context.writeAndFlush(wrapOutboundOut(.head(head)), promise: nil)
    }

    private func sendSSEData(context: ChannelHandlerContext, string: String) {
        var buffer = context.channel.allocator.buffer(capacity: string.utf8.count)
        buffer.writeString(string)
        context.writeAndFlush(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
    }

    private func endSSE(context: ChannelHandlerContext) {
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
}

final class DataServer {
    let group = MultiThreadedEventLoopGroup.singleton
    var channel: Channel?

    func start() {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(FileServerHandler())
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.socket(.init(IPPROTO_TCP), .init(TCP_NODELAY)), value: 1)

        do {
            channel = try bootstrap.bind(host: ServiceInfo.host, port: ServiceInfo.port).wait()
            dprint("Server started")
        }
        catch {
            dprint("Failed to start server: \(error)")
        }
    }

    func stop() {
        try? group.syncShutdownGracefully()
    }
}
