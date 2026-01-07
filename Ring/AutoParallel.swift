
import Foundation
import MLX
import MLXNN
import MLXLMCommon
import MLXLLM

// adapted from https://github.com/exo-explore/exo/blob/main/src/exo/worker/engines/mlx/auto_parallel.py
// import Models // Implicitly assumed available

// MARK: - Auto Parallel Functions

/// Automatically parallelize a model across multiple devices using pipeline parallelism.
/// - Parameters:
///   - model: The LanguageModel to parallelize (LlamaModel, DeepseekV3Model, Qwen3MoEModel, etc.)
///   - group: The distributed group for communication
///   - modelShardMeta: Metadata specifying which layers this device should handle
/// - Returns: The modified model with pipeline parallel layers wrapped
public func pipelineAutoParallel(
    model: any LanguageModel,
    group: DistributedGroup,
    modelShardMeta: PipelineShardMetadata
) -> any LanguageModel {
    let layers = getLayers(from: model)
    
    guard !layers.isEmpty else {
        print("Warning: pipelineAutoParallel could not find any layers in model")
        return model
    }

    // extract designated layers
    let startLayer = modelShardMeta.startLayer
    let endLayer = modelShardMeta.endLayer
    let deviceRank = modelShardMeta.deviceRank
    let worldSize = modelShardMeta.worldSize
    
    let safeStart = max(0, min(startLayer, layers.count))
    let safeEnd = max(safeStart, min(endLayer, layers.count))
    
    let subsetLayers = Array(layers[safeStart..<safeEnd])
    guard !subsetLayers.isEmpty else {
        print("Warning: pipelineAutoParallel layer range [\(safeStart), \(safeEnd)) is empty")
        return model
    }
    
    // wrap first and last layers with pipeline communication
    let first = PipelineFirstLayer(originalLayer: subsetLayers[0], r: deviceRank, group: group)
    let last = PipelineLastLayer(originalLayer: subsetLayers.last!, r: deviceRank, s: worldSize, group: group)
    
    var newLayers = subsetLayers
    newLayers[0] = first
    newLayers[newLayers.count - 1] = last
    
    setLayers(on: model, newLayers: newLayers)

    return model
}


public func tensorAutoParallel(model: any LanguageModel, group: DistributedGroup) throws -> any LanguageModel {
    let strategy: TensorParallelShardingStrategy
    
    // Use proper type checking instead of string-based type name comparison
    if model is LlamaModel {
        strategy = LlamaShardingStrategy(group: group)
    } else if model is DeepseekV3Model {
        strategy = DeepSeekShardingStrategy(group: group)
    } else if model is Qwen3MoEModel {
        strategy = QwenShardingStrategy(group: group)
    } else {
        let typeName = String(describing: type(of: model))
        fatalError("Unsupported model type for tensor parallelism: \(typeName)")
    }
    
    return try strategy.shardModel(model) as! any LanguageModel
}

// MARK: - Custom Layers

public class CustomMlxLayer: Module {
    public let originalLayer: Module
    
    public init(originalLayer: Module) {
        self.originalLayer = originalLayer
        super.init()
    }
}

public class PipelineFirstLayer: CustomMlxLayer, TransformerLayer {
    public let r: Int
    public let group: DistributedGroup
    
    public init(originalLayer: Module, r: Int, group: DistributedGroup) {
        self.r = r
        self.group = group
        super.init(originalLayer: originalLayer)
    }
    
    public func callAsFunction(_ x: MLXArray, mask: MLXFast.ScaledDotProductAttentionMaskMode, cache: KVCache? = nil) -> MLXArray {
        var x = x
        if r != 0 {
            x = group.recvLike(x, source: Int32(r - 1))
        }
        
        if let layer = originalLayer as? TransformerLayer {
            return layer(x, mask: mask, cache: cache)
        }
        else if let layer = originalLayer as? UnaryLayer {
            return layer(x)
        }
        fatalError("PipelineFirstLayer: originalLayer signature not supported")
    }
}

public class PipelineLastLayer: CustomMlxLayer, TransformerLayer {

    public let r: Int
    public let s: Int
    public let group: DistributedGroup
    
    public init(originalLayer: Module, r: Int, s: Int, group: DistributedGroup) {
        self.r = r
        self.s = s
        self.group = group
        super.init(originalLayer: originalLayer)
    }

    public func callAsFunction(_ x: MLXArray, mask: MLXFast.ScaledDotProductAttentionMaskMode, cache: KVCache? = nil) -> MLXArray {
        var output: MLXArray
        if let layer = originalLayer as? TransformerLayer {
            output = layer(x, mask: mask, cache: cache)
        }
        else if let layer = originalLayer as? UnaryLayer {
            output = layer(x)
        }
        else {
            fatalError("PipelineLastLayer: originalLayer signature not supported")
        }

        if r != s - 1 {
            output = group.send(output, dest: Int32((r + 1) % s))
        }

        let gathered = group.allGather(output)
        let batchSize = output.dim(0)
        let totalSize = gathered.dim(0)
        let startIndex = totalSize - batchSize

        return gathered[startIndex..<totalSize]
    }

}

public class ShardedDeepseekV3MoE: CustomMlxLayer {
    public var shardingGroup: DistributedGroup? = nil
    
    public override init(originalLayer: Module) {
        super.init(originalLayer: originalLayer)
    }
    
    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        var x = x
        if let group = shardingGroup {
            x = MLXNN.sumGradients(group: group)(x)
        }
        
        var y: MLXArray
        if let layer = originalLayer as? UnaryLayer {
            y = layer(x)
        } else {
             fatalError("ShardedDeepseekV3MoE: originalLayer not UnaryLayer")
        }
        
        if let group = shardingGroup {
            y = group.allSum(y)
        }
        return y
    }
}

public class ShardedQwenMoE: CustomMlxLayer {
    public var shardingGroup: DistributedGroup? = nil
    
    public override init(originalLayer: Module) {
        super.init(originalLayer: originalLayer)
    }
    
    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        var x = x
        if let group = shardingGroup {
            x = MLXNN.sumGradients(group: group)(x)
        }
        
        var y: MLXArray
        if let layer = originalLayer as? UnaryLayer {
            y = layer(x)
        } else {
             fatalError("ShardedQwenMoE: originalLayer not UnaryLayer")
        }
        
        if let group = shardingGroup {
            y = group.allSum(y)
        }
        return y
    }
}


// MARK: - Strategies

public protocol TensorParallelShardingStrategy {
    var group: DistributedGroup { get }
    func shardModel(_ model: any LanguageModel) throws -> Module
}

extension TensorParallelShardingStrategy {
    public func shardLinear(_ module: Module, sharding: String) throws -> Module {
        try MLXNN.shardLinear(module: module, sharding: sharding, group: group)
    }
    
    public func shardInPlace(_ module: Module, sharding: String) throws {
        try MLXNN.shardInPlace(module: module, sharding: .left(sharding), group: group)
    }
}

public class LlamaShardingStrategy: TensorParallelShardingStrategy {
    public let group: DistributedGroup
    public let N: Int
    
    public init(group: DistributedGroup) {
        self.group = group
        self.N = Int(group.size)
    }
    
    public func shardModel(_ model: any LanguageModel) throws -> Module {
        let layers = getLayers(from: model)

        for layer in layers {
             let children = layer.children()
             
             if let attn = children[unwrapping: "self_attn"] {
                 let attnChildren = attn.children()
                 if let q = attnChildren[unwrapping: "q_proj"] { try attn.updateModule(key: "q_proj", shardLinear(q, sharding: "all-to-sharded")) }
                 if let k = attnChildren[unwrapping: "k_proj"] { try attn.updateModule(key: "k_proj", shardLinear(k, sharding: "all-to-sharded")) }
                 if let v = attnChildren[unwrapping: "v_proj"] { try attn.updateModule(key: "v_proj", shardLinear(v, sharding: "all-to-sharded")) }
                 if let o = attnChildren[unwrapping: "o_proj"] { try attn.updateModule(key: "o_proj", shardLinear(o, sharding: "sharded-to-all")) }
                 // TODO: Updating n_heads logic requires modifying the Attention object properties which is not easily supported in Swift without redesign.
             }
             
             if let mlp = children[unwrapping: "mlp"] {
                 let mlpChildren = mlp.children()
                 if let gate = mlpChildren[unwrapping: "gate_proj"] { try mlp.updateModule(key: "gate_proj", shardLinear(gate, sharding: "all-to-sharded")) }
                 if let down = mlpChildren[unwrapping: "down_proj"] { try mlp.updateModule(key: "down_proj", shardLinear(down, sharding: "sharded-to-all")) }
                 if let up = mlpChildren[unwrapping: "up_proj"] { try mlp.updateModule(key: "up_proj", shardLinear(up, sharding: "all-to-sharded")) }
             }
        }
        return model
    }
}

public class DeepSeekShardingStrategy: TensorParallelShardingStrategy {
    public let group: DistributedGroup
    public let N: Int
     
    public init(group: DistributedGroup) {
        self.group = group
        self.N = Int(group.size)
    }
     
    public func shardModel(_ model: any LanguageModel) throws -> Module {
        let layers = getLayers(from: model)
        
        for layer in layers {
             let children = layer.children()
             
             // Shard Self Attention
             if let attn = children[unwrapping: "self_attn"] {
                 let attnChildren = attn.children()
                 // Check if q_lora_rank is None (Deepseek V3 specifics)
                 // In Swift we check if "q_b_proj" exists vs "q_proj"
                 if let q = attnChildren[unwrapping: "q_proj"] {
                     try attn.updateModule(key: "q_proj", shardLinear(q, sharding: "all-to-sharded"))
                 } else if let qb = attnChildren[unwrapping: "q_b_proj"] {
                     try attn.updateModule(key: "q_b_proj", shardLinear(qb, sharding: "all-to-sharded"))
                 }
                 
                 if let kvb = attnChildren[unwrapping: "kv_b_proj"] {
                     try attn.updateModule(key: "kv_b_proj", shardLinear(kvb, sharding: "all-to-sharded"))
                 }
                 
                 if let o = attnChildren[unwrapping: "o_proj"] {
                     try attn.updateModule(key: "o_proj", shardLinear(o, sharding: "sharded-to-all"))
                 }
             }
             
             // Shard MLP
             if let mlp = children[unwrapping: "mlp"] {
                 let mlpType = String(describing: type(of: mlp))
                 
                 if mlpType.contains("DeepseekV3MLP") { // Standard MLP
                     let mlpChildren = mlp.children()
                     if let gate = mlpChildren[unwrapping: "gate_proj"] { try mlp.updateModule(key: "gate_proj", shardLinear(gate, sharding: "all-to-sharded")) }
                     if let down = mlpChildren[unwrapping: "down_proj"] { try mlp.updateModule(key: "down_proj", shardLinear(down, sharding: "sharded-to-all")) }
                     if let up = mlpChildren[unwrapping: "up_proj"] { try mlp.updateModule(key: "up_proj", shardLinear(up, sharding: "all-to-sharded")) }
                 } else { // MoE
                     // Shard in place
                     let mlpChildren = mlp.children()
                     
                     if let sharedExperts = mlpChildren[unwrapping: "shared_experts"] {
                         let seChildren = sharedExperts.children()
                         if let m = seChildren[unwrapping: "gate_proj"] { try shardInPlace(m, sharding: "all-to-sharded") }
                         if let m = seChildren[unwrapping: "down_proj"] { try shardInPlace(m, sharding: "sharded-to-all") }
                         if let m = seChildren[unwrapping: "up_proj"] { try shardInPlace(m, sharding: "all-to-sharded") }
                     }
                     
                     if let switchMlp = mlpChildren[unwrapping: "switch_mlp"] {
                         let swChildren = switchMlp.children()
                         if let m = swChildren[unwrapping: "gate_proj"] { try shardInPlace(m, sharding: "all-to-sharded") }
                         if let m = swChildren[unwrapping: "down_proj"] { try shardInPlace(m, sharding: "sharded-to-all") }
                         if let m = swChildren[unwrapping: "up_proj"] { try shardInPlace(m, sharding: "all-to-sharded") }
                     }
                     
                     // Replace MLP with Sharded wrapper
                     let wrapper = ShardedDeepseekV3MoE(originalLayer: mlp)
                     wrapper.shardingGroup = group
                     // Update the layer to use the wrapper
                     try layer.updateModule(key: "mlp", wrapper)
                 }
             }
        }
        return model
    }
}

public class QwenShardingStrategy: TensorParallelShardingStrategy {
     public let group: DistributedGroup
     public let N: Int
     
     public init(group: DistributedGroup) {
         self.group = group
         self.N = Int(group.size)
     }
     
     public func shardModel(_ model: any LanguageModel) throws -> Module {
        let layers = getLayers(from: model)
        
        for layer in layers {
             let children = layer.children()
             
             // Shard Self Attention
             if let attn = children[unwrapping: "self_attn"] {
                 let attnChildren = attn.children()
                 if let q = attnChildren[unwrapping: "q_proj"] { try attn.updateModule(key: "q_proj", shardLinear(q, sharding: "all-to-sharded")) }
                 if let k = attnChildren[unwrapping: "k_proj"] { try attn.updateModule(key: "k_proj", shardLinear(k, sharding: "all-to-sharded")) }
                 if let v = attnChildren[unwrapping: "v_proj"] { try attn.updateModule(key: "v_proj", shardLinear(v, sharding: "all-to-sharded")) }
                 if let o = attnChildren[unwrapping: "o_proj"] { try attn.updateModule(key: "o_proj", shardLinear(o, sharding: "sharded-to-all")) }
             }
             
             // Shard MLP or MoE
             if let mlp = children[unwrapping: "mlp"] {
                 let mlpType = String(describing: type(of: mlp))
                 
                 if mlpType.contains("Qwen3MoeSparseMoeBlock") {
                    // MoE
                    let mlpChildren = mlp.children()
                    if let switchMlp = mlpChildren[unwrapping: "switch_mlp"] {
                        let swChildren = switchMlp.children()
                        if let m = swChildren[unwrapping: "gate_proj"] { try shardInPlace(m, sharding: "all-to-sharded") }
                        if let m = swChildren[unwrapping: "down_proj"] { try shardInPlace(m, sharding: "sharded-to-all") }
                        if let m = swChildren[unwrapping: "up_proj"] { try shardInPlace(m, sharding: "all-to-sharded") }
                    }
                    
                    let wrapper = ShardedQwenMoE(originalLayer: mlp)
                    wrapper.shardingGroup = group
                    try layer.updateModule(key: "mlp", wrapper)
                    
                 } else {
                    // Standard MLP
                    let mlpChildren = mlp.children()
                    if let gate = mlpChildren[unwrapping: "gate_proj"] { try mlp.updateModule(key: "gate_proj", shardLinear(gate, sharding: "all-to-sharded")) }
                    if let down = mlpChildren[unwrapping: "down_proj"] { try mlp.updateModule(key: "down_proj", shardLinear(down, sharding: "sharded-to-all")) }
                    if let up = mlpChildren[unwrapping: "up_proj"] { try mlp.updateModule(key: "up_proj", shardLinear(up, sharding: "all-to-sharded")) }
                 }
             }
        }
        return model
     }
}

// MARK: - Helpers

/// Protocol for models that expose their inner model and layers for pipeline parallelism.
/// This allows type-safe access to the transformer layers without relying on children() dictionary.
public protocol PipelineParallelizable: Module {
    associatedtype InnerModel: Module
    associatedtype Layer: Module
    
    var innerModel: InnerModel { get }
    var layers: [Layer] { get set }
}

// MARK: - Type-specific layer access

/// Get the inner model from a LanguageModel.
func getInnerModel(_ model: any LanguageModel) -> Module? {
    if let llama = model as? LlamaModel {
        return llama.model
    }
    if let deepseek = model as? DeepseekV3Model {
        return deepseek.model
    }
    if let qwen = model as? Qwen3MoEModel {
        return qwen.model
    }
    if let qwen = model as? Qwen3Model {
        return qwen.model
    }
    if let lfm = model as? LFM2Model {
        return lfm.model
    }

    // Fallback:
    let children = model.children()
    if let m = children[unwrapping: "model"] { return m }
    if let t = children[unwrapping: "transformer"] { return t }
    
    return nil
}

/// Get transformer layers from a LanguageModel
func getLayers(from model: any LanguageModel) -> [TransformerLayer] {
    if let llama = model as? LlamaModel {
        return llama.model.layers
    }
    if let deepseek = model as? DeepseekV3Model {
        return deepseek.model.layers
    }
    if let qwen = model as? Qwen3MoEModel {
        return qwen.model.layers
    }
    if let qwen = model as? Qwen3Model {
        return qwen.model.layers
    }
    if let lfm = model as? LFM2Model {
        return lfm.model.layers
    }

    // Fallback:
    if let inner = getInnerModel(model) {
        let children = inner.children()
        if let layers = children[unwrapping: "layers"] {
            return layers.modules() as? [TransformerLayer] ?? []
        }
        if let h = children[unwrapping: "h"] {
            return h.modules() as? [TransformerLayer] ?? []
        }
    }
    
    return []
}

/// Set transformer layers on a LanguageModel.
/// Uses type-specific property access for reliable layer assignment.
func setLayers(on model: any LanguageModel, newLayers: [TransformerLayer]) {
    if let llama = model as? LlamaModel {
        llama.model.layers = newLayers
        llama.model.rebuildCaches()
    }
    else if let deepseek = model as? DeepseekV3Model {
        deepseek.model.layers = newLayers
        deepseek.model.endIdx = newLayers.count
        deepseek.model.numLayers = newLayers.count
        deepseek.model.rebuildCaches()
    }
    else if let qwen = model as? Qwen3MoEModel {
        qwen.model.layers = newLayers
        qwen.model.rebuildCaches()
    }
    else if let qwen = model as? Qwen3Model {
        qwen.model.layers = newLayers
        qwen.model.rebuildCaches()
    }
    else if let lfm = model as? LFM2Model {
        lfm.model.layers = newLayers
        lfm.model.rebuildCaches()
    }
    else {
        // Fallback: try children() based approach
        guard let inner = getInnerModel(model) else { return }
        let children = inner.children()

        let prefix: String
        if children["layers"] != nil {
            prefix = "layers"
        } else if children["h"] != nil {
            prefix = "h"
        } else {
            prefix = "layers"
        }

        do {
            try inner.updateModule(key: prefix, newLayers)
            inner.rebuildCaches()
        }
        catch {
            print("Couldn't update inner model layers \(error) for model \(String(describing: type(of: model)))")
        }
    }

}

