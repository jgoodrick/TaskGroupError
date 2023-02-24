
import XCTest
import ComposableArchitecture
@testable import TaskGroupError

@MainActor
final class TaskGroupErrorTests: XCTestCase {
    
    func test_task_startsUploadTriggerTimer() async {
        let clock = TestClock()
        let store = TestStore(
            initialState: MyReducer.State(queue: []),
            reducer: MyReducer(),
            prepareDependencies: {
                $0.continuousClock = clock
                $0.apiClient.submission = { .success(for: $0.id) }
            }
        )
        await store.send(.task)
        await clock.advance(by: .seconds(5))
        await store.receive(.startSubmitting)
        await clock.advance(by: .seconds(5))
        await store.receive(.startSubmitting)
        await clock.advance(by: .seconds(5))
        await store.receive(.startSubmitting)
        await store.send(.cancel)
    }
    
    func test_queue_triggersUploadImmediately() async {
        let clock = TestClock()
        let previouslyFailed = Submission(id: .init())
        let anotherPreviouslyFailed = Submission(id: .init())
        let store = TestStore(
            initialState: MyReducer.State(queue: [previouslyFailed, anotherPreviouslyFailed]),
            reducer: MyReducer(),
            prepareDependencies: {
                $0.continuousClock = clock
                $0.apiClient.submission = { .success(for: $0.id) }
            }
        )
        let newSubmission = Submission(id: .init())
        await store.send(.task)
        await store.send(.queue(newSubmission)) {
            $0.queue = [previouslyFailed, anotherPreviouslyFailed, newSubmission]
        }
        await store.receive(.startSubmitting) {
            $0.inFlight = .init(results: [])
        }
        await store.receive(.received(result: .success(for: previouslyFailed.id)))
        await store.receive(.received(result: .success(for: anotherPreviouslyFailed.id)))
        await store.receive(.received(result: .success(for: newSubmission.id)))
        await store.receive(.finishedSubmitting) {
            $0 = .init()
        }
        await store.send(.cancel)
    }
    
    func test_queue_canceledEarly_cancelsChildren() async {
        let clock = TestClock()
        let previouslyFailed = Submission(id: .init())
        let anotherPreviouslyFailed = Submission(id: .init())
        let store = TestStore(
            initialState: MyReducer.State(queue: [previouslyFailed, anotherPreviouslyFailed]),
            reducer: MyReducer(),
            prepareDependencies: {
                $0.continuousClock = clock
                
                var uploadSeconds: Double = 0
                let sleepDuration: () -> Duration = {
                    defer { uploadSeconds += 1 }
                    return .seconds(uploadSeconds)
                }
                $0.apiClient.submission = { submission in
                    try? await clock.sleep(for: sleepDuration())
                    return .success(for: submission.id)
                }
            }
        )
        let newSubmission = Submission(id: .init())
        await store.send(.task)
        await store.send(.queue(newSubmission)) {
            $0.queue = [previouslyFailed, anotherPreviouslyFailed, newSubmission]
        }
        await store.receive(.startSubmitting) {
            $0.inFlight = .init(results: [])
        }
        await clock.advance(by: .seconds(0))
        await store.receive(.received(result: .success(for: previouslyFailed.id)))
        await clock.advance(by: .seconds(1))
        await store.receive(.received(result: .success(for: anotherPreviouslyFailed.id)))
        await clock.advance(by: .seconds(0.5))
        await store.send(.cancel)
    }

}
