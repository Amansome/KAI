//
//  AllViews.swift
//  KAI
//
//  Kitchen Assistant - All Views (Temporary combined file)
//

import SwiftUI
import AVFoundation

// MARK: - Recipe Image View (Simplified)
struct RecipeImageView: View {
    let recipe: Recipe
    
    var body: some View {
        // Simple placeholder with category emoji and colors
        ZStack {
            // Background gradient based on category
            LinearGradient(
                colors: getColorsForCategory(recipe.category),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 4) {
                Text(recipe.categoryEmoji)
                    .font(.title2)
                
                Text(recipe.name)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
            .padding(4)
        }
    }
    
    private func getColorsForCategory(_ category: String) -> [Color] {
        switch category.lowercased() {
        case "sandwich":
            return [Color.orange, Color.red]
        case "salad":
            return [Color.green, Color.teal]
        case "kids":
            return [Color.purple, Color.pink]
        case "prep":
            return [Color.blue, Color.indigo]
        default:
            return [Color.gray, Color.secondary]
        }
    }
}

// MARK: - Recipe List View
struct RecipeListView: View {
    @ObservedObject var recipeManager: RecipeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    
    var filteredRecipes: [Recipe] {
        var recipes = recipeManager.recipes
        
        // Filter by category
        if selectedCategory != "All" {
            recipes = recipes.filter { $0.category.lowercased() == selectedCategory.lowercased() }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            recipes = recipes.filter { recipe in
                recipe.name.lowercased().contains(searchText.lowercased()) ||
                recipe.ingredients.whole.contains { ingredient in
                    ingredient.name.lowercased().contains(searchText.lowercased())
                }
            }
        }
        
        return recipes.sorted { $0.name < $1.name }
    }
    
    var categories: [String] {
        ["All"] + recipeManager.categories
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter section
                VStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search recipes or ingredients...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.self) { category in
                                Button(action: { selectedCategory = category }) {
                                    Text(category.capitalized)
                                        .font(.subheadline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedCategory == category ? Color.blue : Color(.systemGray5)
                                        )
                                        .foregroundColor(
                                            selectedCategory == category ? .white : .primary
                                        )
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                // Recipe list
                if recipeManager.isLoading {
                    Spacer()
                    ProgressView("Loading recipes...")
                    Spacer()
                } else if filteredRecipes.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No recipes found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if !searchText.isEmpty {
                            Text("Try adjusting your search terms")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                } else {
                    List(filteredRecipes) { recipe in
                        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                            RecipeRowView(recipe: recipe)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Recipes (\(filteredRecipes.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RecipeRowView: View {
    let recipe: Recipe
    
    var body: some View {
        HStack(spacing: 12) {
            // Recipe image
            RecipeImageView(recipe: recipe)
                .frame(width: 60, height: 45)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(recipe.categoryDisplayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Label("\(recipe.ingredients.whole.count)", systemImage: "list.bullet")
                    Label("\(recipe.steps.count)", systemImage: "number")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recipe Detail View
struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with image
                VStack(alignment: .leading, spacing: 12) {
                    // Recipe image
                    RecipeImageView(recipe: recipe)
                        .frame(height: 200)
                        .cornerRadius(12)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text(recipe.name)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(recipe.categoryDisplayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(recipe.categoryEmoji)
                            .font(.largeTitle)
                    }
                    
                    // Quick stats
                    HStack(spacing: 20) {
                        StatView(icon: "list.bullet", value: "\(recipe.ingredients.whole.count)", label: "Ingredients")
                        StatView(icon: "number", value: "\(recipe.steps.count)", label: "Steps")
                        if !recipe.equipment.isEmpty {
                            StatView(icon: "wrench.and.screwdriver", value: "\(recipe.equipment.count)", label: "Equipment")
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Tab selector
                Picker("Section", selection: $selectedTab) {
                    Text("Ingredients").tag(0)
                    Text("Steps").tag(1)
                    if !recipe.equipment.isEmpty || !recipe.scoops.isEmpty {
                        Text("Equipment").tag(2)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case 0:
                        ingredientsSection
                    case 1:
                        stepsSection
                    case 2:
                        equipmentSection
                    default:
                        ingredientsSection
                    }
                }
            }
            .padding()
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Ingredients Section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.headline)
            
            ForEach(recipe.ingredients.whole) { ingredient in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(ingredient.amount)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            
                            Text(ingredient.name.capitalized)
                                .font(.subheadline)
                        }
                        
                        if !ingredient.notes.isEmpty {
                            Text(ingredient.notes.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Steps Section
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Instructions")
                .font(.headline)
            
            if recipe.steps.isEmpty {
                Text("No steps available for this recipe.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.blue)
                            .clipShape(Circle())
                        
                        Text(step)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Equipment Section
    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !recipe.equipment.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Equipment Needed")
                        .font(.headline)
                    
                    ForEach(recipe.equipment, id: \.self) { equipment in
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.orange)
                            Text(equipment)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            
            if !recipe.scoops.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scoops Required")
                        .font(.headline)
                    
                    ForEach(recipe.scoops, id: \.self) { scoop in
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundColor(scoopColor(for: scoop))
                            Text(scoop)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func scoopColor(for scoop: String) -> Color {
        switch scoop.lowercased() {
        case let s where s.contains("blue"): return .blue
        case let s where s.contains("yellow"): return .yellow
        case let s where s.contains("red"): return .red
        case let s where s.contains("green"): return .green
        case let s where s.contains("purple"): return .purple
        case let s where s.contains("grey") || s.contains("gray"): return .gray
        default: return .primary
        }
    }
}

struct StatView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.blue)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var voiceManager: VoiceManager
    @ObservedObject var llmQueryProcessor: LLMQueryProcessor
    @Environment(\.dismiss) private var dismiss

    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var selectedVoiceIdentifier: String = ""
    @State private var isDownloading = false
    @State private var showDeleteConfirmation = false
    @State private var downloadError: String?

    // State for async model data
    @State private var modelStatus: (isDownloaded: Bool, isLoaded: Bool, downloadProgress: Double, modelInfo: ModelInfo?) = (false, false, 0.0, nil)
    @State private var storageInfo: (modelSize: String, available: String, required: String) = ("0 MB", "0 MB", "0 MB")
    @State private var canDownload = false

    var body: some View {
        NavigationView {
            Form {
                // AI Model Section
                Section {
                    aiModelSection
                } header: {
                    Text("AI Model")
                } footer: {
                    Text("Required for intelligent recipe responses. Model will be downloaded once and used offline.")
                }

                // Speech Settings Section
                Section("Speech Settings") {
                    // Speech Rate
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speech Rate")
                            Spacer()
                            Text("\(Int(voiceManager.speechRate * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $voiceManager.speechRate, in: 0.1...1.0, step: 0.1)
                            .accentColor(.blue)
                    }
                    
                    // Speech Volume
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Volume")
                            Spacer()
                            Text("\(Int(voiceManager.speechVolume * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $voiceManager.speechVolume, in: 0.1...1.0, step: 0.1)
                            .accentColor(.blue)
                    }
                    
                    // Speech Pitch
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Pitch")
                            Spacer()
                            Text(String(format: "%.1fx", voiceManager.speechPitch))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $voiceManager.speechPitch, in: 0.5...2.0, step: 0.1)
                            .accentColor(.blue)
                    }
                    
                    // Test Speech Button
                    Button(action: testSpeech) {
                        HStack {
                            Image(systemName: "speaker.wave.2")
                            Text("Test Speech")
                        }
                    }
                    .disabled(voiceManager.isSpeaking)
                }
                
                // Permissions Section
                Section("Permissions") {
                    HStack {
                        Image(systemName: voiceManager.hasPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(voiceManager.hasPermission ? .green : .red)
                        
                        VStack(alignment: .leading) {
                            Text("Speech Recognition")
                            if !voiceManager.hasPermission {
                                Text("Required for voice commands")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if !voiceManager.hasPermission {
                            Button("Grant") {
                                voiceManager.requestPermissions()
                            }
                            .font(.caption)
                        }
                    }
                    
                    if let errorMessage = voiceManager.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Reset Section
                Section("Reset") {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadModelData()
            }
            .onChange(of: isDownloading) { _ in
                Task {
                    await loadModelData()
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadModelData() async {
        modelStatus = await llmQueryProcessor.getModelStatus()
        storageInfo = await llmQueryProcessor.getStorageInfo()
        canDownload = await llmQueryProcessor.canDownloadModel()
    }
    
    // MARK: - AI Model Section
    private var aiModelSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Model Status
            modelStatusRow

            // Model Information
            if let modelInfo = modelStatus.modelInfo {
                modelInfoRow(modelInfo)
            }

            // Storage Information
            storageInfoRow

            // Download/Delete Button
            modelActionButton

            // Error Message
            if let error = downloadError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    private var modelStatusRow: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Llama 3.2 1B")
                    .font(.headline)

                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isDownloading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    private func modelInfoRow(_ model: ModelInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Size:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2f GB", model.sizeInGB))
                    .fontWeight(.medium)
            }
            .font(.subheadline)

            HStack {
                Text("Description:")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .font(.subheadline)

            Text(model.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var storageInfoRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Available Storage:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(storageInfo.available)
                    .fontWeight(.medium)
            }
            .font(.subheadline)

            if !modelStatus.isDownloaded {
                HStack {
                    Text("Required:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(storageInfo.required)
                        .fontWeight(.medium)
                }
                .font(.subheadline)
            }
        }
    }

    private var modelActionButton: some View {
        Group {
            if modelStatus.isDownloaded {
                // Delete button
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Model")
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                }
                .confirmationDialog(
                    "Delete AI Model?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        deleteModel()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will delete the downloaded model (~1.5 GB). You can download it again later.")
                }
            } else if isDownloading {
                // Progress bar
                VStack(spacing: 8) {
                    ProgressView(value: modelStatus.downloadProgress)
                        .progressViewStyle(.linear)

                    HStack {
                        Text("\(Int(modelStatus.downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("Cancel") {
                            cancelDownload()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            } else {
                // Download button
                Button(action: {
                    downloadModel()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download Model")
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                }
                .disabled(!canDownload)
            }
        }
    }

    // MARK: - AI Model Helpers

    private var statusIcon: String {
        if modelStatus.isDownloaded && modelStatus.isLoaded {
            return "checkmark.circle.fill"
        } else if modelStatus.isDownloaded {
            return "arrow.down.circle.fill"
        } else if isDownloading {
            return "arrow.down.circle"
        } else {
            return "xmark.circle"
        }
    }

    private var statusColor: Color {
        if modelStatus.isDownloaded && modelStatus.isLoaded {
            return .green
        } else if modelStatus.isDownloaded {
            return .orange
        } else if isDownloading {
            return .blue
        } else {
            return .gray
        }
    }

    private var statusText: String {
        if modelStatus.isDownloaded && modelStatus.isLoaded {
            return "Ready • AI responses active"
        } else if modelStatus.isDownloaded {
            return "Downloaded • Tap to reload"
        } else if isDownloading {
            return "Downloading..."
        } else {
            return "Not downloaded • Required for AI"
        }
    }

    private func downloadModel() {
        guard canDownload else {
            downloadError = "Not enough storage space. Need at least 2GB free."
            return
        }

        isDownloading = true
        downloadError = nil

        Task {
            do {
                try await llmQueryProcessor.downloadModel()
                await MainActor.run {
                    isDownloading = false
                    downloadError = nil
                }
                await loadModelData()
            } catch {
                await MainActor.run {
                    isDownloading = false
                    downloadError = error.localizedDescription
                }
            }
        }
    }

    private func cancelDownload() {
        Task {
            await llmQueryProcessor.cancelDownload()
            await MainActor.run {
                isDownloading = false
                downloadError = nil
            }
            await loadModelData()
        }
    }

    private func deleteModel() {
        Task {
            do {
                try await llmQueryProcessor.deleteModel()
                await MainActor.run {
                    downloadError = nil
                }
                await loadModelData()
            } catch {
                await MainActor.run {
                    downloadError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Helper Functions
    private func testSpeech() {
        let testMessage = "Hello! This is a test of the Kitchen Assistant voice settings."
        voiceManager.speak(testMessage)
    }

    private func resetToDefaults() {
        voiceManager.speechRate = 0.5
        voiceManager.speechVolume = 1.0
        voiceManager.speechPitch = 1.0
    }
}
