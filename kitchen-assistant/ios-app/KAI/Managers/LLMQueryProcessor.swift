//
//  LLMQueryProcessor.swift
//  KAI
//
//  Kitchen Assistant - LLM Query Processor
//  Processes user queries using local LLM with fallback
//

import Foundation
import Combine

/// Query processor that uses local LLM with pattern-based fallback
@MainActor
class LLMQueryProcessor: ObservableObject {

    // MARK: - Published Properties

    @Published var isProcessing = false
    @Published var lastQuery: String = ""
    @Published var lastResponse: String = ""
    @Published var conversationHistory: [(question: String, answer: String)] = []

    // MARK: - Properties

    private let llmManager: LocalLLMManager
    private let fallbackProcessor: QueryProcessor
    private let maxHistorySize = 20

    // MARK: - Initialization

    init(recipeManager: RecipeManager) {
        self.llmManager = LocalLLMManager(recipeManager: recipeManager)
        self.fallbackProcessor = QueryProcessor(recipeManager: recipeManager)
    }

    // MARK: - Query Processing

    /// Process a query using LLM (async, returns immediately)
    func processQuery(_ query: String) async -> String {
        lastQuery = query
        isProcessing = true

        defer {
            isProcessing = false
        }

        // Check if model is ready
        let status = await llmManager.getModelStatus()

        if !status.isDownloaded {
            return handleModelNotDownloaded()
        }

        // Try LLM processing
        do {
            let response = try await llmManager.processQuery(query)
            lastResponse = response
            addToHistory(question: query, answer: response)
            return response

        } catch {
            print("⚠️ LLM processing failed: \(error.localizedDescription)")
            print("🔄 Falling back to pattern-based processing")

            // Fallback to pattern matching
            let fallbackResponse = fallbackProcessor.processQuery(query)
            lastResponse = fallbackResponse
            addToHistory(question: query, answer: fallbackResponse)
            return fallbackResponse
        }
    }

    /// Process query with streaming response
    func processQueryStreaming(
        _ query: String,
        onToken: @escaping (String) -> Void
    ) async -> String {
        lastQuery = query
        isProcessing = true

        defer {
            isProcessing = false
        }

        let status = await llmManager.getModelStatus()

        if !status.isDownloaded {
            let response = handleModelNotDownloaded()
            onToken(response)
            return response
        }

        do {
            let response = try await llmManager.processQueryStreaming(query, onToken: onToken)
            lastResponse = response
            addToHistory(question: query, answer: response)
            return response

        } catch {
            print("⚠️ LLM streaming failed: \(error.localizedDescription)")

            let fallbackResponse = fallbackProcessor.processQuery(query)
            onToken(fallbackResponse)
            lastResponse = fallbackResponse
            addToHistory(question: query, answer: fallbackResponse)
            return fallbackResponse
        }
    }

    // MARK: - Model Not Downloaded Handler

    private func handleModelNotDownloaded() -> String {
        return """
        The AI model needs to be downloaded first. Please go to Settings and download the Llama 3.2 1B model \
        (~1.5GB). Once downloaded, I'll be able to answer your recipe questions with full AI understanding!

        In the meantime, here's what I found using basic pattern matching:

        \(fallbackProcessor.processQuery(lastQuery))
        """
    }

    // MARK: - Conversation History

    private func addToHistory(question: String, answer: String) {
        conversationHistory.append((question: question, answer: answer))

        // Maintain history size
        if conversationHistory.count > maxHistorySize {
            conversationHistory.removeFirst()
        }
    }

    /// Clear conversation history
    func clearHistory() {
        conversationHistory.removeAll()
        lastQuery = ""
        lastResponse = ""
    }

    /// Get recent conversation context (for contextual queries)
    func getRecentContext(count: Int = 3) -> String {
        let recent = conversationHistory.suffix(count)

        var context = ""
        for (q, a) in recent {
            context += "Q: \(q)\nA: \(a)\n\n"
        }

        return context
    }

    // MARK: - Model Status

    /// Check if model is ready for use
    func isModelReady() async -> Bool {
        let status = await llmManager.getModelStatus()
        return status.isDownloaded && status.isLoaded
    }

    /// Get current model state
    func getModelState() async -> LLMManagerState {
        return await llmManager.state
    }

    /// Get model status information
    func getModelStatus() async -> (
        isDownloaded: Bool,
        isLoaded: Bool,
        downloadProgress: Double,
        modelInfo: ModelInfo?
    ) {
        return llmManager.getModelStatus()
    }

    // MARK: - Model Management (for Settings)

    /// Download model (call from Settings)
    func downloadModel() async throws {
        try await llmManager.downloadModel()
    }

    /// Cancel ongoing download
    func cancelDownload() async {
        await llmManager.cancelDownload()
    }

    /// Delete model
    func deleteModel() async throws {
        try await llmManager.deleteModel()
    }

    /// Get download progress
    func getDownloadProgress() async -> Double {
        return llmManager.getModelStatus().downloadProgress
    }

    /// Preload model in background
    func preloadModel() async {
        llmManager.preloadModel()
    }

    // MARK: - Storage Information

    /// Get storage info for displaying in Settings
    func getStorageInfo() async -> (modelSize: String, available: String, required: String) {
        return llmManager.getStorageInfo()
    }

    /// Check if device has enough storage to download model
    func canDownloadModel() async -> Bool {
        return llmManager.canDownloadModel()
    }

    // MARK: - Specialized Query Handlers

    /// Process recipe scaling query
    func processRecipeScalingQuery(_ recipeName: String, servings: Int) async -> String {
        let query = "How do I scale the \(recipeName) recipe for \(servings) servings?"
        return await processQuery(query)
    }

    /// Process ingredient substitution query
    func processIngredientSubstitutionQuery(_ ingredient: String, in recipeName: String) async -> String {
        let query = "What can I substitute for \(ingredient) in \(recipeName)?"
        return await processQuery(query)
    }

    /// Process recipe comparison query
    func processRecipeComparisonQuery(_ recipe1: String, _ recipe2: String) async -> String {
        let query = "What's the difference between \(recipe1) and \(recipe2)?"
        return await processQuery(query)
    }

    /// Get list of all recipes
    func getRecipeList() async -> String {
        return await llmManager.getRecipeList()
    }

    // MARK: - Context Management

    /// Rebuild context after recipes change
    func rebuildRecipeContext() async {
        await llmManager.rebuildContext()
    }

    /// Get context statistics
    func getContextStats() async -> (recipeCount: Int, ingredientCount: Int, estimatedTokens: Int) {
        return await llmManager.getContextStats()
    }

    // MARK: - Error Handling

    /// Get user-friendly error message
    func getErrorMessage(for error: Error) async -> String {
        return await llmManager.getErrorMessage(for: error)
    }

    /// Reset manager state
    func reset() async {
        await llmManager.reset()
        clearHistory()
    }

    // MARK: - Debug Helpers

    /// Print current status
    func printStatus() async {
        await llmManager.printStatus()

        print("Query Processor Status:")
        print("  - Processing: \(isProcessing)")
        print("  - History size: \(conversationHistory.count)")
        print("  - Last query: \(lastQuery)")
    }
}

// MARK: - Suggestion Helpers

extension LLMQueryProcessor {

    /// Get common query suggestions
    func getSuggestions() -> [String] {
        return [
            "What recipes do you know?",
            "How do I make McAlister's Club?",
            "What ingredients do I need for the club sandwich?",
            "What recipes use bacon?",
            "Tell me about the kids menu recipes",
            "What equipment do I need for sandwiches?",
            "How many slices of bacon go in the club?",
            "What can I substitute for turkey?",
            "Show me all salad recipes",
            "What's the difference between the club sandwiches?"
        ]
    }

    /// Get contextual suggestions based on recent query
    func getContextualSuggestions() -> [String] {
        guard !lastQuery.isEmpty else {
            return getSuggestions()
        }

        let query = lastQuery.lowercased()

        if query.contains("recipe") || query.contains("know") {
            return [
                "Tell me more about McAlister's Club",
                "What ingredients are in it?",
                "How do I make it?",
                "Show me the steps"
            ]
        } else if query.contains("ingredient") {
            return [
                "What can I substitute?",
                "What recipes use this?",
                "How much do I need?",
                "Where do I find it?"
            ]
        } else if query.contains("make") || query.contains("cook") {
            return [
                "What equipment do I need?",
                "How long does it take?",
                "What's the next step?",
                "Any cooking tips?"
            ]
        }

        return getSuggestions()
    }
}
