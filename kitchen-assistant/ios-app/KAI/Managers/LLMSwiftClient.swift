//
//  LLMSwiftClient.swift
//  KAI
//
//  Kitchen Assistant - LLM Integration Client
//  Provides unified interface for both LLM.swift and native llama.cpp
//

import Foundation

// Import LLM.swift (if available)
#if canImport(LLM)
import LLM
#endif

/// Errors that can occur during LLM operations
enum LLMSwiftError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case generationFailed(String)
    case invalidModelPath
    case outOfMemory

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model is not loaded. Please download the model first."
        case .modelLoadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .generationFailed(let reason):
            return "Text generation failed: \(reason)"
        case .invalidModelPath:
            return "Invalid model file path"
        case .outOfMemory:
            return "Not enough memory to run the model"
        }
    }
}

/// Configuration for LLM
struct LLMConfig {
    /// Temperature for sampling (0.0 = deterministic, higher = more creative)
    let temperature: Float

    /// Top-p sampling parameter
    let topP: Float

    /// Maximum number of tokens to generate
    let maxTokens: Int

    /// Number of threads for inference
    let threads: Int

    static let `default` = LLMConfig(
        temperature: 0.7,
        topP: 0.9,
        maxTokens: 512,
        threads: 4
    )

    static let fast = LLMConfig(
        temperature: 0.5,
        topP: 0.85,
        maxTokens: 256,
        threads: 2
    )

    static let quality = LLMConfig(
        temperature: 0.8,
        topP: 0.95,
        maxTokens: 1024,
        threads: 6
    )
    
    /// Convert to llama.cpp configuration
    func toLlamaCppConfig() -> LlamaCppConfig {
        return LlamaCppConfig(
            nThreads: Int32(threads),
            nCtx: Int32(maxTokens * 8), // Context size should be larger than max tokens
            temperature: temperature,
            topP: topP,
            topK: 40, // Reasonable default
            repeatPenalty: 1.1, // Reasonable default
            maxTokens: Int32(maxTokens),
            useGPU: true,
            nGpuLayers: 32 // Reasonable default for 1B models
        )
    }
}

/// Client implementation type
enum LLMClientType {
    case llamaSwift  // Uses LLM.swift wrapper (simpler, less control)
    case llamaCpp    // Uses native llama.cpp (more control, better performance)
}

/// Unified LLM client that can use either LLM.swift or native llama.cpp
@MainActor
class LLMSwiftClient: ObservableObject {

    // MARK: - Properties

    @Published var isModelLoaded = false
    @Published var isGenerating = false

    private let clientType: LLMClientType
    private let config: LLMConfig
    
    // LLM.swift implementation
    #if canImport(LLM)
    private var llm: LLM?
    #endif
    
    // Native llama.cpp implementation
    private var llamaCppClient: LlamaCppClient?
    private var modelPath: String?

    // MARK: - Initialization

    init(config: LLMConfig = .default, clientType: LLMClientType = .llamaCpp) {
        self.config = config
        self.clientType = clientType
        
        // Initialize the appropriate client
        switch clientType {
        case .llamaSwift:
            print("🔧 Using LLM.swift wrapper implementation")
        case .llamaCpp:
            print("🔧 Using native llama.cpp implementation")
            let llamaCppConfig = config.toLlamaCppConfig()
            llamaCppClient = LlamaCppClient(config: llamaCppConfig)
        }
    }

    deinit {
        // Cleanup is handled automatically when properties are deallocated
        // Cannot call MainActor-isolated methods from deinit
    }

    // MARK: - Model Management

    /// Load model from file path
    func loadModel(from path: String) async throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw LLMSwiftError.invalidModelPath
        }

        self.modelPath = path

        print("📦 Loading model with \(clientType) from: \(path)")

        do {
            switch clientType {
            case .llamaSwift:
                try await loadWithLLMSwift(path: path)
            case .llamaCpp:
                try await loadWithLlamaCpp(path: path)
            }
            
            self.isModelLoaded = true
            print("✅ Model loaded successfully with \(clientType)")

        } catch {
            print("❌ Failed to load model with \(clientType): \(error)")
            throw LLMSwiftError.modelLoadFailed(error.localizedDescription)
        }
    }
    
    private func loadWithLLMSwift(path: String) async throws {
        #if canImport(LLM)
        // Load model with LLM.swift (so simple!)
        llm = try await LLM(from: path)
        #else
        throw LLMSwiftError.modelLoadFailed("LLM.swift not available")
        #endif
    }
    
    private func loadWithLlamaCpp(path: String) async throws {
        guard let client = llamaCppClient else {
            throw LLMSwiftError.modelLoadFailed("llama.cpp client not initialized")
        }
        
        do {
            try await client.loadModel(from: path)
        } catch {
            if let llamaError = error as? LlamaCppError {
                throw LLMSwiftError.modelLoadFailed(llamaError.localizedDescription)
            } else {
                throw LLMSwiftError.modelLoadFailed(error.localizedDescription)
            }
        }
    }

    /// Unload model and free memory
    func unloadModel() {
        switch clientType {
        case .llamaSwift:
            #if canImport(LLM)
            llm = nil
            #endif
        case .llamaCpp:
            llamaCppClient?.unloadModel()
        }
        
        isModelLoaded = false
        print("🗑️ Model unloaded")
    }

    // MARK: - Text Generation

    /// Generate text response for a prompt
    func generateResponse(for prompt: String, systemPrompt: String? = nil) async throws -> String {
        guard isModelLoaded else {
            throw LLMSwiftError.modelNotLoaded
        }

        isGenerating = true
        defer { isGenerating = false }

        print("🤔 Generating response for: \(prompt.prefix(50))...")

        do {
            let response: String
            
            switch clientType {
            case .llamaSwift:
                response = try await generateWithLLMSwift(prompt: prompt, systemPrompt: systemPrompt)
            case .llamaCpp:
                response = try await generateWithLlamaCpp(prompt: prompt, systemPrompt: systemPrompt)
            }

            let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ Generated response: \(cleaned.prefix(100))...")

            return cleaned

        } catch {
            print("❌ Generation failed: \(error)")
            throw LLMSwiftError.generationFailed(error.localizedDescription)
        }
    }
    
    private func generateWithLLMSwift(prompt: String, systemPrompt: String?) async throws -> String {
        #if canImport(LLM)
        guard let llm = llm else {
            throw LLMSwiftError.modelNotLoaded
        }

        // Build full prompt with system context
        let fullPrompt = buildFullPrompt(system: systemPrompt, user: prompt)

        // Generate with LLM.swift
        // Note: The exact API depends on the LLM.swift version installed
        // Common patterns: llm.predict(), llm.generate(), llm.complete()
        var response = ""

        // Try different API patterns based on LLM.swift version
        // Pattern 1: Direct streaming with for-await
        if let asyncSequence = llm as? any AsyncSequence {
            // This won't work directly but shows intent
            throw LLMSwiftError.generationFailed("LLM.swift API pattern not yet configured. Please use llamaCpp client type instead.")
        }

        // For now, throw an error directing to use llama.cpp
        throw LLMSwiftError.generationFailed("LLM.swift integration not fully configured. Use clientType: .llamaCpp instead.")

        #else
        throw LLMSwiftError.modelNotLoaded
        #endif
    }
    
    private func generateWithLlamaCpp(prompt: String, systemPrompt: String?) async throws -> String {
        guard let client = llamaCppClient else {
            throw LLMSwiftError.modelNotLoaded
        }
        
        do {
            return try await client.generateResponse(for: prompt, systemPrompt: systemPrompt)
        } catch {
            if let llamaError = error as? LlamaCppError {
                throw LLMSwiftError.generationFailed(llamaError.localizedDescription)
            } else {
                throw LLMSwiftError.generationFailed(error.localizedDescription)
            }
        }
    }

    /// Generate text with streaming callback for real-time output
    func generateResponseStreaming(
        for prompt: String,
        systemPrompt: String? = nil,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        guard isModelLoaded else {
            throw LLMSwiftError.modelNotLoaded
        }

        isGenerating = true
        defer { isGenerating = false }

        print("🤔 Streaming response for: \(prompt.prefix(50))...")

        do {
            let response: String
            
            switch clientType {
            case .llamaSwift:
                response = try await streamWithLLMSwift(prompt: prompt, systemPrompt: systemPrompt, onToken: onToken)
            case .llamaCpp:
                response = try await streamWithLlamaCpp(prompt: prompt, systemPrompt: systemPrompt, onToken: onToken)
            }

            print("✅ Streaming complete")
            return response.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch {
            print("❌ Streaming failed: \(error)")
            throw LLMSwiftError.generationFailed(error.localizedDescription)
        }
    }
    
    private func streamWithLLMSwift(prompt: String, systemPrompt: String?, onToken: @escaping (String) -> Void) async throws -> String {
        #if canImport(LLM)
        guard let llm = llm else {
            throw LLMSwiftError.modelNotLoaded
        }

        let fullPrompt = buildFullPrompt(system: systemPrompt, user: prompt)

        // For now, throw an error directing to use llama.cpp
        throw LLMSwiftError.generationFailed("LLM.swift streaming not fully configured. Use clientType: .llamaCpp instead.")

        #else
        throw LLMSwiftError.modelNotLoaded
        #endif
    }
    
    private func streamWithLlamaCpp(prompt: String, systemPrompt: String?, onToken: @escaping (String) -> Void) async throws -> String {
        guard let client = llamaCppClient else {
            throw LLMSwiftError.modelNotLoaded
        }
        
        do {
            return try await client.generateResponseStreaming(for: prompt, systemPrompt: systemPrompt, onToken: onToken)
        } catch {
            if let llamaError = error as? LlamaCppError {
                throw LLMSwiftError.generationFailed(llamaError.localizedDescription)
            } else {
                throw LLMSwiftError.generationFailed(error.localizedDescription)
            }
        }
    }

    // MARK: - Helper Methods

    private func buildFullPrompt(system: String?, user: String) -> String {
        // Llama 3.2 format
        if let system = system {
            return """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>

            \(system)<|eot_id|><|start_header_id|>user<|end_header_id|>

            \(user)<|eot_id|><|start_header_id|>assistant<|end_header_id|>

            """
        } else {
            return """
            <|begin_of_text|><|start_header_id|>user<|end_header_id|>

            \(user)<|eot_id|><|start_header_id|>assistant<|end_header_id|>

            """
        }
    }

    /// Get model information
    func getModelInfo() -> (loaded: Bool, path: String?, clientType: LLMClientType) {
        return (
            loaded: isModelLoaded,
            path: modelPath,
            clientType: clientType
        )
    }

    /// Check if model file exists at path
    static func modelExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    /// Get estimated memory usage
    func getMemoryUsage() -> UInt64 {
        switch clientType {
        case .llamaSwift:
            // Estimate: ~2GB for 1B model
            return isModelLoaded ? 2_000_000_000 : 0
        case .llamaCpp:
            return llamaCppClient?.getMemoryUsage() ?? 0
        }
    }

    /// Test if model is working
    func testGeneration() async throws -> Bool {
        let test = try await generateResponse(for: "Hello, how are you?")
        return !test.isEmpty
    }
    
    /// Get additional info for llama.cpp client
    func getLlamaCppInfo() -> (vocabularySize: Int?, contextSize: Int?, currentTokens: Int?)? {
        guard case .llamaCpp = clientType, let client = llamaCppClient else {
            return nil
        }
        
        return (
            vocabularySize: client.getVocabularySize(),
            contextSize: client.getContextSize(),
            currentTokens: client.getCurrentTokenCount()
        )
    }
    
    /// Clear context (llama.cpp only)
    func clearContext() {
        if case .llamaCpp = clientType {
            llamaCppClient?.clearContext()
        }
    }
}

// MARK: - Convenience Extensions

extension LLMSwiftClient {

    /// Quick test query
    func quickTest() async -> Bool {
        do {
            let response = try await generateResponse(for: "Say hello")
            return !response.isEmpty
        } catch {
            print("❌ Quick test failed: \(error)")
            return false
        }
    }

    /// Generate with timeout
    func generateWithTimeout(
        _ prompt: String,
        systemPrompt: String? = nil,
        timeout: TimeInterval = 30
    ) async throws -> String {
        return try await withThrowingTaskGroup(of: String?.self) { group in
            // Task for actual generation
            group.addTask {
                try await self.generateResponse(for: prompt, systemPrompt: systemPrompt)
            }

            // Task for timeout
            group.addTask {
                do {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    return nil // Timeout reached
                } catch {
                    return nil // Task cancelled
                }
            }

            // Get first result
            guard let firstResult = try await group.next() else {
                throw LLMSwiftError.generationFailed("No response")
            }

            // Cancel remaining tasks
            group.cancelAll()

            // Check if we got a real result or timeout
            if let result = firstResult {
                return result
            } else {
                throw LLMSwiftError.generationFailed("Timeout after \(timeout)s")
            }
        }
    }
}
