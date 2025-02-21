//
//  SpeechStreamRecognizer.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 26/1/25.
//

import AVFoundation
import Speech

class SpeechStreamRecognizer {
    @Published var initiallized: Bool = false
    @Published var recognizedText: String = ""
    @Published var previewText: String = ""
    @Published var wakeWordDetected: Bool = false
    private var recognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastRecognizedText: String = ""
    private var isListeningForWakeWord: Bool = false
    private var lastTranscriptionTime: Date = Date()
    private var silenceTimer: Timer?
    let languageDic = [
        "EN": "en-US"
    ]
    
    private var lastTranscription: SFTranscription?
    private var cacheString = ""
    
    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        
        var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }
    
    init() {
        if #available(iOS 13.0, *) {
            Task {
                do {
                    guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                        throw RecognizerError.notAuthorizedToRecognize
                    }
                    
                     guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                         throw RecognizerError.notPermittedToRecord
                     }
                    initiallized = true
                } catch {
                    print("SFSpeechRecognizer------permission error----\(error)")
                }
            }
        }
    }
    
    func startWakeWordDetection() {
        // Reset all state
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        lastTranscription = nil
        self.lastRecognizedText = ""
        cacheString = ""
        previewText = ""
        wakeWordDetected = false
        
        // Set wake word detection mode
        isListeningForWakeWord = true
        lastTranscriptionTime = Date()
        
        // Start fresh recognition
        startRecognition()
    }

    func stopWakeWordDetection() {
        isListeningForWakeWord = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // Clean up recognition
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Clear all text
        previewText = ""
        lastRecognizedText = ""
        cacheString = ""
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error stopping audio session: \(error)")
        }
    }
// Voice recognition is used for two cases:
// 1. The user is in always listening mode to listen to the user's wake word to enable the AI
// 2. The user is in translation mode to listen to the user's voice to translate the text
// 3. There is basic control flow to the recognition:
// 4. If the user is not in translation mode, start wake word detection
// 5. If the user is in translation mode, stop wake word detection
// 6. If the user says "Hey Jarvis", start AI mode

    func startRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        lastTranscription = nil
        self.lastRecognizedText = ""
        cacheString = ""
        previewText = ""
        wakeWordDetected = false
        lastTranscriptionTime = Date()
        
        guard recognizer.isAvailable else {
            print("startRecognition recognizer is not available")
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error setting up audio session: \(error)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Failed to create recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true
        
        var lastPreviewUpdate = Date()
        let updateInterval = 0.1 // Reduce update interval to 100ms for smoother updates
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] (result, error) in
            guard let self = self else { return }
            if let error = error as? NSError {
                // Just log errors, don't display them
                let isNoSpeechError = (error.domain == "kAFAssistantErrorDomain" && error.code == 203) ||
                                    (error.domain == "com.apple.speech.recognition.error" && error.code == 203)
                let isCanceledError = (error.domain == "com.apple.speech.recognition.error" && error.code == 1)
                
                if !isNoSpeechError && !isCanceledError {
                    print("SpeechRecognizer Recognition error: \(error)")
                }
                return  // Don't update preview text for any errors
            }
            
            guard let result = result else { return }
            let currentTranscription = result.bestTranscription
            
            // Update last transcription time and start silence detection
            self.lastTranscriptionTime = Date()
            
            // Handle silence detection based on mode
            if self.isListeningForWakeWord || G1Controller.shared.g1Manager.currentMode != .translation {
                self.silenceTimer?.invalidate()
                self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    let currentTime = Date()
                    if currentTime.timeIntervalSince(self.lastTranscriptionTime) >= 1.5 {
                        if self.isListeningForWakeWord {
                            // Wake word mode silence detection
                            let finalText = currentTranscription.formattedString.lowercased()
                            if finalText.contains("hey jarvis"), let range = finalText.range(of: "hey jarvis") {
                                let aiQuery = String(finalText[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                                if !aiQuery.isEmpty {
                                    print("Sending to AI after wake word: \(aiQuery)")
                                    self.previewText = ""
                                    self.recognizedText = aiQuery
                                    self.wakeWordDetected = true
                                    
                                    // Stop wake word detection before sending the query
                                    self.stopWakeWordDetection()
                                    
                                    // Ensure the query is processed
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        self.recognizedText = aiQuery
                                    }
                                }
                            }
                        } else if G1Controller.shared.g1Manager.currentMode != .translation {
                            // Normal transcription mode silence detection (not in translation mode)
                            let finalText = currentTranscription.formattedString
                            // Don't send if it's just the wake word
                            if !finalText.isEmpty && !finalText.lowercased().contains("hey jarvis") {
                                print("Sending to AI after silence (transcription mode): \(finalText)")
                                self.previewText = ""
                                self.recognizedText = finalText
                                self.stopRecognition()
                            }
                        }
                    }
                }
            }
            
            // Check for wake word if in wake word detection mode
            if self.isListeningForWakeWord {
                let transcribedText = currentTranscription.formattedString.lowercased()
                if transcribedText.contains("hey jarvis") {
                    print("Wake word detected!")
                    self.wakeWordDetected = true
                    self.lastRecognizedText = ""
                    self.cacheString = ""
                    
                    Task {
                        // First exit all functions on both glasses
                        await G1Controller.shared.g1Manager.sendCommand([0x4F]) // Exit all functions
                        try? await Task.sleep(nanoseconds: 300 * 1_000_000) // 300ms delay
                        
                        // Send the text display command with proper flags
                        let displayText = "Listening..."
                        guard let textData = displayText.data(using: .utf8) else { return }
                        
                        // Build command based on SendResult model from the g1 python library
                        // Command structure: [command, seq, total_packages, current_package, screen_status, char_pos0, char_pos1, page_number, max_pages, ...data]
                        var command: [UInt8] = [
                            0x4E,           // SEND_RESULT command
                            0x00,           // sequence number
                            0x01,           // total packages
                            0x00,           // current package
                            0x71,           // screen status (0x70 Text Show | 0x01 New Content)
                            0x00,           // char position 0
                            0x00,           // char position 1
                            0x01,           // page number
                            0x01            // max pages
                        ]
                        command.append(contentsOf: Array(textData))
                        
                        // Send to both glasses with proper timing
                        await G1Controller.shared.g1Manager.sendCommand(command)
                        try? await Task.sleep(nanoseconds: 300 * 1_000_000) // 300ms delay
                        
                        // Send AI mode command
                        let aiCommand: [UInt8] = [0xF5, 0x17] // Start AI mode
                        await G1Controller.shared.g1Manager.sendCommand(aiCommand)
                    }
                    
                    self.stopWakeWordDetection()
                    return
                }
                // Don't update preview text in wake word mode
                return
            }
            
            // Update preview text at regular intervals
            let now = Date()
            if now.timeIntervalSince(lastPreviewUpdate) >= updateInterval {
                if !self.isListeningForWakeWord {
                    self.previewText = currentTranscription.formattedString
                }
                lastPreviewUpdate = now
            }
        }
    }
    
    func stopRecognition() {
        // Update recognized text if we have content
        if !cacheString.isEmpty {
            self.lastRecognizedText += cacheString
        }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error stop audio session: \(error)")
            return
        }
        
        // If we have recognized text, send it through
        if !self.lastRecognizedText.isEmpty {
            print("COMPLETE RECOGNITION IS : \(self.lastRecognizedText)")
            recognizedText = self.lastRecognizedText
        }
        
        // Always clear the preview text
        previewText = ""
        self.lastRecognizedText = ""
        cacheString = ""
    }
    
    func appendPCMData(_ pcmData: Data) {
        guard initiallized else {
            print("Cannot process PCM data - speech recognizer not initialized")
            return
        }
        
        guard let recognitionRequest = recognitionRequest else {
            print("Cannot process PCM data - recognition request not available")
            return
        }
        
        guard pcmData.count > 0 else {
            print("Received empty PCM data")
            return
        }

        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)!
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(pcmData.count) / audioFormat.streamDescription.pointee.mBytesPerFrame) else {
            print("Failed to create audio buffer")
            return
        }
        audioBuffer.frameLength = audioBuffer.frameCapacity

        pcmData.withUnsafeBytes { (bufferPointer: UnsafeRawBufferPointer) in
            if let audioDataPointer = bufferPointer.baseAddress?.assumingMemoryBound(to: Int16.self) {
                let audioBufferPointer = audioBuffer.int16ChannelData?.pointee
                audioBufferPointer?.initialize(from: audioDataPointer, count: pcmData.count / MemoryLayout<Int16>.size)
                recognitionRequest.append(audioBuffer)
            } else {
                print("Failed to get pointer to audio data")
            }
        }
    }
    // update speech recognizer if the input language for translation is changed
    func updateRecognizer(locale: Locale?) {
        guard let locale = locale,
              let newRecognizer = SFSpeechRecognizer(locale: locale) else {
            print("Failed to create speech recognizer for locale: \(String(describing: locale))")
            return
        }
        
        // Stop any ongoing recognition
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Create a new recognizer with the specified locale
        recognizer = newRecognizer
        print("Successfully updated speech recognizer to locale: \(locale.identifier)")
        
        // If we were actively recognizing, restart with new language
        let wasRecognizing = recognitionTask != nil
        if wasRecognizing {
            startRecognition()
        }
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
