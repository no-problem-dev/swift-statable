/// The state of a value that is loaded asynchronously, held as one exclusive enum so there is a single source of truth.
///
/// **Both `loading` and `failed` carry the previous value across the transition.**
/// Throwing that value away on every reload or failure costs the screen even the answer it already had.
/// Whether to drop it is the view's decision; if the state decides first, the view has no choice left.
///
/// ## A view renders exactly three faces
///
/// ```swift
/// if let value = store.value {
///     Content(value)                       // shown during a reload and after a failure alike
///     if let error = store.error { Banner(error) }   // a failure speaks in a banner, it does not take the screen
/// } else if let error = store.error {
///     FailureFace(error)                   // take the screen only when there is nothing to show
/// } else {
///     Skeleton()                           // no answer has arrived yet
/// }
/// ```
///
/// **Do not render from `isLoading` alone.** Being in flight is not a reason to empty the screen.
public enum AsyncState<Value: Sendable>: Sendable {
    /// Nothing has been asked for yet.
    case idle

    /// A load is in flight, carrying along whatever was already on screen.
    /// - Parameter previous: The value shown until now, if there was one.
    case loading(previous: Value?)

    /// The load finished successfully — the only case that counts as done for a skip-if-loaded check.
    /// - Parameter value: The value that was loaded.
    case loaded(Value)

    /// The load failed, without taking away what was already on screen.
    /// - Parameters:
    ///   - error: The failure that occurred.
    ///   - previous: The value shown until now, if there was one. **A failure does not discard it**
    case failed(StateError, previous: Value?)
}

// MARK: - Computed Properties

extension AsyncState {
    /// The value that can be shown right now. **One check answers "is there anything to show" in every state.**
    ///
    /// An empty array or dictionary is a real value — the answer "none" — so a caller must never
    /// read `value?.isEmpty` as "there is no value". Doing so makes users with zero items, and only
    /// those users, watch a skeleton on every reload.
    public var value: Value? {
        switch self {
        case .idle:
            nil
        case .loading(let previous):
            previous
        case .loaded(let value):
            value
        case .failed(_, let previous):
            previous
        }
    }

    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// Whether a load is in flight with nothing to show yet.
    ///
    /// A skeleton belongs on screen only while this is true.
    public var isInitialLoading: Bool {
        if case .loading(let previous) = self {
            return previous == nil
        }
        return false
    }

    /// Whether a load is in flight while the previous value is still shown — a reload.
    ///
    /// **Do not empty the screen.** Keep the previous answer up and swap it quietly.
    public var isReloading: Bool {
        if case .loading(let previous) = self {
            return previous != nil
        }
        return false
    }

    /// The error from the last load, or nil unless that load failed.
    public var error: StateError? {
        if case .failed(let error, _) = self {
            return error
        }
        return nil
    }

    /// Whether there is anything to show, including a value kept through a reload or a failure.
    public var hasValue: Bool {
        value != nil
    }

    /// Whether the last load finished successfully.
    ///
    /// Unlike `hasValue`, this excludes a failure that merely left the previous value behind —
    /// this is the one `loadIfNeeded` may read as "there is nothing left to fetch".
    public var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }

    public var isIdle: Bool {
        if case .idle = self {
            return true
        }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

// MARK: - State Transitions

extension AsyncState {
    /// Begins a load, carrying the current value across the transition.
    public mutating func startLoading() {
        self = .loading(previous: value)
    }

    /// Records a successful load, replacing whatever was there.
    /// - Parameter value: The value that was loaded.
    public mutating func succeed(with value: Value) {
        self = .loaded(value)
    }

    /// Records a failure, carrying the current value across the transition.
    /// - Parameter error: The failure that occurred.
    public mutating func fail(with error: StateError) {
        self = .failed(error, previous: value)
    }

    /// Ends a load that was called off. **This is not a failure.**
    ///
    /// Leaving the screen or retyping a query merely stops the work; there is nothing to show a person.
    /// The previous answer comes back if there is one, and otherwise the state returns to idle —
    /// doing nothing here would strand it in loading, which is exactly the spinner that never stops.
    public mutating func cancelLoading() {
        self = value.map { .loaded($0) } ?? .idle
    }

    /// Drops the value and the error, as if nothing had been asked for.
    public mutating func reset() {
        self = .idle
    }
}

// MARK: - Equatable

extension AsyncState: Equatable where Value: Equatable {}

// MARK: - Hashable

extension AsyncState: Hashable where Value: Hashable {}
