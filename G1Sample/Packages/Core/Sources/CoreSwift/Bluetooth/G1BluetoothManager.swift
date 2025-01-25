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
    
    @Published public var voiceData: Data = Data()
    
    let UART_SERVICE_UUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    let UART_TX_CHAR_UUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    let UART_RX_CHAR_UUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    public static let _bluetoothQueue = DispatchQueue(label: "BluetoothG1", qos: .userInitiated)
    public static let shared = G1BluetoothManager()
    
    
    var centralManager: CBCentralManager!
    var leftPeripheral: CBPeripheral?
    var rightPeripheral: CBPeripheral?
    var connectedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]
    
    var aiTriggerTimeoutTimer: Timer?
    
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
        case .BLE_REQ_TRANSFER_MIC_DATA:
            print("Received voice data: \(data.subdata(in: 1..<data.count).hexEncodedString())")
            self.voiceData = data
        case .BLE_REQ_DEVICE_ORDER:
            print("Received device order: \(data.subdata(in: 1..<data.count).hexEncodedString())")
            let order = data[1]
            switch DeviceOrders(rawValue: order) {
            case .TRIGGER_FOR_AI:
                if let rightPeripheral {
                    aiTriggerTimeoutTimer?.invalidate()
                    aiTriggerTimeoutTimer = nil
                    sendMicOn(to: rightPeripheral, isOn: true)
                    startAITriggerTimeoutTimer()
                }
                print("Trigger AI")
            case .TRIGGER_FOR_STOP_RECORDING:
                aiTriggerTimeoutTimer?.invalidate()
                aiTriggerTimeoutTimer = nil
            default:
                break
            }
        case .BLE_REQ_EVENAI:
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
}
// MARK: BLE Stubs
extension G1BluetoothManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    
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
            startScan()
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
