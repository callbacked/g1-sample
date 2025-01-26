//
//  G1Controller.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 26/1/25.
//

import Foundation
import Combine
import CoreObjC

final class G1Controller {
    static let shared = G1Controller()
    private var cancellables = Set<AnyCancellable>()

    private let speechRecognizer: SpeechStreamRecognizer
    private let bluetoothManager: G1BluetoothManager

    @Published var g1Connected: Bool = false
    
    private init() {
        self.speechRecognizer = SpeechStreamRecognizer()
        self.bluetoothManager = G1BluetoothManager()
        handleRecogizerReady()
        handleReady()
    }

    private func startSpeechRecognition() {
        speechRecognizer.startRecognition()
    }

    private func stopSpeechRecognition() {
        speechRecognizer.stopRecognition()
    }

    public func startBluetoothScanning() {
        bluetoothManager.startScan()
    }
    
    private func handleRecogizerReady() {
        speechRecognizer.$initiallized.sink { [weak self] initialized in
            guard let self = self else { return }
            if initialized {
                handleListenTrigger()
                handleIncomingVoiceData()
                handleRecognizedText()
            }
        }
        .store(in: &cancellables)
    }
    
    private func handleReady() {
        bluetoothManager.$g1Ready.sink { [weak self] ready in
            guard let self = self else { return }
            self.g1Connected = ready
        }
        .store(in: &cancellables)
    }
    
    private func handleListenTrigger() {
        bluetoothManager.$aiListening.sink { [weak self] listening in
            guard let self = self else { return }
            if listening {
                self.startSpeechRecognition()
            } else {
                self.stopSpeechRecognition()
            }
        }
        .store(in: &cancellables)
    }
    
    private func handleIncomingVoiceData() {
        bluetoothManager.$voiceData.sink { [weak self] data in
            guard let self = self else { return }
            
            guard data.count > 2 else { return }
            let effectiveData = data.subdata(in: 2..<data.count)
            let pcmConverter = PcmConverter()
            let pcmData = pcmConverter.decode(effectiveData)
            
            self.speechRecognizer.appendPCMData(pcmData as Data)
        }
        .store(in: &cancellables)
    }
    
    private func handleRecognizedText() {
        speechRecognizer.$recognizedText.sink { [weak self] text in
            guard let self = self else { return }
            print("RECOGNIZED TEXT : \(text)")
            Task {
                await self.bluetoothManager.sendText(text: text)
            }
        }
        .store(in: &cancellables)
    }
}
