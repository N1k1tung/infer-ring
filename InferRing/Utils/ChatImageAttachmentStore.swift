import Foundation

enum ChatImageAttachmentStore {
    private static let directoryURL: URL = {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cachesDirectory.appendingPathComponent("ChatAttachments", isDirectory: true)
    }()

    static func importImage(from sourceURL: URL) throws -> ChatImageAttachment {
        let isAccessingSecurityScopedResource = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessingSecurityScopedResource {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let pathExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let destinationURL = directoryURL.appendingPathComponent(
            "\(UUID().uuidString).\(pathExtension)"
        )

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }
        catch {
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: destinationURL, options: .atomic)
        }

        return ChatImageAttachment(
            url: destinationURL,
            filename: sourceURL.lastPathComponent
        )
    }

    static func removeAll() {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else { return }
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
