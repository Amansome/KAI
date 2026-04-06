//
//  SearchHistoryManager.swift
//  KAI
//
//  Kitchen Assistant - Search History Manager
//

import Foundation

class SearchHistoryManager: ObservableObject {
    @Published var recentQueries: [SearchQuery] = []
    @Published var popularQueries: [SearchQuery] = []
    
    private let maxRecentQueries = 20
    private let userDefaults = UserDefaults.standard
    private let recentQueriesKey = "KAI_RecentQueries"
    
    init() {
        loadSearchHistory()
        generatePopularQueries()
    }
    
    // MARK: - Search Query Management
    
    func addQuery(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        let searchQuery = SearchQuery(
            id: UUID().uuidString,
            text: trimmedQuery,
            timestamp: Date(),
            frequency: 1
        )
        
        // Remove existing query if it exists
        recentQueries.removeAll { $0.text.lowercased() == trimmedQuery.lowercased() }
        
        // Add to beginning
        recentQueries.insert(searchQuery, at: 0)
        
        // Limit to max queries
        if recentQueries.count > maxRecentQueries {
            recentQueries = Array(recentQueries.prefix(maxRecentQueries))
        }
        
        saveSearchHistory()
        updatePopularQueries()
    }
    
    func clearHistory() {
        recentQueries.removeAll()
        saveSearchHistory()
    }
    
    func removeQuery(_ query: SearchQuery) {
        recentQueries.removeAll { $0.id == query.id }
        saveSearchHistory()
    }
    
    // MARK: - Smart Suggestions
    
    func getSuggestions(for input: String) -> [String] {
        let lowercaseInput = input.lowercased()
        guard !lowercaseInput.isEmpty else {
            return popularQueries.prefix(5).map { $0.text }
        }
        
        var suggestions: [String] = []
        
        // Add matching recent queries
        let recentMatches = recentQueries
            .filter { $0.text.lowercased().contains(lowercaseInput) }
            .prefix(3)
            .map { $0.text }
        suggestions.append(contentsOf: recentMatches)
        
        // Add smart completions based on common patterns
        let smartCompletions = generateSmartCompletions(for: lowercaseInput)
        suggestions.append(contentsOf: smartCompletions)
        
        // Remove duplicates and limit
        return Array(Set(suggestions)).prefix(5).map { $0 }
    }
    
    private func generateSmartCompletions(for input: String) -> [String] {
        var completions: [String] = []
        
        // Recipe-based completions
        if input.contains("how many") || input.contains("how much") {
            completions.append("How many slices of bacon go in McAlister's Club?")
            completions.append("How much cheese for the club sandwich?")
        }
        
        if input.contains("what do i need") || input.contains("ingredients") {
            completions.append("What do I need to make the club sandwich?")
            completions.append("What ingredients are in the Caesar salad?")
        }
        
        if input.contains("how do i make") || input.contains("steps") {
            completions.append("How do I make the club sandwich?")
            completions.append("What are the steps for making a Caesar salad?")
        }
        
        if input.contains("recipes with") || input.contains("have") {
            completions.append("What recipes have bacon?")
            completions.append("What recipes have chicken?")
        }
        
        return completions.filter { !$0.lowercased().contains(input) }
    }
    
    // MARK: - Popular Queries
    
    private func updatePopularQueries() {
        let queryFrequency = Dictionary(grouping: recentQueries) { $0.text.lowercased() }
            .mapValues { $0.count }
        
        popularQueries = queryFrequency
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { SearchQuery(id: UUID().uuidString, text: $0.key, timestamp: Date(), frequency: $0.value) }
    }
    
    private func generatePopularQueries() {
        // Default popular queries for new users
        if recentQueries.isEmpty {
            popularQueries = [
                SearchQuery(id: "1", text: "How many slices of bacon go in McAlister's Club?", timestamp: Date(), frequency: 10),
                SearchQuery(id: "2", text: "What do I need to make the club sandwich?", timestamp: Date(), frequency: 8),
                SearchQuery(id: "3", text: "How do I make the club?", timestamp: Date(), frequency: 7),
                SearchQuery(id: "4", text: "What recipes have bacon?", timestamp: Date(), frequency: 6),
                SearchQuery(id: "5", text: "What ingredients are in Caesar salad?", timestamp: Date(), frequency: 5)
            ]
        }
    }
    
    // MARK: - Persistence
    
    private func saveSearchHistory() {
        do {
            let data = try JSONEncoder().encode(recentQueries)
            userDefaults.set(data, forKey: recentQueriesKey)
        } catch {
            print("Failed to save search history: \(error)")
        }
    }
    
    private func loadSearchHistory() {
        guard let data = userDefaults.data(forKey: recentQueriesKey) else { return }
        
        do {
            recentQueries = try JSONDecoder().decode([SearchQuery].self, from: data)
        } catch {
            print("Failed to load search history: \(error)")
            recentQueries = []
        }
    }
}

// MARK: - Search Query Model

struct SearchQuery: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let timestamp: Date
    let frequency: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SearchQuery, rhs: SearchQuery) -> Bool {
        lhs.id == rhs.id
    }
}