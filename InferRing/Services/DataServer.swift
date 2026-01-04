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
            if path.hasPrefix("/download") {
                let filePath = "/path/to/file"
                sendFile(context: context, path: filePath)
            }
            else if path.hasPrefix("/elect") {
                guard let buffer = requestBodyBuffer else {
                    sendText(context: context, body: "Bad Request: Empty Body", status: .badRequest)
                    return
                }
                let data = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) ?? Data()
                guard let message = try? JSONDecoder.default.decode(ElectionMessage.self, from: data) else {
                    sendText(context: context, body: "Bad Request: Invalid JSON", status: .badRequest)
                    return
                }
                ringCoordinator?.handleElectionRequest(message)
                sendText(context: context, body: "OK", status: .ok)
            }
            else if path.hasPrefix("/ping") {
                sendData(context: context, body: Ping(isAlive: true), status: .ok)
            }
            else {
                sendText(context: context, body: "OK", status: .ok)
            }
        }
    }

    private func sendFile(context: ChannelHandlerContext, path: String) {
        do {
            let fileHandle = try NIOFileHandle(path: path)
            let region = try FileRegion(fileHandle: fileHandle)

            var headers = HTTPHeaders()
            headers.add(name: "Content-Length", value: "\(region.endIndex)")
            headers.add(name: "Content-Type", value: "application/octet-stream")

            let responseHead = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
            context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)

            // Stream the file without loading it into memory
            context.write(self.wrapOutboundOut(.body(.fileRegion(region))), promise: nil)

            context.writeAndFlush(self.wrapOutboundOut(.end(nil))).whenComplete { _ in
                try? fileHandle.close()
            }
        } catch {
            sendText(context: context, body: "File Not Found", status: .notFound)
        }
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
