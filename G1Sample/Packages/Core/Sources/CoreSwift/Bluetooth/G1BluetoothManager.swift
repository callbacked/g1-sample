//
//  G1BluetoothManager.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//

import CoreBluetooth
import Foundation
import UIKit
import Combine

public final class G1BluetoothManager: NSObject {
    
    @Published public var g1Ready: Bool = false
    @Published public var voiceData: Data = Data()
    @Published public var aiListening: Bool = false
    
    enum AiMode: String {
        case AI_REQUESTED
        case AI_MIC_ON
        case AI_IDLE
    }
    
    let UART_SERVICE_UUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    let UART_TX_CHAR_UUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    let UART_RX_CHAR_UUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    public static let _bluetoothQueue = DispatchQueue(label: "BluetoothG1", qos: .userInitiated)
    
    private var aiMode: AiMode = .AI_IDLE {
        didSet {
            if aiMode == .AI_MIC_ON {
                aiListening = true
            } else {
                aiListening = false
            }
        }
    }
    
    private var responseModel:AiResponseToG1Model?
    private var receivedAck = false
    private var displayingResponseAiRightAck: Bool = false
    private var displayingResponseAiLeftAck: Bool = false
    
    private var evenaiSeq: UInt8 = 0
    private var centralManager: CBCentralManager!
    private var leftPeripheral: CBPeripheral?
    private var rightPeripheral: CBPeripheral?
    private var connectedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]
    
    private var aiTriggerTimeoutTimer: Timer?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: G1BluetoothManager._bluetoothQueue)
    }
    
    func startScan() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth is not powered on.")
            return
        }
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        print("Scanning for devices...")
    }
    
    func connectToGlasses() {
        if let leftPeripheral = leftPeripheral {
            centralManager.connect(leftPeripheral, options: nil)
        }
        
        if let rightPeripheral = rightPeripheral {
            centralManager.connect(rightPeripheral, options: nil)
        }
        guard let leftPeripheral, let rightPeripheral else { return }
        startHeartbeatTimer()
    }
    
    private func startAITriggerTimeoutTimer() {
        let backgroundQueue = DispatchQueue(label: "com.sample.aiTriggerTimerQueue", qos: .default)
        
        backgroundQueue.async { [weak self] in
            self?.aiTriggerTimeoutTimer = Timer(timeInterval: 6.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                guard let rightPeripheral = self.rightPeripheral else { return }
                sendMicOn(to: rightPeripheral, isOn: false)
            }
            
            RunLoop.current.add((self?.aiTriggerTimeoutTimer)!, forMode: .default)
            RunLoop.current.run()
        }
    }
    
    func startHeartbeatTimer() {
        let backgroundQueue = DispatchQueue(label: "com.sample.heartbeatTimerQueue", qos: .background)
        
        backgroundQueue.async { [weak self] in
            let timer = Timer(timeInterval: 15.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                guard let leftPeripheral = self.leftPeripheral else { return }
                self.sendHeartbeat(to: leftPeripheral)
                guard let rightPeripheral = self.rightPeripheral else { return }
                self.sendHeartbeat(to: rightPeripheral)
            }
            
            RunLoop.current.add(timer, forMode: .default)
            RunLoop.current.run()
        }
    }
    
    private func findCharacteristic(uuid: CBUUID, peripheral: CBPeripheral) -> CBCharacteristic? {
        for service in peripheral.services ?? [] {
            for characteristic in service.characteristics ?? [] {
                if characteristic.uuid == uuid {
                    return characteristic
                }
            }
        }
        return nil
    }
    
    private func getConnectedDevices() -> [CBPeripheral] {
        let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [UART_SERVICE_UUID])
        for peripheral in connectedPeripherals {
            print("Connected device: \(peripheral.name ?? "Unknown") - UUID: \(peripheral.identifier.uuidString)")
        }
        return connectedPeripherals
    }
    
    private func handleNotification(from peripheral: CBPeripheral, data: Data) {
        guard let command = data.first else { return }
        
        switch Commands(rawValue: command) {
        case .BLE_REQ_MIC_ON:
            guard aiMode == .AI_REQUESTED else { return }
            let acknowledge = CommandResponse(rawValue: data[1])
            if acknowledge == .ACK {
                aiMode = .AI_MIC_ON
            }
        case .BLE_REQ_TRANSFER_MIC_DATA:
            //print("Received voice data: \(data.subdata(in: 1..<data.count).hexEncodedString())")
            self.voiceData = data
        case .BLE_REQ_DEVICE_ORDER:
            print("Received device order: \(data.subdata(in: 1..<data.count).hexEncodedString())")
            let order = data[1]
            switch DeviceOrders(rawValue: order) {
            case .DISPLAY_READY:
                self.responseModel = nil
            case .TRIGGER_FOR_AI:
                if let rightPeripheral {
                    aiTriggerTimeoutTimer?.invalidate()
                    aiTriggerTimeoutTimer = nil
                    startAITriggerTimeoutTimer()
                    aiMode = .AI_REQUESTED
                    sendMicOn(to: rightPeripheral, isOn: true)
                }
                print("Trigger AI")
            case .TRIGGER_FOR_STOP_RECORDING:
                aiTriggerTimeoutTimer?.invalidate()
                aiTriggerTimeoutTimer = nil
                aiMode = .AI_IDLE
            case .TRIGGER_CHANGE_PAGE:
                guard var responseModel else { return }
                print("Change Page right")
                if responseModel.currentPage < responseModel.totalPages {
                    responseModel.currentPage += 1
                    self.responseModel = responseModel
                    Task {
                        await self.manualTextControl()
                    }
                } else {
                    print("Change Page left")
                    if responseModel.currentPage > 1 {
                        responseModel.currentPage -= 1
                        self.responseModel = responseModel
                        Task {
                            await self.manualTextControl()
                        }
                    }
                }
            case .G1_IS_READY:
                g1Ready = true
            default:
                break
            }
        case .BLE_REQ_EVENAI:
            if data.count > 1 {
                let acknowledge = CommandResponse(rawValue: data[1])
                if acknowledge == .ACK {
                    if peripheral == self.rightPeripheral {
                        self.displayingResponseAiRightAck = true
                    }
                    if peripheral == self.leftPeripheral {
                        self.displayingResponseAiLeftAck = true
                    }
                    receivedAck = self.displayingResponseAiRightAck && self.displayingResponseAiLeftAck
                }
            }
            print("Received EvenAI response: \(data.hexEncodedString())")
        default:
            print("received from G1(not handled): \(data.hexEncodedString())")
        }
    }
}
// MARK: Commands
extension G1BluetoothManager {
    
    private func sendMicOn(to peripheral: CBPeripheral, isOn: Bool) {
        
        var micOnData = Data()
        micOnData.append(Commands.BLE_REQ_MIC_ON.rawValue)
        if isOn {
            micOnData.append(0x01)
        } else {
            micOnData.append(0x00)
        }

        if let txChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: peripheral) {
            peripheral.writeValue(micOnData, for: txChar, type: .withResponse)
        }
    }
    
    private func sendInitCommand(to peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let initData = Data([Commands.BLE_REQ_INIT.rawValue, 0x01])
        peripheral.writeValue(initData, for: characteristic, type: .withResponse)
    }
    
    private func sendHeartbeat(to peripheral: CBPeripheral) {
        var heartbeatData = Data()
        heartbeatData.append(Commands.BLE_REQ_HEARTBEAT.rawValue)
        heartbeatData.append(UInt8(0x02 & 0xFF))

        if let txChar = findCharacteristic(uuid: UART_TX_CHAR_UUID, peripheral: peripheral) {
            let hexString = heartbeatData.map { String(format: "%02X", $0) }.joined()
            //print("Hex String Send: \(hexString)")
            peripheral.writeValue(heartbeatData, for: txChar, type: .withoutResponse)
        }
    }
    
    public func sendText(text: String, newScreen: Bool = true, currentPage: UInt8 = 1, maxPages: UInt8 = 1, isCommand: Bool = false) async -> Bool {
        
        let lines = formatTextLines(text: text)
        let totalPages = UInt8((lines.count + 4) / 4)
        evenaiSeq = 1
        let status: DisplayStatus = isCommand ? .FINAL_TEXT : .MANUAL_PAGE
        // Example for single page
        if lines.count <= 4 {
            let displayText = "\n\n" + lines.joined(separator: "\n")
            let result =  await sendTextPacket(displayText: displayText, newScreen: true, status: status, currentPage: 1, maxPages: 1)
            return (result)
        } else {
            var cPage:UInt8 = 1
            var start_idx = 0
            var success = false
            self.responseModel = AiResponseToG1Model(lines: lines, totalPages: totalPages, newScreen: true, currentPage: cPage, maxPages: totalPages, status: status)
            success = await self.manualTextControl()
            
            return success
        }
        return false
    }
    
    private func sendTextPacket(displayText: String, newScreen: Bool, status: DisplayStatus, currentPage: UInt8, maxPages: UInt8) async -> Bool {
        guard let textData = displayText.data(using: .utf8) else { return false }
        let chunks = textData.chunked(into: 191)
        
        for (i, chunk) in chunks.enumerated() {
            receivedAck = false
            let header = Data([Commands.BLE_REQ_EVENAI.rawValue, evenaiSeq, UInt8(chunks.count), UInt8(i), status.rawValue | (newScreen ? 1 : 0), 0, 0, currentPage, maxPages])
            let packet = header + chunk
            if let leftChar = getWriteCharacteristic(for: leftPeripheral),
               let rightChar = getWriteCharacteristic(for: rightPeripheral) {
                
                let screen0 = await writePacket(peripheral: leftPeripheral, packet, to: leftChar)
                let screen1 = await writePacket(peripheral: rightPeripheral, packet, to: rightChar)
                
                
                if !(await waitForAck(timeout: 0.8)) {
                    return false
                }
            }
            evenaiSeq += 1
        }
        return true
    }
    
    private func waitForAck(timeout: TimeInterval) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                continuation.resume(returning: self.receivedAck)
            }
        }
    }
    
    private func formatTextLines(text: String) -> [String] {
        let paragraphs = text.split(separator: "\n").map { String($0) }
        var lines = [String]()
        
        for paragraph in paragraphs {
            var remainingText = paragraph
            while remainingText.count > 40 {
                let endIndex = remainingText.index(remainingText.startIndex, offsetBy: 40)
                let line = String(remainingText[..<endIndex])
                lines.append(line)
                remainingText = String(remainingText[endIndex...])
            }
            lines.append(remainingText)
        }
        return lines
    }
    
    private func manualTextControl() async -> Bool {
        guard let responseModel else { return false }
        let lines = responseModel.lines
        var start_idx = Int((responseModel.currentPage - 1) * 4)
        let pageLines = lines[start_idx..<min(start_idx + 4, lines.count)]
        let displayText = pageLines.joined(separator: "\n")
        var success = false
        success =  await sendTextPacket(displayText: displayText, newScreen: true, status: responseModel.status, currentPage: responseModel.currentPage, maxPages: responseModel.totalPages)
        success =  await sendTextPacket(displayText: displayText, newScreen: true, status: responseModel.status, currentPage: responseModel.currentPage, maxPages: responseModel.totalPages)
        return success
    }
}
// MARK: BLE Stubs
extension G1BluetoothManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    
    func getWriteCharacteristic(for peripheral: CBPeripheral?) -> CBCharacteristic? {
        guard let peripheral = peripheral else { return nil }
        for service in peripheral.services ?? [] {
            if service.uuid == UART_SERVICE_UUID {
                for characteristic in service.characteristics ?? [] where characteristic.uuid == UART_TX_CHAR_UUID {
                    return characteristic
                }
            }
        }
        return nil
    }
    
    func writePacket(peripheral: CBPeripheral? ,_ packet: Data, to characteristic: CBCharacteristic) async -> Bool {
        guard let peripheral else { return false }
        guard let leftPeripheral else { return false }
        guard let rightPeripheral else { return false }
        if leftPeripheral.identifier.uuidString == peripheral.identifier.uuidString {
            leftPeripheral.writeValue(packet, for: characteristic, type: .withoutResponse)
        }
        
        if rightPeripheral.identifier.uuidString == peripheral.identifier.uuidString {
            rightPeripheral.writeValue(packet, for: characteristic, type: .withoutResponse)
        }
        let timeoutDuration = 0.08
        let timeoutDate = Date().addingTimeInterval(timeoutDuration)
        
        while Date() < timeoutDate {
            if receivedAck {
                return true
            }
            await Task.sleep(UInt64(0.1 * Double(NSEC_PER_SEC)))
        }
        return false
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name {
            if name.contains("_L_") {
                leftPeripheral = peripheral
            } else if name.contains("_R_") {
                rightPeripheral = peripheral
            }
            
            if leftPeripheral != nil && rightPeripheral != nil {
                central.stopScan()
                connectToGlasses()
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([UART_SERVICE_UUID])
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        if peripheral == leftPeripheral {
            g1Ready = true
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services where service.uuid == UART_SERVICE_UUID {
                peripheral.discoverCharacteristics([UART_TX_CHAR_UUID, UART_RX_CHAR_UUID], for: service)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        if service.uuid.isEqual(UART_SERVICE_UUID){
            if let characteristics = service.characteristics {
                for characteristic in characteristics {
                    if characteristic.uuid == UART_TX_CHAR_UUID {
                        sendInitCommand(to: peripheral, characteristic: characteristic)
                    } else if characteristic.uuid == UART_RX_CHAR_UUID {
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                }
            }
        }
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            //startScan()
            let devices = getConnectedDevices()
            for device in devices {
                if let name = device.name {
                    if name.contains("_L_") {
                        leftPeripheral = device
                    } else if name.contains("_R_") {
                        rightPeripheral = device
                    }
                }
            }
        } else {
            print("Bluetooth is not available.")
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating value for characteristic: \(error.localizedDescription)")
            return
        }
        guard let data = characteristic.value else {
            print("Characteristic value is nil.")
            return
        }
        handleNotification(from: peripheral, data: data)
    }
}
