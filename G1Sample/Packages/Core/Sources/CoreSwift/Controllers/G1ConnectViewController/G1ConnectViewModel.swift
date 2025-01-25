//
//  G1ConnectViewModel.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//

import Combine

final public class G1ConnectViewModel: ViewModel, ViewModelBlueprint {
    
    public override init() {
        super.init()
    }
    public struct Input {
        let viewDidLoadIn: AnyPublisher<Void, Never>
        let startScanTapIn: AnyPublisher<Void, Never>
    }

    public struct Output {
        let viewDidLoadOut: AnyPublisher<Void, Never>
        let startScanTapOut: AnyPublisher<Void, Never>
    }
    
    public func convert(input: Input) -> Output {
        
        let viewDidLoadHandler = input.viewDidLoadIn
            .handleEvents(receiveOutput: { [weak self] value in
                guard let self else { return }
                print("View loaded")
            })
        
        let startScanHandler = input.startScanTapIn
            .handleEvents(receiveOutput: { [weak self] value in
                guard let self else { return }
                G1BluetoothManager.shared.startScan()
                print("startScan tapped")
            })
        
        return Output(
            viewDidLoadOut: viewDidLoadHandler.eraseToAnyPublisher(),
            startScanTapOut: startScanHandler.eraseToAnyPublisher()
            )
    }
}
