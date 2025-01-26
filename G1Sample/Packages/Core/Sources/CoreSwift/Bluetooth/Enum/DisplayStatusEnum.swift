//
//  DisplayStatus.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 26/1/25.
//

enum DisplayStatus: UInt8 {
    case NORMAL_TEXT = 0x30
    case FINAL_TEXT = 0x40
    case MANUAL_PAGE = 0x50
    case ERROR_TEXT = 0x60
    case SIMPLE_TEXT = 0x70
}
