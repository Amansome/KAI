//
//  ContentView.swift
//  KAI
//
//  Kitchen Assistant - Main View
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var recipeManager = RecipeManager()
    @StateObject private var voiceManager = VoiceManager()
    @State private var llmQueryProcessor: LLMQueryProcessor? = nil
    // Temporarily disabled new managers to fix compilation
    // @StateObject private var searchHistoryManager = SearchHistoryManager()
    // @StateObject private var offlineModeManager = OfflineModeManager()
    // @StateObject private var imageManager = RecipeImageManager()

    @State private var conversationHistory: [(question: String, answer: String)] = []
    @State private var showingRecipeList = false
    @State private var showingSettings = false
    @State private var textInput = ""
    @State private var inputMode: InputMode = .voice
    @State private var showingSuggestions = false
    @State private var suggestions: [String] = []
    @State private var isProcessingQuery = false
    @State private var modelReady = false
    @FocusState private var isTextFieldFocused: Bool

    enum InputMode {
        case voice, text
    }

    init() {
        // Empty init - we'll initialize llmQueryProcessor in onAppear
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

                // Input controls
                VStack(spacing: 16) {
                    // Status indicator
                    if voiceManager.wakeWordDetected {
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .scaleEffect(1.5)
                                .animation(.easeInOut(duration: 0.3).repeatForever(), value: voiceManager.wakeWordDetected)
                            
                            Text("Hey, Kai detected! 👋")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    } else if voiceManager.isListening {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(voiceManager.transcribedText.isEmpty ? 1.5 : 1.0)
                                .animation(.easeInOut(duration: 0.8).repeatForever(), value: voiceManager.transcribedText.isEmpty)
                            
                            Text(voiceManager.transcribedText.isEmpty ? "Listening..." : voiceManager.transcribedText)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else if voiceManager.isSpeaking {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Speaking...")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    } else if voiceManager.isWakeWordListening {
                        HStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                                .opacity(0.7)
                            
                            Text("Say 'Hey, Kai' to start")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(8)
                    } else if isProcessingQuery {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing...")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Input mode selector
                    Picker("Input Mode", selection: $inputMode) {
                        Label("Voice", systemImage: "mic").tag(InputMode.voice)
                        Label("Text", systemImage: "keyboard").tag(InputMode.text)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Input interface based on mode
                    if inputMode == .text {
                        textInputInterface
                    } else {
                        voiceInputInterface
                    }

                    // Quick action buttons
                    quickActionButtons
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(.systemGroupedBackground), Color(.systemBackground)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .navigationTitle("🍳 Kitchen Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button(action: { showingRecipeList = true }) {
                            Image(systemName: "list.bullet")
                        }
                        
                        // Network status indicator (temporarily disabled)
                        // if !offlineModeManager.isOnline {
                        //     Image(systemName: "wifi.slash")
                        //         .foregroundColor(.orange)
                        //         .font(.caption)
                        // }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // AI Model status indicator
                        Button(action: {
                            Task {
                                await checkModelStatus()
                            }
                        }) {
                            Image(systemName: modelReady ? "brain.head.profile" : "brain.head.profile.fill")
                                .foregroundColor(modelReady ? .green : .gray)
                        }

                        // Wake word toggle
                        Button(action: { voiceManager.toggleWakeWordListening() }) {
                            Image(systemName: voiceManager.wakeWordEnabled ? "ear" : "ear.trianglebadge.exclamationmark")
                                .foregroundColor(voiceManager.wakeWordEnabled ? .blue : .gray)
                        }

                        // Search history button
                        Button(action: { showSearchHistory() }) {
                            Image(systemName: "clock.arrow.circlepath")
                        }

                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingRecipeList) {
                RecipeListView(recipeManager: recipeManager)
            }
            .sheet(isPresented: $showingSettings) {
                if let processor = llmQueryProcessor {
                    SettingsView(voiceManager: voiceManager, llmQueryProcessor: processor)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Initialize the LLM query processor on main actor
            Task { @MainActor in
                llmQueryProcessor = LLMQueryProcessor(recipeManager: recipeManager)
                
                // Check model availability on startup
                await checkModelStatus()

                // Monitor wake word detection
                setupWakeWordMonitoring()

                // Preload model in background for faster first query
                await llmQueryProcessor?.preloadModel()
            }
        }
        .onChange(of: voiceManager.shouldProcessTranscription) { shouldProcess in
            if shouldProcess && !voiceManager.transcribedText.isEmpty {
                // Process the transcribed text automatically
                let transcribedText = voiceManager.transcribedText
                
                // Add to search history for voice queries too (temporarily disabled)
                // searchHistoryManager.addQuery(transcribedText)
                
                // Check if this was triggered by wake word
                if voiceManager.wakeWordDetected {
                    processWakeWordQuery(transcribedText)
                } else {
                    processQuery(transcribedText)
                }
                
                // Reset the signal
                voiceManager.shouldProcessTranscription = false
            }
        }
    }
    
    private func setupWakeWordMonitoring() {
        // Monitor wake word detection changes
        voiceManager.$wakeWordDetected
            .sink { detected in
                if detected {
                    // Wake word was detected, start listening for the actual query
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if !voiceManager.isListening {
                            voiceManager.startListening()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    @State private var cancellables = Set<AnyCancellable>()

    // MARK: - Welcome View
    private var welcomeView: some View {
        VStack(spacing: 32) {
            // Hero section
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.blue.opacity(0.25), radius: 8, x: 0, y: 4)
                        .shadow(color: Color.purple.opacity(0.15), radius: 16, x: 0, y: 8)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 52))
                        .foregroundColor(.blue)
                        .shadow(color: Color.blue.opacity(0.35), radius: 10, x: 0, y: 6)
                }

                VStack(spacing: 8) {
                    Text("Kitchen Assistant")
                        .font(.system(size: 34 * 1.12, weight: .bold))
                        .fontWeight(.bold)
                    
                    Text("Your AI-powered cooking companion")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if voiceManager.wakeWordEnabled {
                        Text("Say 'Hey, Kai' to start")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                }
            }

            // Instructions
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Image(systemName: "1.circle.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Choose your input method")
                            .font(.headline)
                        Text("Voice or text - whatever works for you")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                HStack(spacing: 16) {
                    Image(systemName: "2.circle.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ask your question")
                            .font(.headline)
                        Text("About recipes, ingredients, or cooking steps")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                HStack(spacing: 16) {
                    Image(systemName: "3.circle.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Get instant answers")
                            .font(.headline)
                        Text("Powered by your recipe database")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemGray6), Color.orange.opacity(0.08)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)

            // Example questions
            VStack(alignment: .leading, spacing: 16) {
                Text("Popular questions:")
                    .font(.headline)
                    .foregroundColor(.primary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    exampleQuestionCard("How many slices of bacon go in McAlister's Club?")
                    exampleQuestionCard("What do I need to make the club sandwich?")
                    exampleQuestionCard("How do I make the club?")
                    exampleQuestionCard("What recipes have bacon?")
                }
            }
        }
        .padding()
    }

    private func exampleQuestionCard(_ text: String) -> some View {
        Button(action: {
            if inputMode == .text {
                textInput = text
                isTextFieldFocused = true
            } else {
                processQuery(text)
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "quote.bubble.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                
                Text(text)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.orange.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.clear)
        )
        .hoverEffect(.highlight)
    }

    // MARK: - Conversation Bubble
    private func conversationBubble(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question bubble
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(question)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .frame(maxWidth: 280, alignment: .trailing)
                    
                    Text("You")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
            }

            // Answer bubble
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.top, 2)
                        
                        Text(answer)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(18)
                            .frame(maxWidth: 280, alignment: .leading)
                    }
                    
                    Text("Kitchen Assistant")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 32)
                }
                Spacer()
            }
        }
    }

    // MARK: - Input Interfaces
    private var textInputInterface: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Ask about recipes, ingredients, or cooking steps...", text: $textInput, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .lineLimit(1...4)
                        .onSubmit {
                            submitTextQuery()
                        }
                        .onChange(of: textInput) { newValue in
                            updateSuggestions(for: newValue)
                        }
                        .onChange(of: isTextFieldFocused) { focused in
                            if focused {
                                updateSuggestions(for: textInput)
                            } else {
                                showingSuggestions = false
                            }
                        }
                    
                    // Suggestions dropdown
                    if showingSuggestions && !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(action: {
                                    textInput = suggestion
                                    showingSuggestions = false
                                    isTextFieldFocused = false
                                    submitTextQuery()
                                }) {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(suggestion)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if suggestion != suggestions.last {
                                    Divider()
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.top, 4)
                    }
                }
                
                Button(action: submitTextQuery) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Search history quick access (temporarily disabled)
            // if !searchHistoryManager.recentQueries.isEmpty && !isTextFieldFocused {
            //     ScrollView(.horizontal, showsIndicators: false) {
            //         HStack(spacing: 8) {
            //             ForEach(searchHistoryManager.recentQueries.prefix(5)) { query in
            //                 Button(action: {
            //                     textInput = query.text
            //                     submitTextQuery()
            //                 }) {
            //                     Text(query.text)
            //                         .font(.caption)
            //                         .padding(.horizontal, 12)
            //                         .padding(.vertical, 6)
            //                         .background(Color(.systemGray6))
            //                         .cornerRadius(16)
            //                         .lineLimit(1)
            //                 }
            //                 .buttonStyle(PlainButtonStyle())
            //             }
            //         }
            //         .padding(.horizontal)
            //     }
            //     .padding(.top, 8)
            // }
        }
    }
    
    private var voiceInputInterface: some View {
        Button(action: handleMicrophonePress) {
            ZStack {
                Circle()
                    .fill(microphoneButtonColor)
                    .frame(width: 80, height: 80)
                    .shadow(color: microphoneButtonColor.opacity(0.3), radius: 10, x: 0, y: 5)
                    .scaleEffect(voiceManager.isListening ? 1.1 : 1.0)
                    .overlay(
                        Circle()
                            .stroke(microphoneButtonColor.opacity(0.5), lineWidth: 2)
                            .scaleEffect(voiceManager.isListening ? 1.3 : 1.0)
                            .opacity(voiceManager.isListening ? 0.0 : 0.0)
                            .animation(
                                voiceManager.isListening ?
                                    .easeOut(duration: 1.2).repeatForever(autoreverses: false) : .default,
                                value: voiceManager.isListening
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: voiceManager.isListening)

                Image(systemName: microphoneIconName)
                    .font(.system(size: 35))
                    .foregroundColor(.white)
            }
        }
        .disabled(!voiceManager.hasPermission)
    }
    
    private var quickActionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Show Recipes",
                    icon: "list.bullet",
                    color: .blue
                ) {
                    showingRecipeList = true
                }
                
                QuickActionButton(
                    title: "What's Popular?",
                    icon: "star.fill",
                    color: .orange
                ) {
                    processQuery("What are the most popular recipes?")
                }
                
                QuickActionButton(
                    title: "Quick Meals",
                    icon: "clock.fill",
                    color: .green
                ) {
                    processQuery("What recipes can I make quickly?")
                }
                
                QuickActionButton(
                    title: "Ingredients",
                    icon: "carrot.fill",
                    color: .purple
                ) {
                    processQuery("What ingredients do I need for popular items?")
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Input Handling
    private func submitTextQuery() {
        let query = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        // Add to search history (temporarily disabled)
        // searchHistoryManager.addQuery(query)
        
        textInput = ""
        isTextFieldFocused = false
        showingSuggestions = false
        processQuery(query)
    }
    
    private func updateSuggestions(for input: String) {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedInput.isEmpty {
            suggestions = [] // Array(searchHistoryManager.recentQueries.prefix(3).map { $0.text })
        } else {
            suggestions = [] // searchHistoryManager.getSuggestions(for: trimmedInput)
        }
        
        showingSuggestions = !suggestions.isEmpty && isTextFieldFocused
    }
    
    private func handleMicrophonePress() {
        if voiceManager.isListening {
            // Stop listening and signal to process query
            voiceManager.shouldProcessTranscription = true
            voiceManager.stopListening()
        } else if voiceManager.isSpeaking {
            // Stop speaking
            voiceManager.stopSpeaking()
        } else {
            // Start listening (manual activation)
            voiceManager.startListening()
        }
    }

    private func processQuery(_ query: String) {
        Task {
            isProcessingQuery = true

            // Use LLM query processor (async)
            let answer = await llmQueryProcessor?.processQuery(query) ?? "LLM not initialized"

            await MainActor.run {
                conversationHistory.append((question: query, answer: answer))
                isProcessingQuery = false

                // Speak the answer only in voice mode or if user prefers it
                if inputMode == .voice {
                    voiceManager.speak(answer)
                }
            }
        }
    }

    private func processWakeWordQuery(_ query: String) {
        Task {
            isProcessingQuery = true

            // Use LLM query processor for wake word queries
            let answer = await llmQueryProcessor?.processQuery("Hey, Kai: \(query)") ?? "LLM not initialized"

            await MainActor.run {
                conversationHistory.append((question: "Hey, Kai: \(query)", answer: answer))
                isProcessingQuery = false

                // Always speak wake word responses
                voiceManager.speak(answer)
            }
        }
    }

    private func checkModelStatus() async {
        guard let processor = llmQueryProcessor else {
            modelReady = false
            return
        }
        modelReady = await processor.isModelReady()
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
    
    // MARK: - Search History
    private func showSearchHistory() {
        // Show recent queries as quick actions (temporarily disabled)
        // if !searchHistoryManager.recentQueries.isEmpty {
        //     let recentQuery = searchHistoryManager.recentQueries.first!
        //     if inputMode == .text {
        //         textInput = recentQuery.text
        //         isTextFieldFocused = true
        //     } else {
        //         processQuery(recentQuery.text)
        //     }
        // }
        
        // Fallback: show a sample query
        if inputMode == .text {
            textInput = "What recipes have bacon?"
            isTextFieldFocused = true
        } else {
            processQuery("What recipes have bacon?")
        }
    }
}

// MARK: - Quick Action Button Component
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80, height: 60)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView()
}
