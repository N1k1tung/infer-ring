//
import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1
import NIOFoundationCompat

final class DataClient {

    private let baseUrl: String

    init(baseUrl: String) {
        self.baseUrl = baseUrl
    }

    private func get<T: Decodable>(path: String) async -> T? {
        do {
            let request = HTTPClientRequest(url: "\(baseUrl)\(path)")
            let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))
            dprint("HTTP head \(response)")
            if response.status == .ok {
                let body = try await response.body.collect(upTo: 2 * 1024 * 1024)
                return try JSONDecoder.default.decode(T.self, from: body)
            }
            else {
                dprint("response error: \(response.status)")
            }
        }
        catch {
            dprint("request failed: \(error)")
        }
        return nil
    }

    private func post<T: Encodable>(path: String, body: T) async {
        do {
            var request = HTTPClientRequest(url: "\(baseUrl)\(path)")
            request.method = .POST
            request.headers.add(name: "Content-Type", value: "application/json")
            request.body = .bytes(try JSONEncoder.default.encode(body))

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

extension DataClient {
    func ping() async -> Bool {
        let result: Ping? = await get(path: "/path")
        return result?.isAlive ?? false
    }

    func elect(message: ElectionMessage) async {
        await post(path: "/elect", body: message)
    }
}
