//
import Foundation

extension FileManager {
    func directorySize(at url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]
        var total: Int64 = 0

        if let enumerator = enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) {
            for case let fileURL as URL in enumerator {
                do {
                    let values = try fileURL.resourceValues(forKeys: Set(keys))
                    // Only count regular files
                    if values.isRegularFile == true {
                        if let allocated = values.totalFileAllocatedSize ?? values.fileAllocatedSize {
                            total += Int64(allocated)
                        } else if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            total += Int64(fileSize)
                        }
                    }
                }
                catch {
                    // Ignore unreadable files
                    continue
                }
            }
        }
        return total
    }
}

@MainActor
public extension ModelCard {
    var isLoaded: Bool {
        ModelCards.loadedModels.contains(modelId)
    }
    var isPartiallyLoaded: Bool {
        ModelCards.partiallyLoadedModels.contains(modelId)
    }
    var downloadedFiles: [String] {
        guard isLoaded else { return [] }
        var fileNames: [String] = []
        let keys: [URLResourceKey] = [.isRegularFileKey]
        if let enumerator = FileManager.default.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) {
            for case let fileURL as URL in enumerator {
                do {
                    let values = try fileURL.resourceValues(forKeys: Set(keys))
                    if values.isRegularFile == true {
                        fileNames.append(fileURL.lastPathComponent)
                    }
                }
                catch {
                    // Ignore unreadable files
                    continue
                }
            }
        }
        return fileNames
    }
}

public extension ModelCard {
    var cacheDirectory: URL {
        ModelCards.modelsDirectory.appendingPathComponent(modelId)
    }
}

extension ModelCards {
    @MainActor static var loadedModels: [String] = []
    @MainActor static var partiallyLoadedModels: [String] = []

    static var modelsDirectory: URL {
        let fm = FileManager.default
        let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let modelsDir = cachesDir.appendingPathComponent("models")
        return modelsDir
    }

    public static func checkLoadedModels() async {
        let fm = FileManager.default
        let modelsDir = modelsDirectory
        var loaded = [String]()
        var partiallyLoaded = [String]()
        for (_, card) in allModels {
            let modelDir = modelsDir.appendingPathComponent(card.modelId)
            if fm.fileExists(atPath: modelDir.path) {
                let size = fm.directorySize(at: modelDir)
                if Double(size) >= Double(card.metadata.storageSize.inBytes) * 0.8 {
                    loaded.append(card.modelId)
                }
                else {
                    partiallyLoaded.append(card.modelId)
                }
            }
        }
        Task { @MainActor in
            loadedModels = loaded
            partiallyLoadedModels = partiallyLoaded
        }
    }

    public static func deleteModel(_ card: ModelCard) async throws {
        let fm = FileManager.default
        let modelDir = modelsDirectory.appendingPathComponent(card.modelId)
        if fm.fileExists(atPath: modelDir.path) {
            try fm.removeItem(at: modelDir)
        }
        await Task { @MainActor in
            partiallyLoadedModels.removeAll(where: { $0 == card.modelId })
            loadedModels.removeAll(where: { $0 == card.modelId })
        }.value
    }
}
