import Foundation
import CoreBluetooth

enum GlassSide {
    case left
    case right
}

class GlassDevice {
    var peripheral: CBPeripheral
    var side: GlassSide
    var uartTx: CBCharacteristic?
    var uartRx: CBCharacteristic?
    var heartbeatSeq: UInt8 = 0
    var heartbeatTimer: Timer?
    
    init(peripheral: CBPeripheral, side: GlassSide) {
        self.peripheral = peripheral
        self.side = side
    }
    
    func startHeartbeat(manager: BluetoothManager) {
        DispatchQueue.main.async {
            self.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
                guard self.uartTx != nil else { return }
                let data = self.constructHeartbeat()
                manager.sendData(data, to: self)
            }
        }
    }
    
    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func constructHeartbeat() -> Data {
        let length: UInt16 = 6
        let seq = heartbeatSeq
        heartbeatSeq = heartbeatSeq &+ 1
        var data = Data()
        let HEARTBEAT: UInt8 = 0xAA
        data.append(HEARTBEAT)
        data.append(UInt8(length & 0xFF))
        data.append(UInt8((length >> 8) & 0xFF))
        data.append(seq)
        data.append(0x04)
        data.append(seq)
        return data
    }
}

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BluetoothManager()
    
    var centralManager: CBCentralManager!
    let uartServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    let uartTxCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    let uartRxCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    
    var leftGlass: GlassDevice?
    var rightGlass: GlassDevice?
    var discoveredPeripherals: [CBPeripheral] = []
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [uartServiceUUID], options: nil)
            print("Started scanning for glasses.")
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        print("Stopped scanning.")
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            print("Bluetooth not available: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        print("Discovered: \(peripheral.name ?? "Unknown")")
        if !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected: \(peripheral.name ?? "Unknown")")
        peripheral.discoverServices([uartServiceUUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == uartServiceUUID {
            peripheral.discoverCharacteristics([uartTxCharacteristicUUID, uartRxCharacteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        var deviceSide: GlassSide = .left
        if let left = leftGlass, left.peripheral.identifier == peripheral.identifier {
            deviceSide = .left
        } else if let right = rightGlass, right.peripheral.identifier == peripheral.identifier {
            deviceSide = .right
        } else {
            deviceSide = (leftGlass == nil) ? .left : .right
        }
        let glass = GlassDevice(peripheral: peripheral, side: deviceSide)
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == uartTxCharacteristicUUID {
                    glass.uartTx = characteristic
                    print("TX for \(deviceSide) assigned")
                } else if characteristic.uuid == uartRxCharacteristicUUID {
                    glass.uartRx = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("RX for \(deviceSide) assigned")
                }
            }
        }
        if glass.side == .left {
            leftGlass = glass
        } else {
            rightGlass = glass
        }
        glass.startHeartbeat(manager: self)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let value = characteristic.value {
            print("Received from \(peripheral.name ?? "Unknown"): \(value as NSData)")
        }
    }
    
    func sendData(_ data: Data, to device: GlassDevice) {
        if let tx = device.uartTx {
            device.peripheral.writeValue(data, for: tx, type: .withResponse)
        } else {
            print("No TX for \(device.side)")
        }
    }
} 