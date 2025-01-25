//
//  Data+Extension.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//
import Foundation

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
