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
    case QUICK_NOTE_ADD = 0x1E
    case BATTERY_STATUS = 0x2D
    case BRIGHTNESS = 0x01
    case SILENT_MODE = 0x03
    case TRANSLATE_SETUP = 0x39
    case TRANSLATE_START = 0x50
    case TRANSLATE_ORIGINAL = 0x0F
    case TRANSLATE_TRANSLATED = 0x0D
    case TRANSLATE_CONFIG = 0x1C
}

public enum TranslateLanguage: UInt8 {
    case chinese = 0x01    // Shows CN correctly
    case english = 0x02    // Shows EN correctly
    case japanese = 0x03   // Shows JP correctly
    case korean = 0x04     // Shows KR correctly
    case french = 0x05     // Shows FR correctly
    case german = 0x06     // Shows DE correctly
    case spanish = 0x07    // Shows ES correctly
    case russian = 0x08    // Shows RU
    case dutch = 0x09      // Shows NL correctly
    case norwegian = 0x0A  // Shows NB correctly
    case danish = 0x0B     // Shows DA correctly
    case swedish = 0x0C    // Shows SV
    case finnish = 0x0D    // Shows FI
    case italian = 0x0E    // Shows IT
    case arabic = 0x0F     // Shows AR
    case hindi = 0x10      // Shows HI
    case bengali = 0x11    // Shows BN
    case cantonese = 0x12  // Shows HK
}

public enum GlassesMode: UInt8 {
    case normal = 0x00
    case translation = 0x01
    case ai = 0x02
}

public enum AIStatus: UInt8 {
    case displaying = 0x30
    case displayComplete = 0x40
    case manualMode = 0x50
    case networkError = 0x60
}

public enum ScreenAction: UInt8 {
    case newContent = 0x01
}

public enum SubCommand: UInt8 {
    case exit = 0x00
    case pageControl = 0x01
    case start = 0x17
    case stop = 0x18
    case putOn = 0x06
    case takenOff = 0x07
}

public enum VoiceState: String {
    case idle
    case listening
    case processing
}

public enum AiState: String {
    case idle
    case active
    case responding
}
