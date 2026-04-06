//
//  LocalLLMManager.swift
//  KAI
//
//  Kitchen Assistant - LLM Manager (Claude API)
//  Coordinates Claude API client and recipe context
//

import Foundation
import Combine

/// LLM Manager State
enum LLMManagerState: Equatable {
    case notInitialized
    case modelNotDownloaded  // Not used with Claude
    case modelDownloading(progress: Double)  // Not used with Claude
    case modelReady
    case loading
    case processing
    case error(Error)

    static func == (lhs: LLMManagerState, rhs: LLMManagerState) -> Bool {
        switch (lhs, rhs) {
        case (.notInitialized, .notInitialized),
             (.modelNotDownloaded, .modelNotDownloaded),
             (.modelReady, .modelReady),
             (.loading, .loading),
             (.processing, .processing):
            return true
        case (.modelDownloading(let lhsProgress), .modelDownloading(let rhsProgress)):
            return lhsProgress == rhsProgress
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }

    var isReady: Bool {
        if case .modelReady = self {
            return true
        }
        return false
    }

    var description: String {
        switch self {
        case .notInitialized:
            return "Not initialized"
        case .modelNotDownloaded:
            return "API not configured"
        case .modelDownloading(let progress):
            return "Downloading \(Int(progress * 100))%"
        case .modelReady:
            return "Ready"
        case .loading:
            return "Connecting to Claude..."
        case .processing:
            return "Processing..."
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}

/// Main coordinator for Claude API operations
@MainActor
class LocalLLMManager: ObservableObject {

    // MARK: - Published Properties

    @Published var state: LLMManagerState = .notInitialized
    @Published var isModelLoaded = false

    // MARK: - Components

    private let claudeClient: ClaudeClient
    private let contextBuilder: RecipeContextBuilder
    private let recipeManager: RecipeManager

    // MARK: - Configuration

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(recipeManager: RecipeManager) {
        self.recipeManager = recipeManager
        self.claudeClient = ClaudeClient(config: .default)
        self.contextBuilder = RecipeContextBuilder(recipeManager: recipeManager)

        setupObservers()
        checkInitialState()
    }

    private func setupObservers() {
        // Observe Claude generation status
        claudeClient.$isGenerating
            .sink { [weak self] generating in
                if generating {
                    self?.state = .processing
                }
            }
            .store(in: &cancellables)
    }

    private func checkInitialState() {
        // Check if Claude API is configured
        if claudeClient.isConfigured() {
            state = .modelReady
            isModelLoaded = true
            print("✅ Claude API is configured and ready")

            // Test connection
            Task {
                let (success, message) = await claudeClient.testConnection()
                print(message)
            }
        } else {
            state = .modelNotDownloaded
            print("⚠️ Claude API key not configured")
        }
    }

    // MARK: - API Management

    /// Check Claude API status
    func checkServerStatus() async -> Bool {
        let (success, _) = await claudeClient.testConnection()
        return success
    }

    /// Test Claude connection
    func testConnection() async -> (success: Bool, message: String) {
        return await claudeClient.testConnection()
    }

    // MARK: - Query Processing

    /// Process a user query with recipe context using Claude
    func processQuery(_ query: String) async throws -> String {
        guard claudeClient.isConfigured() else {
            throw ClaudeError.invalidAPIKey
        }

        state = .processing

        do {
            // Build system prompt with recipe context
            let systemPrompt = contextBuilder.buildSystemPrompt()

            print("🤖 Processing query with Claude API: \(query.prefix(50))...")

            // Generate response with Claude
            let response = try await claudeClient.generateResponse(
                for: query,
                systemPrompt: systemPrompt
            )

            state = .modelReady

            print("✅ Claude response: \(response.prefix(100))...")

            return response

        } catch {
            state = .error(error)
            print("❌ Claude error: \(error.localizedDescription)")
            throw error
        }
    }

    /// Process query with streaming response
    func processQueryStreaming(
        _ query: String,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        guard claudeClient.isConfigured() else {
            throw ClaudeError.invalidAPIKey
        }

        state = .processing

        do {
            let systemPrompt = contextBuilder.buildSystemPrompt()

            print("🤖 Streaming query with Claude...")

            // Stream response with Claude
            let response = try await claudeClient.generateResponseStreaming(
                for: query,
                systemPrompt: systemPrompt,
                onToken: onToken
            )

            state = .modelReady

            return response

        } catch {
            state = .error(error)
            throw error
        }
    }

    // MARK: - Status Information (for compatibility)

    /// Get model status information
    func getModelStatus() -> (
        isDownloaded: Bool,
        isLoaded: Bool,
        downloadProgress: Double,
        modelInfo: ModelInfo?
    ) {
        return (
            isDownloaded: isModelLoaded,  // API configured = "downloaded"
            isLoaded: isModelLoaded,
            downloadProgress: 0.0,
            modelInfo: nil
        )
    }

    /// Get storage information (not applicable for Claude API)
    func getStorageInfo() -> (modelSize: String, available: String, required: String) {
        return (
            modelSize: "N/A (Cloud API)",
            available: "N/A",
            required: "N/A"
        )
    }

    /// Get context statistics
    func getContextStats() -> (recipeCount: Int, ingredientCount: Int, estimatedTokens: Int) {
        return contextBuilder.getContextStats()
    }

    /// Check if model can be "downloaded" (always true for API)
    func canDownloadModel() -> Bool {
        return true
    }

    // MARK: - Context Management

    /// Rebuild recipe context (call after recipes.json changes)
    func rebuildContext() {
        contextBuilder.rebuildContext()
        print("🔄 Recipe context rebuilt")
    }

    /// Get list of all available recipes
    func getRecipeList() -> String {
        return contextBuilder.getRecipeList()
    }

    // MARK: - Helper Methods

    /// Reset state (useful for error recovery)
    func reset() {
        checkInitialState()
        print("🔄 LLM Manager reset")
    }

    /// Preload model (just checks API)
    func preloadModel() {
        Task {
            _ = await checkServerStatus()
        }
    }

    // MARK: - Dummy Methods for UI Compatibility

    func downloadModel() async throws {
        // Not applicable for Claude API
        print("ℹ️ No download needed - using Claude API")
    }

    func cancelDownload() async {
        // Not applicable
    }

    func deleteModel() async throws {
        // Not applicable
    }
}

// MARK: - Error Extensions

extension LocalLLMManager {

    /// Get user-friendly error message
    func getErrorMessage(for error: Error) -> String {
        if let claudeError = error as? ClaudeError {
            return claudeError.localizedDescription
        } else {
            return error.localizedDescription
        }
    }

    /// Check if error is recoverable
    func isRecoverableError(_ error: Error) -> Bool {
        if let claudeError = error as? ClaudeError {
            switch claudeError {
            case .networkError, .rateLimitExceeded, .serverError:
                return true
            case .invalidAPIKey:
                return false
            default:
                return true
            }
        }
        return true
    }
}

// MARK: - Debug Helpers

extension LocalLLMManager {

    /// Print current status to console
    func printStatus() {
        print(String(repeating: "=", count: 60))
        print("CLAUDE API LLM MANAGER STATUS")
        print(String(repeating: "=", count: 60))
        print("State: \(state.description)")
        print("API Configured: \(isModelLoaded)")

        Task {
            let (success, message) = await testConnection()
            print("Connection Test: \(message)")
        }

        let stats = getContextStats()
        print("Context - Recipes: \(stats.recipeCount), Tokens: ~\(stats.estimatedTokens)")

        print(String(repeating: "=", count: 60))
    }
}
