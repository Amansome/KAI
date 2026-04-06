//
//  OfflineModeManager.swift
//  KAI
//
//  Kitchen Assistant - Offline Mode Manager
//

import Foundation
import Network

class OfflineModeManager: ObservableObject {
    @Published var isOnline = true
    @Published var offlineCapabilities: OfflineCapabilities
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        self.offlineCapabilities = OfflineCapabilities()
        startNetworkMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                self?.updateOfflineCapabilities()
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateOfflineCapabilities() {
        offlineCapabilities.updateCapabilities(isOnline: isOnline)
    }
    
    // MARK: - Offline Features
    
    func getOfflineResponse(for query: String) -> String? {
        guard !isOnline else { return nil }
        
        let lowercaseQuery = query.lowercased()
        
        // Basic offline responses
        if lowercaseQuery.contains("network") || lowercaseQuery.contains("internet") || lowercaseQuery.contains("connection") {
            return "You're currently offline. I can still help you with recipes from your local database, search history, and basic cooking questions."
        }
        
        if lowercaseQuery.contains("offline") {
            return "In offline mode, I can:\n• Search your local recipe database\n• Show your search history\n• Provide basic cooking tips\n• Help with ingredient substitutions"
        }
        
        // Offline cooking tips
        if lowercaseQuery.contains("substitute") || lowercaseQuery.contains("replacement") {
            return getIngredientSubstitutions(for: lowercaseQuery)
        }
        
        if lowercaseQuery.contains("cooking tip") || lowercaseQuery.contains("help") {
            return getRandomCookingTip()
        }
        
        return nil
    }
    
    private func getIngredientSubstitutions(for query: String) -> String {
        let substitutions = [
            "butter": "Use vegetable oil (3/4 the amount) or applesauce for baking",
            "egg": "Use 1/4 cup applesauce, 1 mashed banana, or 1 tbsp ground flaxseed + 3 tbsp water",
            "milk": "Use water, almond milk, or any plant-based milk",
            "sugar": "Use honey (3/4 the amount), maple syrup, or stevia",
            "flour": "Use almond flour, coconut flour, or oat flour",
            "onion": "Use onion powder (1 tbsp = 1 medium onion) or shallots",
            "garlic": "Use garlic powder (1/8 tsp = 1 clove) or garlic salt"
        ]
        
        for (ingredient, substitution) in substitutions {
            if query.contains(ingredient) {
                return "For \(ingredient): \(substitution)"
            }
        }
        
        return "Common substitutions: butter→oil, egg→applesauce, milk→plant milk. What specific ingredient do you need to substitute?"
    }
    
    private func getRandomCookingTip() -> String {
        let tips = [
            "Always taste your food as you cook and adjust seasoning accordingly.",
            "Let meat rest for 5-10 minutes after cooking to retain juices.",
            "Salt your pasta water - it should taste like the sea.",
            "Room temperature ingredients mix better than cold ones.",
            "Don't overcrowd your pan when searing - it causes steaming instead.",
            "Sharp knives are safer than dull ones and make prep work easier.",
            "Read the entire recipe before starting to cook.",
            "Mise en place - prepare all ingredients before you start cooking."
        ]
        
        return tips.randomElement() ?? "Keep cooking and experimenting!"
    }
}

// MARK: - Offline Capabilities

struct OfflineCapabilities {
    var canSearchRecipes = true
    var canViewHistory = true
    var canGetCookingTips = true
    var canUseVoiceCommands = true
    var canSyncData = false
    var canAccessOnlineFeatures = false
    
    mutating func updateCapabilities(isOnline: Bool) {
        canSyncData = isOnline
        canAccessOnlineFeatures = isOnline
    }
    
    var availableFeatures: [String] {
        var features: [String] = []
        
        if canSearchRecipes { features.append("Recipe Search") }
        if canViewHistory { features.append("Search History") }
        if canGetCookingTips { features.append("Cooking Tips") }
        if canUseVoiceCommands { features.append("Voice Commands") }
        
        return features
    }
    
    var unavailableFeatures: [String] {
        var features: [String] = []
        
        if !canSyncData { features.append("Data Sync") }
        if !canAccessOnlineFeatures { features.append("Online Recipe Updates") }
        
        return features
    }
}