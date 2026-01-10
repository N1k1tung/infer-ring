import Foundation
import MLX
import MLXNN
import MLXLMCommon
import MLXLLM

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

    // handle custom cache allocation for LFM2
    if let lfm2 = model as? LFM2Model {
        lfm2.shardOffset = safeStart
    }

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

// MARK: - Helpers

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

/// Set transformer layers on a LanguageModel
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
        // Fallback:
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

