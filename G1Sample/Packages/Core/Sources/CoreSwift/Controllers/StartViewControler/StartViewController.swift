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
    
    public override func viewDidLoad() {
        bindViewModel()
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        navigationItem.hidesBackButton = true
        
        view.backgroundColor = .systemOrange
        view.addSubview(connectWithG1Button)
        
        // Layout the buttons
        connectWithG1Button.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Connect with G1 button constraints
            connectWithG1Button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            connectWithG1Button.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            connectWithG1Button.widthAnchor.constraint(equalToConstant: 200),
            connectWithG1Button.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func bindViewModel() {
        
        let input = StartViewModel.Input(
            viewDidLoadIn: viewDidLoadPublisher.eraseToAnyPublisher(),
            connectG1TapIn: connectWithG1Button.tapPublisher.eraseToAnyPublisher()
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
                if G1Controller.shared.g1Connected {
                    self.showAlert(title: "G1 Already Connected", message: "The G1 device is already connected.")
                } else {
                    self.navigator?.presentModal(.popUpConnectG1)
                }
            }
            .store(in: &cancellables)
        
    }

    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true)
    }
}
