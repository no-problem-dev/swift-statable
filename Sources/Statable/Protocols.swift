import Observation

// MARK: - Statable

/// What a type has to be before it can hold view state.
///
/// A class annotated with the `@Statable` macro conforms to this automatically.
///
/// ## What conformance guarantees
///
/// - It is protected by `@MainActor` (or another global actor)
/// - It behaves as `@Observable`
/// - It is `Sendable`
///
/// ## Example
///
/// ```swift
/// @Statable(MetabolicProfile.self)
/// @MainActor @Observable
/// final class ProfileStore {
///     public init() {}
/// }
/// // ProfileStore conforms to Statable without being told to
/// ```
///
/// - Note: The ``AsyncValue`` and ``OperationTracker`` inside are `@MainActor`, so putting
///   `@Statable` on a class that is not `@MainActor` **will not compile**. That is the intent:
///   you find out while writing it instead of racing at runtime.
public protocol Statable: AnyObject, Observable, Sendable {}
