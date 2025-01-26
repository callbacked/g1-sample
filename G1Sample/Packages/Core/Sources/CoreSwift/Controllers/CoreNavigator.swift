//
//  CoreNavigator.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//

import UIKit

public final class CoreNavigator: UINavigationController {
    
    public enum Destination {
        case startScreen
        case popUpConnectG1
    }
    
    func presentModal(_ destination: Destination, animated: Bool = true, keepInitialVC: Bool = false) {
        let vc = makeViewController(for: destination)
        self.present(vc, animated: true)
    }
    
    public func makeViewController(for destination: Destination) -> UIViewController {
        switch destination {
        case .startScreen:
            let vm = StartViewModel()
            let vc = StartViewController(vm)
            vc.navigator = self
            return vc
        case .popUpConnectG1:
            let vm = G1ConnectViewModel()
            let vc = G1ConnectViewController(vm)
            vc.navigator = self
            return vc
        }
    }
}
