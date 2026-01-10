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

public extension ModelCard {
    var isLoaded: Bool {
        ModelCards.loadedModels.contains(modelId)
    }
    var isPartiallyLoaded: Bool {
        ModelCards.partiallyLoadedModels.contains(modelId)
    }
}

extension ModelCards {
    static var loadedModels: [String] = []
    static var partiallyLoadedModels: [String] = []
    
    public static func checkLoadedModels() async {
        let fm = FileManager.default
        let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let modelsDir = cachesDir.appendingPathComponent("models")
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
        loadedModels = loaded
        partiallyLoadedModels = partiallyLoaded
    }
}
