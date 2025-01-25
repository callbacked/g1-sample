//
//  LaunchViewController.swift
//  G1Sample
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//

import UIKit
import CoreSwift

class LaunchViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let navigationController = self.navigationController as? CoreNavigator else { return }
        let startCoreController = navigationController.makeViewController(for: .startScreen)
        navigationController.pushViewController(startCoreController, animated: false)
    }

    
}

