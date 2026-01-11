import Foundation
import NIO
import NIOHTTP1
import Logging
import NIOFoundationCompat

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
            if path.hasPrefix("/elect") {
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
                    let response = await modelManager?.handleModelLoadRequest(request) ?? ModelLoadResponse(
                        requestID: request.requestID,
                        success: false,
                        errorMessage: "ModelManager not available",
                        timestamp: Date()
                    )
                    context.eventLoop.execute { [weak self] in
                        self?.sendData(context: context, body: response, status: .ok)
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
                    context.eventLoop.execute { [weak self] in
                        self?.sendData(context: context, body: response, status: .ok)
                    }
                }
            }
            else if path.hasPrefix("/updateLastMessage") {
                guard let data = getData(context: context) else { return }
                guard let request = parseBody(data: data, context: context, type: UpdateLastMessageRequest.self)
                    else { return }

                let response =  modelManager?.handleUpdateLastMessageRequest(request) ?? UpdateLastMessageResponse(
                    success: false,
                    errorMessage: "ModelManager not available",
                    timestamp: Date()
                )
                sendData(context: context, body: response, status: .ok)
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
            else {
                sendText(context: context, body: "OK", status: .ok)
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
        guard let payload = try? JSONDecoder.default.decode(type.self, from: data) else {
            sendText(context: context, body: "Bad Request: Invalid JSON", status: .badRequest)
            return nil
        }
        return payload
    }

    private func sendText(context: ChannelHandlerContext, body: String, status: HTTPResponseStatus) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Length", value: "\(body.utf8.count)")
        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(self.wrapOutboundOut(.head(head)), promise: nil)

        var buffer = context.channel.allocator.buffer(capacity: body.utf8.count)
        buffer.writeString(body)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)

        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func sendData<T: Encodable>(context: ChannelHandlerContext, body: T, status: HTTPResponseStatus) {
        guard let data = try? JSONEncoder.default.encode(body) else { return }
        var headers = HTTPHeaders()
        headers.add(name: "Content-Length", value: "\(data.count)")
        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(self.wrapOutboundOut(.head(head)), promise: nil)

        let buffer = context.channel.allocator.buffer(data: data)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)

        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }
}

final class DataServer {
#if os(iOS)
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
#else
    let group = MultiThreadedEventLoopGroup(numberOfThreads:System.coreCount)
#endif
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
        } catch {
            dprint("Failed to start server: \(error)")
        }
    }

    func stop() {
        try? group.syncShutdownGracefully()
    }
}
