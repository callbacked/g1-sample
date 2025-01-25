//
//  BaseViewController.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//


import Combine
import UIKit

open class BaseViewController<VM: ViewModel>: UIViewController {
    // MARK: - Properties
    open var viewModel: VM
    
    public var cancellables = Set<AnyCancellable>()
    
    let viewDidLoadPublisher = PassthroughSubject<Void, Never>()
    
    // MARK: - Methods
    public init(_ viewModel: VM) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        viewDidLoadPublisher.send(())
    }
}
