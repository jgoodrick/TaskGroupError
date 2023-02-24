
import Foundation
import ComposableArchitecture

struct MyReducer {
    @Dependency(\.continuousClock) var clock
    @Dependency(\.apiClient) var apiClient
}

extension MyReducer {
    
    enum CancelID {}
        
    struct State: Equatable {
        var queue: [Submission]
        var uploadsInFlight: Bool = false
    }
    
    enum Action: Equatable {
        case task
        case queue(Submission)
        case triggerUpload
        case registerProgress
        case finishedUpload
        case cancel
    }
}

extension MyReducer: ReducerProtocol {
    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .task:
            
            return .run { send in
                for await _ in clock.timer(interval: .seconds(5.0)) {
                    await send(.triggerUpload)
                }
            }.cancellable(id: CancelID.self)
            
        case .queue(let newSubmission):
            
            state.queue.append(newSubmission)
                        
            return .send(.triggerUpload)
            
        case .triggerUpload where !state.uploadsInFlight && !state.queue.isEmpty:
            
            state.uploadsInFlight = true
            
            return .run { [records = state.queue] send in
                await withTaskGroup(of: Void.self) { group in
                    for submission in records {
                        group.addTask {
                            let _ = await apiClient.submit(submission)
                        }
                    }
                    
                    for await _ in group {
                        await send(.registerProgress)
                    }
                    
                    await send(.finishedUpload)
                }
            }.cancellable(id: CancelID.self)

        case .triggerUpload:
                        
            return .none
            
        case .registerProgress:
                        
            return .none
            
        case .finishedUpload:
                        
            state.queue = []
                        
            state.uploadsInFlight = false
            
            return .none
            
        case .cancel:
            
            return .cancel(id: CancelID.self)
            
        }
    }
    
}

struct Submission: Sendable, Equatable {
    let id: UUID
}

struct APIClient {
    var submission: @Sendable (Submission) async -> SubmissionError?
}

extension APIClient {
    
    struct SubmissionError: Error, Equatable {}
    
    func submit(_ data: Submission) async -> SubmissionError? {
        await submission(data)
    }
}

extension DependencyValues {
    var apiClient: APIClient {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}

extension APIClient: DependencyKey {
    static let liveValue: Self = .init(submission: { _ in nil })
}

extension APIClient: TestDependencyKey {
    static let testValue: Self = .liveValue
}
