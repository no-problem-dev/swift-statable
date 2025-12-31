import Testing
@testable import Statable

@Suite("AsyncValue Tests")
struct AsyncValueTests {

    // MARK: - Initialization

    @Test("Default initialization creates idle state")
    func defaultInit() {
        let value = AsyncValue<String>()

        #expect(value.state.isIdle)
        #expect(value.value == nil)
        #expect(!value.isLoading)
        #expect(!value.hasValue)
    }

    @Test("Initialization with initial value creates loaded state")
    func initWithValue() {
        let value = AsyncValue(initialValue: "Hello")

        #expect(value.hasValue)
        #expect(value.value == "Hello")
    }

    // MARK: - State Transitions

    @Test("Set value transitions to loaded")
    func setValue() {
        let value = AsyncValue<String>()
        value.set("World")

        #expect(value.hasValue)
        #expect(value.value == "World")
    }

    @Test("Set error transitions to failed")
    func setError() {
        let value = AsyncValue<String>()
        value.setError(.unauthorized)

        #expect(value.isFailed)
        #expect(value.error == .unauthorized)
    }

    @Test("Start loading transitions to loading")
    func startLoading() {
        let value = AsyncValue<String>()
        value.startLoading()

        #expect(value.isLoading)
        #expect(value.value == nil)
    }

    @Test("Start loading preserves previous value")
    func startLoadingPreservesPrevious() {
        let value = AsyncValue(initialValue: "Previous")
        value.startLoading()

        #expect(value.isLoading)
        #expect(value.value == "Previous")
    }

    @Test("Reset transitions to idle")
    func reset() {
        let value = AsyncValue(initialValue: "Test")
        value.reset()

        #expect(value.state.isIdle)
        #expect(value.value == nil)
    }

    // MARK: - Switch on State

    @Test("Switch on state works correctly")
    func switchOnState() {
        let value = AsyncValue(initialValue: 42)

        var result: String = ""

        switch value.state {
        case .idle:
            result = "idle"
        case .loading:
            result = "loading"
        case .loaded(let num):
            result = "loaded:\(num)"
        case .failed:
            result = "failed"
        }

        #expect(result == "loaded:42")
    }

    // MARK: - Convenience Methods

    @Test("Load method handles success")
    func loadSuccess() async {
        let value = AsyncValue<Int>()

        await value.load {
            42
        }

        #expect(value.hasValue)
        #expect(value.value == 42)
    }

    @Test("Load method handles failure")
    func loadFailure() async {
        let value = AsyncValue<Int>()

        await value.load {
            throw TestError.simulated
        }

        #expect(value.isFailed)
        #expect(value.error != nil)
    }

    @Test("Load if needed skips when value exists")
    func loadIfNeededSkips() async {
        let value = AsyncValue(initialValue: 100)

        await value.loadIfNeeded {
            // This should not be called
            200
        }

        // Value should remain unchanged
        #expect(value.value == 100)
    }

    @Test("Load if needed loads when no value")
    func loadIfNeededLoads() async {
        let value = AsyncValue<Int>()

        await value.loadIfNeeded {
            200
        }

        // Value should be loaded
        #expect(value.value == 200)
    }
}

// MARK: - Test Helpers

private enum TestError: Error {
    case simulated
}
