//
//  G1ConnectViewController.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//
import UIKit
import SVProgressHUD
import Combine

public class G1ConnectViewController: BaseViewController<G1ConnectViewModel> {
    var navigator: CoreNavigator?
    
    var g1connected: AnyPublisher<Bool, Never> {
        G1Controller.shared.$g1Connected.eraseToAnyPublisher()
    }
    
    private lazy var startScanButton: CombineButton = {
        let button = CombineButton(type: .system)
        button.setTitle("Connect with your G1", for: .normal)
        return button
    }()
    
    public override func viewDidLoad() {
        bindViewModel()
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGray
        view.addSubview(startScanButton)
        startScanButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Connect with G1 button constraints
            startScanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startScanButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            startScanButton.widthAnchor.constraint(equalToConstant: 200),
            startScanButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func bindViewModel() {
        
        let input = G1ConnectViewModel.Input(
            viewDidLoadIn: viewDidLoadPublisher.eraseToAnyPublisher(),
            startScanTapIn: startScanButton.tapPublisher.eraseToAnyPublisher(),
            g1ConnectedIn: g1connected.eraseToAnyPublisher()
            )
        
        let output = viewModel.convert(input: input)
        
        output.viewDidLoadOut
            .receive(on: DispatchQueue.main).eraseToAnyPublisher()
            .sink { [weak self] in
                guard let self else { return }
                
            }
            .store(in: &cancellables)
        
        output.startScanTapOut
            .receive(on: DispatchQueue.main).eraseToAnyPublisher()
            .sink { [weak self] in
                guard let self else { return }
            }
            .store(in: &cancellables)
        
        output.startScanTapOut
            .receive(on: DispatchQueue.main).eraseToAnyPublisher()
            .sink { [weak self] in
                guard let self else { return }
            }
            .store(in: &cancellables)
        
        output.isLoading
            .receive(on: DispatchQueue.main).eraseToAnyPublisher()
            .sink { [weak self] in
                guard let self else { return }
                if $0 {
                    SVProgressHUD.show(withStatus: "Connecting with G1")
                } else {
                    SVProgressHUD.dismiss()
                }
            }
            .store(in: &cancellables)
        
        output.g1ConnectedOut
            .receive(on: DispatchQueue.main).eraseToAnyPublisher()
            .sink { [weak self] in
                guard let self else { return }
                if $0 {
                    self.dismiss(animated: true)
                    print("G1 connected")
                } else {
                    print("G1 not connected")
                }
            }
            .store(in: &cancellables)
    }

}
