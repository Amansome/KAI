//
//  ClaudeClient.swift
//  KAI
//
//  Kitchen Assistant - Claude API Integration
//  Uses Anthropic's Claude for intelligent recipe assistance
//

import Foundation

/// Errors for Claude API operations
enum ClaudeError: LocalizedError {
    case invalidAPIKey
    case requestFailed(String)
    case invalidResponse
    case networkError(Error)
    case rateLimitExceeded
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid Claude API key. Please check your configuration."
        case .requestFailed(let reason):
            return "Request failed: \(reason)"
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait a moment and try again."
        case .serverError(let code):
            return "Server error: HTTP \(code)"
        }
    }
}

/// Configuration for Claude API
struct ClaudeConfig {
    let apiKey: String
    let model: String
    let maxTokens: Int
    let temperature: Float

    static let `default` = ClaudeConfig(
        apiKey: "YOUR_ANTHROPIC_API_KEY_HERE", // Set via environment or config — never hardcode
        model: "claude-3-5-haiku-20241022",
        maxTokens: 1024,
        temperature: 0.7
    )
}

/// Claude API client for recipe assistance
@MainActor
class ClaudeClient: ObservableObject {

    // MARK: - Properties

    @Published var isGenerating = false

    private let config: ClaudeConfig
    private let urlSession: URLSession
    private let apiURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"

    // MARK: - Initialization

    init(config: ClaudeConfig = .default) {
        self.config = config

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: configuration)

        print("🤖 ClaudeClient initialized with model: \(config.model)")
    }

    // MARK: - Text Generation

    /// Generate response from Claude
    func generateResponse(for prompt: String, systemPrompt: String? = nil) async throws -> String {
        guard !config.apiKey.isEmpty else {
            throw ClaudeError.invalidAPIKey
        }

        isGenerating = true
        defer { isGenerating = false }

        guard let url = URL(string: apiURL) else {
            throw ClaudeError.requestFailed("Invalid URL")
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        // Build request body
        var requestBody: [String: Any] = [
            "model": config.model,
            "max_tokens": config.maxTokens,
            "temperature": config.temperature,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        // Add system prompt if provided
        if let systemPrompt = systemPrompt {
            requestBody["system"] = systemPrompt
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("🤖 Sending request to Claude API...")
        print("   Model: \(config.model)")
        print("   Query: \(prompt.prefix(50))...")
        print("   System prompt length: \(systemPrompt?.count ?? 0) chars")
        if let sys = systemPrompt {
            print("   System prompt preview: \(sys.prefix(200))...")
        }

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeError.invalidResponse
            }

            print("📡 Claude API response: HTTP \(httpResponse.statusCode)")

            // Handle different status codes
            switch httpResponse.statusCode {
            case 200:
                // Success - parse response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {

                    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("✅ Claude response: \(cleaned.prefix(100))...")
                    return cleaned
                }

                // Try to parse error message if JSON parsing failed
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw ClaudeError.requestFailed(message)
                }

                throw ClaudeError.invalidResponse

            case 401:
                throw ClaudeError.invalidAPIKey

            case 429:
                throw ClaudeError.rateLimitExceeded

            case 500...599:
                throw ClaudeError.serverError(httpResponse.statusCode)

            default:
                // Try to get error message from response
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw ClaudeError.requestFailed(message)
                }

                throw ClaudeError.requestFailed("HTTP \(httpResponse.statusCode)")
            }

        } catch let error as ClaudeError {
            print("❌ Claude error: \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw ClaudeError.networkError(error)
        }
    }

    /// Generate response with streaming (not implemented for simplicity)
    func generateResponseStreaming(
        for prompt: String,
        systemPrompt: String? = nil,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        // For now, just use non-streaming and return full response
        let response = try await generateResponse(for: prompt, systemPrompt: systemPrompt)
        onToken(response)
        return response
    }

    // MARK: - Helper Methods

    /// Test connection to Claude API
    func testConnection() async -> (success: Bool, message: String) {
        do {
            let response = try await generateResponse(for: "Say 'hello' in one word", systemPrompt: nil)
            if !response.isEmpty {
                return (true, "✅ Connected to Claude API. Model: \(config.model)")
            } else {
                return (false, "⚠️ Empty response from Claude")
            }
        } catch let error as ClaudeError {
            return (false, "❌ \(error.localizedDescription)")
        } catch {
            return (false, "❌ \(error.localizedDescription)")
        }
    }

    /// Check if API key is configured
    func isConfigured() -> Bool {
        return !config.apiKey.isEmpty && config.apiKey.starts(with: "sk-ant-")
    }
}

// MARK: - Convenience Extensions

extension ClaudeClient {

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
}
