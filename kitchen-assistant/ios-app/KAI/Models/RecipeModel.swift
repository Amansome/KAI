//
//  RecipeModel.swift
//  KAI
//
//  Kitchen Assistant - Recipe Data Models
//

import Foundation

// MARK: - Recipe Model
struct Recipe: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let ingredients: RecipeIngredients
    let steps: [String]
    let equipment: [String]
    let scoops: [String]
}

// MARK: - Recipe Ingredients
struct RecipeIngredients: Codable {
    let whole: [Ingredient]
}

// MARK: - Ingredient
struct Ingredient: Codable, Identifiable {
    var id: String { name + amount }
    let name: String
    let amount: String
    let notes: String
}

// MARK: - Recipe Collection (Root JSON structure)
struct RecipeCollection: Codable {
    let recipes: [Recipe]
    let metadata: RecipeMetadata?
}

struct RecipeMetadata: Codable {
    let totalRecipes: Int?
    let categories: [String]?
    let generatedBy: String?

    enum CodingKeys: String, CodingKey {
        case totalRecipes = "total_recipes"
        case categories
        case generatedBy = "generated_by"
    }
}

// MARK: - Category Extension
extension Recipe {
    var categoryDisplayName: String {
        switch category.lowercased() {
        case "sandwich": return "Sandwiches"
        case "salad": return "Salads"
        case "kids": return "Kids Menu"
        case "prep": return "Prep Items"
        default: return "Other"
        }
    }

    var categoryEmoji: String {
        switch category.lowercased() {
        case "sandwich": return "🥪"
        case "salad": return "🥗"
        case "kids": return "🧒"
        case "prep": return "🔪"
        default: return "🍽️"
        }
    }
}
