//
//  DeviceOrdersEnum.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//

enum DeviceOrders: UInt8 {
    case DISPLAY_READY = 0x00
    case DISPLAY_BUSY = 0x11
    case DISPLAY_UPDATE = 0x0F
    case DISPLAY_COMPLETE = 0x09
    case READY_FOR_AI = 0x0E
    case TRIGGER_FOR_AI = 0x17
    case TRIGGER_FOR_STOP_RECORDING = 0x18
    case TRIGGER_CHANGE_PAGE = 0x01
    case WEAR_ON = 0x06
    case WEAR_OFF = 0x07
    case CASE_IN_OPEN = 0x08
    case CASE_IN_CLOSE = 0x0b
    case SILENT_MODE_ON = 0x04
    case SILENT_MODE_OFF = 0x05
    case DISPLAY_ON = 0x02
    case DISPLAY_OFF = 0x03
}
