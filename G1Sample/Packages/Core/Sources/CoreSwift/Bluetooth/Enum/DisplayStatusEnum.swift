//
//  DisplayStatus.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 26/1/25.
//

public enum DisplayStatus: UInt8 {
    case NORMAL_TEXT = 0x30
    case FINAL_TEXT = 0x40
    case MANUAL_PAGE = 0x50
    case ERROR_TEXT = 0x60
    case SIMPLE_TEXT = 0x70
}

public enum DashboardMode: UInt8 {
    case full = 0x00
    case dual = 0x01
    case minimal = 0x02
}

public enum DashboardPosition: UInt8 {
    case position0 = 0x00  // Bottom
    case position1 = 0x01
    case position2 = 0x02
    case position3 = 0x03
    case position4 = 0x04
    case position5 = 0x05
    case position6 = 0x06
    case position7 = 0x07
    case position8 = 0x08  // Top
}
