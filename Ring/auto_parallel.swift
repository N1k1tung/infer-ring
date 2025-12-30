
import Foundation
import MLX
import MLXNN
// import Models // Implicitly assumed available

// MARK: - Auto Parallel Functions

/// Automatically parallelize a model across multiple devices using pipeline parallelism.
public func pipelineAutoParallel(
    model: Module,
    group: DistributedGroup,
    modelShardMeta: PipelineShardMetadata
) -> Module {
    let inner = innerModel(model)
    let layers = getLayers(inner)
    
    let startLayer = modelShardMeta.startLayer
    let endLayer = modelShardMeta.endLayer
    let deviceRank = modelShardMeta.deviceRank
    let worldSize = modelShardMeta.worldSize
    
    // Safety check indices
    let safeStart = max(0, min(startLayer, layers.count))
    let safeEnd = max(safeStart, min(endLayer, layers.count))
    
    let subsetLayers = Array(layers[safeStart..<safeEnd])
    guard !subsetLayers.isEmpty else { return model }
    
    let first = PipelineFirstLayer(originalLayer: subsetLayers[0], r: deviceRank, group: group)
    let last = PipelineLastLayer(originalLayer: subsetLayers.last!, r: deviceRank, s: worldSize, group: group)
    
    var newLayers = subsetLayers
    newLayers[0] = first
    newLayers[newLayers.count - 1] = last
    
    setLayers(model, newLayers: newLayers)
    
    return model
}


public func tensorAutoParallel(model: Module, group: DistributedGroup) -> Module {
    let strategy: TensorParallelShardingStrategy
    
    let typeName = String(describing: type(of: model))
    
    if typeName.contains("LlamaModel") {
        strategy = LlamaShardingStrategy(group: group)
    } else if typeName.contains("DeepseekV3Model") {
        strategy = DeepSeekShardingStrategy(group: group)
    } else if typeName.contains("Qwen3MoeModel") {
        strategy = QwenShardingStrategy(group: group)
    } else {
        fatalError("Unsupported model type: \(typeName)")
    }
    
    return strategy.shardModel(model)
}

// MARK: - Custom Layers

public class CustomMlxLayer: Module {
    public let originalLayer: Module
    
    public init(originalLayer: Module) {
        self.originalLayer = originalLayer
        super.init()
    }
}

public class PipelineFirstLayer: CustomMlxLayer {
    public let r: Int
    public let group: DistributedGroup
    
    public init(originalLayer: Module, r: Int, group: DistributedGroup) {
        self.r = r
        self.group = group
        super.init(originalLayer: originalLayer)
    }
    
    public func callAsFunction(_ x: MLXArray, mask: MLXArray? = nil, cache: AnyObject? = nil) -> MLXArray {
        var x = x
        if r != 0 {
            x = group.recvLike(x, source: Int32(r - 1))
        }
        
        if let layer = originalLayer as? LlamaTransformerBlockLike {
            return layer(x, mask: mask, cache: cache)
        } else if let layer = originalLayer as? UnaryLayerLike {
            return layer(x)
        }
        fatalError("PipelineFirstLayer: originalLayer signature not supported")
    }
}

public class PipelineLastLayer: CustomMlxLayer {
    public let r: Int
    public let s: Int
    public let group: DistributedGroup
    
    public init(originalLayer: Module, r: Int, s: Int, group: DistributedGroup) {
        self.r = r
        self.s = s
        self.group = group
        super.init(originalLayer: originalLayer)
    }
    
    public func callAsFunction(_ x: MLXArray, mask: MLXArray? = nil, cache: AnyObject? = nil) -> MLXArray {
        var output: MLXArray
        if let layer = originalLayer as? LlamaTransformerBlockLike {
            output = layer(x, mask: mask, cache: cache)
        } else if let layer = originalLayer as? UnaryLayerLike {
            output = layer(x)
        } else {
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
        if let layer = originalLayer as? UnaryLayerLike {
            y = layer(x)
        } else {
             fatalError("ShardedDeepseekV3MoE: originalLayer not UnaryLayerLike")
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
        if let layer = originalLayer as? UnaryLayerLike {
            y = layer(x)
        } else {
             fatalError("ShardedQwenMoE: originalLayer not UnaryLayerLike")
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
    func shardModel(_ model: Module) -> Module
}

extension TensorParallelShardingStrategy {
    public func shardLinear(_ module: Module, sharding: String) -> Module {
        return try! MLXNN.shardLinear(module: module, sharding: sharding, group: group)
    }
    
    public func shardInPlace(_ module: Module, sharding: String) {
        try! MLXNN.shardInPlace(module: module, sharding: .left(sharding), group: group)
    }
}

public class LlamaShardingStrategy: TensorParallelShardingStrategy {
    public let group: DistributedGroup
    public let N: Int
    
    public init(group: DistributedGroup) {
        self.group = group
        self.N = Int(group.size)
    }
    
    public func shardModel(_ model: Module) -> Module {
        let inner = innerModel(model)
        let layers = getLayers(inner)
        
        for layer in layers {
             let children = layer.children()
             
             if let attn = children[unwrapping: "self_attn"] {
                 let attnChildren = attn.children()
                 if let q = attnChildren[unwrapping: "q_proj"] { try! attn.updateModule(key: "q_proj", shardLinear(q, sharding: "all-to-sharded")) }
                 if let k = attnChildren[unwrapping: "k_proj"] { try! attn.updateModule(key: "k_proj", shardLinear(k, sharding: "all-to-sharded")) }
                 if let v = attnChildren[unwrapping: "v_proj"] { try! attn.updateModule(key: "v_proj", shardLinear(v, sharding: "all-to-sharded")) }
                 if let o = attnChildren[unwrapping: "o_proj"] { try! attn.updateModule(key: "o_proj", shardLinear(o, sharding: "sharded-to-all")) }
                 // Note: Updating n_heads logic requires modifying the Attention object properties which is not easily supported in Swift without redesign.
             }
             
             if let mlp = children[unwrapping: "mlp"] {
                 let mlpChildren = mlp.children()
                 if let gate = mlpChildren[unwrapping: "gate_proj"] { try! mlp.updateModule(key: "gate_proj", shardLinear(gate, sharding: "all-to-sharded")) }
                 if let down = mlpChildren[unwrapping: "down_proj"] { try! mlp.updateModule(key: "down_proj", shardLinear(down, sharding: "sharded-to-all")) }
                 if let up = mlpChildren[unwrapping: "up_proj"] { try! mlp.updateModule(key: "up_proj", shardLinear(up, sharding: "all-to-sharded")) }
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
     
    public func shardModel(_ model: Module) -> Module {
        let inner = innerModel(model)
        let layers = getLayers(inner)
        
        for layer in layers {
             let children = layer.children()
             
             // Shard Self Attention
             if let attn = children[unwrapping: "self_attn"] {
                 let attnChildren = attn.children()
                 // Check if q_lora_rank is None (Deepseek V3 specifics)
                 // In Swift we check if "q_b_proj" exists vs "q_proj"
                 if let q = attnChildren[unwrapping: "q_proj"] {
                     try! attn.updateModule(key: "q_proj", shardLinear(q, sharding: "all-to-sharded"))
                 } else if let qb = attnChildren[unwrapping: "q_b_proj"] {
                     try! attn.updateModule(key: "q_b_proj", shardLinear(qb, sharding: "all-to-sharded"))
                 }
                 
                 if let kvb = attnChildren[unwrapping: "kv_b_proj"] {
                     try! attn.updateModule(key: "kv_b_proj", shardLinear(kvb, sharding: "all-to-sharded"))
                 }
                 
                 if let o = attnChildren[unwrapping: "o_proj"] {
                     try! attn.updateModule(key: "o_proj", shardLinear(o, sharding: "sharded-to-all"))
                 }
             }
             
             // Shard MLP
             if let mlp = children[unwrapping: "mlp"] {
                 let mlpType = String(describing: type(of: mlp))
                 
                 if mlpType.contains("DeepseekV3MLP") { // Standard MLP
                     let mlpChildren = mlp.children()
                     if let gate = mlpChildren[unwrapping: "gate_proj"] { try! mlp.updateModule(key: "gate_proj", shardLinear(gate, sharding: "all-to-sharded")) }
                     if let down = mlpChildren[unwrapping: "down_proj"] { try! mlp.updateModule(key: "down_proj", shardLinear(down, sharding: "sharded-to-all")) }
                     if let up = mlpChildren[unwrapping: "up_proj"] { try! mlp.updateModule(key: "up_proj", shardLinear(up, sharding: "all-to-sharded")) }
                 } else { // MoE
                     // Shard in place
                     let mlpChildren = mlp.children()
                     
                     if let sharedExperts = mlpChildren[unwrapping: "shared_experts"] {
                         let seChildren = sharedExperts.children()
                         if let m = seChildren[unwrapping: "gate_proj"] { shardInPlace(m, sharding: "all-to-sharded") }
                         if let m = seChildren[unwrapping: "down_proj"] { shardInPlace(m, sharding: "sharded-to-all") }
                         if let m = seChildren[unwrapping: "up_proj"] { shardInPlace(m, sharding: "all-to-sharded") }
                     }
                     
                     if let switchMlp = mlpChildren[unwrapping: "switch_mlp"] {
                         let swChildren = switchMlp.children()
                         if let m = swChildren[unwrapping: "gate_proj"] { shardInPlace(m, sharding: "all-to-sharded") }
                         if let m = swChildren[unwrapping: "down_proj"] { shardInPlace(m, sharding: "sharded-to-all") }
                         if let m = swChildren[unwrapping: "up_proj"] { shardInPlace(m, sharding: "all-to-sharded") }
                     }
                     
                     // Replace MLP with Sharded wrapper
                     let wrapper = ShardedDeepseekV3MoE(originalLayer: mlp)
                     wrapper.shardingGroup = group
                     // Update the layer to use the wrapper
                     try! layer.updateModule(key: "mlp", wrapper)
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
     
     public func shardModel(_ model: Module) -> Module {
        let inner = innerModel(model)
        let layers = getLayers(inner)
        
        for layer in layers {
             let children = layer.children()
             
             // Shard Self Attention
             if let attn = children[unwrapping: "self_attn"] {
                 let attnChildren = attn.children()
                 if let q = attnChildren[unwrapping: "q_proj"] { try! attn.updateModule(key: "q_proj", shardLinear(q, sharding: "all-to-sharded")) }
                 if let k = attnChildren[unwrapping: "k_proj"] { try! attn.updateModule(key: "k_proj", shardLinear(k, sharding: "all-to-sharded")) }
                 if let v = attnChildren[unwrapping: "v_proj"] { try! attn.updateModule(key: "v_proj", shardLinear(v, sharding: "all-to-sharded")) }
                 if let o = attnChildren[unwrapping: "o_proj"] { try! attn.updateModule(key: "o_proj", shardLinear(o, sharding: "sharded-to-all")) }
             }
             
             // Shard MLP or MoE
             if let mlp = children[unwrapping: "mlp"] {
                 let mlpType = String(describing: type(of: mlp))
                 
                 if mlpType.contains("Qwen3MoeSparseMoeBlock") {
                    // MoE
                    let mlpChildren = mlp.children()
                    if let switchMlp = mlpChildren[unwrapping: "switch_mlp"] {
                        let swChildren = switchMlp.children()
                        if let m = swChildren[unwrapping: "gate_proj"] { shardInPlace(m, sharding: "all-to-sharded") }
                        if let m = swChildren[unwrapping: "down_proj"] { shardInPlace(m, sharding: "sharded-to-all") }
                        if let m = swChildren[unwrapping: "up_proj"] { shardInPlace(m, sharding: "all-to-sharded") }
                    }
                    
                    let wrapper = ShardedQwenMoE(originalLayer: mlp)
                    wrapper.shardingGroup = group
                    try! layer.updateModule(key: "mlp", wrapper)
                    
                 } else {
                    // Standard MLP
                    let mlpChildren = mlp.children()
                    if let gate = mlpChildren[unwrapping: "gate_proj"] { try! mlp.updateModule(key: "gate_proj", shardLinear(gate, sharding: "all-to-sharded")) }
                    if let down = mlpChildren[unwrapping: "down_proj"] { try! mlp.updateModule(key: "down_proj", shardLinear(down, sharding: "sharded-to-all")) }
                    if let up = mlpChildren[unwrapping: "up_proj"] { try! mlp.updateModule(key: "up_proj", shardLinear(up, sharding: "all-to-sharded")) }
                 }
             }
        }
        return model
     }
}

// MARK: - Helpers

public protocol LlamaTransformerBlockLike {
    func callAsFunction(_ x: MLXArray, mask: MLXArray?, cache: AnyObject?) -> MLXArray
}

public protocol UnaryLayerLike {
    func callAsFunction(_ x: MLXArray) -> MLXArray
}

func innerModel(_ model: Module) -> Module {
    let children = model.children()
    if let m = children[unwrapping: "model"] { return m }
    if let t = children[unwrapping: "transformer"] { return t }
    return model
}

func getLayers(_ innerModel: Module) -> [Module] {
    let children = innerModel.children()
    if let m = children[unwrapping: "layers"] { return m.modules() }
    else if let t = children[unwrapping: "h"] { return t.modules() }
    return []

}

func setLayers(_ model: Module, newLayers: [Module]) {
    let inner = innerModel(model)
    let children = inner.children()
    let prefix: String
    if children["layers"] != nil {
        prefix = "layers"
//        # Update DeepSeek V3 specific parameters when layers are shrunk
//        if isinstance(model, DeepseekV3Model) and hasattr(
//            inner_model_instance, "num_layers"
//        ):
//                inner_model_instance.start_idx = 0
//            inner_model_instance.end_idx = len(layers)
//            inner_model_instance.num_layers = len(layers)
    } else if children["h"] != nil {
        prefix = "h"
    } else {
        // throw error
        prefix = "layers"
    }
    
    try? inner.updateModule(key: prefix, newLayers)
}
