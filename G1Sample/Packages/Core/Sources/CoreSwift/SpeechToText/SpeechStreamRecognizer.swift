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
    private var recognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastRecognizedText: String = ""
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
    
    func startRecognition() {
        lastTranscription = nil
        self.lastRecognizedText = ""
        cacheString = ""
        let localIdentifier = languageDic["EN"]
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localIdentifier ?? "en-US"))!
        
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
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] (result, error) in
            guard let self = self else { return }
            if let error = error {
                print("SpeechRecognizer Recognition error: \(error)")
            } else if let result = result {
                    
                let currentTranscription = result.bestTranscription
                if lastTranscription == nil {
                    cacheString = currentTranscription.formattedString
                } else {
                    
                    if (currentTranscription.segments.count < lastTranscription?.segments.count ?? 1 || currentTranscription.segments.count == 1) {
                        self.lastRecognizedText += cacheString
                        cacheString = ""
                        print("lastRecognizedText: \(self.lastRecognizedText)")
                    } else {
                        cacheString = currentTranscription.formattedString
                    }
                }
                lastTranscription = result.bestTranscription
            }
        }
    }
    
    func stopRecognition() {
        
        print("stopRecognition-----self.lastRecognizedText-------\(self.lastRecognizedText)------cacheString----------\(cacheString)---")
        self.lastRecognizedText += cacheString
        
        recognitionTask?.cancel()
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Error stop audio session: \(error)")
            return
        }
        recognitionRequest = nil
        recognitionTask = nil
        print("COMPLETE RECOGNITION IS : \(self.lastRecognizedText)")
        recognizedText = self.lastRecognizedText
        self.lastRecognizedText = ""
    }
    
    func appendPCMData(_ pcmData: Data) {
        print("appendPCMData-------pcmData------\(pcmData.count)--")
        guard let recognitionRequest = recognitionRequest else {
            print("Recognition request is not available")
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
