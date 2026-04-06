//
//  ContentView_Simple.swift
//  KAI
//
//  Kitchen Assistant - Simplified Main View (Fallback)
//

import SwiftUI

struct ContentView_Simple: View {
    @StateObject private var recipeManager = RecipeManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var queryProcessor: QueryProcessor

    @State private var conversationHistory: [(question: String, answer: String)] = []
    @State private var showingRecipeList = false
    @State private var showingSettings = false
    @State private var textInput = ""
    @State private var inputMode: InputMode = .voice
    @FocusState private var isTextFieldFocused: Bool

    enum InputMode {
        case voice, text
    }

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

                // Input controls
                VStack(spacing: 16) {
                    // Status indicator
                    if voiceManager.isListening {
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
        VStack(spacing: 32) {
            // Hero section
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                }

                VStack(spacing: 8) {
                    Text("Kitchen Assistant")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your AI-powered cooking companion")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Instructions
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Image(systemName: "1.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
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
                        .font(.title2)
                        .foregroundColor(.blue)
                    
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
                        .font(.title2)
                        .foregroundColor(.blue)
                    
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
            .background(Color(.systemGray6))
            .cornerRadius(16)

            // Example questions
            VStack(alignment: .leading, spacing: 12) {
                Text("Popular questions:")
                    .font(.headline)
                    .foregroundColor(.primary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
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
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "quote.bubble.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text(text)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
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
        HStack(spacing: 12) {
            TextField("Ask about recipes, ingredients, or cooking steps...", text: $textInput, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isTextFieldFocused)
                .lineLimit(1...4)
                .onSubmit {
                    submitTextQuery()
                }
            
            Button(action: submitTextQuery) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
            }
            .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        
        textInput = ""
        isTextFieldFocused = false
        processQuery(query)
    }
    
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

        // Speak the answer only in voice mode
        if inputMode == .voice {
            voiceManager.speak(answer)
        }
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

#Preview {
    ContentView_Simple()
}