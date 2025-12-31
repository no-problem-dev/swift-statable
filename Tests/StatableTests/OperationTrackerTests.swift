import Testing
@testable import Statable

@Suite("OperationTracker Tests")
struct OperationTrackerTests {

    enum TestOperation: String, CaseIterable, Sendable {
        case fetch
        case create
        case update
        case delete
    }

    // MARK: - Initial State

    @Test("Initial state has no active operations")
    func initialState() {
        let tracker = OperationTracker<TestOperation>()

        #expect(!tracker.hasActiveOperations)
        #expect(tracker.active.isEmpty)
        #expect(!tracker.hasErrors)
    }

    // MARK: - Operation Lifecycle

    @Test("Start operation marks it as active")
    func startOperation() {
        let tracker = OperationTracker<TestOperation>()
        tracker.start(.fetch)

        #expect(tracker.isActive(.fetch))
        #expect(tracker.hasActiveOperations)
        #expect(tracker.active.contains(.fetch))
    }

    @Test("Complete operation removes it from active")
    func completeOperation() {
        let tracker = OperationTracker<TestOperation>()
        tracker.start(.fetch)
        tracker.complete(.fetch)

        #expect(!tracker.isActive(.fetch))
        #expect(!tracker.hasActiveOperations)
    }

    @Test("Fail operation removes from active and stores error")
    func failOperation() {
        let tracker = OperationTracker<TestOperation>()
        tracker.start(.create)
        tracker.fail(.create, with: .network(.timeout))

        #expect(!tracker.isActive(.create))
        #expect(tracker.error(for: .create) == .network(.timeout))
        #expect(tracker.hasErrors)
    }

    // MARK: - Multiple Operations

    @Test("Multiple operations can be active simultaneously")
    func multipleOperations() {
        let tracker = OperationTracker<TestOperation>()
        tracker.start(.fetch)
        tracker.start(.create)

        #expect(tracker.isActive(.fetch))
        #expect(tracker.isActive(.create))
        #expect(!tracker.isActive(.delete))
        #expect(tracker.active.count == 2)
    }

    @Test("Complete one operation doesn't affect others")
    func completeOneOperation() {
        let tracker = OperationTracker<TestOperation>()
        tracker.start(.fetch)
        tracker.start(.create)
        tracker.complete(.fetch)

        #expect(!tracker.isActive(.fetch))
        #expect(tracker.isActive(.create))
    }

    // MARK: - Error Management

    @Test("Clear error for specific operation")
    func clearErrorForOperation() {
        let tracker = OperationTracker<TestOperation>()
        tracker.start(.fetch)
        tracker.fail(.fetch, with: .unauthorized)

        #expect(tracker.error(for: .fetch) != nil)

        tracker.clearError(for: .fetch)

        #expect(tracker.error(for: .fetch) == nil)
        #expect(!tracker.hasErrors)
    }

    @Test("Clear all errors")
    func clearAllErrors() {
        let tracker = OperationTracker<TestOperation>()
        tracker.start(.fetch)
        tracker.fail(.fetch, with: .network(.timeout))
        tracker.start(.create)
        tracker.fail(.create, with: .unauthorized)

        #expect(tracker.allErrors.count == 2)

        tracker.clearAllErrors()

        #expect(tracker.allErrors.isEmpty)
        #expect(!tracker.hasErrors)
    }

    @Test("Starting operation clears previous error for that operation")
    func startClearsPreviousError() {
        let tracker = OperationTracker<TestOperation>()
        tracker.start(.fetch)
        tracker.fail(.fetch, with: .network(.timeout))

        #expect(tracker.error(for: .fetch) != nil)

        tracker.start(.fetch)

        #expect(tracker.error(for: .fetch) == nil)
        #expect(tracker.isActive(.fetch))
    }

    // MARK: - Run Method

    @Test("Run method handles success")
    func runSuccess() async {
        let tracker = OperationTracker<TestOperation>()

        let result = await tracker.run(.fetch) {
            42
        }

        #expect(!tracker.isActive(.fetch))
        #expect(tracker.error(for: .fetch) == nil)

        if case .success(let value) = result {
            #expect(value == 42)
        } else {
            Issue.record("Expected success result")
        }
    }

    @Test("Run method handles failure")
    func runFailure() async {
        let tracker = OperationTracker<TestOperation>()

        let result = await tracker.run(.fetch) {
            throw TestError.simulated
        }

        #expect(!tracker.isActive(.fetch))
        #expect(tracker.error(for: .fetch) != nil)

        if case .failure = result {
            // Expected
        } else {
            Issue.record("Expected failure result")
        }
    }

    @Test("Run with AsyncValue updates both")
    func runWithAsyncValue() async {
        let tracker = OperationTracker<TestOperation>()
        let value = AsyncValue<Int>()

        await tracker.run(.fetch, into: value) {
            100
        }

        #expect(!tracker.isActive(.fetch))
        #expect(value.hasValue)
        #expect(value.value == 100)
    }
}

// MARK: - Test Helpers

private enum TestError: Error {
    case simulated
}
