//
//  G1ConnectViewModel.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//

import Combine
import Foundation

final public class G1ConnectViewModel: ViewModel, ViewModelBlueprint {
    
    private let loading = CurrentValueSubject<Bool, Never>(false)
    private let dismissView = PassthroughSubject<Void, Never>()
    
    public override init() {
        super.init()
    }
    public struct Input {
        let viewDidLoadIn: AnyPublisher<Void, Never>
        let startScanTapIn: AnyPublisher<Void, Never>
        let g1ConnectedIn: AnyPublisher<Bool, Never>
    }

    public struct Output {
        let viewDidLoadOut: AnyPublisher<Void, Never>
        let startScanTapOut: AnyPublisher<Void, Never>
        let isLoading: AnyPublisher<Bool, Never>
        let g1ConnectedOut: AnyPublisher<Bool, Never>
    }
    
    public func convert(input: Input) -> Output {
        
        let viewDidLoadHandler = input.viewDidLoadIn
            .handleEvents(receiveOutput: { [weak self] value in
                guard let self else { return }
                print("View loaded")
            })
        
        let g1ConnectedHandler = input.g1ConnectedIn
            .handleEvents(receiveOutput: { [weak self] connected in
                guard let self else { return }
                if connected {
                    loading.send(false)
                }
            })
        
        let startScanHandler = input.startScanTapIn
            .handleEvents(receiveOutput: { [weak self] value in
                guard let self else { return }
                G1Controller.shared.startBluetoothScanning()
                loading.send(true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    self.loading.send(false)
                }
                print("startScan tapped")
            })
        
        return Output(
            viewDidLoadOut: viewDidLoadHandler.eraseToAnyPublisher(),
            startScanTapOut: startScanHandler.eraseToAnyPublisher(),
            isLoading: loading.eraseToAnyPublisher(),
            g1ConnectedOut: g1ConnectedHandler.eraseToAnyPublisher()
            )
    }
}
