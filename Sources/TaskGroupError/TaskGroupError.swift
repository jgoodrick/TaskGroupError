
import Foundation
import ComposableArchitecture
import AsyncAlgorithms

struct MyReducer {
    @Dependency(\.continuousClock) var clock
    @Dependency(\.apiClient) var apiClient
}

extension MyReducer {
    
    enum CancelID {}
        
    struct State: Equatable {
        var queue: [Submission] = []
        var inFlight: InFlightSubmissions?
    }
    
    enum Action: Equatable {
        case task
        case queue(Submission)
        case startSubmitting
        case received(result: Submission.Result)
        case finishedSubmitting
        case cancel
    }
}

extension MyReducer: ReducerProtocol {
    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .task:
            
            return .run { send in
                for await _ in clock.timer(interval: .seconds(5.0)) {
                    await send(.startSubmitting)
                }
            }.cancellable(id: CancelID.self)
            
        case .queue(let newSubmission):
            
            state.queue.append(newSubmission)
                        
            return .send(.startSubmitting)
            
        case .startSubmitting where state.inFlight == nil && !state.queue.isEmpty:
            
            state.inFlight = .init()
            
            return .run { [records = state.queue] send in
                
                let channel = AsyncChannel<Action>()
                
                Task(priority: .background) {
                    await withTaskGroup(of: Submission.Result.self) { group in
                        for submission in records {
                            group.addTask {
                                await apiClient.submit(submission)
                            }
                        }
                                                
                        for await result in group {
                            await channel.send(.received(result: result))
                        }
                        await channel.send(.finishedSubmitting)
                        channel.finish()
                    }
                }
                
                for await action in channel {
                    await send(action)
                }
                
            }.cancellable(id: CancelID.self)
            
        case .startSubmitting:
                        
            return .none
            
        case .received(let result):
            
            guard var inFlight = state.inFlight else {
                return .none
            }
            
            inFlight.results.append(result)
            
            return .none
            
        case .finishedSubmitting:
                        
            state.queue = []
                        
            state.inFlight = nil
            
            return .none
            
        case .cancel:
            
            return .cancel(id: CancelID.self)
            
        }
    }
    
}

struct Submission: Sendable, Equatable, Identifiable {
    let id: UUID
}

extension Submission {
    struct Failure: Error, Equatable {}
    
    enum Result: Sendable, Equatable {
        case success(for: Submission.ID)
        case failure(for: Submission.ID, Failure)
    }
}

extension Submission.Result: Identifiable {
    var id: Submission.ID {
        switch self {
        case .success(let id): return id
        case .failure(let id, _): return id
        }
    }
}

struct InFlightSubmissions: Equatable {
    var results: [Submission.Result] = []
}

struct APIClient {
    var submission: @Sendable (Submission) async -> Submission.Result
}

extension APIClient {
    
    func submit(_ value: Submission) async -> Submission.Result {
        await submission(value)
    }
}

extension DependencyValues {
    var apiClient: APIClient {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}

extension APIClient: DependencyKey {
    static let liveValue: Self = .init(submission: { .success(for: $0.id) })
}

extension APIClient: TestDependencyKey {
    static let testValue: Self = .liveValue
}
