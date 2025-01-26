//
//  Publisher+Extension.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 26/1/25.
//

import Combine

extension Published.Publisher {
    func withoutPublishing(_ perform: () -> Void) {
        // Temporarily suppress observation
        var wasObserved: AnyCancellable? = self.sink(receiveValue: { _ in })
        defer { wasObserved = nil }
        perform()
    }
}
