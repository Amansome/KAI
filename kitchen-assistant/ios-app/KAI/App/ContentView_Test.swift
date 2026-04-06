//
//  ContentView_Test.swift
//  KAI
//
//  Test version of ContentView to verify compilation
//

import SwiftUI
import Combine

struct ContentView_Test: View {
    @StateObject private var recipeManager = RecipeManager()
    @StateObject private var voiceManager = VoiceManager()
    @StateObject private var enhancedQueryProcessor: EnhancedQueryProcessor
    @StateObject private var fallbackQueryProcessor: QueryProcessor

    @State private var conversationHistory: [(question: String, answer: String)] = []
    @State private var isProcessingQuery = false
    @State private var ollamaAvailable = false

    init() {
        let recipeManager = RecipeManager()
        _recipeManager = StateObject(wrappedValue: recipeManager)
        _enhancedQueryProcessor = StateObject(wrappedValue: EnhancedQueryProcessor(recipeManager: recipeManager))
        _fallbackQueryProcessor = StateObject(wrappedValue: QueryProcessor(recipeManager: recipeManager))
    }

    var body: some View {
        NavigationView {
            VStack {
                Text("Kitchen Assistant")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if voiceManager.wakeWordDetected {
                    Text("Hey, Kai detected! 👋")
                        .foregroundColor(.green)
                } else if voiceManager.isWakeWordListening {
                    Text("Say 'Hey, Kai' to start")
                        .foregroundColor(.blue)
                }
                
                Button("Test Query") {
                    testQuery()
                }
                .padding()
                
                if isProcessingQuery {
                    ProgressView("Processing...")
                }
                
                Spacer()
            }
            .navigationTitle("Test")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { checkOllamaStatus() }) {
                            Image(systemName: ollamaAvailable ? "brain.head.profile" : "brain.head.profile.fill")
                                .foregroundColor(ollamaAvailable ? .green : .gray)
                        }
                        
                        Button(action: { voiceManager.toggleWakeWordListening() }) {
                            Image(systemName: voiceManager.wakeWordEnabled ? "ear" : "ear.trianglebadge.exclamationmark")
                                .foregroundColor(voiceManager.wakeWordEnabled ? .blue : .gray)
                        }
                    }
                }
            }
        }
        .onAppear {
            checkOllamaStatus()
        }
    }
    
    private func testQuery() {
        isProcessingQuery = true
        
        Task {
            let answer = await enhancedQueryProcessor.processQuery("What recipes do you know?")
            
            await MainActor.run {
                conversationHistory.append((question: "What recipes do you know?", answer: answer))
                isProcessingQuery = false
            }
        }
    }
    
    private func checkOllamaStatus() {
        Task {
            let available = await enhancedQueryProcessor.checkOllamaAvailability()
            await MainActor.run {
                ollamaAvailable = available
            }
        }
    }
}

#Preview {
    ContentView_Test()
}