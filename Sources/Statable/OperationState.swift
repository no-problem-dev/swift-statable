import Observation

/// Tracks several concurrent operations one by one. **It lives only on the main actor** (for the same reason ``AsyncValue`` does).
///
/// Each operation keeps its own running state and its own last error.
///
/// Up to 1.x `run(_:task:)` was a `nonisolated async` function too, so `start` / `complete` /
/// `fail` ran on the generic executor and wrote to `activeOperations` — which SwiftUI is reading —
/// from another thread. It showed up as a spinner on the button that never went away.
///
/// ## Example
///
/// ```swift
/// @Statable([WorkoutActivity].self)
/// @MainActor @Observable
/// final class WorkoutStore {
///     enum Operation: String, CaseIterable, Sendable {
///         case fetch
///         case recordStrength
///         case recordCardio
///     }
///
///     @Track(Operation.self) var operations
/// }
///
/// // Starting and completing an operation
/// store.operations.start(.fetch)
/// store.operations.complete(.fetch)
///
/// // Checking the state
/// if store.operations.isActive(.recordStrength) {
///     ProgressView("Recording…")
/// }
/// ```
@MainActor
@Observable
public final class OperationTracker<Operation: Hashable & Sendable> {
    // MARK: - State

    private var activeOperations: Set<Operation> = []

    private var errors: [Operation: StateError] = [:]

    // MARK: - Initialization

    /// Creates a tracker with nothing running and no errors recorded.
    public init() {}

    // MARK: - Operation Management

    /// Marks an operation as running and clears the error left over from its last attempt.
    /// - Parameter operation: The operation that is starting.
    public func start(_ operation: Operation) {
        activeOperations.insert(operation)
        errors.removeValue(forKey: operation)
    }

    /// Marks an operation as no longer running, leaving any recorded error untouched.
    /// - Parameter operation: The operation that finished.
    public func complete(_ operation: Operation) {
        activeOperations.remove(operation)
    }

    /// Stops tracking an operation as running and records why it failed.
    /// - Parameters:
    ///   - operation: The operation that failed.
    ///   - error: The failure to record.
    public func fail(_ operation: Operation, with error: StateError) {
        activeOperations.remove(operation)
        errors[operation] = error
    }

    /// Stops tracking an operation as running and records an arbitrary error, converted on the way in.
    /// - Parameters:
    ///   - operation: The operation that failed.
    ///   - error: The error to convert and record.
    public func fail(_ operation: Operation, with error: Error) {
        fail(operation, with: StateError(from: error))
    }

    // MARK: - Query Methods

    public func isActive(_ operation: Operation) -> Bool {
        activeOperations.contains(operation)
    }

    public var hasActiveOperations: Bool {
        !activeOperations.isEmpty
    }

    /// The operations running right now, as a snapshot you can iterate over.
    public var active: Set<Operation> {
        activeOperations
    }

    /// The error left by an operation's last attempt, which its next start clears.
    /// - Parameter operation: The operation to ask about.
    public func error(for operation: Operation) -> StateError? {
        errors[operation]
    }

    public var hasErrors: Bool {
        !errors.isEmpty
    }

    /// Every error still on record, keyed by the operation that produced it.
    public var allErrors: [Operation: StateError] {
        errors
    }

    // MARK: - Error Management

    /// Clears one operation's error, for a retry button that should reset the message before running again.
    /// - Parameter operation: The operation whose error to clear.
    public func clearError(for operation: Operation) {
        errors.removeValue(forKey: operation)
    }

    public func clearAllErrors() {
        errors.removeAll()
    }

    // MARK: - Convenience Methods

    /// Runs a task and tracks its start, finish and failure for you.
    ///
    /// Cancellation (a cancelled `Task`) is not recorded as a failure. Showing something that was
    /// merely called off in red leaves a failure on screen that nobody remembers asking for.
    ///
    /// ```swift
    /// await store.operations.run(.fetch) {
    ///     try await api.fetchActivities()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - operation: The operation to track.
    ///   - task: The work to run.
    /// - Returns: The outcome of the task, or `nil` when it was cancelled.
    @discardableResult
    public func run<T: Sendable>(
        _ operation: Operation,
        task: @Sendable () async throws -> T
    ) async -> Result<T, StateError>? {
        start(operation)
        do {
            let result = try await task()
            complete(operation)
            return .success(result)
        } catch {
            guard !isCancellation(error) else {
                complete(operation)
                return nil
            }
            let stateError = StateError(from: error)
            fail(operation, with: stateError)
            return .failure(stateError)
        }
    }

    /// Runs a task and puts its result into an ``AsyncValue``.
    ///
    /// The transition rules — how overlaps settle, how cancellation is handled — belong to
    /// ``AsyncValue/load(_:)``, so this defers to them and only adds the operation tracking.
    /// **The same rule is not written in two places.**
    ///
    /// ```swift
    /// await store.operations.run(.fetch, into: store.activities) {
    ///     try await api.fetchActivities()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - operation: The operation to track.
    ///   - asyncValue: The container that receives the result.
    ///   - task: The work to run.
    public func run<T: Sendable>(
        _ operation: Operation,
        into asyncValue: AsyncValue<T>,
        task: @Sendable () async throws -> T
    ) async {
        start(operation)
        await asyncValue.load(task)
        if let error = asyncValue.error {
            fail(operation, with: error)
        } else {
            complete(operation)
        }
    }

    /// Whether the work was called off. URLSession reports cancellation as `URLError(.cancelled)`,
    /// so this also decides from where the task stands rather than from the type that was thrown.
    private func isCancellation(_ error: Error) -> Bool {
        Task.isCancelled || error is CancellationError
    }
}
