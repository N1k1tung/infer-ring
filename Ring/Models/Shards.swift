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

    private enum CodingKeys: String, CodingKey {
        case modelId
        case prettyName
        case storageSize
        case nLayers
        case hiddenSize
        case supportsTensor
    }

    public init(
        modelId: String,
        prettyName: String,
        storageSize: MemorySize,
        nLayers: Int,
        hiddenSize: Int,
        supportsTensor: Bool? = nil
    ) {
        self.modelId = modelId
        self.prettyName = prettyName
        self.storageSize = storageSize
        self.nLayers = nLayers
        self.hiddenSize = hiddenSize
        self.supportsTensor = supportsTensor ?? false
    }
}

public enum ParallelModeSettings {
    public static let useTensorParallelKey = "useTensorParallel"

    public static var useTensorParallel: Bool {
        get {
            UserDefaults.standard.object(forKey: useTensorParallelKey) as? Bool ?? false
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: useTensorParallelKey)
        }
    }
}

// MARK: - ShardMetadata

public struct ShardMetadata: Codable {
    public let modelMeta: ModelMetadata
    public let deviceRank: Int
    public let worldSize: Int
    public let useTensorParallel: Bool
    
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

    private enum CodingKeys: String, CodingKey {
        case modelMeta
        case deviceRank
        case worldSize
        case useTensorParallel
        case immediateException
        case shouldTimeout
        case startLayer
        case endLayer
        case nLayers
    }

    public init(
        modelMeta: ModelMetadata,
        deviceRank: Int,
        worldSize: Int,
        useTensorParallel: Bool = false,
        immediateException: Bool = false,
        shouldTimeout: Double? = nil,
        startLayer: Int,
        endLayer: Int,
        nLayers: Int
    ) {
        self.modelMeta = modelMeta
        self.deviceRank = deviceRank
        self.worldSize = worldSize
        self.useTensorParallel = useTensorParallel
        self.immediateException = immediateException
        self.shouldTimeout = shouldTimeout
        self.startLayer = startLayer
        self.endLayer = endLayer
        self.nLayers = nLayers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.modelMeta = try container.decode(ModelMetadata.self, forKey: .modelMeta)
        self.deviceRank = try container.decode(Int.self, forKey: .deviceRank)
        self.worldSize = try container.decode(Int.self, forKey: .worldSize)
        self.useTensorParallel = try container.decodeIfPresent(Bool.self, forKey: .useTensorParallel) ?? false
        self.immediateException = try container.decodeIfPresent(Bool.self, forKey: .immediateException) ?? false
        self.shouldTimeout = try container.decodeIfPresent(Double.self, forKey: .shouldTimeout)
        self.startLayer = try container.decode(Int.self, forKey: .startLayer)
        self.endLayer = try container.decode(Int.self, forKey: .endLayer)
        self.nLayers = try container.decode(Int.self, forKey: .nLayers)
    }
}

extension ShardMetadata: Hashable {
    public static func == (lhs: ShardMetadata, rhs: ShardMetadata) -> Bool {
        return lhs.modelMeta.modelId == rhs.modelMeta.modelId &&
               lhs.startLayer == rhs.startLayer &&
               lhs.endLayer == rhs.endLayer &&
               lhs.nLayers == rhs.nLayers &&
               lhs.deviceRank == rhs.deviceRank &&
               lhs.worldSize == rhs.worldSize &&
               lhs.useTensorParallel == rhs.useTensorParallel
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(modelMeta.modelId)
        hasher.combine(startLayer)
        hasher.combine(endLayer)
        hasher.combine(nLayers)
        hasher.combine(deviceRank)
        hasher.combine(worldSize)
        hasher.combine(useTensorParallel)
    }
}
