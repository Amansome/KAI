# iOS App Code Structure

## Architecture Overview

The Kitchen Assistant app follows the MVVM (Model-View-ViewModel) pattern with SwiftUI:

- **Models**: Data structures (Recipe, Ingredient)
- **Managers**: Business logic (RecipeManager, VoiceManager, QueryProcessor)
- **Views**: SwiftUI user interface components

## File Implementations

---

## Models/RecipeModel.swift

This file defines the data structures that match the JSON format from the Python processor.

```swift
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
```

---

## Managers/RecipeManager.swift

Handles loading recipes from the JSON file and searching/filtering functionality.

```swift
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
```

---

## Managers/VoiceManager.swift

Handles speech recognition (listening) and text-to-speech (speaking).

```swift
import Foundation
import Speech
import AVFoundation

class VoiceManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcribedText = ""
    @Published var hasPermission = false
    @Published var errorMessage: String?

    // MARK: - Speech Recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Text-to-Speech
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Settings
    @Published var speechRate: Float = 0.5 // 0.0 to 1.0
    @Published var speechVolume: Float = 1.0 // 0.0 to 1.0
    @Published var speechPitch: Float = 1.0 // 0.5 to 2.0

    override init() {
        super.init()
        synthesizer.delegate = self
        requestPermissions()
    }

    // MARK: - Permissions
    func requestPermissions() {
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.hasPermission = true
                    print("✅ Speech recognition authorized")
                case .denied:
                    self?.errorMessage = "Speech recognition permission denied"
                    self?.hasPermission = false
                case .restricted:
                    self?.errorMessage = "Speech recognition restricted"
                    self?.hasPermission = false
                case .notDetermined:
                    self?.errorMessage = "Speech recognition not determined"
                    self?.hasPermission = false
                @unknown default:
                    self?.errorMessage = "Unknown authorization status"
                    self?.hasPermission = false
                }
            }
        }

        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.errorMessage = "Microphone permission denied"
                }
            }
        }
    }

    // MARK: - Speech Recognition
    func startListening() {
        guard hasPermission else {
            requestPermissions()
            return
        }

        // Cancel any ongoing tasks
        if audioEngine.isRunning {
            stopListening()
            return
        }

        do {
            try startRecognition()
        } catch {
            errorMessage = "Could not start speech recognition: \(error.localizedDescription)"
        }
    }

    private func startRecognition() throws {
        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "VoiceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }

        recognitionRequest.shouldReportPartialResults = true

        // Get audio input
        let inputNode = audioEngine.inputNode

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }

                // Auto-stop after silence
                if result.isFinal {
                    self.stopListening()
                }
            }

            if error != nil {
                self.stopListening()
            }
        }

        // Configure audio format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        DispatchQueue.main.async {
            self.isListening = true
            self.transcribedText = ""
            self.errorMessage = nil
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        DispatchQueue.main.async {
            self.isListening = false
        }
    }

    // MARK: - Text-to-Speech
    func speak(_ text: String) {
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = speechRate
        utterance.volume = speechVolume
        utterance.pitchMultiplier = speechPitch

        DispatchQueue.main.async {
            self.isSpeaking = true
        }

        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension VoiceManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
```

---

## Managers/QueryProcessor.swift

Processes natural language questions and generates appropriate answers.

```swift
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
```

---

## Views/ContentView.swift

Main UI with microphone button and conversation history.

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var recipeManager = RecipeManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var queryProcessor: QueryProcessor

    @State private var conversationHistory: [(question: String, answer: String)] = []
    @State private var showingRecipeList = false
    @State private var showingSettings = false

    init() {
        let recipeManager = RecipeManager()
        _recipeManager = StateObject(wrappedValue: recipeManager)
        _queryProcessor = StateObject(wrappedValue: QueryProcessor(recipeManager: recipeManager))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Conversation history
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if conversationHistory.isEmpty {
                                welcomeView
                            } else {
                                ForEach(conversationHistory.indices, id: \.self) { index in
                                    conversationBubble(
                                        question: conversationHistory[index].question,
                                        answer: conversationHistory[index].answer
                                    )
                                    .id(index)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: conversationHistory.count) { _ in
                        withAnimation {
                            proxy.scrollTo(conversationHistory.count - 1, anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Status and controls
                VStack(spacing: 16) {
                    if voiceManager.isListening {
                        Text(voiceManager.transcribedText.isEmpty ? "Listening..." : voiceManager.transcribedText)
                            .font(.headline)
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut, value: voiceManager.transcribedText)
                    } else if voiceManager.isSpeaking {
                        HStack {
                            Text("Speaking...")
                                .font(.headline)
                                .foregroundColor(.green)

                            ProgressView()
                        }
                    }

                    // Microphone button
                    Button(action: handleMicrophonePress) {
                        ZStack {
                            Circle()
                                .fill(microphoneButtonColor)
                                .frame(width: 100, height: 100)
                                .shadow(radius: 5)

                            Image(systemName: microphoneIconName)
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(!voiceManager.hasPermission)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("🍳 Kitchen Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingRecipeList = true }) {
                        Image(systemName: "list.bullet")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingRecipeList) {
                RecipeListView(recipeManager: recipeManager)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(voiceManager: voiceManager)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Welcome View
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Kitchen Assistant")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Tap the microphone and ask a question!")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Text("Try asking:")
                    .font(.headline)

                exampleQuestion("How many slices of bacon go in McAlister's Club?")
                exampleQuestion("What do I need to make the club sandwich?")
                exampleQuestion("How do I make the club?")
                exampleQuestion("What recipes have bacon?")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
    }

    private func exampleQuestion(_ text: String) -> some View {
        HStack {
            Image(systemName: "quote.bubble")
                .foregroundColor(.blue)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Conversation Bubble
    private func conversationBubble(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question
            HStack {
                Spacer()
                Text(question)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .frame(maxWidth: 300, alignment: .trailing)
            }

            // Answer
            HStack {
                Text(answer)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(16)
                    .frame(maxWidth: 300, alignment: .leading)
                Spacer()
            }
        }
    }

    // MARK: - Microphone Handling
    private func handleMicrophonePress() {
        if voiceManager.isListening {
            // Stop listening and process query
            voiceManager.stopListening()

            if !voiceManager.transcribedText.isEmpty {
                processQuery(voiceManager.transcribedText)
            }
        } else if voiceManager.isSpeaking {
            // Stop speaking
            voiceManager.stopSpeaking()
        } else {
            // Start listening
            voiceManager.startListening()
        }
    }

    private func processQuery(_ query: String) {
        let answer = queryProcessor.processQuery(query)

        conversationHistory.append((question: query, answer: answer))

        // Speak the answer
        voiceManager.speak(answer)
    }

    private var microphoneButtonColor: Color {
        if voiceManager.isListening {
            return .red
        } else if voiceManager.isSpeaking {
            return .green
        } else {
            return .blue
        }
    }

    private var microphoneIconName: String {
        if voiceManager.isListening {
            return "mic.fill"
        } else if voiceManager.isSpeaking {
            return "speaker.wave.2.fill"
        } else {
            return "mic"
        }
    }
}
```

---

## Additional Views

Create these additional views for a complete app:

### Views/RecipeListView.swift
- List all recipes grouped by category
- Search functionality
- Tap to see details

### Views/RecipeDetailView.swift
- Show full recipe information
- Ingredients list
- Step-by-step instructions
- Equipment needed

### Views/SettingsView.swift
- Speech rate slider
- Volume control
- Voice selection
- Dark mode toggle
- About information

---

## Implementation Order

1. **Start with Models** - Create RecipeModel.swift first
2. **Add RecipeManager** - Load and parse JSON
3. **Add VoiceManager** - Speech recognition and TTS
4. **Add QueryProcessor** - Natural language processing
5. **Build ContentView** - Main UI
6. **Add Supporting Views** - Recipe list, details, settings

## Testing Tips

- Test each manager independently
- Use print statements to debug JSON loading
- Test voice recognition with simple queries first
- Add more patterns to QueryProcessor as you discover common questions

## Next Steps

Once the basic app is working:
- Add more sophisticated NLP patterns
- Implement fuzzy search improvements
- Add favorites/bookmarks
- Add recipe images
- Implement offline voice recognition improvements
- Add analytics to track commonly asked questions
