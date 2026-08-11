import Testing
@testable import Statable

@Suite("AsyncValue Tests")
@MainActor
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

    // MARK: - 失敗しても前の答えは捨てない

    @Test("失敗しても、直前まで見せていた答えは残る")
    func failureKeepsPreviousValue() async {
        let value = AsyncValue(initialValue: 100)

        await value.load { throw TestError.simulated }

        #expect(value.isFailed)
        #expect(value.error != nil)
        // 見せるものはまだある。画面を奪うかどうかは画面が決める
        #expect(value.value == 100)
        // 「済んでいる」には数えない（loadIfNeeded はもう一度読みに行く）
        #expect(!value.isLoaded)
    }

    @Test("前の答えが無いまま失敗したら、見せるものは無い")
    func failureWithoutPreviousValue() async {
        let value = AsyncValue<Int>()

        await value.load { throw TestError.simulated }

        #expect(value.isFailed)
        #expect(value.value == nil)
    }

    @Test("失敗の後に読み直すと、前の答えを持ったままのロード中になる")
    func reloadAfterFailureIsReloading() async {
        let value = AsyncValue(initialValue: 100)
        await value.load { throw TestError.simulated }

        value.startLoading()

        #expect(value.isReloading)
        #expect(!value.isInitialLoading)
        #expect(value.value == 100)
    }

    // MARK: - 初回のロードと読み直しの区別

    @Test("初回のロードは isInitialLoading、読み直しは isReloading")
    func initialLoadingVsReloading() {
        let first = AsyncValue<Int>()
        first.startLoading()
        #expect(first.isInitialLoading)
        #expect(!first.isReloading)

        let again = AsyncValue(initialValue: 1)
        again.startLoading()
        #expect(!again.isInitialLoading)
        #expect(again.isReloading)
    }

    @Test("空の配列は「答えが無い」ではない")
    func emptyCollectionIsAValue() {
        let value = AsyncValue<[Int]>()
        value.set([])
        value.startLoading()

        // 0 件の利用者だけが読み直しのたびに骨組みを見る、が起きないこと
        #expect(value.hasValue)
        #expect(!value.isInitialLoading)
        #expect(value.isReloading)
    }

    // MARK: - 重なったロードは後から始まった方が勝つ

    @Test("先に始まった遅いロードは、後から始まったロードの答えを上書きしない")
    func laterLoadWins() async {
        let value = AsyncValue<Int>()

        async let slow: Void = value.load {
            try? await Task.sleep(for: .milliseconds(60))
            return 1
        }
        try? await Task.sleep(for: .milliseconds(10))
        async let fast: Void = value.load { 2 }
        _ = await (slow, fast)

        #expect(value.value == 2)
    }

    @Test("先に始まった遅いロードの失敗が、後から始まった成功を塗り潰さない")
    func staleFailureDoesNotOverwriteFreshSuccess() async {
        let value = AsyncValue<Int>()

        async let slow: Void = value.load {
            try? await Task.sleep(for: .milliseconds(60))
            throw TestError.simulated
        }
        try? await Task.sleep(for: .milliseconds(10))
        async let fast: Void = value.load { 42 }
        _ = await (slow, fast)

        #expect(value.value == 42)
        #expect(!value.isFailed)
    }

    @Test("先に始まった遅いロードの成功が、後から始まった失敗を塗り潰さない")
    func staleSuccessDoesNotOverwriteFreshFailure() async {
        // staleFailureDoesNotOverwriteFreshSuccess の逆。
        // 「後から始まった方が勝つ」が、勝つ側が失敗のときにも成り立つか
        let value = AsyncValue<Int>()

        async let slow: Void = value.load {
            try? await Task.sleep(for: .milliseconds(60))
            return 1
        }
        try? await Task.sleep(for: .milliseconds(10))
        async let fast: Void = value.load { throw TestError.simulated }
        _ = await (slow, fast)

        #expect(value.isFailed)
        #expect(value.value == nil)
    }

    @Test("明示的に置いた値は、走っている途中のロードより新しい")
    func explicitSetWinsOverInFlightLoad() async {
        let value = AsyncValue<Int>()

        async let running: Void = value.load {
            try? await Task.sleep(for: .milliseconds(40))
            return 1
        }
        try? await Task.sleep(for: .milliseconds(10))
        value.set(99)
        await running

        #expect(value.value == 99)
    }

    // MARK: - 取り消しは失敗にしない

    @Test("取り消されたロードは失敗にならず、前の答えへ戻る")
    func cancellationRestoresPreviousValue() async {
        let value = AsyncValue(initialValue: 7)

        let task = Task { @MainActor in
            await value.load {
                try await Task.sleep(for: .seconds(5))
                return 8
            }
        }
        try? await Task.sleep(for: .milliseconds(20))
        task.cancel()
        await task.value

        #expect(!value.isFailed)
        // ここが loading のまま残ると、回りっぱなしの表示になる
        #expect(!value.isLoading)
        #expect(value.value == 7)
    }

    @Test("前の答えが無いまま取り消されたら初期状態へ戻る")
    func cancellationWithoutPreviousValueResetsToIdle() async {
        let value = AsyncValue<Int>()

        let task = Task { @MainActor in
            await value.load {
                try await Task.sleep(for: .seconds(5))
                return 1
            }
        }
        try? await Task.sleep(for: .milliseconds(20))
        task.cancel()
        await task.value

        #expect(value.isIdle)
        #expect(!value.isLoading)
    }
}

// MARK: - Test Helpers

private enum TestError: Error {
    case simulated
}
