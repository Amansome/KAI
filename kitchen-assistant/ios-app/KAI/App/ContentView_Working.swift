//
//  ContentView_Working.swift
//  KAI
//
//  Working version of ContentView with wake word support
//

import SwiftUI
import Combine

struct ContentView_Working: View {
    @StateObject private var recipeManager = RecipeManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var queryProcessor: QueryProcessor

    @State private var conversationHistory: [(question: String, answer: String)] = []
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
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Kitchen Assistant")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if voiceManager.wakeWordDetected {
                        Text("Hey, Kai detected! 👋")
                            .foregroundColor(.green)
                            .font(.headline)
                    } else if voiceManager.isWakeWordListening {
                        Text("Say 'Hey, Kai' to start")
                            .foregroundColor(.blue)
                            .font(.subheadline)
                    }
                }
                .padding()
                
                // Status indicators
                if voiceManager.isListening {
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .scaleEffect(1.5)
                            .animation(.easeInOut(duration: 0.8).repeatForever(), value: voiceManager.isListening)
                        
                        Text(voiceManager.transcribedText.isEmpty ? "Listening..." : voiceManager.transcribedText)
                            .font(.headline)
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
                
                // Conversation history
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(conversationHistory.indices, id: \.self) { index in
                            conversationBubble(
                                question: conversationHistory[index].question,
                                answer: conversationHistory[index].answer
                            )
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // Input controls
                VStack(spacing: 16) {
                    // Input mode selector
                    Picker("Input Mode", selection: $inputMode) {
                        Label("Voice", systemImage: "mic").tag(InputMode.voice)
                        Label("Text", systemImage: "keyboard").tag(InputMode.text)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Input interface
                    if inputMode == .text {
                        HStack {
                            TextField("Ask about recipes...", text: $textInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    submitTextQuery()
                                }
                            
                            Button(action: submitTextQuery) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(textInput.isEmpty ? .gray : .blue)
                            }
                            .disabled(textInput.isEmpty)
                        }
                        .padding(.horizontal)
                    } else {
                        Button(action: handleMicrophonePress) {
                            ZStack {
                                Circle()
                                    .fill(microphoneButtonColor)
                                    .frame(width: 80, height: 80)
                                    .scaleEffect(voiceManager.isListening ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: voiceManager.isListening)

                                Image(systemName: microphoneIconName)
                                    .font(.system(size: 35))
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(!voiceManager.hasPermission)
                    }
                }
                .padding()
            }
            .navigationTitle("Kitchen Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { voiceManager.toggleWakeWordListening() }) {
                        Image(systemName: voiceManager.wakeWordEnabled ? "ear" : "ear.trianglebadge.exclamationmark")
                            .foregroundColor(voiceManager.wakeWordEnabled ? .blue : .gray)
                    }
                }
            }
        }
        .onAppear {
            setupWakeWordMonitoring()
        }
    }
    
    // MARK: - Helper Methods
    private func conversationBubble(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question
            HStack {
                Spacer()
                Text(question)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .frame(maxWidth: 250, alignment: .trailing)
            }
            
            // Answer
            HStack {
                Text(answer)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .frame(maxWidth: 250, alignment: .leading)
                Spacer()
            }
        }
    }
    
    private func submitTextQuery() {
        let query = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        textInput = ""
        isTextFieldFocused = false
        processQuery(query)
    }
    
    private func handleMicrophonePress() {
        if voiceManager.isListening {
            voiceManager.stopListening()
            
            if !voiceManager.transcribedText.isEmpty {
                if voiceManager.wakeWordDetected {
                    processWakeWordQuery(voiceManager.transcribedText)
                } else {
                    processQuery(voiceManager.transcribedText)
                }
            }
        } else if voiceManager.isSpeaking {
            voiceManager.stopSpeaking()
        } else {
            voiceManager.startListening()
        }
    }
    
    private func processQuery(_ query: String) {
        let answer = queryProcessor.processQuery(query)
        conversationHistory.append((question: query, answer: answer))
        
        if inputMode == .voice {
            voiceManager.speak(answer)
        }
    }
    
    private func processWakeWordQuery(_ query: String) {
        let answer = queryProcessor.processQuery(query)
        conversationHistory.append((question: "Hey, Kai: \(query)", answer: answer))
        
        // Always speak wake word responses
        voiceManager.speak(answer)
    }
    
    private func setupWakeWordMonitoring() {
        // This would set up wake word monitoring
        // For now, it's handled automatically by VoiceManager
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
    ContentView_Working()
}