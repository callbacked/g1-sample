//
//  CombineButton.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//
import UIKit
import Combine

public class CombineButton: UIButton {

    private var tapSubject = PassthroughSubject<Void, Never>()

    var tapPublisher: AnyPublisher<Void, Never> {
        return tapSubject.eraseToAnyPublisher()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
    }

    @objc private func didTapButton() {
        tapSubject.send(())
    }
}
