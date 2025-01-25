//
//  ViewModelBlueprint.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//


import Foundation

public protocol ViewModelBlueprint {
    associatedtype Input

    associatedtype Output
    
    func convert(input: Input) -> Output
}
