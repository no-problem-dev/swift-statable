import Testing
@testable import Statable

@Suite("AsyncState Tests")
struct AsyncStateTests {

    // MARK: - Initial State

    @Test("Initial state is idle")
    func initialState() {
        let state: AsyncState<String> = .idle
        #expect(state.isIdle)
        #expect(!state.isLoading)
        #expect(!state.hasValue)
        #expect(!state.isFailed)
        #expect(state.value == nil)
        #expect(state.error == nil)
    }

    // MARK: - State Transitions

    @Test("Transition to loading")
    func transitionToLoading() {
        var state: AsyncState<String> = .idle
        state.startLoading()

        #expect(state.isLoading)
        #expect(!state.isIdle)
        #expect(state.value == nil)
    }

    @Test("Transition to loading preserves previous value")
    func loadingPreservesPreviousValue() {
        var state: AsyncState<String> = .loaded("Hello")
        state.startLoading()

        #expect(state.isLoading)
        #expect(state.value == "Hello")

        if case .loading(let previous) = state {
            #expect(previous == "Hello")
        } else {
            Issue.record("Expected loading state with previous value")
        }
    }

    @Test("Transition to loaded")
    func transitionToLoaded() {
        var state: AsyncState<String> = .loading(previous: nil)
        state.succeed(with: "World")

        #expect(state.hasValue)
        #expect(state.value == "World")
        #expect(!state.isLoading)
    }

    @Test("Transition to failed")
    func transitionToFailed() {
        var state: AsyncState<String> = .loading(previous: nil)
        state.fail(with: .network(.timeout))

        #expect(state.isFailed)
        #expect(state.error == .network(.timeout))
        #expect(state.value == nil)
    }

    @Test("Reset to idle")
    func resetToIdle() {
        var state: AsyncState<String> = .loaded("Test")
        state.reset()

        #expect(state.isIdle)
        #expect(state.value == nil)
    }

    // MARK: - Equatable

    @Test("Equatable conformance")
    func equatable() {
        let state1: AsyncState<Int> = .loaded(42)
        let state2: AsyncState<Int> = .loaded(42)
        let state3: AsyncState<Int> = .loaded(100)

        #expect(state1 == state2)
        #expect(state1 != state3)
    }
}
