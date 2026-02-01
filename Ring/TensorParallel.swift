import Foundation
import MLX
import MLXNN
import MLXLMCommon
import MLXLLM

// MARK: - Tensor Parallel Auto Sharding

/// Automatically apply tensor parallelism to a model across multiple devices.
/// - Parameters:
///   - model: The LanguageModel to parallelize (Qwen3MoEModel, etc.)
///   - group: The distributed group for communication
/// - Returns: The modified model with tensor parallel layers
public func tensorAutoParallel(
    model: any LanguageModel,
    group: DistributedGroup
) -> any LanguageModel {
    
    if let qwen = model as? Qwen3MoEModel {
        shardQwen3MoE(qwen, group: group)
        return qwen
    }
    if let qwen = model as? Qwen3Model {
        shardQwen3(qwen, group: group)
        return qwen
    }
    if let oss = model as? GPTOSSModel {
        shardGPTOSS(oss, group: group)
        return oss
    }

    print("Warning: tensorAutoParallel unsupported model type: \(type(of: model))")
    return model
}

// MARK: - GPTOSS Sharding Strategy

private func shardGPTOSS(_ model: GPTOSSModel, group: DistributedGroup) {
    for layerModule in model.model.layers {
        guard let layer = layerModule as? GPTOSSTransformerBlock else { continue }

        // Shard the self attention
        layer.selfAttn.shard(group: group)

        // Shard the MLP
        layer.mlp.shard(group: group)
    }
    model.rebuildCaches()
}

// MARK: - Qwen3MoE Sharding Strategy

private func shardQwen3MoE(_ model: Qwen3MoEModel, group: DistributedGroup) {
    for layerModule in model.model.layers {
        guard let layer = layerModule as? Qwen3MoeDecoderLayer else { continue }
        
        // Shard the self attention
        layer.selfAttn.shard(group: group)
        
        // Shard the MLP (either dense MLP or MoE)
        if let moeBlock = layer.mlp as? Qwen3MoESparseMoeBlock {
            moeBlock.shard(group: group)
        } else if let mlp = layer.mlp as? Qwen3MoEMLP {
            mlp.shard(group: group)
        }
    }
    model.rebuildCaches()
}

// MARK: - Qwen3 Sharding Strategy

private func shardQwen3(_ model: Qwen3Model, group: DistributedGroup) {
    for layerModule in model.model.layers {
        guard let layer = layerModule as? Qwen3TransformerBlock else { continue }
        
        // Shard the self attention
        layer.attention.shard(group: group)
        
        // Shard the MLP
        layer.mlp.shard(group: group)
    }
    model.rebuildCaches()
}

// MARK: - Sharded MoE Wrapper (Alternative approach for other models)

/// Wrapper for MoE blocks that adds distributed gradient aggregation and result summation
public class ShardedMoE: Module, UnaryLayer {
    public let originalMoE: UnaryLayer
    public let group: DistributedGroup
    
    public init(originalMoE: UnaryLayer, group: DistributedGroup) {
        self.originalMoE = originalMoE
        self.group = group
        super.init()
    }
    
    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        // Aggregate gradients coming from each shard (for training)
        let x = sumGradients(group: group)(x)
        
        // Forward through original MoE
        let y = originalMoE(x)
        
        // Aggregate results across all devices
        return group.allSum(y)
    }
}
