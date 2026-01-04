import Foundation

// adapted from https://github.com/exo-explore/exo/blob/main/src/exo/shared/types/shards.py

// MARK: - Memory

public struct Memory: Codable, Hashable {
    public var inBytes: Int = 0
}

// MARK: - ModelMetadata

public struct ModelMetadata: Codable, Hashable {
    public let modelId: String
    public let prettyName: String
    public let storageSize: Memory
    public let nLayers: Int
    public let hiddenSize: Int
    public let supportsTensor: Bool
}

// MARK: - Sharding

enum Sharding: String, Codable {
    case tensor = "Tensor"
    case pipeline = "Pipeline"
}

// MARK: - BaseShardMetadata

public struct BaseShardMetadata: Codable {
    let modelMeta: ModelMetadata
    let deviceRank: Int
    let worldSize: Int
    
    var immediateException: Bool = false
    var shouldTimeout: Double? = nil
    
    let startLayer: Int
    let endLayer: Int
    let nLayers: Int
    
    var isFirstLayer: Bool {
        return startLayer == 0
    }
    
    var isLastLayer: Bool {
        return endLayer == nLayers
    }
}

extension BaseShardMetadata: Hashable {
    public static func == (lhs: BaseShardMetadata, rhs: BaseShardMetadata) -> Bool {
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

// MARK: - ShardMetadata Union

enum ShardMetadata: Codable, Hashable {
    case pipeline(BaseShardMetadata)
    case tensor(BaseShardMetadata)
    
    enum CodingKeys: String, CodingKey {
        case pipeline = "PipelineShardMetadata"
        case tensor = "TensorShardMetadata"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(BaseShardMetadata.self, forKey: .pipeline) {
            self = .pipeline(value)
        } else if let value = try? container.decode(BaseShardMetadata.self, forKey: .tensor) {
            self = .tensor(value)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid or missing keys for ShardMetadata")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pipeline(let meta):
            try container.encode(meta, forKey: .pipeline)
        case .tensor(let meta):
            try container.encode(meta, forKey: .tensor)
        }
    }
    
    // Helper to access the underlying metadata
    var base: BaseShardMetadata {
        switch self {
        case .pipeline(let meta): return meta
        case .tensor(let meta): return meta
        }
    }
}

public typealias PipelineShardMetadata = BaseShardMetadata
public typealias TensorShardMetadata = BaseShardMetadata
