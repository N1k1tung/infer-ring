import Foundation

// adapted from https://github.com/exo-explore/exo/blob/main/src/exo/shared/types/shards.py

// MARK: - Memory

public struct MemorySize: Codable, Hashable, Sendable {
    public var inBytes: Int = 0
}

// MARK: - ModelMetadata

public struct ModelMetadata: Codable, Hashable, Sendable {
    public let modelId: String
    public let prettyName: String
    public let storageSize: MemorySize
    public let nLayers: Int
    public let hiddenSize: Int
    public let supportsTensor: Bool
}

// MARK: - ShardMetadata

public struct ShardMetadata: Codable {
    let modelMeta: ModelMetadata
    let deviceRank: Int
    let worldSize: Int
    
    var immediateException: Bool = false
    var shouldTimeout: Double? = nil
    
    let startLayer: Int
    let endLayer: Int
    let nLayers: Int
    
    var isFirstLayer: Bool {
        startLayer == 0
    }
    var isLastLayer: Bool {
        endLayer == nLayers
    }

    public init(modelMeta: ModelMetadata, deviceRank: Int, worldSize: Int, immediateException: Bool = false, shouldTimeout: Double? = nil, startLayer: Int, endLayer: Int, nLayers: Int) {
        self.modelMeta = modelMeta
        self.deviceRank = deviceRank
        self.worldSize = worldSize
        self.immediateException = immediateException
        self.shouldTimeout = shouldTimeout
        self.startLayer = startLayer
        self.endLayer = endLayer
        self.nLayers = nLayers
    }
}

extension ShardMetadata: Hashable {
    public static func == (lhs: ShardMetadata, rhs: ShardMetadata) -> Bool {
        return lhs.modelMeta.modelId == rhs.modelMeta.modelId &&
               lhs.startLayer == rhs.startLayer &&
               lhs.endLayer == rhs.endLayer &&
               lhs.nLayers == rhs.nLayers &&
               lhs.deviceRank == rhs.deviceRank &&
               lhs.worldSize == rhs.worldSize
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(modelMeta.modelId)
        hasher.combine(startLayer)
        hasher.combine(endLayer)
        hasher.combine(nLayers)
        hasher.combine(deviceRank)
        hasher.combine(worldSize)
    }
}

