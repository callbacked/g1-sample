//
//  StartViewModel.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//
import Combine

final public class StartViewModel: ViewModel, ViewModelBlueprint {
    
    public override init() {
        super.init()
    }
    public struct Input {
        let viewDidLoadIn: AnyPublisher<Void, Never>
        let connectG1TapIn: AnyPublisher<Void, Never>
    }

    public struct Output {
        let viewDidLoadOut: AnyPublisher<Void, Never>
        let connectG1TapOut: AnyPublisher<Void, Never>
    }
    
    public func convert(input: Input) -> Output {
        
        let viewDidLoadHandler = input.viewDidLoadIn
            .handleEvents(receiveOutput: { [weak self] value in
                guard let self else { return }
                print("View loaded")
            })
        
        let connectG1TapHandler = input.connectG1TapIn
            .handleEvents(receiveOutput: { [weak self] value in
                guard let self else { return }
                print("connectG1 Tapped")
            })
        
        return Output(
            viewDidLoadOut: viewDidLoadHandler.eraseToAnyPublisher(),
            connectG1TapOut: connectG1TapHandler.eraseToAnyPublisher()
            )
    }
}
