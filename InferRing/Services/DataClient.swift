//
import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1
import NIOFoundationCompat

enum DataClientError: LocalizedError {
    case downloadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        }
    }
}

final class DataClient {

    private let baseUrl: String

    init(baseUrl: String) {
        self.baseUrl = baseUrl
    }

    static func client(for device: DiscoveredDevice) -> DataClient {
        let url = "http://\(device.host):\(ServiceInfo.port)"
        return DataClient(baseUrl: url)
    }

    private func get<T: Decodable>(path: String, timeout: TimeAmount = .seconds(8)) async -> T? {
        do {
            let request = HTTPClientRequest(url: "\(baseUrl)\(path)")
            let response = try await HTTPClient.shared.execute(request, timeout: timeout)
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

    private func post<T: Encodable, R: Decodable>(path: String, body: T, timeout: TimeAmount = .seconds(30)) async -> R? {
        do {
            var request = HTTPClientRequest(url: "\(baseUrl)\(path)")
            request.method = .POST
            request.headers.add(name: "Content-Type", value: "application/json")
            request.body = .bytes(try JSONEncoder.default.encode(body))

            let response = try await HTTPClient.shared.execute(request, timeout: timeout)
            if response.status == .ok {
                let responseBody = try await response.body.collect(upTo: 2 * 1024 * 1024)
                return try JSONDecoder.default.decode(R.self, from: responseBody)
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

    private func post<T: Encodable>(path: String, body: T, timeout: TimeAmount = .seconds(8)) async {
        do {
            var request = HTTPClientRequest(url: "\(baseUrl)\(path)")
            request.method = .POST
            request.headers.add(name: "Content-Type", value: "application/json")
            request.body = .bytes(try JSONEncoder.default.encode(body))

            let response = try await HTTPClient.shared.execute(request, timeout: timeout)
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

    func download(modelId: String, fileName: String, destinationURL: URL) async throws {
        let encodedModelId = modelId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? modelId
        let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
        let request = HTTPClientRequest(url: "\(baseUrl)/download/\(encodedModelId)/\(encodedFileName)")
        
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(600))
        
        guard response.status == .ok else {
            throw DataClientError.downloadFailed("HTTP \(response.status)")
        }
        
//        let expectedBytes = response.headers.first(name: "Content-Length").flatMap(Int.init)
        var receivedBytes = 0
        
        // Create destination directory if needed
        let directory = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Create empty file
        FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
        
        // Write to file
        guard let fileHandle = FileHandle(forWritingAtPath: destinationURL.path) else {
            throw DataClientError.downloadFailed("Could not open file for writing")
        }
        defer {
            try? fileHandle.close()
        }
        
        for try await buffer in response.body {
            if let data = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) {
                try fileHandle.write(contentsOf: data)
                receivedBytes += buffer.readableBytes
                // skip progress reporting for now
//                if let expectedBytes {
//                    let progress = Double(receivedBytes) / Double(expectedBytes)
//                    dprint("download progress: \(Int(progress * 100))% (\(receivedBytes)/\(expectedBytes) bytes)")
//                }
            }
        }
        
        dprint("download complete: \(receivedBytes) bytes written to \(destinationURL.path)")
    }

}

extension DataClient {
    func ping() async -> Bool {
        let result: Ping? = await get(path: "/ping")
        return result?.isAlive ?? false
    }

    func elect(message: ElectionMessage) async {
        await post(path: "/elect", body: message)
    }
    
    func loadModel(request: ModelLoadRequest) async -> ModelLoadResponse? {
        await post(path: "/loadModel", body: request, timeout: .seconds(1200))
    }
    
    func startGeneration(request: GenerationRequest) async -> GenerationResponse? {
        await post(path: "/startGeneration", body: request, timeout: .seconds(300))
    }

    func resetChat(request: ChatResetRequest) async -> ChatResetResponse? {
        await post(path: "/resetChat", body: request, timeout: .seconds(10))
    }
    
    func getHardwareProfile(request: HardwareProfileRequest) async -> HardwareProfileResponse? {
        await post(path: "/getHardwareProfile", body: request, timeout: .seconds(10))
    }
}
