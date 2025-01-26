//
//  DeviceOrdersEnum.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//

enum DeviceOrders: UInt8 {
    case DISPLAY_READY = 0x00
    case TRIGGER_CHANGE_PAGE = 0x01
    case TRIGGER_FOR_AI = 0x17
    case TRIGGER_FOR_STOP_RECORDING = 0x18
    case G1_IS_READY = 0x09
}
