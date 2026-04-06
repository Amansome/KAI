//
//  BuildTest.swift
//  KAI
//
//  Build test to verify all managers compile correctly
//

import Foundation
import SwiftUI

// Test that all managers can be instantiated
class BuildTest {
    static func testManagers() {
        let recipeManager = RecipeManager()
        let voiceManager = VoiceManager()
        let queryProcessor = QueryProcessor(recipeManager: recipeManager)
        let searchHistoryManager = SearchHistoryManager()
        let offlineModeManager = OfflineModeManager()
        let imageManager = RecipeImageManager()
        
        print("All managers instantiated successfully")
        print("Recipe count: \(recipeManager.recipes.count)")
        print("Voice permission: \(voiceManager.hasPermission)")
        print("Search history count: \(searchHistoryManager.recentQueries.count)")
        print("Online status: \(offlineModeManager.isOnline)")
        print("Image cache size: \(imageManager.getCacheSize())")
    }
}