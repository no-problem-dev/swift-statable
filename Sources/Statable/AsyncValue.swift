import Observation

/// An observable container for a value that is loaded asynchronously. **It lives only on the main actor.**
///
/// ## Why `@MainActor`
///
/// This *is* the state of the screen, and SwiftUI reads it on the main actor. When a write arrives
/// from another thread, Observation's invalidation is delivered from that thread too, so SwiftUI can
/// drop it. **A dropped invalidation freezes the view on whatever it drew last** — which is what
/// "the loading indicator never goes away" actually is.
///
/// Up to 1.x this was `@unchecked Sendable` with a note saying it was "protected by `@MainActor`".
/// But `load(_:)` was a `nonisolated async` function, so calling it even from a `@MainActor` store
/// hopped onto the generic executor immediately, and `startLoading()` and `set()` ran there
/// (`AsyncValueIsolationTests` measures this). **An assumption is kept by the declaration, not by a note.**
///
/// The call itself still leaves — `operation` is `@Sendable`, so it never blocks the main actor.
/// Only the state writes stay behind.
///
/// ## Example
///
/// ```swift
/// @Statable(UserProfile.self)
/// @MainActor @Observable
/// final class ProfileStore {
///     func load() async {
///         await load { try await api.fetchProfile() }
///     }
/// }
/// ```
@MainActor
@Observable
public final class AsyncValue<Value: Sendable> {
    // MARK: - State

    /// The exclusive state behind every convenience property, exposed so a view can switch on it.
    public private(set) var state: AsyncState<Value>

    /// The number of the call that is currently allowed to write state back.
    ///
    /// **The last one started wins.** When loads for the same value overlap, the one that finishes
    /// last would otherwise win instead of the one that started last, so an old failure can paint
    /// over a newer success. Each start takes the next number, and a result is only written back
    /// while that number is still current.
    ///
    /// `set` / `setError` / `reset` / `startLoading` take a number too — a value placed explicitly
    /// is newer information than a load that is still running.
    private var generation: UInt64 = 0

    // MARK: - Initialization

    /// Creates a container that has not been asked for anything yet.
    public init() {
        self.state = .idle
    }

    /// Creates a container that already holds a value, as if a load had just succeeded.
    /// - Parameter initialValue: The value to start from.
    public init(initialValue: Value) {
        self.state = .loaded(initialValue)
    }

    /// Creates a container that starts in a state you choose.
    /// - Parameter state: The state to start in.
    public init(state: AsyncState<Value>) {
        self.state = state
    }

    // MARK: - Computed Properties

    /// The value that can be shown right now; during a reload or after a failure it is the previous one.
    public var value: Value? { state.value }

    public var isLoading: Bool { state.isLoading }

    /// Whether a load is in flight with nothing to show yet — the only state in which a skeleton belongs.
    public var isInitialLoading: Bool { state.isInitialLoading }

    /// Whether a load is in flight while the previous value is still shown. Use it to avoid emptying the screen.
    public var isReloading: Bool { state.isReloading }

    /// The error from the last load, or nil unless that load failed.
    public var error: StateError? { state.error }

    /// Whether there is anything to show, including a value kept through a reload or a failure.
    public var hasValue: Bool { state.hasValue }

    /// Whether the last load finished successfully. A value left over from before a failure does not count.
    public var isLoaded: Bool { state.isLoaded }

    public var isIdle: Bool { state.isIdle }

    public var isFailed: Bool { state.isFailed }

    // MARK: - State Transitions

    /// Stores a value directly, superseding a load that is still in flight.
    /// - Parameter value: The value to show.
    public func set(_ value: Value) {
        claim()
        state = .loaded(value)
    }

    /// Records a failure while keeping the previous value, and supersedes a load that is still in flight.
    /// - Parameter error: The failure to record.
    public func setError(_ error: StateError) {
        claim()
        state.fail(with: error)
    }

    /// Converts an arbitrary error into a structured one and records it.
    /// - Parameter error: The error to convert.
    public func setError(from error: Error) {
        setError(StateError(from: error))
    }

    /// Marks a load as started, keeping the previous value so the screen stays filled.
    public func startLoading() {
        claim()
        state.startLoading()
    }

    /// Drops the value and the error, and abandons a load that is still in flight.
    public func reset() {
        claim()
        state.reset()
    }

    // MARK: - Convenience Methods

    /// Runs an async operation and reflects its outcome in the state.
    ///
    /// Starting, succeeding, failing and being cancelled are all handled here.
    ///
    /// - When loads overlap, **the last one started wins** (the older one drops its result and returns quietly)
    /// - Cancellation (a cancelled `Task`) is not a failure. The previous value comes back
    ///
    /// ```swift
    /// await store.profile.load {
    ///     try await api.fetchProfile()
    /// }
    /// ```
    ///
    /// - Parameter operation: The work to run.
    public func load(_ operation: @Sendable () async throws -> Value) async {
        let token = claim()
        state.startLoading()
        do {
            let value = try await operation()
            guard token == generation else { return }
            state = .loaded(value)
        } catch {
            guard token == generation else { return }
            // Do not show something that was merely stopped as a failure. At the same time,
            // do not let a cancellation strand the state in `loading` — that is what "leave the
            // screen, come back, and the spinner is still going" really is.
            // URLSession reports cancellation as `URLError(.cancelled)`, so decide from where the
            // task stands rather than from the type that was thrown.
            if Task.isCancelled || error is CancellationError {
                state.cancelLoading()
            } else {
                state.fail(with: StateError(from: error))
            }
        }
    }

    /// Loads only when no load has succeeded yet.
    ///
    /// A failure that left the previous value behind does not count as done, so it is read again.
    ///
    /// - Parameter operation: The work to run.
    public func loadIfNeeded(_ operation: @Sendable () async throws -> Value) async {
        guard !isLoaded else { return }
        await load(operation)
    }

    /// Takes the right to write state back and returns the number that grants it.
    @discardableResult
    private func claim() -> UInt64 {
        generation &+= 1
        return generation
    }
}
