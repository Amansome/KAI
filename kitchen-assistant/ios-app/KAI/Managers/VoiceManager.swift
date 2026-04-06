//
//  VoiceManager.swift
//  KAI
//
//  Kitchen Assistant - Voice Recognition & Text-to-Speech Manager
//

import Foundation
import Speech
import AVFoundation
import AudioToolbox

class VoiceManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcribedText = ""
    @Published var hasPermission = false
    @Published var errorMessage: String?
    @Published var isWakeWordListening = false
    @Published var wakeWordDetected = false
    @Published var shouldProcessTranscription = false

    // MARK: - Speech Recognition
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    // MARK: - Wake Word Detection
    private var wakeWordRecognizer: SFSpeechRecognizer?
    private var wakeWordRequest: SFSpeechAudioBufferRecognitionRequest?
    private var wakeWordTask: SFSpeechRecognitionTask?
    private var wakeWordAudioEngine: AVAudioEngine?
    private let wakeWord = "hey kai"
    private var wakeWordBuffer: [String] = []
    private let wakeWordBufferSize = 10

    // MARK: - Text-to-Speech
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Silence Detection
    private var lastSpeechTimestamp: Date?
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 2.0

    // MARK: - Settings
    @Published var speechRate: Float = 0.5 // 0.0 to 1.0
    @Published var speechVolume: Float = 1.0 // 0.0 to 1.0
    @Published var speechPitch: Float = 1.0 // 0.5 to 2.0
    @Published var wakeWordEnabled = true

    override init() {
        super.init()
        synthesizer.delegate = self
        setupSpeechRecognizer()
        requestPermissions()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        audioEngine = AVAudioEngine()
        
        // Setup wake word recognizer
        wakeWordRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        wakeWordAudioEngine = AVAudioEngine()
        
        guard speechRecognizer != nil else {
            errorMessage = "Speech recognition not available on this device"
            return
        }
        
        // Wake word listening will be started after permissions are granted
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
                    
                    // Start wake word listening now that we have permission
                    if self?.wakeWordEnabled == true {
                        self?.startWakeWordListening()
                    }
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
        
        guard let audioEngine = audioEngine, let speechRecognizer = speechRecognizer else {
            errorMessage = "Speech recognition not available"
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
            DispatchQueue.main.async {
                self.errorMessage = "Could not start speech recognition: \(error.localizedDescription)"
            }
        }
    }

    private func startRecognition() throws {
        guard let audioEngine = audioEngine, let speechRecognizer = speechRecognizer else {
            throw NSError(domain: "VoiceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not available"])
        }
        
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
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    // Update timestamp when we receive speech data
                    self.lastSpeechTimestamp = Date()
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

        // Initialize silence detection
        lastSpeechTimestamp = Date()
        startSilenceDetection()

        DispatchQueue.main.async {
            self.isListening = true
            self.transcribedText = ""
            self.errorMessage = nil
        }
    }

    func stopListening() {
        // Stop silence detection
        stopSilenceDetection()
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        DispatchQueue.main.async {
            self.isListening = false
        }
        
        // Restart wake word listening if enabled
        if wakeWordEnabled && !isWakeWordListening {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startWakeWordListening()
            }
        }
    }
    
    // MARK: - Silence Detection
    private func startSilenceDetection() {
        // Stop any existing timer
        stopSilenceDetection()
        
        // Start a repeating timer to check for silence
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Check if we've been silent for too long
            if let lastSpeech = self.lastSpeechTimestamp {
                let timeSinceLastSpeech = Date().timeIntervalSince(lastSpeech)
                if timeSinceLastSpeech >= self.silenceThreshold {
                    // Silence detected, signal to process transcription and stop listening
                    DispatchQueue.main.async {
                        self.shouldProcessTranscription = true
                        self.stopListening()
                    }
                }
            }
        }
    }
    
    private func stopSilenceDetection() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        lastSpeechTimestamp = nil
    }
    
    // MARK: - Wake Word Detection
    func startWakeWordListening() {
        guard wakeWordEnabled && hasPermission else { return }
        guard let wakeWordAudioEngine = wakeWordAudioEngine, let wakeWordRecognizer = wakeWordRecognizer else { return }
        
        // Don't start if already listening for wake word or actively listening
        if isWakeWordListening || isListening { return }
        
        do {
            try startWakeWordRecognition()
        } catch {
            print("❌ Could not start wake word detection: \(error.localizedDescription)")
            // Disable wake word if it fails to start
            DispatchQueue.main.async {
                self.wakeWordEnabled = false
                self.errorMessage = "Wake word detection unavailable: \(error.localizedDescription)"
            }
        }
    }
    
    private func startWakeWordRecognition() throws {
        guard let wakeWordAudioEngine = wakeWordAudioEngine, let wakeWordRecognizer = wakeWordRecognizer else {
            throw NSError(domain: "VoiceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Wake word recognition not available"])
        }
        
        // Cancel previous task
        wakeWordTask?.cancel()
        wakeWordTask = nil
        
        // Configure audio session for background listening
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        wakeWordRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let wakeWordRequest = wakeWordRequest else {
            throw NSError(domain: "VoiceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create wake word recognition request"])
        }
        
        wakeWordRequest.shouldReportPartialResults = true
        
        // Get audio input
        let inputNode = wakeWordAudioEngine.inputNode
        
        // Start recognition task
        wakeWordTask = wakeWordRecognizer.recognitionTask(with: wakeWordRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString.lowercased()
                self.processWakeWordTranscription(transcription)
            }
            
            if error != nil {
                // Restart wake word listening after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if self.wakeWordEnabled && !self.isListening {
                        self.startWakeWordListening()
                    }
                }
            }
        }
        
        // Configure audio format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            wakeWordRequest.append(buffer)
        }
        
        // Start audio engine
        wakeWordAudioEngine.prepare()
        try wakeWordAudioEngine.start()
        
        DispatchQueue.main.async {
            self.isWakeWordListening = true
        }
        
        print("👂 Wake word listening started - say 'Hey, Kai' to activate")
    }
    
    private func processWakeWordTranscription(_ transcription: String) {
        // Add to buffer and maintain size
        wakeWordBuffer.append(transcription)
        if wakeWordBuffer.count > wakeWordBufferSize {
            wakeWordBuffer.removeFirst()
        }
        
        // Check if wake word is detected in recent transcriptions
        let recentText = wakeWordBuffer.joined(separator: " ").lowercased()
        
        if recentText.contains(wakeWord) {
            DispatchQueue.main.async {
                self.onWakeWordDetected()
            }
        }
    }
    
    private func onWakeWordDetected() {
        print("🎯 Wake word 'Hey, Kai' detected!")
        
        // Stop wake word listening
        stopWakeWordListening()
        
        // Clear buffer
        wakeWordBuffer.removeAll()
        
        // Set wake word detected flag
        wakeWordDetected = true
        
        // Provide audio feedback
        playWakeWordFeedback()
        
        // Start main listening after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.startListening()
        }
        
        // Reset wake word detected flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.wakeWordDetected = false
        }
    }
    
    func stopWakeWordListening() {
        wakeWordAudioEngine?.stop()
        wakeWordAudioEngine?.inputNode.removeTap(onBus: 0)
        
        wakeWordRequest?.endAudio()
        wakeWordRequest = nil
        
        wakeWordTask?.cancel()
        wakeWordTask = nil
        
        DispatchQueue.main.async {
            self.isWakeWordListening = false
        }
    }
    
    private func playWakeWordFeedback() {
        // Play a subtle audio cue to indicate wake word was detected
        // Using system sound for now - could be customized later
        AudioServicesPlaySystemSound(1057) // Short beep sound
    }
    
    func toggleWakeWordListening() {
        wakeWordEnabled.toggle()
        
        if wakeWordEnabled {
            startWakeWordListening()
        } else {
            stopWakeWordListening()
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
