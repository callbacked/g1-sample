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
    
    private let endpointConfiguredPublisher = PassthroughSubject<(String, String), Never>()
    
    private lazy var mainStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.distribution = .fill
        return stack
    }()
    
    private lazy var headerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()
    
    private lazy var contentContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var leftColumnStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        return stack
    }()
    
    private lazy var rightColumnStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        return stack
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "G1 Smart Glasses"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Connect and control your glasses"
        label.font = .systemFont(ofSize: 18, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.9)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var connectionStatusView: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 16
        return view
    }()
    
    private lazy var connectionStatusStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.distribution = .fill
        return stack
    }()
    
    private lazy var connectionStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "Searching for glasses..."
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private lazy var connectionActivityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private lazy var connectWithG1Button: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Search for Glasses", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .white.withAlphaComponent(0.15)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 25
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.widthAnchor.constraint(equalToConstant: 280).isActive = true
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.2
        button.layer.shadowRadius = 4
        button.addTarget(self, action: #selector(connectButtonTapped), for: .touchUpInside)
        
        button.addSubview(connectionActivityIndicator)
        connectionActivityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            connectionActivityIndicator.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -20),
            connectionActivityIndicator.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        return button
    }()
    
    private lazy var batteryContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.15)
        view.layer.cornerRadius = 20
        view.isHidden = true
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.2
        view.layer.shadowRadius = 4
        return view
    }()
    
    private lazy var batteryStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var batteryIcon: UIImageView = {
        let image = UIImageView(image: UIImage(systemName: "battery.100"))
        image.tintColor = .white
        image.contentMode = .scaleAspectFit
        return image
    }()
    
    private lazy var batteryLabel: UILabel = {
        let label = UILabel()
        label.text = "100%"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        return label
    }()
    
    private lazy var batteryRefreshButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(refreshBatteryStatus), for: .touchUpInside)
        return button
    }()
    
    private lazy var transcriptionView: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.15)
        view.layer.cornerRadius = 20
        view.isHidden = true
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.2
        view.layer.shadowRadius = 4
        return view
    }()
    
    private lazy var transcriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        label.textColor = .white
        label.text = "Voice transcription will appear here..."
        return label
    }()
    
    private lazy var dashboardContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.15)
        view.layer.cornerRadius = 20
        view.isHidden = true
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.2
        view.layer.shadowRadius = 4
        return view
    }()
    
    private lazy var settingsContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.15)
        view.layer.cornerRadius = 20
        view.isHidden = true
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.2
        view.layer.shadowRadius = 4
        return view
    }()
    
    private lazy var settingsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)
        stack.isLayoutMarginsRelativeArrangement = true
        return stack
    }()
    
    private lazy var settingsLabel: UILabel = {
        let label = UILabel()
        label.text = "Display Settings"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()
    
    private lazy var displayControlsCard: UIView = {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        card.layer.cornerRadius = 16
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        // Brightness control
        let brightnessRow = UIStackView()
        brightnessRow.axis = .horizontal
        brightnessRow.spacing = 8
        brightnessRow.alignment = .center
        
        let brightnessIcon = UIImageView(image: UIImage(systemName: "sun.max.fill"))
        brightnessIcon.tintColor = .white
        brightnessIcon.contentMode = .scaleAspectFit
        brightnessIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        brightnessIcon.heightAnchor.constraint(equalToConstant: 16).isActive = true
        
        brightnessSlider.minimumTrackTintColor = .white
        brightnessSlider.maximumTrackTintColor = .white.withAlphaComponent(0.3)
        brightnessSlider.setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
        brightnessSlider.tintColor = .white
        
        brightnessRow.addArrangedSubview(brightnessIcon)
        brightnessRow.addArrangedSubview(brightnessSlider)
        brightnessRow.addArrangedSubview(autoBrightnessIcon)
        
        NSLayoutConstraint.activate([
            autoBrightnessIcon.widthAnchor.constraint(equalToConstant: 16),
            autoBrightnessIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        // Silent mode control
        let silentRow = UIStackView()
        silentRow.axis = .horizontal
        silentRow.spacing = 8
        silentRow.alignment = .center
        
        let silentIcon = UIImageView(image: UIImage(systemName: "moon.fill"))
        silentIcon.tintColor = .white
        silentIcon.contentMode = .scaleAspectFit
        silentIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        silentIcon.heightAnchor.constraint(equalToConstant: 16).isActive = true
        
        let silentLabel = UILabel()
        silentLabel.text = "Silent"
        silentLabel.font = .systemFont(ofSize: 14)
        silentLabel.textColor = .white
        silentLabel.textAlignment = .left
        
        silentModeSwitch.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        silentModeSwitch.onTintColor = .white
        
        silentRow.addArrangedSubview(silentIcon)
        silentRow.addArrangedSubview(silentLabel)
        silentRow.addArrangedSubview(UIView()) // Add spacer back
        silentRow.addArrangedSubview(silentModeSwitch)
        
        stack.addArrangedSubview(brightnessRow)
        stack.addArrangedSubview(silentRow)
        
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            card.heightAnchor.constraint(equalToConstant: 110)
        ])
        
        return card
    }()
    
    private lazy var brightnessSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 50
        slider.minimumTrackTintColor = .systemBlue
        slider.maximumTrackTintColor = .white.withAlphaComponent(0.3)
        slider.setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
        slider.tintColor = .white
        slider.addTarget(self, action: #selector(brightnessChanged), for: .valueChanged)
        return slider
    }()
    
    private var isAutoBrightnessEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isAutoBrightnessEnabled, forKey: "autoBrightnessEnabled")
            brightnessSlider.alpha = isAutoBrightnessEnabled ? 0.5 : 1.0
            brightnessSlider.isEnabled = !isAutoBrightnessEnabled
            autoBrightnessIcon.tintColor = isAutoBrightnessEnabled ? .systemBlue : .white
            
            // Update brightness with auto mode
            Task {
                if let value = Int(exactly: round(brightnessSlider.value / 100 * 41)) {
                    await G1Controller.shared.g1Manager.setBrightness(UInt8(value), autoMode: isAutoBrightnessEnabled)
                }
            }
        }
    }
    
    private lazy var autoBrightnessIcon: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "a.circle.fill"))
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        
        // Add tap gesture to the icon
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleAutoBrightness))
        imageView.addGestureRecognizer(tapGesture)
        
        return imageView
    }()
    
    private lazy var silentModeSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = .systemBlue
        toggle.addTarget(self, action: #selector(silentModeChanged), for: .valueChanged)
        return toggle
    }()
    
    private lazy var weatherSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = .systemBlue
        toggle.addTarget(self, action: #selector(weatherEnabledChanged), for: .valueChanged)
        return toggle
    }()
    
    private lazy var temperatureUnitSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = .systemBlue
        toggle.addTarget(self, action: #selector(temperatureUnitChanged), for: .valueChanged)
        return toggle
    }()
    
    private lazy var timeFormatSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = .systemBlue
        toggle.addTarget(self, action: #selector(timeFormatChanged), for: .valueChanged)
        return toggle
    }()
    
    private lazy var continuousListeningSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = .systemBlue
        toggle.addTarget(self, action: #selector(continuousListeningChanged), for: .valueChanged)
        return toggle
    }()
    
    private lazy var weatherStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        let label = UILabel()
        label.text = "Show Weather"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .white
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(weatherSwitch)
        return stack
    }()
    
    private lazy var temperatureStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        let label = UILabel()
        label.text = "Use Fahrenheit"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .white
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(temperatureUnitSwitch)
        return stack
    }()
    
    private lazy var timeFormatStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        let label = UILabel()
        label.text = "Use 24-hour Format"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .white
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(timeFormatSwitch)
        return stack
    }()
    
    private lazy var continuousListeningStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        let label = UILabel()
        label.text = "Always-On Microphone"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .white
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(continuousListeningSwitch)
        return stack
    }()
    
    private lazy var dashboardStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var dashboardLabel: UILabel = {
        let label = UILabel()
        label.text = "Dashboard Mode"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .left
        return label
    }()

    private lazy var dashboardModeCard: UIView = {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        card.layer.cornerRadius = 16
        card.isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cycleDashboardMode))
        card.addGestureRecognizer(tapGesture)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.alignment = .center
        
        // Mode label
        let modeLabel = UILabel()
        modeLabel.text = "Full Mode"
        modeLabel.font = .systemFont(ofSize: 14)
        modeLabel.textColor = .white
        modeLabel.textAlignment = .center
        modeLabel.tag = 100 // Tag for easy access
        
        stack.addArrangedSubview(modeLabel)
        
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            card.heightAnchor.constraint(equalToConstant: 110),
            card.widthAnchor.constraint(equalToConstant: 110)
        ])
        
        return card
    }()
    
    private lazy var fullModeButton: UIButton = {
        let button = createModeButton(title: "Full Mode")
        button.tag = 0
        return button
    }()
    
    private lazy var dualModeButton: UIButton = {
        let button = createModeButton(title: "Dual Mode")
        button.tag = 1
        return button
    }()
    
    private lazy var minimalModeButton: UIButton = {
        let button = createModeButton(title: "Minimal Mode")
        button.tag = 2
        return button
    }()
    
    private lazy var endpointConfigStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        stack.distribution = .fill
        stack.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        stack.layer.cornerRadius = 16
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)
        stack.isLayoutMarginsRelativeArrangement = true
        return stack
    }()
    
    private lazy var endpointTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "API Endpoint"
        textField.textColor = .white
        textField.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        textField.layer.cornerRadius = 12
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.leftViewMode = .always
        textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        textField.attributedPlaceholder = NSAttributedString(
            string: "API Endpoint",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
        )
        textField.font = .systemFont(ofSize: 16)
        return textField
    }()
    
    private lazy var apiKeyTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "API Key"
        textField.textColor = .white
        textField.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        textField.layer.cornerRadius = 12
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.leftViewMode = .always
        textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        textField.isSecureTextEntry = true
        textField.attributedPlaceholder = NSAttributedString(
            string: "API Key",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
        )
        textField.font = .systemFont(ofSize: 16)
        return textField
    }()
    
    private lazy var connectButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Connect to API", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: #selector(connectToAPITapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var modelSelectorContainer: UIView = {
        let container = UIView()
        container.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        container.layer.cornerRadius = 12
        container.isHidden = true
        container.alpha = 0 // Start hidden for fade-in
        
        let label = UILabel()
        label.text = "Model"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .white.withAlphaComponent(0.7)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.indicatorStyle = .white
        
        container.addSubview(label)
        container.addSubview(scrollView)
        scrollView.addSubview(modelListStackView)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            
            scrollView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 200), // Fixed height
            
            modelListStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            modelListStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            modelListStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            modelListStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
            modelListStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        return container
    }()
    
    private lazy var modelListStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private func createModelButton(for model: String, isSelected: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(model, for: .normal)
        button.setTitleColor(isSelected ? .white : .white.withAlphaComponent(0.7), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.contentHorizontalAlignment = .left
        button.backgroundColor = .clear
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: #selector(modelButtonTapped(_:)), for: .touchUpInside)
        
        // Add checkmark for selected state
        if isSelected {
            let checkmark = UIImageView(image: UIImage(systemName: "checkmark"))
            checkmark.tintColor = .white
            checkmark.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(checkmark)
            
            NSLayoutConstraint.activate([
                checkmark.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                checkmark.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -8),
                checkmark.widthAnchor.constraint(equalToConstant: 16),
                checkmark.heightAnchor.constraint(equalToConstant: 16)
            ])
        }
        
        return button
    }
    
    private func updateModelSelector(with models: [String], forcedSelection: String? = nil) {
        // Clear existing buttons
        modelListStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Get saved model or forced selection
        let savedModel = forcedSelection ?? UserDefaults.standard.string(forKey: "selectedModel") ?? models.first
        
        // Create and add buttons for each model
        for model in models {
            let isSelected = model == savedModel
            let button = createModelButton(for: model, isSelected: isSelected)
            modelListStackView.addArrangedSubview(button)
            
            // Add separator after each button except the last one
            if model != models.last {
                let separator = UIView()
                separator.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
                separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
                modelListStackView.addArrangedSubview(separator)
            }
            
            // If this is the saved/first model, configure OpenAI with it
            if isSelected {
                G1Controller.shared.configureOpenAI(
                    apiKey: apiKeyTextField.text ?? "",
                    baseURL: endpointTextField.text,
                    model: model
                )
            }
        }
        
        // Show container with fade-in animation if we have models
        modelSelectorContainer.isHidden = models.isEmpty
        if !models.isEmpty {
            UIView.animate(withDuration: 0.3) {
                self.modelSelectorContainer.alpha = 1
            }
        }
    }
    
    @objc private func modelButtonTapped(_ sender: UIButton) {
        // Get the model name from the button's title
        guard let selectedModel = sender.title(for: .normal) else { return }
        
        // Save the selection
        UserDefaults.standard.set(selectedModel, forKey: "selectedModel")
        
        // Update OpenAI configuration
        G1Controller.shared.configureOpenAI(
            apiKey: apiKeyTextField.text ?? "",
            baseURL: endpointTextField.text,
            model: selectedModel
        )
        
        // Update the UI with the new selection
        updateModelSelector(with: viewModel.availableModels, forcedSelection: selectedModel)
    }
    
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .systemRed
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        return tap
    }()
    
    private lazy var customTabBarController: UITabBarController = {
        let tabBar = UITabBarController()
        tabBar.view.backgroundColor = .clear
        tabBar.tabBar.tintColor = .white
        tabBar.tabBar.unselectedItemTintColor = .white.withAlphaComponent(0.4)
        tabBar.tabBar.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        tabBar.tabBar.isTranslucent = false
        return tabBar
    }()
    
    private lazy var homeViewController: UIViewController = {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        stack.addArrangedSubview(headerStack)
        stack.addArrangedSubview(connectWithG1Button)
        stack.addArrangedSubview(batteryContainer)
        
        vc.view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -20)
        ])
        
        vc.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)
        return vc
    }()
    
    private lazy var apiViewController: UIViewController = {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "API Configuration"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Configure your API endpoint and key"
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = .white.withAlphaComponent(0.7)
        subtitleLabel.textAlignment = .center
        
        let headerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 8
        headerStack.alignment = .center
        
        // Add the API configuration elements
        endpointConfigStack.removeFromSuperview() // Remove from any previous parent
        
        stack.addArrangedSubview(headerStack)
        stack.addArrangedSubview(endpointConfigStack)
        
        vc.view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -20),
            endpointConfigStack.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        
        vc.tabBarItem = UITabBarItem(title: "API", image: UIImage(systemName: "network"), tag: 1)
        return vc
    }()
    
    private lazy var settingsViewController: UIViewController = {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Settings"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        settingsContainer.addSubview(settingsStack)
        NSLayoutConstraint.activate([
            settingsStack.topAnchor.constraint(equalTo: settingsContainer.topAnchor),
            settingsStack.leadingAnchor.constraint(equalTo: settingsContainer.leadingAnchor),
            settingsStack.trailingAnchor.constraint(equalTo: settingsContainer.trailingAnchor),
            settingsStack.bottomAnchor.constraint(equalTo: settingsContainer.bottomAnchor)
        ])
        
        // Update settings stack with new display controls
        settingsStack.addArrangedSubview(settingsLabel)
        settingsStack.addArrangedSubview(weatherStack)
        settingsStack.addArrangedSubview(temperatureStack)
        settingsStack.addArrangedSubview(timeFormatStack)
        settingsStack.addArrangedSubview(continuousListeningStack)
        settingsStack.addArrangedSubview(dashboardPositionStack)
        
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(settingsContainer)
        
        vc.view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -20),
            settingsContainer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        
        vc.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 3)
        return vc
    }()
    
    private lazy var voiceViewController: UIViewController = {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Voice Transcription"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(transcriptionView)
        
        vc.view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -20),
            transcriptionView.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        
        vc.tabBarItem = UITabBarItem(title: "Voice", image: UIImage(systemName: "waveform"), tag: 4)
        return vc
    }()
    
    private func createModeButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .white.withAlphaComponent(0.1)
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        button.addTarget(self, action: #selector(modeButtonTapped(_:)), for: .touchUpInside)
        return button
    }
    
    private lazy var debugButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "hammer.circle.fill"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(showDebugMenu), for: .touchUpInside)
        return button
    }()
    
    private lazy var debugMenu: UIAlertController = {
        let alert = UIAlertController(title: "Debug Menu", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Send Test Text", style: .default) { [weak self] _ in
            self?.sendTestText()
        })
        
        alert.addAction(UIAlertAction(title: "Add Quick Note", style: .default) { [weak self] _ in
            self?.addQuickNote()
        })
        
        alert.addAction(UIAlertAction(title: "Clear Quick Notes", style: .destructive) { [weak self] _ in
            self?.clearQuickNotes()
        })

        // Add Dashboard Mode submenu
        alert.addAction(UIAlertAction(title: "Set Dashboard Mode", style: .default) { [weak self] _ in
            self?.showDashboardModeMenu()
        })
        
        // Add Calendar Widget Test
        alert.addAction(UIAlertAction(title: "Test Calendar Widget", style: .default) { [weak self] _ in
            self?.testCalendarWidget()
        })
        
        // Add Translation Test
        alert.addAction(UIAlertAction(title: "Test Translation", style: .default) { [weak self] _ in
            self?.testTranslation()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        return alert
    }()
    
    private lazy var quickActionsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var currentDashboardMode: DashboardMode = .full {
        didSet {
            updateDashboardModeUI()
            Task {
                await G1Controller.shared.g1Manager.setDashboardMode(currentDashboardMode)
            }
        }
    }

    private lazy var dashboardPositionStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        
        // Height control
        let heightStack = UIStackView()
        heightStack.axis = .horizontal
        heightStack.spacing = 8
        heightStack.alignment = .center
        
        let heightLabel = UILabel()
        heightLabel.text = "Dashboard Height"
        heightLabel.font = .systemFont(ofSize: 16)
        heightLabel.textColor = .white
        
        let heightValueLabel = UILabel()
        heightValueLabel.text = "Level 0"
        heightValueLabel.font = .systemFont(ofSize: 14)
        heightValueLabel.textColor = .white.withAlphaComponent(0.7)
        heightValueLabel.tag = 101 // Tag for height value label
        heightValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        heightValueLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        let heightSlider = UISlider()
        heightSlider.minimumValue = 0
        heightSlider.maximumValue = 8
        heightSlider.value = 0
        heightSlider.tag = 1 // Tag for height slider
        heightSlider.addTarget(self, action: #selector(positionSliderChanged(_:)), for: .valueChanged)
        heightSlider.addTarget(self, action: #selector(positionSliderFinished(_:)), for: .touchUpInside)
        heightSlider.setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
        heightSlider.minimumTrackTintColor = .white
        heightSlider.maximumTrackTintColor = .white.withAlphaComponent(0.3)
        
        heightStack.addArrangedSubview(heightLabel)
        heightStack.addArrangedSubview(heightSlider)
        heightStack.addArrangedSubview(heightValueLabel)
        
        // Distance control
        let distanceStack = UIStackView()
        distanceStack.axis = .horizontal
        distanceStack.spacing = 8
        distanceStack.alignment = .center
        
        let distanceLabel = UILabel()
        distanceLabel.text = "Dashboard Distance"
        distanceLabel.font = .systemFont(ofSize: 16)
        distanceLabel.textColor = .white
        
        let distanceValueLabel = UILabel()
        distanceValueLabel.text = "4m"
        distanceValueLabel.font = .systemFont(ofSize: 14)
        distanceValueLabel.textColor = .white.withAlphaComponent(0.7)
        distanceValueLabel.tag = 102 // Tag for distance value label
        distanceValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        distanceValueLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        let distanceSlider = UISlider()
        distanceSlider.minimumValue = 1
        distanceSlider.maximumValue = 9
        distanceSlider.value = 4 // Default middle distance
        distanceSlider.tag = 2 // Tag for distance slider
        distanceSlider.addTarget(self, action: #selector(positionSliderChanged(_:)), for: .valueChanged)
        distanceSlider.addTarget(self, action: #selector(positionSliderFinished(_:)), for: .touchUpInside)
        distanceSlider.setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
        distanceSlider.minimumTrackTintColor = .white
        distanceSlider.maximumTrackTintColor = .white.withAlphaComponent(0.3)
        
        distanceStack.addArrangedSubview(distanceLabel)
        distanceStack.addArrangedSubview(distanceSlider)
        distanceStack.addArrangedSubview(distanceValueLabel)

        // Tilt angle control
        let tiltStack = UIStackView()
        tiltStack.axis = .horizontal
        tiltStack.spacing = 8
        tiltStack.alignment = .center
        
        let tiltLabel = UILabel()
        tiltLabel.text = "Dashboard Tilt"
        tiltLabel.font = .systemFont(ofSize: 16)
        tiltLabel.textColor = .white
        
        let tiltValueLabel = UILabel()
        tiltValueLabel.text = "30°"
        tiltValueLabel.font = .systemFont(ofSize: 14)
        tiltValueLabel.textColor = .white.withAlphaComponent(0.7)
        tiltValueLabel.tag = 103 // Tag for tilt value label
        tiltValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        tiltValueLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        let tiltSlider = UISlider()
        tiltSlider.minimumValue = 0
        tiltSlider.maximumValue = 60
        tiltSlider.value = 30 // Default middle tilt
        tiltSlider.tag = 3 // Tag for tilt slider
        tiltSlider.addTarget(self, action: #selector(positionSliderChanged(_:)), for: .valueChanged)
        tiltSlider.addTarget(self, action: #selector(positionSliderFinished(_:)), for: .touchUpInside)
        tiltSlider.setThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
        tiltSlider.minimumTrackTintColor = .white
        tiltSlider.maximumTrackTintColor = .white.withAlphaComponent(0.3)
        
        tiltStack.addArrangedSubview(tiltLabel)
        tiltStack.addArrangedSubview(tiltSlider)
        tiltStack.addArrangedSubview(tiltValueLabel)
        
        stack.addArrangedSubview(heightStack)
        stack.addArrangedSubview(distanceStack)
        stack.addArrangedSubview(tiltStack)
        return stack
    }()

    private var quickNotesListStack: UIStackView!
    private var quickNoteTextView: UITextView!
    private var currentlyEditingNoteId: UUID?
    private var addNoteButton: UIButton!
    
    private var weatherIcon: UIImageView!
    private var temperatureLabel: UILabel!

    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.text = "--:--"
        label.font = .monospacedSystemFont(ofSize: 32, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        return label
    }()

    private lazy var dateLabel: UILabel = {
        let label = UILabel()
        label.text = "--"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.7)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var timeUpdateTimer: Timer?

    @objc private func positionSliderChanged(_ sender: UISlider) {
        let position = Int(round(sender.value))
        sender.value = Float(position) // Snap to integer values
        
        // Update value label based on slider tag
        switch sender.tag {
        case 1: // Height slider
            if let valueLabel = sender.superview?.viewWithTag(101) as? UILabel {
                valueLabel.text = "Level \(position)"
            }
            if let dashboardPosition = DashboardPosition(rawValue: UInt8(position)) {
                Task {
                    await G1Controller.shared.setDashboardPosition(dashboardPosition)
                }
            }
            
        case 2: // Distance slider
            if let valueLabel = sender.superview?.viewWithTag(102) as? UILabel {
                valueLabel.text = "\(position)m"
            }
            Task {
                await G1Controller.shared.setDashboardDistance(UInt8(position))
            }
            
        case 3: // Tilt slider
            if let valueLabel = sender.superview?.viewWithTag(103) as? UILabel {
                valueLabel.text = "\(position)°"
            }
            Task {
                await G1Controller.shared.setTiltAngle(UInt8(position))
            }
            
        default:
            break
        }
    }

    @objc private func positionSliderFinished(_ sender: UISlider) {
        let position = Int(round(sender.value))
        
        // Save final position to settings
        switch sender.tag {
        case 1: // Height slider
            G1SettingsManager.shared.dashboardHeight = position
        case 2: // Distance slider
            G1SettingsManager.shared.dashboardDistance = position
        case 3: // Tilt slider
            G1SettingsManager.shared.dashboardTilt = position
        default:
            break
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardHandling()
        setupUI()
        setupEndpointConfig()
        bindViewModel()
    }
    
    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        
        view.addGestureRecognizer(tapGestureRecognizer)
        
        endpointTextField.delegate = self
        apiKeyTextField.delegate = self
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
        
        // If active text field is hidden by keyboard, scroll to make it visible
        if let activeField = endpointTextField.isFirstResponder ? endpointTextField : apiKeyTextField.isFirstResponder ? apiKeyTextField : nil {
            let rect = activeField.convert(activeField.bounds, to: scrollView)
            scrollView.scrollRectToVisible(rect, animated: true)
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
    
    private func setupEndpointConfig() {
        endpointConfigStack.addArrangedSubview(endpointTextField)
        endpointConfigStack.addArrangedSubview(apiKeyTextField)
        endpointConfigStack.addArrangedSubview(modelSelectorContainer)
        endpointConfigStack.addArrangedSubview(connectButton)
        endpointConfigStack.addArrangedSubview(errorLabel)
        
        // Load all saved settings
        let settings = G1SettingsManager.shared
        
        // Load API settings
        if let savedEndpoint = settings.apiEndpoint {
            endpointTextField.text = savedEndpoint
        }
        if let savedApiKey = settings.apiKey {
            apiKeyTextField.text = savedApiKey
        }
        
        // Load display settings - Only update UI, don't send commands
        weatherSwitch.isOn = settings.weatherEnabled
        temperatureUnitSwitch.isOn = settings.useFahrenheit
        timeFormatSwitch.isOn = settings.use24Hour
        continuousListeningSwitch.isOn = settings.continuousListeningEnabled
        silentModeSwitch.isOn = settings.silentModeEnabled
        
        // Load dashboard settings - Only update UI, don't send commands
        if let dashboardPosition = DashboardPosition(rawValue: UInt8(settings.dashboardHeight)) {
            // Update height slider UI only
            if let heightSlider = dashboardPositionStack.arrangedSubviews
                .compactMap({ $0 as? UIStackView })
                .first(where: { ($0.arrangedSubviews.first as? UILabel)?.text == "Dashboard Height" })?
                .arrangedSubviews
                .compactMap({ $0 as? UISlider })
                .first {
                heightSlider.value = Float(dashboardPosition.rawValue)
                if let valueLabel = heightSlider.superview?.viewWithTag(101) as? UILabel {
                    valueLabel.text = "Level \(dashboardPosition.rawValue)"
                }
            }
        }
        
        // Update distance slider UI only
        if let distanceSlider = dashboardPositionStack.arrangedSubviews
            .compactMap({ $0 as? UIStackView })
            .first(where: { ($0.arrangedSubviews.first as? UILabel)?.text == "Dashboard Distance" })?
            .arrangedSubviews
            .compactMap({ $0 as? UISlider })
            .first {
            distanceSlider.value = Float(settings.dashboardDistance)
            if let valueLabel = distanceSlider.superview?.viewWithTag(102) as? UILabel {
                valueLabel.text = "\(settings.dashboardDistance)m"
            }
        }
        
        // Update tilt slider UI only
        if let tiltSlider = dashboardPositionStack.arrangedSubviews
            .compactMap({ $0 as? UIStackView })
            .first(where: { ($0.arrangedSubviews.first as? UILabel)?.text == "Dashboard Tilt" })?
            .arrangedSubviews
            .compactMap({ $0 as? UISlider })
            .first {
            tiltSlider.value = Float(settings.dashboardTilt)
            if let valueLabel = tiltSlider.superview?.viewWithTag(103) as? UILabel {
                valueLabel.text = "\(settings.dashboardTilt)°"
            }
        }
        
        // Load brightness settings - Only update UI
        brightnessSlider.value = Float(settings.brightness)
        isAutoBrightnessEnabled = settings.autoBrightnessEnabled
        
        // Auto-connect if we have saved credentials
        if let savedEndpoint = endpointTextField.text,
           let savedApiKey = apiKeyTextField.text,
           !savedEndpoint.isEmpty,
           !savedApiKey.isEmpty {
            // Trigger connection with a slight delay to ensure view is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.connectButton.isEnabled = false
                self?.connectButton.setTitle("Connecting...", for: .normal)
                self?.endpointConfiguredPublisher.send((savedEndpoint, savedApiKey))
            }
        }
    }
    
    private func setupUI() {
        navigationItem.hidesBackButton = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: debugButton)
        
        // Set dark theme
        view.backgroundColor = .black
        overrideUserInterfaceStyle = .dark
        
        // Configure tab bar appearance
        customTabBarController.tabBar.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        customTabBarController.tabBar.tintColor = .white
        customTabBarController.tabBar.unselectedItemTintColor = .white.withAlphaComponent(0.4)
        customTabBarController.tabBar.isTranslucent = false
        
        // Add gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.black.cgColor,
            UIColor(white: 0.1, alpha: 1.0).cgColor
        ]
        gradientLayer.frame = view.bounds
        gradientLayer.locations = [0.0, 1.0]
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Setup tab bar controller
        addChild(customTabBarController)
        view.addSubview(customTabBarController.view)
        customTabBarController.view.translatesAutoresizingMaskIntoConstraints = false
        customTabBarController.didMove(toParent: self)
        
        // Style home view controller
        let homeStack = UIStackView()
        homeStack.axis = .vertical
        homeStack.spacing = 16
        homeStack.alignment = .fill
        homeStack.translatesAutoresizingMaskIntoConstraints = false
        
        // G1 Status Card
        let g1Card = UIView()
        g1Card.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        g1Card.layer.cornerRadius = 20
        g1Card.layer.shadowColor = UIColor.black.cgColor
        g1Card.layer.shadowOffset = CGSize(width: 0, height: 2)
        g1Card.layer.shadowOpacity = 0.2
        g1Card.layer.shadowRadius = 4
        g1Card.translatesAutoresizingMaskIntoConstraints = false
        
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.alignment = .fill
        contentStack.layoutMargins = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Time display stack
        let timeStack = UIStackView()
        timeStack.axis = .vertical
        timeStack.spacing = 4
        timeStack.alignment = .center
        
        timeStack.addArrangedSubview(timeLabel)
        timeStack.addArrangedSubview(dateLabel)
        
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .center
        
        contentStack.addArrangedSubview(timeStack)
        contentStack.addArrangedSubview(headerStack)
        
        let g1IconImage = UIImageView(image: UIImage(systemName: "glasses"))
        g1IconImage.tintColor = .white
        g1IconImage.contentMode = .scaleAspectFit
        g1IconImage.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            g1IconImage.widthAnchor.constraint(equalToConstant: 24),
            g1IconImage.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.spacing = 2  // Reduce spacing between title and status
        titleStack.alignment = .leading
        
        let g1TitleLabel = UILabel()
        g1TitleLabel.text = "My G1"
        g1TitleLabel.font = .systemFont(ofSize: 20, weight: .medium)
        g1TitleLabel.textColor = .white
        
        let g1StatusLabel = UILabel()
        g1StatusLabel.text = "Searching..."
        g1StatusLabel.font = .systemFont(ofSize: 16, weight: .regular)
        g1StatusLabel.textColor = .white.withAlphaComponent(0.7)
        g1StatusLabel.tag = 100 // Tag for easy access
        
        titleStack.addArrangedSubview(g1TitleLabel)
        titleStack.addArrangedSubview(g1StatusLabel)
        
        headerStack.setCustomSpacing(4, after: g1IconImage) // Reduce spacing after icon
        
        let batteryStack = UIStackView()
        batteryStack.axis = .horizontal
        batteryStack.spacing = 8
        batteryStack.alignment = .center
        
        let batteryIcon = UIImageView(image: UIImage(systemName: "battery.75"))
        batteryIcon.tintColor = .white
        batteryIcon.contentMode = .scaleAspectFit
        batteryIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            batteryIcon.widthAnchor.constraint(equalToConstant: 24),
            batteryIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        let batteryLabel = UILabel()
        batteryLabel.text = "46%"
        batteryLabel.font = .systemFont(ofSize: 16, weight: .medium)
        batteryLabel.textColor = .white
        
        batteryStack.addArrangedSubview(batteryIcon)
        batteryStack.addArrangedSubview(batteryLabel)
        
        // Add weather stack
        let weatherStack = UIStackView()
        weatherStack.axis = .horizontal
        weatherStack.spacing = 8
        weatherStack.alignment = .center
        
        let weatherIcon = UIImageView(image: UIImage(systemName: "sun.max.fill"))
        weatherIcon.tintColor = .white.withAlphaComponent(0.5)
        weatherIcon.contentMode = .scaleAspectFit
        weatherIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            weatherIcon.widthAnchor.constraint(equalToConstant: 24),
            weatherIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        let temperatureLabel = UILabel()
        temperatureLabel.text = "--°"
        temperatureLabel.font = .systemFont(ofSize: 16, weight: .medium)
        temperatureLabel.textColor = .white.withAlphaComponent(0.5)
        
        weatherStack.addArrangedSubview(weatherIcon)
        weatherStack.addArrangedSubview(temperatureLabel)
        
        // Store references to weather UI elements
        self.weatherIcon = weatherIcon
        self.temperatureLabel = temperatureLabel
        
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.color = .white
        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        headerStack.addArrangedSubview(g1IconImage)
        headerStack.addArrangedSubview(titleStack)
        headerStack.addArrangedSubview(UIView()) // Spacer
        
        // Create vertical status stack
        let statusStack = UIStackView()
        statusStack.axis = .vertical
        statusStack.spacing = 8
        statusStack.alignment = .trailing
        
        // Add battery and weather stacks to status stack
        statusStack.addArrangedSubview(batteryStack)
        statusStack.addArrangedSubview(weatherStack)
        
        headerStack.addArrangedSubview(statusStack)
        headerStack.addArrangedSubview(activityIndicator)
        
        contentStack.addArrangedSubview(headerStack)
        
        g1Card.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: g1Card.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: g1Card.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: g1Card.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: g1Card.bottomAnchor)
        ])
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(connectButtonTapped))
        g1Card.addGestureRecognizer(tapGesture)
        g1Card.isUserInteractionEnabled = true
        
        homeStack.addArrangedSubview(g1Card)
        
        // Add widgets to quick actions stack
        quickActionsStack.addArrangedSubview(displayControlsCard)
        quickActionsStack.addArrangedSubview(dashboardModeCard)
        
        homeStack.addArrangedSubview(quickActionsStack)
        homeStack.addArrangedSubview(quickNotesCard)
        homeStack.addArrangedSubview(translationCard)
        
        homeViewController.view.addSubview(homeStack)
        
        NSLayoutConstraint.activate([
            customTabBarController.view.topAnchor.constraint(equalTo: view.topAnchor),
            customTabBarController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customTabBarController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customTabBarController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            homeStack.topAnchor.constraint(equalTo: homeViewController.view.safeAreaLayoutGuide.topAnchor, constant: 16),
            homeStack.leadingAnchor.constraint(equalTo: homeViewController.view.leadingAnchor, constant: 20),
            homeStack.trailingAnchor.constraint(equalTo: homeViewController.view.trailingAnchor, constant: -20),
            
            g1Card.heightAnchor.constraint(equalToConstant: 160)
        ])
        
        // Configure view controllers
        customTabBarController.viewControllers = [
            homeViewController,
            apiViewController,
            settingsViewController,
            voiceViewController
        ]
        
        // Start auto-connect
        Task {
            G1Controller.shared.startBluetoothScanning()
        }
        
        // Update UI based on connection status
        G1Controller.shared.g1Manager.$g1Ready
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                UIView.animate(withDuration: 0.3) {
                    if isConnected {
                        g1StatusLabel.text = "Connected"
                        g1StatusLabel.textColor = .systemGreen
                        activityIndicator.stopAnimating()
                        activityIndicator.isHidden = true
                        // Fetch initial battery status
            Task {
                            await G1Controller.shared.g1Manager.fetchBatteryStatus()
            }
        } else {
                        g1StatusLabel.text = "Searching..."
                        g1StatusLabel.textColor = .white.withAlphaComponent(0.7)
                        activityIndicator.startAnimating()
                        activityIndicator.isHidden = false
                    }
                }
            }
            .store(in: &cancellables)
        
        // Update battery status
        G1Controller.shared.g1Manager.$batteryLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self = self else { return }
                batteryLabel.text = "\(level)%"
                
                let imageName: String
                switch level {
                case 0...20:
                    imageName = "battery.25"
                    batteryIcon.tintColor = .systemRed
                    batteryLabel.textColor = .systemRed
                case 21...50:
                    imageName = "battery.50"
                    batteryIcon.tintColor = .systemYellow
                    batteryLabel.textColor = .systemYellow
                case 51...80:
                    imageName = "battery.75"
                    batteryIcon.tintColor = .white
                    batteryLabel.textColor = .white
                default:
                    imageName = "battery.100"
                    batteryIcon.tintColor = .systemGreen
                    batteryLabel.textColor = .systemGreen
                }
                
                batteryIcon.image = UIImage(systemName: imageName)
            }
            .store(in: &cancellables)
        
        // Update weather status
        G1Controller.shared.weatherPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] weather in
                guard let self = self else { return }
                if let weather = weather {
                    self.weatherIcon.tintColor = .white
                    self.temperatureLabel.textColor = .white
                    
                    // Update temperature
                    let temp = weather.useFahrenheit ? 
                        "\(Int(round(weather.temperature * 9/5 + 32)))°F" : 
                        "\(Int(round(weather.temperature)))°C"
                    self.temperatureLabel.text = temp
                    
                    // Update weather icon based on condition
                    let iconName: String
                    switch weather.condition.lowercased() {
                    case _ where weather.condition.contains("clear"):
                        iconName = "sun.max.fill"
                    case _ where weather.condition.contains("cloud"):
                        iconName = "cloud.fill"
                    case _ where weather.condition.contains("rain"):
                        iconName = "cloud.rain.fill"
                    case _ where weather.condition.contains("snow"):
                        iconName = "cloud.snow.fill"
                    case _ where weather.condition.contains("thunder"):
                        iconName = "cloud.bolt.fill"
                    case _ where weather.condition.contains("fog"):
                        iconName = "cloud.fog.fill"
                    default:
                        iconName = "sun.max.fill"
                    }
                    self.weatherIcon.image = UIImage(systemName: iconName)
                } else {
                    self.weatherIcon.tintColor = .white.withAlphaComponent(0.5)
                    self.temperatureLabel.textColor = .white.withAlphaComponent(0.5)
                    self.temperatureLabel.text = "--°"
                    self.weatherIcon.image = UIImage(systemName: "sun.max.fill")
                }
            }
            .store(in: &cancellables)

        // Add time update timer
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeDisplay()
        }
        updateTimeDisplay() // Initial update
    }

    private func updateTimeDisplay() {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = G1Controller.shared.is24HourFormat ? .short : .short
        // Use custom format to control spacing
        dateFormatter.dateFormat = G1Controller.shared.is24HourFormat ? "HH:mm" : "h:mma"
        timeLabel.text = dateFormatter.string(from: Date()).replacingOccurrences(of: " ", with: "")

        dateFormatter.dateFormat = "E, MMM d"
        dateLabel.text = dateFormatter.string(from: Date())
    }

    deinit {
        timeUpdateTimer?.invalidate()
    }
    
    private func createActionCard(title: String, icon: String) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        card.layer.cornerRadius = 20
        
        let iconImage = UIImageView(image: UIImage(systemName: icon))
        iconImage.tintColor = .white
        iconImage.contentMode = .scaleAspectFit
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(iconImage)
        card.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 120),
            
            iconImage.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            iconImage.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            iconImage.widthAnchor.constraint(equalToConstant: 24),
            iconImage.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: iconImage.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20)
        ])
        
        return card
    }
    
    private func bindViewModel() {
        let input = StartViewModel.Input(
            viewDidLoadIn: viewDidLoadPublisher.eraseToAnyPublisher(),
            connectG1TapIn: connectWithG1ButtonTapPublisher.eraseToAnyPublisher(),
            endpointConfigured: endpointConfiguredPublisher.eraseToAnyPublisher()
        )
        
        let output = viewModel.convert(input: input)
        
        output.viewDidLoadOut
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                // Auto-connect to API if we have saved credentials
                if let savedEndpoint = UserDefaults.standard.string(forKey: "apiEndpoint"),
                   let savedApiKey = UserDefaults.standard.string(forKey: "apiKey"),
                   !savedEndpoint.isEmpty,
                   !savedApiKey.isEmpty {
                    self.connectButton.isEnabled = false
                    self.connectButton.setTitle("Connecting...", for: .normal)
                    self.endpointConfiguredPublisher.send((savedEndpoint, savedApiKey))
                }
            }
            .store(in: &cancellables)
        
        output.connectG1TapOut
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                if G1Controller.shared.g1Connected {
                    self.connectionStatusLabel.text = "Glasses already connected"
                    self.connectionActivityIndicator.stopAnimating()
                }
            }
            .store(in: &cancellables)
        
        // Observe speech recognition preview text
        G1Controller.shared.previewTextPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.transcriptionLabel.text = text
            }
            .store(in: &cancellables)
        
        // Update UI based on connection status
        G1Controller.shared.g1Manager.$g1Ready
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                UIView.animate(withDuration: 0.3) {
                    if isConnected {
                        self.connectWithG1Button.backgroundColor = .systemGreen
                        self.connectWithG1Button.setTitle("Connected to G1 Glasses", for: .normal)
                        self.connectWithG1Button.setTitleColor(.white, for: .normal)
                        self.connectWithG1Button.isEnabled = false
                        self.connectionActivityIndicator.stopAnimating()
                        self.transcriptionView.isHidden = false
                        self.dashboardContainer.isHidden = false
                        self.batteryContainer.isHidden = false
                        self.settingsContainer.isHidden = false
                        // Fetch initial battery status
                        Task {
                            await G1Controller.shared.g1Manager.fetchBatteryStatus()
                        }
                    } else {
                        self.connectWithG1Button.backgroundColor = .white.withAlphaComponent(0.1)
                        self.connectWithG1Button.setTitle("Search for Glasses", for: .normal)
                        self.connectWithG1Button.setTitleColor(.white, for: .normal)
                        self.connectWithG1Button.isEnabled = true
                        self.connectionActivityIndicator.stopAnimating()
                        self.transcriptionView.isHidden = true
                        self.dashboardContainer.isHidden = true
                        self.batteryContainer.isHidden = true
                        self.settingsContainer.isHidden = true
                    }
                }
            }
            .store(in: &cancellables)
        
        // Update battery status
        G1Controller.shared.g1Manager.$batteryLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self = self else { return }
                self.updateBatteryStatus(level)
            }
            .store(in: &cancellables)
        
        output.modelsLoaded
            .sink { [weak self] models in
                guard let self = self else { return }
                self.updateModelSelector(with: models)
            }
            .store(in: &cancellables)
            
        output.isLoadingModels
            .sink { [weak self] isLoading in
                self?.connectButton.isEnabled = !isLoading
                self?.connectButton.setTitle(
                    isLoading ? "Loading Models..." : "Connect to API",
                    for: .normal
                )
            }
            .store(in: &cancellables)
            
        output.endpointError
            .sink { [weak self] error in
                self?.errorLabel.text = error
                self?.errorLabel.isHidden = error == nil
            }
            .store(in: &cancellables)
        
        // Observe quick notes
        G1Controller.shared.g1Manager.$quickNotes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notes in
                self?.updateQuickNotesDisplay(notes)
            }
            .store(in: &cancellables)
    }

    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
    
    @objc private func refreshBatteryStatus() {
        if G1Controller.shared.g1Connected {
            Task {
                await G1Controller.shared.g1Manager.fetchBatteryStatus()
            }
        }
    }

    private func updateBatteryStatus(_ level: Int) {
        batteryLabel.text = "\(level)%"
        
        let imageName: String
        switch level {
        case 0...20:
            imageName = "battery.25"
            batteryIcon.tintColor = .systemRed
            batteryLabel.textColor = .systemRed
        case 21...50:
            imageName = "battery.50"
            batteryIcon.tintColor = .systemYellow
            batteryLabel.textColor = .systemYellow
        case 51...80:
            imageName = "battery.75"
            batteryIcon.tintColor = .white
            batteryLabel.textColor = .white
        default:
            imageName = "battery.100"
            batteryIcon.tintColor = .systemGreen
            batteryLabel.textColor = .systemGreen
        }
        
        batteryIcon.image = UIImage(systemName: imageName)
    }
    
    @objc private func connectToAPITapped() {
        guard let endpoint = endpointTextField.text?.trimmingCharacters(in: .whitespaces),
              let apiKey = apiKeyTextField.text?.trimmingCharacters(in: .whitespaces),
              !endpoint.isEmpty,
              !apiKey.isEmpty else {
            errorLabel.text = "Please enter both endpoint and API key"
            errorLabel.isHidden = false
            return
        }
        
        // Save settings
        UserDefaults.standard.set(endpoint, forKey: "apiEndpoint")
        UserDefaults.standard.set(apiKey, forKey: "apiKey")
        
        endpointConfiguredPublisher.send((endpoint, apiKey))
    }
    
    @objc private func weatherEnabledChanged() {
        if weatherSwitch.isOn {
            G1Controller.shared.configureWeather()
            temperatureStack.isHidden = false
        } else {
            G1Controller.shared.disableWeather()
            temperatureStack.isHidden = true
        }
        G1SettingsManager.shared.weatherEnabled = weatherSwitch.isOn
    }
    
    @objc private func temperatureUnitChanged() {
        G1Controller.shared.setTemperatureUnit(useFahrenheit: temperatureUnitSwitch.isOn)
        G1SettingsManager.shared.useFahrenheit = temperatureUnitSwitch.isOn
    }
    
    @objc private func timeFormatChanged() {
        G1Controller.shared.setTimeFormat(use24Hour: timeFormatSwitch.isOn)
        G1SettingsManager.shared.use24Hour = timeFormatSwitch.isOn
        updateTimeDisplay() // Update time display when format changes
    }

    @objc private func continuousListeningChanged() {
        Task {
            let success = await G1Controller.shared.toggleContinuousListening()
            if success {
                G1SettingsManager.shared.continuousListeningEnabled = continuousListeningSwitch.isOn
            } else {
                // If toggle failed, revert the switch
                DispatchQueue.main.async {
                    self.continuousListeningSwitch.setOn(!self.continuousListeningSwitch.isOn, animated: true)
                }
                showAlert(title: "Error", message: "Failed to toggle continuous listening. Make sure glasses are connected.")
            }
        }
    }

    private func testCalendarWidget() {
        if G1Controller.shared.g1Connected {
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .none
            let timeString = dateFormatter.string(from: Date())
            
            Task {
                await G1Controller.shared.writeToCalendarWidget(
                    name: "Debug Test",
                    time: timeString,
                    location: "Calendar Widget"
                )
            }
        } else {
            showAlert(title: "G1 Not Connected", message: "Please connect to G1 glasses first.")
        }
    }

    @objc private func toggleAutoBrightness() {
        isAutoBrightnessEnabled.toggle()
        G1SettingsManager.shared.autoBrightnessEnabled = isAutoBrightnessEnabled
    }

    @objc private func brightnessChanged() {
        if let value = Int(exactly: round(brightnessSlider.value / 100 * 41)) {
            Task {
                await G1Controller.shared.g1Manager.setBrightness(UInt8(value), autoMode: isAutoBrightnessEnabled)
            }
        }
        G1SettingsManager.shared.brightness = Int(brightnessSlider.value)
    }
    
    @objc private func silentModeChanged() {
        Task {
            await G1Controller.shared.g1Manager.setSilentMode(silentModeSwitch.isOn)
            G1SettingsManager.shared.silentModeEnabled = silentModeSwitch.isOn
        }
    }
    
    @objc private func showDebugMenu() {
        present(debugMenu, animated: true)
    }
    
    private func sendTestText() {
        if G1Controller.shared.g1Connected {
            Task {
                await G1Controller.shared.sendTextToGlasses(
                    text: "Test message from debug menu!",
                    status: .SIMPLE_TEXT
                )
            }
        } else {
            showAlert(title: "G1 Not Connected", message: "Please connect to G1 glasses first.")
        }
    }

    private func addQuickNote() {
        if G1Controller.shared.g1Connected {
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .none
            let timeString = dateFormatter.string(from: Date())
            let note = "Debug Note \(timeString) \nDebug Note \(timeString)\nDebug Note \(timeString)"
            Task {
                await G1Controller.shared.g1Manager.addQuickNote(note)
            }
        } else {
            showAlert(title: "G1 Not Connected", message: "Please connect to G1 glasses first.")
        }
    }

    private func clearQuickNotes() {
        if G1Controller.shared.g1Connected {
            Task {
                await G1Controller.shared.g1Manager.clearQuickNotes()
            }
        } else {
            showAlert(title: "G1 Not Connected", message: "Please connect to G1 glasses first.")
        }
    }
    
    @objc private func connectButtonTapped() {
        if !G1Controller.shared.g1Connected {
            connectionActivityIndicator.startAnimating()
            connectWithG1Button.setTitle("Searching for glasses...", for: .normal)
            G1Controller.shared.startBluetoothScanning()
        }
        connectWithG1ButtonTapPublisher.send()
    }
    
    private func showDashboardModeMenu() {
        let alert = UIAlertController(title: "Set Dashboard Mode", message: "Choose a dashboard mode", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Full Mode", style: .default) { [weak self] _ in
            self?.setDashboardMode(.full)
        })
        
        alert.addAction(UIAlertAction(title: "Dual Mode", style: .default) { [weak self] _ in
            self?.setDashboardMode(.dual)
        })
        
        alert.addAction(UIAlertAction(title: "Minimal Mode", style: .default) { [weak self] _ in
            self?.setDashboardMode(.minimal)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func setDashboardMode(_ mode: DashboardMode) {
        if G1Controller.shared.g1Connected {
            Task {
                let success = await G1Controller.shared.g1Manager.setDashboardMode(mode)
                if !success {
                    await MainActor.run {
                        showAlert(title: "Error", message: "Failed to set dashboard mode")
                    }
                }
            }
        } else {
            showAlert(title: "G1 Not Connected", message: "Please connect to G1 glasses first.")
        }
    }
    
    @objc private func modeButtonTapped(_ sender: UIButton) {
        // Reset all buttons to default state
        [fullModeButton, dualModeButton, minimalModeButton].forEach { button in
            button.backgroundColor = .white.withAlphaComponent(0.1)
        }
        
        // Highlight selected button
        sender.backgroundColor = .white.withAlphaComponent(0.3)
        
        // Set dashboard mode based on button tag
        let mode = DashboardMode(rawValue: UInt8(sender.tag)) ?? .full
        setDashboardMode(mode)
    }

    @objc private func cycleDashboardMode() {
        switch currentDashboardMode {
        case .full:
            currentDashboardMode = .dual
        case .dual:
            currentDashboardMode = .minimal
        case .minimal:
            currentDashboardMode = .full
        }
    }
    
    private func updateDashboardModeUI() {
        if let modeLabel = dashboardModeCard.viewWithTag(100) as? UILabel {
            switch currentDashboardMode {
            case .full:
                modeLabel.text = "Full Mode"
            case .dual:
                modeLabel.text = "Dual Mode"
            case .minimal:
                modeLabel.text = "Minimal Mode"
            }
            modeLabel.textAlignment = .left
        }
    }

    private func setupDashboardControls() {
        view.addSubview(dashboardStack)
        dashboardStack.addArrangedSubview(dashboardLabel)
        dashboardStack.addArrangedSubview(fullModeButton)
        dashboardStack.addArrangedSubview(dualModeButton)
        dashboardStack.addArrangedSubview(minimalModeButton)
        
        NSLayoutConstraint.activate([
            dashboardStack.topAnchor.constraint(equalTo: endpointConfigStack.bottomAnchor, constant: 24),
            dashboardStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            dashboardStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private lazy var quickNotesCard: UIView = {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        card.layer.cornerRadius = 20
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowOpacity = 0.2
        card.layer.shadowRadius = 4
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        // Header row
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center
        
        let notesIcon = UIImageView(image: UIImage(systemName: "note.text"))
        notesIcon.tintColor = .white
        notesIcon.contentMode = .scaleAspectFit
        notesIcon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        notesIcon.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        let notesLabel = UILabel()
        notesLabel.text = "Quick Notes"
        notesLabel.font = .systemFont(ofSize: 16, weight: .medium)
        notesLabel.textColor = .white
        
        let clearAllButton = UIButton(type: .system)
        clearAllButton.setTitle("Clear All", for: .normal)
        clearAllButton.titleLabel?.font = .systemFont(ofSize: 14)
        clearAllButton.setTitleColor(.white.withAlphaComponent(0.7), for: .normal)
        clearAllButton.addTarget(self, action: #selector(clearAllNotesTapped), for: .touchUpInside)
        
        headerRow.addArrangedSubview(notesIcon)
        headerRow.addArrangedSubview(notesLabel)
        headerRow.addArrangedSubview(UIView()) // Spacer
        headerRow.addArrangedSubview(clearAllButton)
        
        // Notes list
        let notesListStack = UIStackView()
        notesListStack.axis = .vertical
        notesListStack.spacing = 12
        notesListStack.alignment = .fill
        
        // Input row
        let inputRow = UIStackView()
        inputRow.axis = .horizontal
        inputRow.spacing = 8
        inputRow.alignment = .top
        
        let textView = UITextView()
        textView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        textView.textColor = .white
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.layer.cornerRadius = 8
        textView.isScrollEnabled = false
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
        textView.heightAnchor.constraint(lessThanOrEqualToConstant: 100).isActive = true
        textView.delegate = self
        
        // Set placeholder text
        textView.text = "Add a quick note..."
        textView.textColor = UIColor.white.withAlphaComponent(0.5)
        
        let addButton = UIButton(type: .system)
        addButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        addButton.tintColor = .white
        addButton.widthAnchor.constraint(equalToConstant: 36).isActive = true
        addButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        addButton.addTarget(self, action: #selector(addOrUpdateNoteTapped), for: .touchUpInside)
        
        inputRow.addArrangedSubview(textView)
        inputRow.addArrangedSubview(addButton)
        
        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(notesListStack)
        stack.addArrangedSubview(inputRow)
        
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        
        // Store references
        self.quickNotesListStack = notesListStack
        self.quickNoteTextView = textView
        self.addNoteButton = addButton
        
        return card
    }()
    
    @objc private func addOrUpdateNoteTapped() {
        guard let text = quickNoteTextView.text,
              !text.isEmpty,
              text != "Add a quick note..." else { return }
        
        Task {
            if let editingId = currentlyEditingNoteId {
                // Update existing note
                await G1Controller.shared.g1Manager.updateQuickNote(id: editingId, newText: text)
                // Reset edit state
                currentlyEditingNoteId = nil
                addNoteButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
            } else {
                // Add new note
                await G1Controller.shared.g1Manager.addQuickNote(text)
            }
            quickNoteTextView.text = "Add a quick note..."
            quickNoteTextView.textColor = UIColor.white.withAlphaComponent(0.5)
        }
    }
    
    @objc private func editNoteTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < G1Controller.shared.g1Manager.quickNotes.count else { return }
        
        let note = G1Controller.shared.g1Manager.quickNotes[index]
        
        // Set text view content to note text
        quickNoteTextView.text = note.text
        quickNoteTextView.textColor = .white
        
        // Change add button to save button
        addNoteButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
        
        // Store editing state
        currentlyEditingNoteId = note.id
        
        // Focus the text view
        quickNoteTextView.becomeFirstResponder()
    }
    
    @objc private func clearAllNotesTapped() {
        let alert = UIAlertController(
            title: "Clear All Notes",
            message: "Are you sure you want to clear all quick notes?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { [weak self] _ in
            Task {
                await G1Controller.shared.g1Manager.clearQuickNotes()
            }
        })
        
        present(alert, animated: true)
    }
    
    private func updateQuickNotesDisplay(_ notes: [QuickNote]) {
        // Clear existing notes
        quickNotesListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add notes (up to 4)
        for note in notes.prefix(4) {
            let noteRow = UIStackView()
            noteRow.axis = .horizontal
            noteRow.spacing = 8
            noteRow.alignment = .center
            
            let noteLabel = UILabel()
            noteLabel.text = note.text
            noteLabel.textColor = .white
            noteLabel.font = .systemFont(ofSize: 14)
            noteLabel.numberOfLines = 2
            
            let buttonsStack = UIStackView()
            buttonsStack.axis = .horizontal
            buttonsStack.spacing = 8
            buttonsStack.alignment = .center
            
            let editButton = UIButton(type: .system)
            editButton.setImage(UIImage(systemName: "pencil"), for: .normal)
            editButton.tintColor = .white.withAlphaComponent(0.7)
            editButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
            editButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
            
            let deleteButton = UIButton(type: .system)
            deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
            deleteButton.tintColor = .white.withAlphaComponent(0.7)
            deleteButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
            deleteButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
            
            // Store note ID in button tag
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                editButton.tag = index
                deleteButton.tag = index
            }
            
            editButton.addTarget(self, action: #selector(editNoteTapped(_:)), for: .touchUpInside)
            deleteButton.addTarget(self, action: #selector(deleteNoteTapped(_:)), for: .touchUpInside)
            
            buttonsStack.addArrangedSubview(editButton)
            buttonsStack.addArrangedSubview(deleteButton)
            
            noteRow.addArrangedSubview(noteLabel)
            noteRow.addArrangedSubview(buttonsStack)
            
            // Add separator if not the last note
            if note != notes.prefix(4).last {
                let separator = UIView()
                separator.backgroundColor = UIColor.white.withAlphaComponent(0.1)
                separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
                quickNotesListStack.addArrangedSubview(noteRow)
                quickNotesListStack.addArrangedSubview(separator)
            } else {
                quickNotesListStack.addArrangedSubview(noteRow)
            }
        }
        
        // Show empty state if no notes
        if notes.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "No quick notes"
            emptyLabel.textColor = .white.withAlphaComponent(0.5)
            emptyLabel.font = .systemFont(ofSize: 14)
            emptyLabel.textAlignment = .center
            quickNotesListStack.addArrangedSubview(emptyLabel)
        }
    }
    
    @objc private func deleteNoteTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < G1Controller.shared.g1Manager.quickNotes.count else { return }
        
        let note = G1Controller.shared.g1Manager.quickNotes[index]
        Task {
            await G1Controller.shared.g1Manager.removeQuickNote(id: note.id)
        }
    }

    private func testTranslation() {
        if G1Controller.shared.g1Connected {
            Task {
                // Start live translation mode
                let success = await G1Controller.shared.startLiveTranslation()
                if !success {
                    await MainActor.run {
                        showAlert(title: "Error", message: "Failed to start translation mode")
                    }
                    return
                }
                
                // Show alert with stop button
                await MainActor.run {
                    let alert = UIAlertController(
                        title: "Live Translation Active",
                        message: "Speak to see your words appear in the translation UI.",
                        preferredStyle: .alert
                    )
                    
                    alert.addAction(UIAlertAction(title: "Stop Translation", style: .default) { _ in
                        // Stop translation when stop button is tapped
                        Task {
                            await G1Controller.shared.stopLiveTranslation()
                        }
                    })
                    
                    self.present(alert, animated: true)
                }
            }
        } else {
            showAlert(title: "G1 Not Connected", message: "Please connect to G1 glasses first.")
        }
    }

    @objc private func toggleTranslation() {
        Task {
            if G1Controller.shared.g1Manager.currentMode == .translation {
                // Stop translation if it's active
                await G1Controller.shared.stopLiveTranslation()
                if let button = translationCard.viewWithTag(200) as? UIButton {
                    button.setTitle("Start Translation", for: .normal)
                    button.backgroundColor = .systemBlue
                }
            } else {
                // Start translation
                let success = await G1Controller.shared.startLiveTranslation()
                if success {
                    if let button = translationCard.viewWithTag(200) as? UIButton {
                        button.setTitle("Stop Translation", for: .normal)
                        button.backgroundColor = .systemRed
                    }
                } else {
                    showAlert(title: "Error", message: "Failed to start translation. Make sure glasses are connected.")
                }
            }
        }
    }

    private lazy var translationCard: UIView = {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        card.layer.cornerRadius = 20
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowOpacity = 0.2
        card.layer.shadowRadius = 4
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        // Header row
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center
        
        let translationIcon = UIImageView(image: UIImage(systemName: "globe"))
        translationIcon.tintColor = .white
        translationIcon.contentMode = .scaleAspectFit
        translationIcon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        translationIcon.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        let translationLabel = UILabel()
        translationLabel.text = "Live Translation"
        translationLabel.font = .systemFont(ofSize: 16, weight: .medium)
        translationLabel.textColor = .white
        
        headerRow.addArrangedSubview(translationIcon)
        headerRow.addArrangedSubview(translationLabel)
        headerRow.addArrangedSubview(UIView()) // Spacer
        
        // Language selection row
        let languageRow = UIStackView()
        languageRow.axis = .horizontal
        languageRow.spacing = 8
        languageRow.alignment = .center
        
        // Input language button
        let inputLanguageButton = UIButton(type: .system)
        // Load saved input language name
        let savedInputCode = UserDefaults.standard.string(forKey: "selectedInputLanguage") ?? "en-US"
        let inputLanguageName = getLanguageNameForCode(savedInputCode)
        inputLanguageButton.setTitle(inputLanguageName, for: .normal)
        inputLanguageButton.titleLabel?.font = .systemFont(ofSize: 14)
        inputLanguageButton.setTitleColor(.white.withAlphaComponent(0.7), for: .normal)
        inputLanguageButton.addTarget(self, action: #selector(selectInputLanguage), for: .touchUpInside)
        inputLanguageButton.tag = 101 // Tag for input language button
        
        // Arrow icon
        let arrowLabel = UILabel()
        arrowLabel.text = "→"
        arrowLabel.textColor = .white.withAlphaComponent(0.7)
        arrowLabel.font = .systemFont(ofSize: 14)
        
        // Output language button
        let outputLanguageButton = UIButton(type: .system)
        // Load saved output language
        let savedOutputLangRaw = UserDefaults.standard.integer(forKey: "selectedTranslationLanguage")
        let outputLanguageName = getLanguageNameForTranslateLanguage(UInt8(savedOutputLangRaw))
        outputLanguageButton.setTitle(outputLanguageName, for: .normal)
        outputLanguageButton.titleLabel?.font = .systemFont(ofSize: 14)
        outputLanguageButton.setTitleColor(.white.withAlphaComponent(0.7), for: .normal)
        outputLanguageButton.addTarget(self, action: #selector(selectOutputLanguage), for: .touchUpInside)
        outputLanguageButton.tag = 100 // Tag for output language button
        
        languageRow.addArrangedSubview(inputLanguageButton)
        languageRow.addArrangedSubview(arrowLabel)
        languageRow.addArrangedSubview(outputLanguageButton)
        
        // Translation controls
        let controlsRow = UIStackView()
        controlsRow.axis = .horizontal
        controlsRow.spacing = 8
        controlsRow.alignment = .center
        
        let startButton = UIButton(type: .system)
        startButton.setTitle("Start Translation", for: .normal)
        startButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        startButton.backgroundColor = .systemBlue
        startButton.setTitleColor(.white, for: .normal)
        startButton.layer.cornerRadius = 12
        startButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        startButton.tag = 200 // Add tag for identification
        startButton.addTarget(self, action: #selector(toggleTranslation), for: .touchUpInside)
        
        controlsRow.addArrangedSubview(startButton)
        
        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(languageRow)
        stack.addArrangedSubview(controlsRow)
        
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        
        return card
    }()

    private func getLanguageNameForCode(_ code: String) -> String {
        let languages = [
            ("English (US)", "en-US"),
            ("English (UK)", "en-GB"),
            ("English (Australia)", "en-AU"),
            ("English (Canada)", "en-CA"),
            ("English (India)", "en-IN"),
            ("Spanish (Spain)", "es-ES"),
            ("Spanish (Mexico)", "es-MX"),
            ("Spanish (US)", "es-US"),
            ("Spanish (Latin America)", "es-419"),
            ("French (France)", "fr-FR"),
            ("French (Canada)", "fr-CA"),
            ("German", "de-DE"),
            ("Italian", "it-IT"),
            ("Japanese", "ja-JP"),
            ("Korean", "ko-KR"),
            ("Portuguese (Brazil)", "pt-BR"),
            ("Russian", "ru-RU"),
            ("Turkish", "tr-TR"),
            ("Arabic", "ar-SA"),
            ("Chinese (Mandarin)", "zh-CN"),
            ("Chinese (Cantonese)", "zh-HK")
        ]
        
        return languages.first { $0.1 == code }?.0 ?? "English (US)"
    }

    @objc private func selectInputLanguage() {
        let alert = UIAlertController(title: "Select Input Language", message: nil, preferredStyle: .actionSheet)
        
        let languages = [
            ("English (US)", "en-US"),
            ("English (UK)", "en-GB"),
            ("English (Australia)", "en-AU"),
            ("English (Canada)", "en-CA"),
            ("English (India)", "en-IN"),
            ("Spanish (Spain)", "es-ES"),
            ("Spanish (Mexico)", "es-MX"),
            ("Spanish (US)", "es-US"),
            ("Spanish (Latin America)", "es-419"),
            ("French (France)", "fr-FR"),
            ("French (Canada)", "fr-CA"),
            ("German", "de-DE"),
            ("Italian", "it-IT"),
            ("Japanese", "ja-JP"),
            ("Korean", "ko-KR"),
            ("Portuguese (Brazil)", "pt-BR"),
            ("Russian", "ru-RU"),
            ("Turkish", "tr-TR"),
            ("Arabic", "ar-SA"),
            ("Chinese (Mandarin)", "zh-CN"),
            ("Chinese (Cantonese)", "zh-HK")
        ]
        
        for (name, code) in languages {
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                if let button = self?.translationCard.viewWithTag(101) as? UIButton {
                    button.setTitle(name, for: .normal)
                }
                // Store selected language for later use
                UserDefaults.standard.set(code, forKey: "selectedInputLanguage")
                // Update speech recognizer
                G1Controller.shared.updateSpeechRecognitionLanguage(code)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func selectOutputLanguage() {
        let alert = UIAlertController(title: "Select Target Language", message: nil, preferredStyle: .actionSheet)
        
        let languages = [
            ("Chinese", TranslateLanguage.chinese),
            ("English", TranslateLanguage.english),
            ("Japanese", TranslateLanguage.japanese),
            ("Korean", TranslateLanguage.korean),
            ("French", TranslateLanguage.french),
            ("German", TranslateLanguage.german),
            ("Spanish (Spain)", TranslateLanguage.spanish),
            ("Spanish (Latin America)", TranslateLanguage.spanish),
            ("Russian", TranslateLanguage.russian),
            ("Dutch", TranslateLanguage.dutch),
            ("Norwegian", TranslateLanguage.norwegian),
            ("Danish", TranslateLanguage.danish),
            ("Swedish", TranslateLanguage.swedish),
            ("Finnish", TranslateLanguage.finnish),
            ("Italian", TranslateLanguage.italian),
            ("Arabic", TranslateLanguage.arabic),
            ("Hindi", TranslateLanguage.hindi),
            ("Bengali", TranslateLanguage.bengali),
            ("Cantonese", TranslateLanguage.cantonese)
        ]
        
        for (name, language) in languages {
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                if let button = self?.translationCard.viewWithTag(100) as? UIButton {
                    button.setTitle(name, for: .normal)
                }
                // Store both the language enum and the display name for later use
                UserDefaults.standard.set(language.rawValue, forKey: "selectedTranslationLanguage")
                UserDefaults.standard.set(name, forKey: "selectedTranslationLanguageName")
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func getLanguageNameForTranslateLanguage(_ rawValue: UInt8) -> String {
        // First try to get the saved display name
        if let savedName = UserDefaults.standard.string(forKey: "selectedTranslationLanguageName") {
            return savedName
        }

        // Fallback to basic mapping
        let languages: [(String, TranslateLanguage)] = [
            ("Chinese", .chinese),
            ("English", .english),
            ("Japanese", .japanese),
            ("Korean", .korean),
            ("French", .french),
            ("German", .german),
            ("Spanish (Spain)", .spanish),
            ("Russian", .russian),
            ("Dutch", .dutch),
            ("Norwegian", .norwegian),
            ("Danish", .danish),
            ("Swedish", .swedish),
            ("Finnish", .finnish),
            ("Italian", .italian),
            ("Arabic", .arabic),
            ("Hindi", .hindi),
            ("Bengali", .bengali),
            ("Cantonese", .cantonese)
        ]
        
        return languages.first { $0.1.rawValue == rawValue }?.0 ?? "French"
    }
}

extension StartViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return viewModel.availableModels.count
    }
    
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return viewModel.availableModels[row]
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedModel = viewModel.availableModels[row]
        UserDefaults.standard.set(selectedModel, forKey: "selectedModel")
        G1Controller.shared.configureOpenAI(
            apiKey: apiKeyTextField.text ?? "",
            baseURL: endpointTextField.text,
            model: selectedModel
        )
    }
    
    public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int) -> UIView? {
        let label = UILabel()
        label.text = viewModel.availableModels[row]
        label.font = .systemFont(ofSize: 16)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }
}

// MARK: - UITextFieldDelegate
extension StartViewController: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == endpointTextField {
            apiKeyTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            connectToAPITapped()
        }
        return true
    }
}

extension StartViewController: UITextViewDelegate {
    public func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == "Add a quick note..." && currentlyEditingNoteId == nil {
            textView.text = ""
            textView.textColor = .white
        }
    }
    
    public func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty && currentlyEditingNoteId == nil {
            textView.text = "Add a quick note..."
            textView.textColor = UIColor.white.withAlphaComponent(0.5)
            addNoteButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
            currentlyEditingNoteId = nil
        }
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        // Limit to 4 lines
        let lines = textView.text.components(separatedBy: .newlines)
        if lines.count > 4 {
            textView.text = lines.prefix(4).joined(separator: "\n")
        }
    }
}
