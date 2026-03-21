import Foundation
import MLX
import MLXNN
import MLXLMCommon
import MLXLLM
import MLXVLM

// adapted from https://github.com/exo-explore/exo/blob/main/src/exo/worker/engines/mlx/auto_parallel.py

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
    modelShardMeta: ShardMetadata
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
    if model is GPTOSSModel {
        last.forceDType = .bfloat16
    }

    setLayers(on: model, newLayers: newLayers, shardOffset: safeStart)

    return model
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
    var forceDType: DType? = nil // MLX GPTOSS is bugged? layer output becomes f32 from bf16

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

        if let forceDType {
            output = output.asType(forceDType)
        }

        if r != s - 1 {
            output = group.send(output, dest: Int32((r + 1) % s))
        }

        let gathered = group.allGather(output)
        let batchSize = output.dim(0)
        let totalSize = gathered.dim(0)
        let startIndex = totalSize - batchSize

        if output.dim(1) > 1, var cache { // setup dependency to make sure batched prefill is not deadlocked
            cache.state = depends(inputs: cache.state, dependencies: Array(gathered[startIndex..<totalSize]))
        }

        return gathered[startIndex..<totalSize]
    }

}

// MARK: - Helpers

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
    if let gpt = model as? GPTOSSModel {
        return gpt.model.layers
    }
    if let glm = model as? GLM4MoELiteModel {
        return glm.model.layers
    }

    return []
}

/// Set transformer layers on a LanguageModel
func setLayers(on model: any LanguageModel, newLayers: [TransformerLayer], shardOffset: Int) {
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
        lfm.shardOffset = shardOffset
        lfm.model.rebuildCaches()
    }
    else if let gpt = model as? GPTOSSModel {
        gpt.model.layers = newLayers
        gpt.model.layerTypes = Array(gpt.model.layerTypes[shardOffset..<shardOffset+newLayers.count])
        gpt.model.slidingAttentionIndex = gpt.model.layerTypes.firstIndex(of: "sliding_attention") ?? 0
        gpt.model.fullAttentionIndex = gpt.model.layerTypes.firstIndex(of: "full_attention") ?? 0
        gpt.model.rebuildCaches()
    }
    else if let glm = model as? GLM4MoELiteModel {
        glm.model.layers = newLayers
        glm.model.rebuildCaches()
    }
    else {
        print("Couldn't update hidden layers for model \(String(describing: type(of: model)))")
    }

}

