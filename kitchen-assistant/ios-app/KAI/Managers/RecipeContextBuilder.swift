//
//  RecipeContextBuilder.swift
//  KAI
//
//  Kitchen Assistant - Recipe Context Builder for LLM
//  Builds context from recipes.json for AI understanding
//

import Foundation

/// Builds context from recipe database for LLM system prompt
class RecipeContextBuilder {

    // MARK: - Properties

    private let recipeManager: RecipeManager
    private var cachedContext: String?
    private let maxRecipes: Int
    private let maxContextLength: Int

    // MARK: - Initialization

    init(recipeManager: RecipeManager, maxRecipes: Int = 50, maxContextLength: Int = 4000) {
        self.recipeManager = recipeManager
        self.maxRecipes = maxRecipes
        self.maxContextLength = maxContextLength
    }

    // MARK: - Context Building

    /// Build complete system prompt with recipe context
    func buildSystemPrompt() -> String {
        // Return cached if available
        if let cached = cachedContext {
            return cached
        }

        // Build new context
        let context = generateContext()
        cachedContext = context
        return context
    }

    /// Force rebuild context (call when recipes change)
    func rebuildContext() -> String {
        cachedContext = nil
        return buildSystemPrompt()
    }

    /// Generate full context from recipes
    private func generateContext() -> String {
        let recipes = recipeManager.recipes
        let recipesToInclude = Array(recipes.prefix(maxRecipes))

        var context = """
        You are Kitchen Assistant (KAI), a helpful AI assistant for restaurant employees.
        You help with recipe questions, ingredient information, cooking instructions, and kitchen procedures.

        IMPORTANT INSTRUCTIONS:
        - For RECIPE-SPECIFIC questions (ingredients, steps), use ONLY the recipe database provided below
        - For GENERAL COOKING questions (substitutions, techniques, tips), use your culinary knowledge
        - Be concise and direct - restaurant staff need quick answers
        - When listing ingredients, include amounts
        - When explaining steps, be clear and sequential
        - Focus on practical, actionable information

        YOUR CAPABILITIES:
        - Provide ingredient lists with quantities from recipes below
        - Explain cooking steps in order from recipes below
        - Answer questions about specific recipes in the database
        - Find recipes by ingredient
        - Suggest ingredient substitutions using general cooking knowledge
        - Explain equipment usage and cooking techniques
        - Help with recipe modifications and scaling
        - Answer general cooking questions (temperatures, times, techniques)

        RECIPE DATABASE (\(recipesToInclude.count) recipes):

        """

        // Add each recipe
        for (index, recipe) in recipesToInclude.enumerated() {
            let recipeText = formatRecipe(recipe, index: index + 1)
            context += recipeText + "\n\n"

            // Check if we're approaching max context length
            if context.count > maxContextLength {
                context += "\n[Note: Some recipes truncated due to length. Ask for specific recipes if needed.]\n"
                break
            }
        }

        context += """

        RESPONSE GUIDELINES:
        - Start responses directly without preamble
        - Use natural, conversational language
        - Be specific with measurements and quantities
        - For substitutions, provide practical alternatives
        - When unsure, admit it rather than guess
        - Keep responses focused and practical

        Example responses:
        Q: "How many slices of bacon in McAlister's Club?"
        A: "4 slices of crispy bacon."

        Q: "What do I need to make the Club Sandwich?"
        A: "You'll need 3 slices of bacon (crispy), 4 oz grilled chicken breast (sliced), 3 slices of bread, 2 leaves of lettuce, 3 slices of tomato, and 2 tbsp mayonnaise."

        Q: "How do I make McAlister's Club?"
        A: "1. Toast 3 slices of bread until golden brown. 2. Cook 4 slices of bacon until crispy. 3. Spread mayonnaise on each bread slice. 4. Layer turkey and swiss cheese on first slice. 5. Add second slice of bread. 6. Layer ham, cheddar cheese, bacon, lettuce, and tomato. 7. Top with third slice and secure with toothpicks. 8. Cut diagonally."

        Q: "Can I substitute bacon?"
        A: "Yes! You can substitute bacon with turkey bacon, prosciutto, or even smoked ham. For a vegetarian option, try crispy coconut bacon or tempeh bacon. Use the same amount as the original recipe calls for."

        Q: "What can I use instead of mayonnaise?"
        A: "You can substitute mayonnaise with Greek yogurt, sour cream, or avocado for a healthier option. Aioli or hummus also work well. Use the same amount as the recipe calls for."

        Now answer the user's question based on the recipe database and your culinary knowledge.
        """

        return context
    }

    // MARK: - Recipe Formatting

    /// Format a single recipe for context
    private func formatRecipe(_ recipe: Recipe, index: Int) -> String {
        var text = "RECIPE \(index): \(recipe.name.uppercased())\n"
        text += "Category: \(recipe.categoryDisplayName)\n"

        // Ingredients
        if !recipe.ingredients.whole.isEmpty {
            text += "\nIngredients:\n"
            for ingredient in recipe.ingredients.whole {
                let amount = ingredient.amount
                let name = ingredient.name.capitalized
                let notes = ingredient.notes.isEmpty ? "" : " (\(ingredient.notes))"
                text += "  - \(amount) \(name)\(notes)\n"
            }
        }

        // Steps
        if !recipe.steps.isEmpty {
            text += "\nInstructions:\n"
            for (stepIndex, step) in recipe.steps.enumerated() {
                text += "  \(stepIndex + 1). \(step)\n"
            }
        }

        // Equipment
        if !recipe.equipment.isEmpty {
            text += "\nEquipment: \(recipe.equipment.joined(separator: ", "))\n"
        }

        // Scoops
        if !recipe.scoops.isEmpty {
            text += "Scoops: \(recipe.scoops.joined(separator: ", "))\n"
        }

        return text
    }

    // MARK: - Context Queries

    /// Build context for a specific query (can add relevant recipes)
    func buildQueryContext(for query: String) -> String {
        let systemPrompt = buildSystemPrompt()

        // Could add query-specific context here
        // For example, if query mentions specific recipe, include more detail about it

        return systemPrompt
    }

    /// Get compact recipe list for quick reference
    func getRecipeList() -> String {
        let recipes = recipeManager.recipes
        let names = recipes.map { $0.name }

        return "Available recipes: " + names.joined(separator: ", ")
    }

    /// Get recipes by category
    func getRecipesByCategory() -> String {
        let recipes = recipeManager.recipes
        var categories: [String: [String]] = [:]

        for recipe in recipes {
            let category = recipe.categoryDisplayName
            if categories[category] == nil {
                categories[category] = []
            }
            categories[category]?.append(recipe.name)
        }

        var text = "Recipes by category:\n"
        for (category, recipeNames) in categories.sorted(by: { $0.key < $1.key }) {
            text += "\n\(category): \(recipeNames.joined(separator: ", "))"
        }

        return text
    }

    /// Find recipes containing specific ingredient
    func findRecipesWithIngredient(_ ingredient: String) -> [Recipe] {
        let recipes = recipeManager.recipes
        let searchTerm = ingredient.lowercased()

        return recipes.filter { recipe in
            recipe.ingredients.whole.contains { ing in
                ing.name.lowercased().contains(searchTerm)
            }
        }
    }

    /// Get context statistics
    func getContextStats() -> (recipeCount: Int, ingredientCount: Int, estimatedTokens: Int) {
        let recipes = recipeManager.recipes
        let context = buildSystemPrompt()

        let ingredientCount = recipes.reduce(0) { $0 + $1.ingredients.whole.count }

        // Rough estimate: ~4 characters per token
        let estimatedTokens = context.count / 4

        return (
            recipeCount: recipes.count,
            ingredientCount: ingredientCount,
            estimatedTokens: estimatedTokens
        )
    }

    /// Clear cached context
    func clearCache() {
        cachedContext = nil
    }
}

// MARK: - Preview/Debug Helpers

extension RecipeContextBuilder {

    /// Print context to console for debugging
    func printContext() {
        let context = buildSystemPrompt()
        print("=" * 80)
        print("RECIPE CONTEXT FOR LLM")
        print("=" * 80)
        print(context)
        print("=" * 80)
        print("Context length: \(context.count) characters (~\(context.count / 4) tokens)")
        print("=" * 80)
    }

    /// Get a preview of the context (first 500 characters)
    func getContextPreview() -> String {
        let context = buildSystemPrompt()
        if context.count > 500 {
            return String(context.prefix(500)) + "... [truncated]"
        }
        return context
    }
}

// MARK: - String Extension

private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
