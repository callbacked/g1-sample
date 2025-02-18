//
//  StartViewModel.swift
//  Core
//
//  Created by FILIPPOS PIRPILIDIS on 25/1/25.
//
import Combine
import Foundation

final public class StartViewModel: ViewModel, ViewModelBlueprint {
    @Published public var availableModels: [String] = []
    @Published public var isLoadingModels: Bool = false
    @Published public var endpointError: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    public override init() {
        super.init()
    }
    
    public struct Input {
        let viewDidLoadIn: AnyPublisher<Void, Never>
        let connectG1TapIn: AnyPublisher<Void, Never>
        let endpointConfigured: AnyPublisher<(String, String), Never>
    }

    public struct Output {
        let viewDidLoadOut: AnyPublisher<Void, Never>
        let connectG1TapOut: AnyPublisher<Void, Never>
        let modelsLoaded: AnyPublisher<[String], Never>
        let isLoadingModels: AnyPublisher<Bool, Never>
        let endpointError: AnyPublisher<String?, Never>
    }
    
    public func convert(input: Input) -> Output {
        let viewDidLoadHandler = input.viewDidLoadIn
            .handleEvents(receiveOutput: { [weak self] value in
                guard let self else { return }
                print("View loaded")
            })
        
        let connectG1TapHandler = input.connectG1TapIn
            .handleEvents(receiveOutput: { [weak self] value in
                guard let self else { return }
                print("connectG1 Tapped")
            })
            
        input.endpointConfigured
            .sink { [weak self] baseURL, apiKey in
                self?.fetchAvailableModels(baseURL: baseURL, apiKey: apiKey)
            }
            .store(in: &cancellables)
        
        return Output(
            viewDidLoadOut: viewDidLoadHandler.eraseToAnyPublisher(),
            connectG1TapOut: connectG1TapHandler.eraseToAnyPublisher(),
            modelsLoaded: $availableModels.eraseToAnyPublisher(),
            isLoadingModels: $isLoadingModels.eraseToAnyPublisher(),
            endpointError: $endpointError.eraseToAnyPublisher()
        )
    }
    
    private func fetchAvailableModels(baseURL: String, apiKey: String) {
        isLoadingModels = true
        endpointError = nil
        
        let modelsURL = baseURL.trimmingCharacters(in: .whitespaces).hasSuffix("/") 
            ? baseURL + "v1/models" 
            : baseURL + "/v1/models"
            
        guard let url = URL(string: modelsURL) else {
            endpointError = "Invalid URL"
            isLoadingModels = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ModelsResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingModels = false
                    if case .failure(let error) = completion {
                        self?.endpointError = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.availableModels = response.data.map { $0.id }
                }
            )
            .store(in: &cancellables)
    }
}

struct ModelsResponse: Codable {
    struct Model: Codable {
        let id: String
    }
    let data: [Model]
}
