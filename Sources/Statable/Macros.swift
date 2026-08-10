// MARK: - @Statable Macro

/// Turns a class into a store for a single asynchronously loaded value.
///
/// It generates the pass-through members of an AsyncValue and adds conformance to the
/// `Statable` and `Sendable` protocols.
///
/// ## Basic use
///
/// ```swift
/// @Statable(MetabolicProfile.self)
/// @MainActor @Observable
/// final class ProfileStore {
///     // computed properties of your own
///     var currentAge: Int { value?.age() ?? 0 }
/// }
/// ```
///
/// ## With operation tracking
///
/// ```swift
/// enum WorkoutOperation: String, CaseIterable, Sendable {
///     case fetch, record, delete
/// }
///
/// @Statable([WorkoutActivity].self, operations: WorkoutOperation.self)
/// @MainActor @Observable
/// final class WorkoutStore {
///     // operations.isActive(.fetch), operations.run(.record) { ... } and so on
/// }
/// ```
///
/// ## Generated members
///
/// ### From AsyncValue
/// - `value: T?` — what can be shown now (the previous value survives a reload and a failure)
/// - `state: AsyncState<T>` — the exclusive state, for switching over every case
/// - `isLoading: Bool` — whether a load is in flight
/// - `isInitialLoading: Bool` — in flight with nothing to show yet (the only state for a skeleton)
/// - `isReloading: Bool` — in flight with the previous value still shown (do not empty the screen)
/// - `hasValue: Bool` — whether there is anything to show at all
/// - `isLoaded: Bool` — whether the last load finished successfully
/// - `error: StateError?` — the failure from the last load
/// - `set(_:)` — store a value directly
/// - `setError(_:)` — record a failure
/// - `startLoading()` — mark a load as started
/// - `reset()` — drop the value and the error
/// - `load(_:)` — run an async operation (last started wins; cancellation is not a failure)
/// - `loadIfNeeded(_:)` — load only when no load has succeeded yet
///
/// ### From OperationTracker (only with the operations argument)
/// - `operations: OperationTracker<Op>` — the tracker instance
///
/// ## In a view
///
/// ```swift
/// // Reading the value
/// if let profile = store.value {
///     Text(profile.name)
/// }
///
/// // Render three faces, never from `isLoading` alone
/// if let profile = store.value {
///     ProfileView(profile: profile)
///     if let error = store.error { Banner(error) }
/// } else if let error = store.error {
///     FailureFace(error)
/// } else {
///     Skeleton()
/// }
///
/// // Operations, when the operations argument was given
/// if store.operations.isActive(.fetch) {
///     ProgressView()
/// }
/// await store.operations.run(.record) {
///     try await api.record(workout)
/// }
/// ```
@attached(member, names: named(_asyncValue), named(_operations), named(value), named(state), named(isLoading), named(isIdle), named(isFailed), named(isInitialLoading), named(isReloading), named(hasValue), named(isLoaded), named(error), named(operations), named(set), named(setError), named(startLoading), named(reset), named(load), named(loadIfNeeded))
@attached(extension, conformances: Statable, Sendable)
public macro Statable<T: Sendable>(
    _ valueType: T.Type
) = #externalMacro(module: "StatableMacros", type: "StatableMacro")

/// The `@Statable` macro with operation tracking attached.
///
/// Pass a `Hashable & Sendable` enum to `operations:` and an `OperationTracker<Op>` instance is
/// generated as the `operations` property. `operations.run(.fetch) { ... }` then tracks the running
/// state of each operation for you.
///
/// - SeeAlso: ``Statable(_:)``
@attached(member, names: named(_asyncValue), named(_operations), named(value), named(state), named(isLoading), named(isIdle), named(isFailed), named(isInitialLoading), named(isReloading), named(hasValue), named(isLoaded), named(error), named(operations), named(set), named(setError), named(startLoading), named(reset), named(load), named(loadIfNeeded))
@attached(extension, conformances: Statable, Sendable)
public macro Statable<T: Sendable, Op: Hashable & Sendable>(
    _ valueType: T.Type,
    operations operationType: Op.Type
) = #externalMacro(module: "StatableMacros", type: "StatableMacro")

// MARK: - @Track Macro

/// Adds a standalone operation tracker to a store.
///
/// Apply it to a variable declaration inside a `@Statable` class and the storage and getter for an
/// `OperationTracker<Op>` are generated for you.
///
/// ## Basic use
///
/// ```swift
/// @Statable(UserProfile.self)
/// @MainActor @Observable
/// final class ProfileStore {
///     enum Operation: Hashable, Sendable {
///         case fetch
///         case update
///     }
///
///     @Track(Operation.self) var operations
/// }
///
/// // At the call site
/// if store.operations.isActive(.fetch) {
///     ProgressView()
/// }
/// await store.operations.run(.fetch) {
///     try await api.fetchProfile()
/// }
/// ```
///
/// ## Generated members
///
/// - `private let _<name> = OperationTracker<Op>()` — the storage behind it
/// - `var <name>: OperationTracker<Op> { get }` — a read-only accessor
@attached(accessor, names: named(get))
@attached(peer, names: prefixed(_))
public macro Track<Op: Hashable & Sendable>(
    _ operationType: Op.Type
) = #externalMacro(module: "StatableMacros", type: "TrackMacro")
