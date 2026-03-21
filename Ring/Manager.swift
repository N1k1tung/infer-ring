//
import Foundation
import Darwin
import MLX
import MLXLMCommon
import MLXLLM
import MLXVLM
import MLXNN

public final class MLXManager {
    public init() {}

    private var group: DistributedGroup?

    public func initMLX(rank: Int, devices: [String]) throws {
        let port = 13373
        let json = try JSONEncoder().encode(devices.map {
            ["\($0):\(port)", "\($0):\(port+1)"]
        })
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        if !FileManager.default.fileExists(atPath: cachesDir.path) {
            try FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true)
        }
        let hostfileUrl = cachesDir.appendingPathComponent("mlx_hostfile.json")
        try json.write(to: hostfileUrl)
        print("Initializing MLX ring with rank \(rank)")
        setenv("MLX_HOSTFILE", hostfileUrl.path, 1)
        setenv("MLX_RANK", "\(rank)", 1)
        #if DEBUG
        setenv("MLX_RING_VERBOSE", "1", 1)
        #endif

        try MLX.withError {
            group = DistributedGroup.initialize(strict: true)
        }
    }

    public func synchronize() {
        guard let group else {
            print("group not initialized")
            return
        }

        group.allSum(MLXArray(1.0)).eval()
    }

    public func validate() {
        guard let group else {
            print("group not initialized")
            return
        }
        let key = MLXRandom.key(0)
        let value = MLXRandom.uniform(-100.0 ..< 100, [2,4,6], key: key)
        let f16 = value.asType(.float16)
        let sum = group.allSum(f16)
        let size = Float(group.size)
        let expected = f16 * size
        let diff = abs(sum - expected).max()
        
        if diff.item(Float.self) < 1e-3 {
            print("Distributed validation passed!")
        } else {
            print("Distributed validation failed! Max difference: \(diff.item(Float.self))")
        }
    }

    public func loadModel(
        _ card: ModelCard,
        shardMeta: ShardMetadata,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> ModelContext {
        Memory.clearCache()

        let factory: ModelFactory = card.isVisionModel ? VLMModelFactory.shared : LLMModelFactory.shared
        var context = try await factory.load(
            configuration: ModelConfiguration(id: card.modelId),
            lazy: group != nil,
            progressHandler: progressHandler
        )

        if let group {
            if shardMeta.useTensorParallel && card.metadata.supportsTensor {
                context.model = tensorAutoParallel(
                    model: context.model,
                    group: group
                )
            }
            else {
                context.model = pipelineAutoParallel(
                    model: context.model,
                    group: group,
                    modelShardMeta: shardMeta
                )
            }
            eval(context.model)
        }

        return context
    }

}
