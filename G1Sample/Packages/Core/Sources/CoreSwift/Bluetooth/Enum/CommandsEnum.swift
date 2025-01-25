//
//  CommandsEnum.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//

enum Commands: UInt8 {
    case BLE_REQ_INIT = 0x4D
    case BLE_REQ_HEARTBEAT = 0x2C
    case BLE_REQ_STATE = 0x2B
    case BLE_REQ_EVENAI = 0x4E
    case BLE_REQ_TRANSFER_MIC_DATA = 0xF1
    case BLE_REQ_DEVICE_ORDER = 0xF5
    case BLE_REQ_NORMAL_TEXT = 0x30
    case BLE_REQ_FINAL_TEXT = 0x40
    case BLE_REQ_MANUAL_PAGE = 0x50
    case BLE_REQ_ERROR_TEXT = 0x60
    case BLE_REQ_MIC_ON = 0x0E
    case BLE_REQ_CONFIGURATION = 0x26
    case BLE_REQ_SILENT_MODE = 0x03
    case BLE_REQ_BRIGHTNESS = 0x29
    case BLE_REQ_BRIGHTNESS_CHANGE = 0x01
    case BLE_REQ_IMAGE = 0x20
    case BLE_REQ_SETTINGS = 0x32
    case BLE_REQ_TELEPROMPT = 0x09
    case BLE_REQ_TRANSLATE_TEXT = 0x0F
    case BLE_REQ_TRANSLATE_VERIFY_TEXT = 0x0D
}
