//
//  AiResponseModel.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 26/1/25.
//


struct AiResponseToG1Model {
    var lines: [String]
    var totalPages: UInt8
    var newScreen: Bool
    var currentPage: UInt8 {
        didSet {
            print("SET : currentPage :\(currentPage)")
        }
    }
    var maxPages: UInt8
    var status: DisplayStatus
}
