import Foundation

// adapted from https://github.com/exo-explore/exo/blob/main/src/exo/shared/models/model_cards.py

extension MemorySize {
    static func from_kb(_ kb: Int) -> MemorySize {
        return MemorySize(inBytes: kb * 1024)
    }
    
    static func from_mb(_ mb: Int) -> MemorySize {
        return MemorySize(inBytes: mb * 1024 * 1024)
    }
    
    static func from_gb(_ gb: Int) -> MemorySize {
        return MemorySize(inBytes: gb * 1024 * 1024 * 1024)
    }
    
    static func from_bytes(_ bytes: Int) -> MemorySize {
        return MemorySize(inBytes: bytes)
    }
}

public struct ModelCard: Codable, Equatable, Sendable {
    public let shortId: String
    public let modelId: String
    public let name: String
    public let description: String
    public let tags: [String]
    public let metadata: ModelMetadata
}

public struct ModelCards {
    public static let otherModels: [String: ModelCard] = [
        // deepseek v3
        "DeepSeek-V3.1-4bit": ModelCard(
            shortId: "DeepSeek-V3.1-4bit",
            modelId: "mlx-community/DeepSeek-V3.1-4bit",
            name: "DeepSeek V3.1 (4-bit)",
            description: """
        DeepSeek V3.1 is a large language model trained on the DeepSeek V3.1 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/DeepSeek-V3.1-4bit",
                prettyName: "DeepSeek V3.1 (4-bit)",
                storageSize: MemorySize.from_gb(378),
                nLayers: 61,
                hiddenSize: 7168
            )
        ),
        "DeepSeek-V3.1-8bit": ModelCard(
            shortId: "DeepSeek-V3.1-8bit",
            modelId: "mlx-community/DeepSeek-V3.1-8bit",
            name: "DeepSeek V3.1 (8-bit)",
            description: """
        DeepSeek V3.1 is a large language model trained on the DeepSeek V3.1 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/DeepSeek-V3.1-8bit",
                prettyName: "DeepSeek V3.1 (8-bit)",
                storageSize: MemorySize.from_gb(713),
                nLayers: 61,
                hiddenSize: 7168
            )
        ),
        // kimi k2
        "Kimi-K2-Instruct-4bit": ModelCard(
            shortId: "Kimi-K2-Instruct-4bit",
            modelId: "mlx-community/Kimi-K2-Instruct-4bit",
            name: "Kimi K2 Instruct (4-bit)",
            description: """
        Kimi K2 is a large language model trained on the Kimi K2 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Kimi-K2-Instruct-4bit",
                prettyName: "Kimi K2 Instruct (4-bit)",
                storageSize: MemorySize.from_gb(578),
                nLayers: 61,
                hiddenSize: 7168
            )
        ),
        "Kimi-K2-Thinking": ModelCard(
            shortId: "Kimi-K2-Thinking",
            modelId: "mlx-community/Kimi-K2-Thinking",
            name: "Kimi K2 Thinking (4-bit)",
            description: """
        Kimi K2 Thinking is the latest, most capable version of open-source thinking model.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Kimi-K2-Thinking",
                prettyName: "Kimi K2 Thinking (4-bit)",
                storageSize: MemorySize.from_gb(658),
                nLayers: 61,
                hiddenSize: 7168
            )
        ),
        "Qwen3-235B-A22B-Instruct-2507-4bit": ModelCard(
            shortId: "Qwen3-235B-A22B-Instruct-2507-4bit",
            modelId: "mlx-community/Qwen3-235B-A22B-Instruct-2507-4bit",
            name: "Qwen3 235B A22B (4-bit)",
            description: """
        Qwen3 235B (Active 22B) is a large language model trained on the Qwen3 235B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-235B-A22B-Instruct-2507-4bit",
                prettyName: "Qwen3 235B A22B (4-bit)",
                storageSize: MemorySize.from_gb(132),
                nLayers: 94,
                hiddenSize: 4096
            )
        ),
        "Qwen3-235B-A22B-Instruct-2507-8bit": ModelCard(
            shortId: "Qwen3-235B-A22B-Instruct-2507-8bit",
            modelId: "mlx-community/Qwen3-235B-A22B-Instruct-2507-8bit",
            name: "Qwen3 235B A22B (8-bit)",
            description: """
        Qwen3 235B (Active 22B) is a large language model trained on the Qwen3 235B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-235B-A22B-Instruct-2507-8bit",
                prettyName: "Qwen3 235B A22B (8-bit)",
                storageSize: MemorySize.from_gb(250),
                nLayers: 94,
                hiddenSize: 4096
            )
        ),
        "Qwen3-Coder-480B-A35B-Instruct-4bit": ModelCard(
            shortId: "Qwen3-Coder-480B-A35B-Instruct-4bit",
            modelId: "mlx-community/Qwen3-Coder-480B-A35B-Instruct-4bit",
            name: "Qwen3 Coder 480B A35B (4-bit)",
            description: """
        Qwen3 Coder 480B (Active 35B) is a large language model trained on the Qwen3 Coder 480B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Coder-480B-A35B-Instruct-4bit",
                prettyName: "Qwen3 Coder 480B A35B (4-bit)",
                storageSize: MemorySize.from_gb(270),
                nLayers: 62,
                hiddenSize: 6144
            )
        ),
        "Qwen3-Coder-480B-A35B-Instruct-8bit": ModelCard(
            shortId: "Qwen3-Coder-480B-A35B-Instruct-8bit",
            modelId: "mlx-community/Qwen3-Coder-480B-A35B-Instruct-8bit",
            name: "Qwen3 Coder 480B A35B (8-bit)",
            description: """
        Qwen3 Coder 480B (Active 35B) is a large language model trained on the Qwen3 Coder 480B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Coder-480B-A35B-Instruct-8bit",
                prettyName: "Qwen3 Coder 480B A35B (8-bit)",
                storageSize: MemorySize.from_gb(540),
                nLayers: 62,
                hiddenSize: 6144
            )
        ),
        "GLM-4.5-Air-8bit": ModelCard(
            shortId: "GLM-4.5-Air-8bit",
            modelId: "mlx-community/GLM-4.5-Air-8bit",
            name: "GLM 4.5 Air 8bit",
            description: """
        GLM 4.5 Air 8bit
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/GLM-4.5-Air-8bit",
                prettyName: "GLM 4.5 Air 8bit",
                storageSize: MemorySize.from_gb(114),
                nLayers: 46,
                hiddenSize: 4096
            )
        ),
        "GLM-4.5-Air-bf16": ModelCard(
            shortId: "GLM-4.5-Air-bf16",
            modelId: "mlx-community/GLM-4.5-Air-bf16",
            name: "GLM 4.5 Air bf16",
            description: """
        GLM 4.5 Air bf16
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/GLM-4.5-Air-bf16",
                prettyName: "GLM 4.5 Air bf16",
                storageSize: MemorySize.from_gb(214),
                nLayers: 46,
                hiddenSize: 4096
            )
        ),

        // llama-3.1
        "Meta-Llama-3.1-8B-Instruct-4bit": ModelCard(
            shortId: "Meta-Llama-3.1-8B-Instruct-4bit",
            modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
            name: "Llama 3.1 8B (4-bit)",
            description: """
        Llama 3.1 is a large language model trained on the Llama 3.1 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
                prettyName: "Llama 3.1 8B (4-bit)",
                storageSize: MemorySize.from_mb(4423),
                nLayers: 32,
                hiddenSize: 4096
            )
        ),
        "Meta-Llama-3.1-8B-Instruct-8bit": ModelCard(
            shortId: "Meta-Llama-3.1-8B-Instruct-8bit",
            modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-8bit",
            name: "Llama 3.1 8B (8-bit)",
            description: """
        Llama 3.1 is a large language model trained on the Llama 3.1 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-8bit",
                prettyName: "Llama 3.1 8B (8-bit)",
                storageSize: MemorySize.from_mb(8540),
                nLayers: 32,
                hiddenSize: 4096
            )
        ),
        "Meta-Llama-3.1-8B-Instruct-bf16": ModelCard(
            shortId: "Meta-Llama-3.1-8B-Instruct-bf16",
            modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-bf16",
            name: "Llama 3.1 8B (BF16)",
            description: """
        Llama 3.1 is a large language model trained on the Llama 3.1 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-bf16",
                prettyName: "Llama 3.1 8B (BF16)",
                storageSize: MemorySize.from_mb(16100),
                nLayers: 32,
                hiddenSize: 4096
            )
        ),
        // llama
        "Meta-Llama-3.1-70B-Instruct-4bit": ModelCard(
            shortId: "Meta-Llama-3.1-70B-Instruct-4bit",
            modelId: "mlx-community/Meta-Llama-3.1-70B-Instruct-4bit",
            name: "Llama 3.1 70B (4-bit)",
            description: """
        Llama 3.1 is a large language model trained on the Llama 3.1 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Meta-Llama-3.1-70B-Instruct-4bit",
                prettyName: "Llama 3.1 70B (4-bit)",
                storageSize: MemorySize.from_mb(38769),
                nLayers: 80,
                hiddenSize: 8192
            )
        ),
        // llama-3.2
        "Llama-3.2-1B-Instruct-4bit": ModelCard(
            shortId: "Llama-3.2-1B-Instruct-4bit",
            modelId: "mlx-community/Llama-3.2-1B-Instruct-4bit",
            name: "Llama 3.2 1B (4-bit)",
            description: """
        Llama 3.2 is a large language model trained on the Llama 3.2 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Llama-3.2-1B-Instruct-4bit",
                prettyName: "Llama 3.2 1B (4-bit)",
                storageSize: MemorySize.from_mb(696),
                nLayers: 16,
                hiddenSize: 2048
            )
        ),
        "Llama-3.2-3B-Instruct-4bit": ModelCard(
            shortId: "Llama-3.2-3B-Instruct-4bit",
            modelId: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "Llama 3.2 3B (4-bit)",
            description: """
        Llama 3.2 is a large language model trained on the Llama 3.2 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Llama-3.2-3B-Instruct-4bit",
                prettyName: "Llama 3.2 3B (4-bit)",
                storageSize: MemorySize.from_mb(1777),
                nLayers: 28,
                hiddenSize: 3072
            )
        ),
        "Llama-3.2-3B-Instruct-8bit": ModelCard(
            shortId: "Llama-3.2-3B-Instruct-8bit",
            modelId: "mlx-community/Llama-3.2-3B-Instruct-8bit",
            name: "Llama 3.2 3B (8-bit)",
            description: """
        Llama 3.2 is a large language model trained on the Llama 3.2 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Llama-3.2-3B-Instruct-8bit",
                prettyName: "Llama 3.2 3B (8-bit)",
                storageSize: MemorySize.from_mb(3339),
                nLayers: 28,
                hiddenSize: 3072
            )
        ),
        // llama-3.3
        "Llama-3.3-70B-Instruct-4bit": ModelCard(
            shortId: "Llama-3.3-70B-Instruct-4bit",
            modelId: "mlx-community/Llama-3.3-70B-Instruct-4bit",
            name: "Llama 3.3 70B (4-bit)",
            description: """
        The Meta Llama 3.3 multilingual large language model (LLM) is an instruction tuned generative model in 70B (text in/text out)
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Llama-3.3-70B-Instruct-4bit",
                prettyName: "Llama 3.3 70B",
                storageSize: MemorySize.from_mb(38769),
                nLayers: 80,
                hiddenSize: 8192
            )
        ),
        "Llama-3.3-70B-Instruct-8bit": ModelCard(
            shortId: "Llama-3.3-70B-Instruct-8bit",
            modelId: "mlx-community/Llama-3.3-70B-Instruct-8bit",
            name: "Llama 3.3 70B (8-bit)",
            description: """
        The Meta Llama 3.3 multilingual large language model (LLM) is an instruction tuned generative model in 70B (text in/text out)
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Llama-3.3-70B-Instruct-8bit",
                prettyName: "Llama 3.3 70B (8-bit)",
                storageSize: MemorySize.from_mb(73242),
                nLayers: 80,
                hiddenSize: 8192
            )
        ),
        ]
    public static let allModels: [String: ModelCard] = [
        // qwen3
        "Qwen3-0.6B-4bit": ModelCard(
            shortId: "Qwen3-0.6B-4bit",
            modelId: "mlx-community/Qwen3-0.6B-4bit",
            name: "Qwen3 0.6B (4-bit)",
            description: """
        Qwen3 0.6B is a large language model trained on the Qwen3 0.6B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-0.6B-4bit",
                prettyName: "Qwen3 0.6B (4-bit)",
                storageSize: MemorySize.from_mb(327),
                nLayers: 28,
                hiddenSize: 1024
            )
        ),
        "Qwen3-0.6B-8bit": ModelCard(
            shortId: "Qwen3-0.6B-8bit",
            modelId: "mlx-community/Qwen3-0.6B-8bit",
            name: "Qwen3 0.6B (8-bit)",
            description: """
        Qwen3 0.6B is a large language model trained on the Qwen3 0.6B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-0.6B-8bit",
                prettyName: "Qwen3 0.6B (8-bit)",
                storageSize: MemorySize.from_mb(666),
                nLayers: 28,
                hiddenSize: 1024
            )
        ),
        "Qwen3-4B-4bit": ModelCard(
            shortId: "Qwen3-4B-4bit",
            modelId: "mlx-community/Qwen3-4B-4bit",
            name: "Qwen3 4B (4-bit)",
            description: """
        Qwen3 4B is a large language model trained on the Qwen3 4B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-4B-4bit",
                prettyName: "Qwen3 4B (4-bit)",
                storageSize: MemorySize.from_mb(2335),
                nLayers: 36,
                hiddenSize: 2560
            )
        ),
        "Qwen3-4B-8bit": ModelCard(
            shortId: "Qwen3-4B-8bit",
            modelId: "mlx-community/Qwen3-4B-8bit",
            name: "Qwen3 4B (8-bit)",
            description: """
        Qwen3 4B is a large language model trained on the Qwen3 4B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-4B-8bit",
                prettyName: "Qwen3 4B (8-bit)",
                storageSize: MemorySize.from_mb(4393),
                nLayers: 36,
                hiddenSize: 2560
            )
        ),
        "Qwen3-14B-MLX-8bit": ModelCard(
            shortId: "Qwen3-14B-MLX-8bit",
            modelId: "Qwen/Qwen3-14B-MLX-8bit",
            name: "Qwen3 14B (8-bit)",
            description: """
        Qwen3 14B is a large language model trained on the Qwen3 14B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "Qwen/Qwen3-14B-MLX-8bit",
                prettyName: "Qwen3 14B (8-bit)",
                storageSize: MemorySize.from_mb(15565),
                nLayers: 40,
                hiddenSize: 5120
            )
        ),
        "Qwen3-Coder-30B-A3B-Instruct-4bit": ModelCard(
            shortId: "Qwen3-Coder-30B-A3B-Instruct-4bit",
            modelId: "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit",
            name: "Qwen3 Coder 30B A3B (4-bit)",
            description: """
        Qwen3 30B Coder is a large language model trained on the Qwen3 30B dataset and trained for coding.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit",
                prettyName: "Qwen3 Coder 30B A3B (4-bit)",
                storageSize: MemorySize.from_mb(16797),
                nLayers: 48,
                hiddenSize: 2048
            )
        ),
        "Qwen3-Coder-30B-A3B-Instruct-6bit": ModelCard(
            shortId: "Qwen3-Coder-30B-A3B-Instruct-6bit",
            modelId: "mlx-community/Qwen3-Coder-30B-A3B-Instruct-6bit",
            name: "Qwen3 Coder 30B A3B (6-bit)",
            description: """
        Qwen3 30B Coder is a large language model trained on the Qwen3 30B dataset and trained for coding.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Coder-30B-A3B-Instruct-6bit",
                prettyName: "Qwen3 Coder 30B A3B (6-bit)",
                storageSize: MemorySize.from_mb(25396),
                nLayers: 48,
                hiddenSize: 2048
            )
        ),
        "Qwen3-Coder-30B-A3B-Instruct-8bit": ModelCard(
            shortId: "Qwen3-Coder-30B-A3B-Instruct-8bit",
            modelId: "mlx-community/Qwen3-Coder-30B-A3B-Instruct-8bit",
            name: "Qwen3 Coder 30B A3B (8-bit)",
            description: """
        Qwen3 30B Coder is a large language model trained on the Qwen3 30B dataset and trained for coding.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Coder-30B-A3B-Instruct-8bit",
                prettyName: "Qwen3 Coder 30B A3B (8-bit)",
                storageSize: MemorySize.from_mb(31738),
                nLayers: 48,
                hiddenSize: 2048
            )
        ),
        "Qwen3-30B-A3B-4bit": ModelCard(
            shortId: "Qwen3-30B-A3B-4bit",
            modelId: "mlx-community/Qwen3-30B-A3B-4bit",
            name: "Qwen3 30B A3B (4-bit)",
            description: """
        Qwen3 30B is a large language model trained on the Qwen3 30B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-30B-A3B-4bit",
                prettyName: "Qwen3 30B A3B (4-bit)",
                storageSize: MemorySize.from_mb(16797),
                nLayers: 48,
                hiddenSize: 2048
            )
        ),
        "Qwen3-30B-A3B-8bit": ModelCard(
            shortId: "Qwen3-30B-A3B-8bit",
            modelId: "mlx-community/Qwen3-30B-A3B-8bit",
            name: "Qwen3 30B A3B (8-bit)",
            description: """
        Qwen3 30B is a large language model trained on the Qwen3 30B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-30B-A3B-8bit",
                prettyName: "Qwen3 30B A3B (8-bit)",
                storageSize: MemorySize.from_mb(31738),
                nLayers: 48,
                hiddenSize: 2048
            )
        ),
        // qwen3
        "Qwen3-Next-80B-A3B-Instruct-4bit": ModelCard(
            shortId: "Qwen3-Next-80B-A3B-Instruct-4bit",
            modelId: "mlx-community/Qwen3-Next-80B-A3B-Instruct-4bit",
            name: "Qwen3 80B A3B (4-bit)",
            description: """
        Qwen3 80B
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Next-80B-A3B-Instruct-4bit",
                prettyName: "Qwen3 80B A3B (4-bit)",
                storageSize: MemorySize.from_mb(44800),
                nLayers: 48,
                hiddenSize: 2048
            )
        ),
        "Qwen3-Next-80B-A3B-Instruct-8bit": ModelCard(
            shortId: "Qwen3-Next-80B-A3B-Instruct-8bit",
            modelId: "mlx-community/Qwen3-Next-80B-A3B-Instruct-8bit",
            name: "Qwen3 80B A3B (8-bit)",
            description: """
        Qwen3 80B
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Next-80B-A3B-Instruct-8bit",
                prettyName: "Qwen3 80B A3B (8-bit)",
                storageSize: MemorySize.from_mb(84700),
                nLayers: 48,
                hiddenSize: 2048
            )
        ),
        "Qwen3-Next-80B-A3B-Thinking-4bit": ModelCard(
            shortId: "Qwen3-Next-80B-A3B-Thinking-4bit",
            modelId: "mlx-community/Qwen3-Next-80B-A3B-Thinking-4bit",
            name: "Qwen3 80B A3B Thinking (4-bit)",
            description: """
        Qwen3 80B Reasoning model
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Next-80B-A3B-Thinking-4bit",
                prettyName: "Qwen3 80B A3B Thinking (4-bit)",
                storageSize: MemorySize.from_mb(42350),
                nLayers: 48,
                hiddenSize: 2048
            )
        ),
        "Qwen3-Next-80B-A3B-Thinking-8bit": ModelCard(
            shortId: "Qwen3-Next-80B-A3B-Thinking-8bit",
            modelId: "mlx-community/Qwen3-Next-80B-A3B-Thinking-8bit",
            name: "Qwen3 80B A3B Thinking (8-bit)",
            description: """
        Qwen3 80B Reasoning model
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Next-80B-A3B-Thinking-8bit",
                prettyName: "Qwen3 80B A3B Thinking (8-bit)",
                storageSize: MemorySize.from_mb(84700),
                nLayers: 48,
                hiddenSize: 2048
            )
        ),

        // LFM2.5
        "LFM2.5-1.2B-Instruct-8bit": ModelCard(
            shortId: "LFM2.5-1.2B-Instruct-8bit",
            modelId: "mlx-community/LFM2.5-1.2B-Instruct-8bit",
            name: "LFM2.5 1.2B (8-bit)",
            description: """
        LFM2.5 1.2 is a new family of hybrid models designed for on-device deployment.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/LFM2.5-1.2B-Instruct-8bit",
                prettyName: "LFM2.5 1.2B (8-bit)",
                storageSize: MemorySize.from_mb(1280),
                nLayers: 16,
                hiddenSize: 2048
            )
        ),
        "LFM2.5-1.2B-Instruct-bf16": ModelCard(
            shortId: "LFM2.5-1.2B-Instruct-bf16",
            modelId: "mlx-community/LFM2.5-1.2B-Instruct-bf16",
            name: "LFM2.5 1.2B (bf16)",
            description: """
        LFM2.5 1.2 is a new family of hybrid models designed for on-device deployment.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/LFM2.5-1.2B-Instruct-bf16",
                prettyName: "LFM2.5 1.2B (bf16)",
                storageSize: MemorySize.from_mb(2407),
                nLayers: 16,
                hiddenSize: 2048
            )
        ),
        // gpt-oss
        "gpt-oss-20b-MXFP4-Q4": ModelCard(
            shortId: "gpt-oss-20b-MXFP4-Q4",
            modelId: "mlx-community/gpt-oss-20b-MXFP4-Q4",
            name: "GPT-OSS 20B (MXFP4-Q4, MLX)",
            description: """
        OpenAI's GPT-OSS 20B is a medium-sized MoE model for lower-latency and local or specialized use cases; this MLX variant uses MXFP4 4-bit quantization.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/gpt-oss-20b-MXFP4-Q4",
                prettyName: "GPT-OSS 20B (MXFP4-Q4, MLX)",
                storageSize: MemorySize.from_kb(11_744_051),
                nLayers: 24,
                hiddenSize: 2880
            )
        ),
        "gpt-oss-20b-MXFP4-Q8": ModelCard(
            shortId: "gpt-oss-20b-MXFP4-Q8",
            modelId: "mlx-community/gpt-oss-20b-MXFP4-Q8",
            name: "GPT-OSS 20B (MXFP4-Q8, MLX)",
            description: """
        OpenAI's GPT-OSS 20B is a medium-sized MoE model for lower-latency and local or specialized use cases; this MLX variant uses MXFP4 8-bit quantization.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/gpt-oss-20b-MXFP4-Q8",
                prettyName: "GPT-OSS 20B (MXFP4-Q8, MLX)",
                storageSize: MemorySize.from_kb(12_744_051),
                nLayers: 24,
                hiddenSize: 2880
            )
        ),
        "gpt-oss-120b-MXFP4-Q4": ModelCard(
            shortId: "gpt-oss-120b-MXFP4-Q4",
            modelId: "mlx-community/gpt-oss-120b-MXFP4-Q4",
            name: "GPT-OSS 120B (MXFP4-Q4, MLX)",
            description: """
        OpenAI's GPT-OSS 120B is a 117B-parameter Mixture-of-Experts model designed for high-reasoning and general-purpose use; this variant is a 4-bit MLX conversion for Apple Silicon.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/gpt-oss-120b-MXFP4-Q4",
                prettyName: "GPT-OSS 120B (MXFP4-Q4, MLX)",
                storageSize: MemorySize.from_kb(34_500_000),
                nLayers: 36,
                hiddenSize: 2880
            )
        ),
        "gpt-oss-120b-MXFP4-Q8": ModelCard(
            shortId: "gpt-oss-120b-MXFP4-Q8",
            modelId: "mlx-community/gpt-oss-120b-MXFP4-Q8",
            name: "GPT-OSS 120B (MXFP4-Q8, MLX)",
            description: """
        OpenAI's GPT-OSS 120B is a 117B-parameter Mixture-of-Experts model designed for high-reasoning and general-purpose use; this variant is a 8-bit MLX conversion for Apple Silicon.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/gpt-oss-120b-MXFP4-Q8",
                prettyName: "GPT-OSS 120B (MXFP4-Q8, MLX)",
                storageSize: MemorySize.from_kb(68_996_301),
                nLayers: 36,
                hiddenSize: 2880
            )
        ),

        // glm
        "GLM-4.7-Flash-4bit": ModelCard(
            shortId: "GLM-4.7-Flash-4bit",
            modelId: "mlx-community/GLM-4.7-Flash-4bit",
            name: "GLM 4.7 Flash 4bit",
            description: """
        GLM-4.7-Flash is a 30B-A3B MoE model
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/GLM-4.7-Flash-4bit",
                prettyName: "GLM 4.7 Flash 4bit",
                storageSize: MemorySize.from_mb(16282),
                nLayers: 47,
                hiddenSize: 2048,
                extraEOSTokens: ["<|user|>"]
            )
        ),
        "GLM-4.7-Flash-6bit": ModelCard(
            shortId: "GLM-4.7-Flash-6bit",
            modelId: "mlx-community/GLM-4.7-Flash-6bit",
            name: "GLM 4.7 Flash 6bit",
            description: """
        GLM-4.7-Flash is a 30B-A3B MoE model
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/GLM-4.7-Flash-68bit",
                prettyName: "GLM 4.7 Flash 6bit",
                storageSize: MemorySize.from_mb(24986),
                nLayers: 47,
                hiddenSize: 2048,
                extraEOSTokens: ["<|user|>"]
            )
        ),
        "GLM-4.7-Flash-8bit": ModelCard(
            shortId: "GLM-4.7-Flash-8bit",
            modelId: "mlx-community/GLM-4.7-Flash-8bit",
            name: "GLM 4.7 Flash 8bit",
            description: """
        GLM-4.7-Flash is a 30B-A3B MoE model
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/GLM-4.7-Flash-8bit",
                prettyName: "GLM 4.7 Flash 8bit",
                storageSize: MemorySize.from_mb(32564),
                nLayers: 47,
                hiddenSize: 2048,
                extraEOSTokens: ["<|user|>"]
            )
        ),
    ]

}
