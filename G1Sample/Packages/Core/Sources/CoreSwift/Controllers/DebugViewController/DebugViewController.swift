import UIKit
import Combine

public class DebugViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UI Components
    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()
    
    private lazy var contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Debug Tools"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var testTextButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Send Test Text", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        return button
    }()
    
    private lazy var notesContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 4
        return view
    }()
    
    private lazy var notesStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var notesHeaderView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var notesHeaderLabel: UILabel = {
        let label = UILabel()
        label.text = "Quick Notes"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .left
        return label
    }()
    
    private lazy var addNoteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Close", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17)
        return button
    }()
    
    // MARK: - Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationItem.title = "Debug Tools"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(closeButtonTapped))
        
        // Add scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        
        // Add components to content stack
        contentStack.addArrangedSubview(headerLabel)
        contentStack.addArrangedSubview(testTextButton)
        contentStack.addArrangedSubview(notesContainer)
        
        // Setup notes container
        notesContainer.addSubview(notesStackView)
        
        // Setup notes header view
        notesHeaderView.addSubview(notesHeaderLabel)
        notesHeaderView.addSubview(addNoteButton)
        notesStackView.addArrangedSubview(notesHeaderView)
        
        // Additional constraints for header view
        NSLayoutConstraint.activate([
            notesHeaderView.heightAnchor.constraint(equalToConstant: 30),
            
            notesHeaderLabel.leadingAnchor.constraint(equalTo: notesHeaderView.leadingAnchor),
            notesHeaderLabel.centerYAnchor.constraint(equalTo: notesHeaderView.centerYAnchor),
            
            addNoteButton.trailingAnchor.constraint(equalTo: notesHeaderView.trailingAnchor),
            addNoteButton.centerYAnchor.constraint(equalTo: notesHeaderView.centerYAnchor),
            addNoteButton.widthAnchor.constraint(equalToConstant: 30),
            addNoteButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Layout constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
            
            notesContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            
            notesStackView.topAnchor.constraint(equalTo: notesContainer.topAnchor, constant: 16),
            notesStackView.leadingAnchor.constraint(equalTo: notesContainer.leadingAnchor, constant: 16),
            notesStackView.trailingAnchor.constraint(equalTo: notesContainer.trailingAnchor, constant: -16),
            notesStackView.bottomAnchor.constraint(equalTo: notesContainer.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Bindings
    private func setupBindings() {
        // Test text button handler
        testTextButton.addTarget(self, action: #selector(testTextButtonTapped), for: .touchUpInside)
        
        // Add note button handler
        addNoteButton.addTarget(self, action: #selector(addNoteButtonTapped), for: .touchUpInside)
        
        // Observe quick notes
        G1Controller.shared.g1Manager.$quickNotes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notes in
                self?.updateNotesDisplay(notes)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    @objc private func testTextButtonTapped() {
        if G1Controller.shared.g1Connected {
            Task {
                await G1Controller.shared.sendTextToGlasses(
                    text: "ITS OVER 9000000!!!!!",
                    status: .SIMPLE_TEXT
                )
            }
        } else {
            showAlert(title: "Not Connected", message: "Please connect to G1 glasses first.")
        }
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func addNoteButtonTapped() {
        if !G1Controller.shared.g1Connected {
            showAlert(title: "Not Connected", message: "Please connect to G1 glasses first.")
            return
        }
        
        let alert = UIAlertController(title: "Add Quick Note", message: "Enter your note text", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Note text"
            textField.returnKeyType = .done
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let text = alert.textFields?.first?.text, !text.isEmpty else { return }
            Task {
                await G1Controller.shared.g1Manager.addQuickNote(text)
            }
        })
        
        present(alert, animated: true)
    }
    
    @objc private func deleteNoteTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < G1Controller.shared.g1Manager.quickNotes.count else { return }
        
        let note = G1Controller.shared.g1Manager.quickNotes[index]
        Task {
            await G1Controller.shared.g1Manager.removeQuickNote(id: note.id)
        }
    }
    
    // MARK: - Helper Methods
    private func updateNotesDisplay(_ notes: [QuickNote]) {
        // Remove all note views (keeping the header)
        notesStackView.arrangedSubviews.dropFirst().forEach { $0.removeFromSuperview() }
        
        if notes.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "No quick notes"
            emptyLabel.textColor = .systemGray
            emptyLabel.font = .systemFont(ofSize: 16)
            notesStackView.addArrangedSubview(emptyLabel)
        } else {
            for note in notes.prefix(4) {
                let noteView = UIView()
                noteView.translatesAutoresizingMaskIntoConstraints = false
                
                let noteLabel = UILabel()
                noteLabel.text = note.text
                noteLabel.textColor = .label
                noteLabel.font = .systemFont(ofSize: 16)
                noteLabel.numberOfLines = 0
                noteLabel.translatesAutoresizingMaskIntoConstraints = false
                
                let deleteButton = UIButton(type: .system)
                deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
                deleteButton.tintColor = .systemRed
                deleteButton.translatesAutoresizingMaskIntoConstraints = false
                
                // Store the note's ID in the button's tag using its index
                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                    deleteButton.tag = index
                }
                
                deleteButton.addTarget(self, action: #selector(deleteNoteTapped(_:)), for: .touchUpInside)
                
                noteView.addSubview(noteLabel)
                noteView.addSubview(deleteButton)
                
                NSLayoutConstraint.activate([
                    noteLabel.leadingAnchor.constraint(equalTo: noteView.leadingAnchor),
                    noteLabel.topAnchor.constraint(equalTo: noteView.topAnchor, constant: 8),
                    noteLabel.bottomAnchor.constraint(equalTo: noteView.bottomAnchor, constant: -8),
                    noteLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
                    
                    deleteButton.centerYAnchor.constraint(equalTo: noteView.centerYAnchor),
                    deleteButton.trailingAnchor.constraint(equalTo: noteView.trailingAnchor),
                    deleteButton.widthAnchor.constraint(equalToConstant: 44),
                    deleteButton.heightAnchor.constraint(equalToConstant: 44)
                ])
                
                notesStackView.addArrangedSubview(noteView)
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
} 