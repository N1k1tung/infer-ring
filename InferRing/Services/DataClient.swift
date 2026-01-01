//
import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1

final class DataClient {

    func get() async {
        do {
            let request = HTTPClientRequest(url: "https://apple.com/")
            let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
            print("HTTP head", response)
            if response.status == .ok {
                let body = try await response.body.collect(upTo: 2 * 1024 * 1024)
                // handle body
            }
            else {
                dprint("response error: \(response.status)")
            }
        }
        catch {
            dprint("request failed: \(error)")
        }
    }

    func post() async {
        do {
            var request = HTTPClientRequest(url: "https://apple.com/")
            request.method = .POST
            request.headers.add(name: "User-Agent", value: "Swift HTTPClient")
            request.body = .bytes(ByteBuffer(string: "some data"))

            let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
            if response.status == .ok {
                // handle response
            }
            else {
                dprint("response error: \(response.status)")
            }
        }
        catch {
            dprint("request failed: \(error)")
        }
    }

    func download() async {
        do {
            let request = HTTPClientRequest(url: "https://apple.com/")
            let response = try await HTTPClient.shared.execute(request, timeout: .seconds(120))
            dprint(response)

            // if defined, the content-length headers announces the size of the body
            let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)

            var receivedBytes = 0
            // asynchronously iterates over all body fragments
            // this loop will automatically propagate backpressure correctly
            for try await buffer in response.body {
                // for this example, we are just interested in the size of the fragment
                receivedBytes += buffer.readableBytes

                if let expectedBytes = expectedBytes {
                    // if the body size is known, we calculate a progress indicator
                    let progress = Double(receivedBytes) / Double(expectedBytes)
                    dprint("progress: \(Int(progress * 100))%")
                }
            }
            dprint("did receive \(receivedBytes) bytes")
        } catch {
            dprint("request failed: \(error)")
        }
    }



}
