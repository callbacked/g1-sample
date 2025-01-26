//
//  CommandsEnum.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//

enum Commands: UInt8 {
    case BLE_EXIT_ALL_FUNCTIONS = 0x18
    case BLE_REQ_INIT = 0x4D
    case BLE_REQ_HEARTBEAT = 0x2C
    case BLE_REQ_EVENAI = 0x4E
    case BLE_REQ_TRANSFER_MIC_DATA = 0xF1
    case BLE_REQ_DEVICE_ORDER = 0xF5
    case BLE_REQ_MIC_ON = 0x0E
}
