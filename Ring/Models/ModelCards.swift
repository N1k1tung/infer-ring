import Foundation

// adapted from https://github.com/exo-explore/exo/blob/main/src/exo/shared/models/model_cards.py

extension Memory {
    static func from_kb(_ kb: Int) -> Memory {
        return Memory(inBytes: kb * 1024)
    }
    
    static func from_mb(_ mb: Int) -> Memory {
        return Memory(inBytes: mb * 1024 * 1024)
    }
    
    static func from_gb(_ gb: Int) -> Memory {
        return Memory(inBytes: gb * 1024 * 1024 * 1024)
    }
    
    static func from_bytes(_ bytes: Int) -> Memory {
        return Memory(inBytes: bytes)
    }
}

public struct ModelCard: Codable {
    public let shortId: String
    public let modelId: String
    public let name: String
    public let description: String
    public let tags: [String]
    public let metadata: ModelMetadata
}

public struct ModelCards {
    public static let allModels: [String: ModelCard] = [
        // deepseek v3
        "deepseek-v3.1-4bit": ModelCard(
            shortId: "deepseek-v3.1-4bit",
            modelId: "mlx-community/DeepSeek-V3.1-4bit",
            name: "DeepSeek V3.1 (4-bit)",
            description: """
        DeepSeek V3.1 is a large language model trained on the DeepSeek V3.1 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/DeepSeek-V3.1-4bit",
                prettyName: "DeepSeek V3.1 (4-bit)",
                storageSize: Memory.from_gb(378),
                nLayers: 61,
                hiddenSize: 7168,
                supportsTensor: true
            )
        ),
        "deepseek-v3.1-8bit": ModelCard(
            shortId: "deepseek-v3.1-8bit",
            modelId: "mlx-community/DeepSeek-V3.1-8bit",
            name: "DeepSeek V3.1 (8-bit)",
            description: """
        DeepSeek V3.1 is a large language model trained on the DeepSeek V3.1 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/DeepSeek-V3.1-8bit",
                prettyName: "DeepSeek V3.1 (8-bit)",
                storageSize: Memory.from_gb(713),
                nLayers: 61,
                hiddenSize: 7168,
                supportsTensor: true
            )
        ),
        // kimi k2
        "kimi-k2-instruct-4bit": ModelCard(
            shortId: "kimi-k2-instruct-4bit",
            modelId: "mlx-community/Kimi-K2-Instruct-4bit",
            name: "Kimi K2 Instruct (4-bit)",
            description: """
        Kimi K2 is a large language model trained on the Kimi K2 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Kimi-K2-Instruct-4bit",
                prettyName: "Kimi K2 Instruct (4-bit)",
                storageSize: Memory.from_gb(578),
                nLayers: 61,
                hiddenSize: 7168,
                supportsTensor: true
            )
        ),
        "kimi-k2-thinking": ModelCard(
            shortId: "kimi-k2-thinking",
            modelId: "mlx-community/Kimi-K2-Thinking",
            name: "Kimi K2 Thinking (4-bit)",
            description: """
        Kimi K2 Thinking is the latest, most capable version of open-source thinking model.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Kimi-K2-Thinking",
                prettyName: "Kimi K2 Thinking (4-bit)",
                storageSize: Memory.from_gb(658),
                nLayers: 61,
                hiddenSize: 7168,
                supportsTensor: true
            )
        ),
        // llama-3.1
        "llama-3.1-8b": ModelCard(
            shortId: "llama-3.1-8b",
            modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
            name: "Llama 3.1 8B (4-bit)",
            description: """
        Llama 3.1 is a large language model trained on the Llama 3.1 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
                prettyName: "Llama 3.1 8B (4-bit)",
                storageSize: Memory.from_mb(4423),
                nLayers: 32,
                hiddenSize: 4096,
                supportsTensor: true
            )
        ),
        "llama-3.1-8b-8bit": ModelCard(
            shortId: "llama-3.1-8b-8bit",
            modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-8bit",
            name: "Llama 3.1 8B (8-bit)",
            description: """
        Llama 3.1 is a large language model trained on the Llama 3.1 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-8bit",
                prettyName: "Llama 3.1 8B (8-bit)",
                storageSize: Memory.from_mb(8540),
                nLayers: 32,
                hiddenSize: 4096,
                supportsTensor: true
            )
        ),
        "llama-3.1-8b-bf16": ModelCard(
            shortId: "llama-3.1-8b-bf16",
            modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-bf16",
            name: "Llama 3.1 8B (BF16)",
            description: """
        Llama 3.1 is a large language model trained on the Llama 3.1 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-bf16",
                prettyName: "Llama 3.1 8B (BF16)",
                storageSize: Memory.from_mb(16100),
                nLayers: 32,
                hiddenSize: 4096,
                supportsTensor: true
            )
        ),
        "llama-3.1-70b": ModelCard(
            shortId: "llama-3.1-70b",
            modelId: "mlx-community/Meta-Llama-3.1-70B-Instruct-4bit",
            name: "Llama 3.1 70B (4-bit)",
            description: """
        Llama 3.1 is a large language model trained on the Llama 3.1 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Meta-Llama-3.1-70B-Instruct-4bit",
                prettyName: "Llama 3.1 70B (4-bit)",
                storageSize: Memory.from_mb(38769),
                nLayers: 80,
                hiddenSize: 8192,
                supportsTensor: true
            )
        ),
        // llama-3.2
        "llama-3.2-1b": ModelCard(
            shortId: "llama-3.2-1b",
            modelId: "mlx-community/Llama-3.2-1B-Instruct-4bit",
            name: "Llama 3.2 1B (4-bit)",
            description: """
        Llama 3.2 is a large language model trained on the Llama 3.2 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Llama-3.2-1B-Instruct-4bit",
                prettyName: "Llama 3.2 1B (4-bit)",
                storageSize: Memory.from_mb(696),
                nLayers: 16,
                hiddenSize: 2048,
                supportsTensor: true
            )
        ),
        "llama-3.2-3b": ModelCard(
            shortId: "llama-3.2-3b",
            modelId: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "Llama 3.2 3B (4-bit)",
            description: """
        Llama 3.2 is a large language model trained on the Llama 3.2 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Llama-3.2-3B-Instruct-4bit",
                prettyName: "Llama 3.2 3B (4-bit)",
                storageSize: Memory.from_mb(1777),
                nLayers: 28,
                hiddenSize: 3072,
                supportsTensor: true
            )
        ),
        "llama-3.2-3b-8bit": ModelCard(
            shortId: "llama-3.2-3b-8bit",
            modelId: "mlx-community/Llama-3.2-3B-Instruct-8bit",
            name: "Llama 3.2 3B (8-bit)",
            description: """
        Llama 3.2 is a large language model trained on the Llama 3.2 dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Llama-3.2-3B-Instruct-8bit",
                prettyName: "Llama 3.2 3B (8-bit)",
                storageSize: Memory.from_mb(3339),
                nLayers: 28,
                hiddenSize: 3072,
                supportsTensor: true
            )
        ),
        // llama-3.3
        "llama-3.3-70b": ModelCard(
            shortId: "llama-3.3-70b",
            modelId: "mlx-community/Llama-3.3-70B-Instruct-4bit",
            name: "Llama 3.3 70B (4-bit)",
            description: """
        The Meta Llama 3.3 multilingual large language model (LLM) is an instruction tuned generative model in 70B (text in/text out)
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Llama-3.3-70B-Instruct-4bit",
                prettyName: "Llama 3.3 70B",
                storageSize: Memory.from_mb(38769),
                nLayers: 80,
                hiddenSize: 8192,
                supportsTensor: true
            )
        ),
        "llama-3.3-70b-8bit": ModelCard(
            shortId: "llama-3.3-70b-8bit",
            modelId: "mlx-community/Llama-3.3-70B-Instruct-8bit",
            name: "Llama 3.3 70B (8-bit)",
            description: """
        The Meta Llama 3.3 multilingual large language model (LLM) is an instruction tuned generative model in 70B (text in/text out)
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Llama-3.3-70B-Instruct-8bit",
                prettyName: "Llama 3.3 70B (8-bit)",
                storageSize: Memory.from_mb(73242),
                nLayers: 80,
                hiddenSize: 8192,
                supportsTensor: true
            )
        ),
        "llama-3.3-70b-fp16": ModelCard(
            shortId: "llama-3.3-70b-fp16",
            modelId: "mlx-community/llama-3.3-70b-instruct-fp16",
            name: "Llama 3.3 70B (FP16)",
            description: """
        The Meta Llama 3.3 multilingual large language model (LLM) is an instruction tuned generative model in 70B (text in/text out)
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/llama-3.3-70b-instruct-fp16",
                prettyName: "Llama 3.3 70B (FP16)",
                storageSize: Memory.from_mb(137695),
                nLayers: 80,
                hiddenSize: 8192,
                supportsTensor: true
            )
        ),
        // qwen3
        "qwen3-0.6b": ModelCard(
            shortId: "qwen3-0.6b",
            modelId: "mlx-community/Qwen3-0.6B-4bit",
            name: "Qwen3 0.6B (4-bit)",
            description: """
        Qwen3 0.6B is a large language model trained on the Qwen3 0.6B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-0.6B-4bit",
                prettyName: "Qwen3 0.6B (4-bit)",
                storageSize: Memory.from_mb(327),
                nLayers: 28,
                hiddenSize: 1024,
                supportsTensor: false
            )
        ),
        "qwen3-0.6b-8bit": ModelCard(
            shortId: "qwen3-0.6b-8bit",
            modelId: "mlx-community/Qwen3-0.6B-8bit",
            name: "Qwen3 0.6B (8-bit)",
            description: """
        Qwen3 0.6B is a large language model trained on the Qwen3 0.6B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-0.6B-8bit",
                prettyName: "Qwen3 0.6B (8-bit)",
                storageSize: Memory.from_mb(666),
                nLayers: 28,
                hiddenSize: 1024,
                supportsTensor: false
            )
        ),
        "qwen3-30b": ModelCard(
            shortId: "qwen3-30b",
            modelId: "mlx-community/Qwen3-30B-A3B-4bit",
            name: "Qwen3 30B A3B (4-bit)",
            description: """
        Qwen3 30B is a large language model trained on the Qwen3 30B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-30B-A3B-4bit",
                prettyName: "Qwen3 30B A3B (4-bit)",
                storageSize: Memory.from_mb(16797),
                nLayers: 48,
                hiddenSize: 2048,
                supportsTensor: true
            )
        ),
        "qwen3-30b-8bit": ModelCard(
            shortId: "qwen3-30b-8bit",
            modelId: "mlx-community/Qwen3-30B-A3B-8bit",
            name: "Qwen3 30B A3B (8-bit)",
            description: """
        Qwen3 30B is a large language model trained on the Qwen3 30B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-30B-A3B-8bit",
                prettyName: "Qwen3 30B A3B (8-bit)",
                storageSize: Memory.from_mb(31738),
                nLayers: 48,
                hiddenSize: 2048,
                supportsTensor: true
            )
        ),
        "qwen3-80b-a3B-4bit": ModelCard(
            shortId: "qwen3-80b-a3B-4bit",
            modelId: "mlx-community/Qwen3-Next-80B-A3B-Instruct-4bit",
            name: "Qwen3 80B A3B (4-bit)",
            description: """
        Qwen3 80B
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Next-80B-A3B-Instruct-4bit",
                prettyName: "Qwen3 80B A3B (4-bit)",
                storageSize: Memory.from_mb(44800),
                nLayers: 48,
                hiddenSize: 2048,
                supportsTensor: true
            )
        ),
        "qwen3-80b-a3B-8bit": ModelCard(
            shortId: "qwen3-80b-a3B-8bit",
            modelId: "mlx-community/Qwen3-Next-80B-A3B-Instruct-8bit",
            name: "Qwen3 80B A3B (8-bit)",
            description: """
        Qwen3 80B
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Next-80B-A3B-Instruct-8bit",
                prettyName: "Qwen3 80B A3B (8-bit)",
                storageSize: Memory.from_mb(84700),
                nLayers: 48,
                hiddenSize: 2048,
                supportsTensor: true
            )
        ),
        "qwen3-80b-a3B-thinking-4bit": ModelCard(
            shortId: "qwen3-80b-a3B-thinking-4bit",
            modelId: "mlx-community/Qwen3-Next-80B-A3B-Thinking-4bit",
            name: "Qwen3 80B A3B Thinking (4-bit)",
            description: """
        Qwen3 80B Reasoning model
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Next-80B-A3B-Thinking-4bit",
                prettyName: "Qwen3 80B A3B (4-bit)",
                storageSize: Memory.from_mb(84700),
                nLayers: 48,
                hiddenSize: 2048,
                supportsTensor: true
            )
        ),
        "qwen3-80b-a3B-thinking-8bit": ModelCard(
            shortId: "qwen3-80b-a3B-thinking-8bit",
            modelId: "mlx-community/Qwen3-Next-80B-A3B-Thinking-8bit",
            name: "Qwen3 80B A3B Thinking (8-bit)",
            description: """
        Qwen3 80B Reasoning model
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Next-80B-A3B-Thinking-8bit",
                prettyName: "Qwen3 80B A3B (8-bit)",
                storageSize: Memory.from_mb(84700),
                nLayers: 48,
                hiddenSize: 2048,
                supportsTensor: true
            )
        ),
        "qwen3-235b-a22b-4bit": ModelCard(
            shortId: "qwen3-235b-a22b-4bit",
            modelId: "mlx-community/Qwen3-235B-A22B-Instruct-2507-4bit",
            name: "Qwen3 235B A22B (4-bit)",
            description: """
        Qwen3 235B (Active 22B) is a large language model trained on the Qwen3 235B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-235B-A22B-Instruct-2507-4bit",
                prettyName: "Qwen3 235B A22B (4-bit)",
                storageSize: Memory.from_gb(132),
                nLayers: 94,
                hiddenSize: 4096,
                supportsTensor: true
            )
        ),
        "qwen3-235b-a22b-8bit": ModelCard(
            shortId: "qwen3-235b-a22b-8bit",
            modelId: "mlx-community/Qwen3-235B-A22B-Instruct-2507-8bit",
            name: "Qwen3 235B A22B (8-bit)",
            description: """
        Qwen3 235B (Active 22B) is a large language model trained on the Qwen3 235B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-235B-A22B-Instruct-2507-8bit",
                prettyName: "Qwen3 235B A22B (8-bit)",
                storageSize: Memory.from_gb(250),
                nLayers: 94,
                hiddenSize: 4096,
                supportsTensor: true
            )
        ),
        "qwen3-coder-480b-a35b-4bit": ModelCard(
            shortId: "qwen3-coder-480b-a35b-4bit",
            modelId: "mlx-community/Qwen3-Coder-480B-A35B-Instruct-4bit",
            name: "Qwen3 Coder 480B A35B (4-bit)",
            description: """
        Qwen3 Coder 480B (Active 35B) is a large language model trained on the Qwen3 Coder 480B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Coder-480B-A35B-Instruct-4bit",
                prettyName: "Qwen3 Coder 480B A35B (4-bit)",
                storageSize: Memory.from_gb(270),
                nLayers: 62,
                hiddenSize: 6144,
                supportsTensor: true
            )
        ),
        "qwen3-coder-480b-a35b-8bit": ModelCard(
            shortId: "qwen3-coder-480b-a35b-8bit",
            modelId: "mlx-community/Qwen3-Coder-480B-A35B-Instruct-8bit",
            name: "Qwen3 Coder 480B A35B (8-bit)",
            description: """
        Qwen3 Coder 480B (Active 35B) is a large language model trained on the Qwen3 Coder 480B dataset.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/Qwen3-Coder-480B-A35B-Instruct-8bit",
                prettyName: "Qwen3 Coder 480B A35B (8-bit)",
                storageSize: Memory.from_gb(540),
                nLayers: 62,
                hiddenSize: 6144,
                supportsTensor: true
            )
        ),
        // gpt-oss
        "gpt-oss-120b-MXFP4-Q8": ModelCard(
            shortId: "gpt-oss-120b-MXFP4-Q8",
            modelId: "mlx-community/gpt-oss-120b-MXFP4-Q8",
            name: "GPT-OSS 120B (MXFP4-Q8, MLX)",
            description: """
        OpenAI's GPT-OSS 120B is a 117B-parameter Mixture-of-Experts model designed for high-reasoning and general-purpose use; this variant is a 4-bit MLX conversion for Apple Silicon.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/gpt-oss-120b-MXFP4-Q8",
                prettyName: "GPT-OSS 120B (MXFP4-Q8, MLX)",
                storageSize: Memory.from_kb(68_996_301),
                nLayers: 36,
                hiddenSize: 2880,
                supportsTensor: true
            )
        ),
        "gpt-oss-20b-4bit": ModelCard(
            shortId: "gpt-oss-20b-4bit",
            modelId: "mlx-community/gpt-oss-20b-MXFP4-Q4",
            name: "GPT-OSS 20B (MXFP4-Q4, MLX)",
            description: """
        OpenAI's GPT-OSS 20B is a medium-sized MoE model for lower-latency and local or specialized use cases; this MLX variant uses MXFP4 4-bit quantization.
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/gpt-oss-20b-MXFP4-Q4",
                prettyName: "GPT-OSS 20B (MXFP4-Q4, MLX)",
                storageSize: Memory.from_kb(11_744_051),
                nLayers: 24,
                hiddenSize: 2880,
                supportsTensor: true
            )
        ),
        // Needs to be quantized g32 or g16.
        "glm-4.5-air-8bit": ModelCard(
            shortId: "glm-4.5-air-8bit",
            modelId: "mlx-community/GLM-4.5-Air-8bit",
            name: "GLM 4.5 Air 8bit",
            description: """
        GLM 4.5 Air 8bit
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/GLM-4.5-Air-8bit",
                prettyName: "GLM 4.5 Air 8bit",
                storageSize: Memory.from_gb(114),
                nLayers: 46,
                hiddenSize: 4096,
                supportsTensor: false
            )
        ),
        "glm-4.5-air-bf16": ModelCard(
            shortId: "glm-4.5-air-bf16",
            modelId: "mlx-community/GLM-4.5-Air-bf16",
            name: "GLM 4.5 Air bf16",
            description: """
        GLM 4.5 Air bf16
        """,
            tags: [],
            metadata: ModelMetadata(
                modelId: "mlx-community/GLM-4.5-Air-bf16",
                prettyName: "GLM 4.5 Air bf16",
                storageSize: Memory.from_gb(214),
                nLayers: 46,
                hiddenSize: 4096,
                supportsTensor: true
            )
        )
    ]

}
