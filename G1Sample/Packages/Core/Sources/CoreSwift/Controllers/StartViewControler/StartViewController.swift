//
//  StartViewController.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//

import UIKit
import Combine

public class StartViewController: BaseViewController<StartViewModel> {
    var navigator: CoreNavigator?
    
    let talkToHostButtonTapPublisher = PassthroughSubject<Void, Never>()
    let connectWithG1ButtonTapPublisher = PassthroughSubject<Void, Never>()
    
    private lazy var connectWithG1Button: CombineButton = {
        let button = CombineButton(type: .system)
        button.setTitle("Connect with G1", for: .normal)
        return button
    }()
    
    private lazy var talkToHostButton: CombineButton = {
        let button = CombineButton(type: .system)
        button.setTitle("Talk to the Host", for: .normal)
        return button
    }()
    
    public override func viewDidLoad() {
        bindViewModel()
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        navigationItem.hidesBackButton = true
        
        view.backgroundColor = .systemOrange
        view.addSubview(connectWithG1Button)
        view.addSubview(talkToHostButton)
        
        // Layout the buttons
        connectWithG1Button.translatesAutoresizingMaskIntoConstraints = false
        talkToHostButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Connect with G1 button constraints
            connectWithG1Button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            connectWithG1Button.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            connectWithG1Button.widthAnchor.constraint(equalToConstant: 200),
            connectWithG1Button.heightAnchor.constraint(equalToConstant: 50),
            
            // Talk to Host button constraints
            talkToHostButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            talkToHostButton.topAnchor.constraint(equalTo: connectWithG1Button.bottomAnchor, constant: 20),
            talkToHostButton.widthAnchor.constraint(equalToConstant: 200),
            talkToHostButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func bindViewModel() {
        
        let input = StartViewModel.Input(
            viewDidLoadIn: viewDidLoadPublisher.eraseToAnyPublisher(),
            connectG1TapIn: connectWithG1Button.tapPublisher.eraseToAnyPublisher(),
            talkToG1TapIn: talkToHostButton.tapPublisher.eraseToAnyPublisher()
            )
        
        let output = viewModel.convert(input: input)
        
        output.viewDidLoadOut
            .receive(on: DispatchQueue.main).eraseToAnyPublisher()
            .sink { [weak self] in
                guard let self else { return }
                
            }
            .store(in: &cancellables)
        
        output.connectG1TapOut
            .receive(on: DispatchQueue.main).eraseToAnyPublisher()
            .sink { [weak self] in
                guard let self else { return }
                self.navigator?.presentModal(.popUpConnectG1)
            }
            .store(in: &cancellables)
        
        output.talkToG1TapOut
            .receive(on: DispatchQueue.main).eraseToAnyPublisher()
            .sink { [weak self] in
                guard let self else { return }
                
            }
            .store(in: &cancellables)
        
    }

}
