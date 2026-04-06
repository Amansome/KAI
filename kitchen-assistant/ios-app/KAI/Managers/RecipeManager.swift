//
//  RecipeManager.swift
//  KAI
//
//  Kitchen Assistant - Recipe Data Manager
//

import Foundation

class RecipeManager: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        loadRecipes()
    }

    // MARK: - Load Recipes
    func loadRecipes() {
        isLoading = true
        errorMessage = nil

        guard let url = Bundle.main.url(forResource: "recipes", withExtension: "json") else {
            errorMessage = "Could not find recipes.json in bundle"
            isLoading = false
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let recipeCollection = try decoder.decode(RecipeCollection.self, from: data)

            DispatchQueue.main.async {
                self.recipes = recipeCollection.recipes
                self.isLoading = false
                print("✅ Loaded \(self.recipes.count) recipes")
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load recipes: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Error loading recipes: \(error)")
            }
        }
    }

    // MARK: - Search Functions

    /// Get recipe by exact ID
    func getRecipe(byId id: String) -> Recipe? {
        return recipes.first { $0.id == id }
    }

    /// Search recipes by name (fuzzy matching)
    func searchRecipes(byName name: String) -> [Recipe] {
        let searchTerm = name.lowercased().trimmingCharacters(in: .whitespaces)

        return recipes.filter { recipe in
            let recipeName = recipe.name.lowercased()

            // Exact match
            if recipeName == searchTerm {
                return true
            }

            // Contains match
            if recipeName.contains(searchTerm) {
                return true
            }

            // Word-by-word fuzzy match
            let searchWords = searchTerm.split(separator: " ")
            let recipeWords = recipeName.split(separator: " ")

            let matchCount = searchWords.filter { searchWord in
                recipeWords.contains { recipeWord in
                    recipeWord.starts(with: searchWord) ||
                    searchWord.starts(with: recipeWord)
                }
            }.count

            return matchCount >= searchWords.count / 2
        }.sorted { first, second in
            // Prioritize exact matches and shorter names
            let firstScore = first.name.lowercased() == searchTerm ? 1000 :
                           (first.name.lowercased().contains(searchTerm) ? 100 : 0)
            let secondScore = second.name.lowercased() == searchTerm ? 1000 :
                            (second.name.lowercased().contains(searchTerm) ? 100 : 0)

            if firstScore != secondScore {
                return firstScore > secondScore
            }

            return first.name.count < second.name.count
        }
    }

    /// Search recipes that contain a specific ingredient
    func searchRecipes(byIngredient ingredientName: String) -> [Recipe] {
        let searchTerm = ingredientName.lowercased().trimmingCharacters(in: .whitespaces)

        return recipes.filter { recipe in
            recipe.ingredients.whole.contains { ingredient in
                ingredient.name.lowercased().contains(searchTerm)
            }
        }
    }

    /// Get ingredient amount for a specific ingredient in a recipe
    func getIngredientAmount(recipeName: String, ingredientName: String) -> String? {
        let matchingRecipes = searchRecipes(byName: recipeName)
        guard let recipe = matchingRecipes.first else { return nil }

        let searchTerm = ingredientName.lowercased()

        let matchingIngredient = recipe.ingredients.whole.first { ingredient in
            ingredient.name.lowercased().contains(searchTerm)
        }

        return matchingIngredient?.amount
    }

    /// Get all recipes in a category
    func getRecipes(inCategory category: String) -> [Recipe] {
        recipes.filter { $0.category.lowercased() == category.lowercased() }
    }

    /// Get all unique categories
    var categories: [String] {
        Array(Set(recipes.map { $0.category })).sorted()
    }
}
