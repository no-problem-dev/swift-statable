import Testing
@testable import Statable

@Suite("OperationTracker Tests")
@MainActor
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

    // MARK: - 同じ操作が重なって走ったとき

    @Test("同じ操作が二重に走っているとき、先に終わった方だけで追跡は止まらない")
    func overlappingSameOperationStaysActiveUntilTheLastOne() {
        let tracker = OperationTracker<TestOperation>()

        tracker.start(.fetch)  // 1 本目（例：画面に出たときの自動更新）
        tracker.start(.fetch)  // 2 本目（例：その最中に引っぱって更新）
        tracker.complete(.fetch)  // 1 本目が返ってきた

        // 2 本目はまだ通信している。ここで「走っていない」と答えると、
        // 通信中なのにぐるぐるが消えて、利用者には終わったように見える
        #expect(tracker.isActive(.fetch))
        #expect(tracker.hasActiveOperations)
        #expect(tracker.active.contains(.fetch))

        tracker.complete(.fetch)

        #expect(!tracker.isActive(.fetch))
        #expect(!tracker.hasActiveOperations)
    }

    @Test("二重に走った片方が落ちても、もう片方が走っている間は追跡が続く")
    func failingOneOfTwoKeepsTheOtherActive() {
        let tracker = OperationTracker<TestOperation>()

        tracker.start(.create)
        tracker.start(.create)
        tracker.fail(.create, with: .network(.timeout))

        #expect(tracker.isActive(.create))
        #expect(tracker.error(for: .create) == .network(.timeout))

        tracker.complete(.create)

        #expect(!tracker.isActive(.create))
        // 落ちた事実は、後から返ってきた方に消されない
        #expect(tracker.error(for: .create) == .network(.timeout))
    }

    @Test("run が重なっても、最後の 1 本が返るまでは走っていると分かる")
    func overlappingRunStaysActiveUntilTheLastOne() async {
        let tracker = OperationTracker<TestOperation>()

        async let slow = tracker.run(.fetch) {
            try? await Task.sleep(for: .milliseconds(120))
            return 1
        }
        try? await Task.sleep(for: .milliseconds(20))
        _ = await tracker.run(.fetch) { 2 }

        #expect(tracker.isActive(.fetch), "速い方が返っただけで、遅い方の通信中の表示が消えている")

        _ = await slow

        #expect(!tracker.isActive(.fetch))
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
