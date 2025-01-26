//
//  Data+Extension.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//
import Foundation

extension Data {
    
    func chunked(into size: Int) -> [Data] {
        var chunks = [Data]()
        var index = 0
        while index < count {
            let chunkSize = Swift.min(size, count - index)
            let chunk = subdata(in: index..<(index + chunkSize))
            chunks.append(chunk)
            index += chunkSize
        }
        return chunks
    }
    
    func hexEncodedString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
