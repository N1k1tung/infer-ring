import Foundation
import NIO
import NIOHTTP1
import Logging

final class FileServerHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)

        guard case .head(let request) = part else { return }

        if request.uri.hasPrefix("/download") {
            let filePath = "/path/to/file"
            sendFile(context: context, path: filePath)
        }
        else {
            sendText(context: context, body: "OK", status: .ok)
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
