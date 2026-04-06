//
//  QueryProcessor.swift
//  KAI
//
//  Kitchen Assistant - Natural Language Query Processor
//

import Foundation

class QueryProcessor: ObservableObject {
    private let recipeManager: RecipeManager

    init(recipeManager: RecipeManager) {
        self.recipeManager = recipeManager
    }

    // MARK: - Process Query
    func processQuery(_ query: String) -> String {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)

        // Pattern: "How many [ingredient] in/go in [recipe]?"
        if let answer = handleIngredientQuantityQuery(normalizedQuery) {
            return answer
        }

        // Pattern: "What do I need to make [recipe]?"
        if let answer = handleIngredientsListQuery(normalizedQuery) {
            return answer
        }

        // Pattern: "How do I make [recipe]?" or "What are the steps for [recipe]?"
        if let answer = handleStepsQuery(normalizedQuery) {
            return answer
        }

        // Pattern: "What recipes have [ingredient]?"
        if let answer = handleRecipesByIngredientQuery(normalizedQuery) {
            return answer
        }

        // Pattern: "What's in [recipe]?" or "Tell me about [recipe]"
        if let answer = handleRecipeInfoQuery(normalizedQuery) {
            return answer
        }

        // Pattern: "What [category] recipes do we have?"
        if let answer = handleCategoryQuery(normalizedQuery) {
            return answer
        }

        // Default response
        return "I'm not sure how to answer that. Try asking:\n" +
               "• How many [ingredient] go in [recipe]?\n" +
               "• What do I need to make [recipe]?\n" +
               "• How do I make [recipe]?\n" +
               "• What recipes have [ingredient]?"
    }

    // MARK: - Query Handlers

    /// Handle: "How many [ingredient] in/go in [recipe]?"
    private func handleIngredientQuantityQuery(_ query: String) -> String? {
        let patterns = [
            #"how many (.+?) (?:in|go in|for) (?:the )?(.+?)[\?.]?$"#,
            #"how much (.+?) (?:in|go in|for) (?:the )?(.+?)[\?.]?$"#,
            #"(?:amount of|quantity of) (.+?) (?:in|for) (?:the )?(.+?)[\?.]?$"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)) {

                if let ingredientRange = Range(match.range(at: 1), in: query),
                   let recipeRange = Range(match.range(at: 2), in: query) {

                    let ingredient = String(query[ingredientRange]).trimmingCharacters(in: .whitespaces)
                    let recipeName = String(query[recipeRange]).trimmingCharacters(in: .whitespaces)

                    if let amount = recipeManager.getIngredientAmount(recipeName: recipeName, ingredientName: ingredient) {
                        return "You need \(amount) of \(ingredient) for \(recipeName)."
                    } else {
                        let recipes = recipeManager.searchRecipes(byName: recipeName)
                        if recipes.isEmpty {
                            return "I couldn't find a recipe for \(recipeName)."
                        } else {
                            return "I couldn't find \(ingredient) in the \(recipes[0].name) recipe."
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Handle: "What do I need to make [recipe]?"
    private func handleIngredientsListQuery(_ query: String) -> String? {
        let patterns = [
            #"what (?:do i|does it) need (?:to make|for) (?:the )?(.+?)[\?.]?$"#,
            #"(?:ingredients|what goes) (?:in|for) (?:the )?(.+?)[\?.]?$"#,
            #"what's in (?:the )?(.+?)[\?.]?$"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
               let recipeRange = Range(match.range(at: 1), in: query) {

                let recipeName = String(query[recipeRange]).trimmingCharacters(in: .whitespaces)
                let recipes = recipeManager.searchRecipes(byName: recipeName)

                guard let recipe = recipes.first else {
                    return "I couldn't find a recipe for \(recipeName)."
                }

                let ingredientsList = recipe.ingredients.whole.map { ingredient in
                    var result = "\(ingredient.amount) \(ingredient.name)"
                    if !ingredient.notes.isEmpty {
                        result += " (\(ingredient.notes))"
                    }
                    return result
                }.joined(separator: ", ")

                return "For \(recipe.name), you need: \(ingredientsList)."
            }
        }

        return nil
    }

    /// Handle: "How do I make [recipe]?"
    private func handleStepsQuery(_ query: String) -> String? {
        let patterns = [
            #"how (?:do i|to) make (?:the )?(.+?)[\?.]?$"#,
            #"(?:steps|instructions|procedure) for (?:the )?(.+?)[\?.]?$"#,
            #"what are the steps (?:for|to make) (?:the )?(.+?)[\?.]?$"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
               let recipeRange = Range(match.range(at: 1), in: query) {

                let recipeName = String(query[recipeRange]).trimmingCharacters(in: .whitespaces)
                let recipes = recipeManager.searchRecipes(byName: recipeName)

                guard let recipe = recipes.first else {
                    return "I couldn't find a recipe for \(recipeName)."
                }

                if recipe.steps.isEmpty {
                    return "I don't have steps for \(recipe.name) yet."
                }

                let stepsList = recipe.steps.enumerated().map { index, step in
                    "Step \(index + 1): \(step)"
                }.joined(separator: ". ")

                return "Here's how to make \(recipe.name). \(stepsList)"
            }
        }

        return nil
    }

    /// Handle: "What recipes have [ingredient]?"
    private func handleRecipesByIngredientQuery(_ query: String) -> String? {
        let patterns = [
            #"what recipes (?:have|use|contain|need) (.+?)[\?.]?$"#,
            #"(?:recipes|dishes) with (.+?)[\?.]?$"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
               let ingredientRange = Range(match.range(at: 1), in: query) {

                let ingredient = String(query[ingredientRange]).trimmingCharacters(in: .whitespaces)
                let recipes = recipeManager.searchRecipes(byIngredient: ingredient)

                if recipes.isEmpty {
                    return "I couldn't find any recipes with \(ingredient)."
                }

                let recipeNames = recipes.map { $0.name }.joined(separator: ", ")
                return "Recipes with \(ingredient): \(recipeNames)."
            }
        }

        return nil
    }

    /// Handle: "What's in [recipe]?" or "Tell me about [recipe]"
    private func handleRecipeInfoQuery(_ query: String) -> String? {
        let patterns = [
            #"(?:tell me about|what's|describe) (?:the )?(.+?)[\?.]?$"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
               let recipeRange = Range(match.range(at: 1), in: query) {

                let recipeName = String(query[recipeRange]).trimmingCharacters(in: .whitespaces)
                let recipes = recipeManager.searchRecipes(byName: recipeName)

                guard let recipe = recipes.first else {
                    return "I couldn't find a recipe for \(recipeName)."
                }

                var info = "\(recipe.name) is a \(recipe.category). "
                info += "It has \(recipe.ingredients.whole.count) ingredients "
                info += "and \(recipe.steps.count) steps."

                if !recipe.equipment.isEmpty {
                    info += " Equipment needed: \(recipe.equipment.joined(separator: ", "))."
                }

                return info
            }
        }

        return nil
    }

    /// Handle: "What [category] recipes do we have?"
    private func handleCategoryQuery(_ query: String) -> String? {
        let categories = ["sandwich", "salad", "kids", "prep"]

        for category in categories {
            if query.contains(category) {
                let recipes = recipeManager.getRecipes(inCategory: category)

                if recipes.isEmpty {
                    return "I don't have any \(category) recipes loaded."
                }

                let recipeNames = recipes.map { $0.name }.joined(separator: ", ")
                return "We have these \(category) recipes: \(recipeNames)."
            }
        }

        return nil
    }
}
