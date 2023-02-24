
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
                $0.apiClient.submission = { _ in nil }
            }
        )
        await store.send(.task)
        await clock.advance(by: .seconds(5))
        await store.receive(.triggerUpload)
        await clock.advance(by: .seconds(5))
        await store.receive(.triggerUpload)
        await clock.advance(by: .seconds(5))
        await store.receive(.triggerUpload)
        await store.send(.cancel)
    }
    
    func test_queue_triggersUploadImmediately() async {
        let clock = TestClock()
        let store = TestStore(
            initialState: MyReducer.State(queue: []),
            reducer: MyReducer(),
            prepareDependencies: {
                $0.continuousClock = clock
                $0.apiClient.submission = { _ in nil }
            }
        )
        let submission = Submission(id: .init())
        await store.send(.task)
        await store.send(.queue(submission)) {
            $0.queue = [submission]
        }
        await store.receive(.triggerUpload) {
            $0.uploadsInFlight = true
        }
        await store.receive(.finishedUpload) {
            $0.queue = []
            $0.uploadsInFlight = false
        }
        await store.send(.cancel)
    }
    
}
