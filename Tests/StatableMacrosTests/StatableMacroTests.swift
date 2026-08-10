import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(StatableMacros)
import StatableMacros

let testMacros: [String: Macro.Type] = [
    "Statable": StatableMacro.self,
]

final class StatableMacroTests: XCTestCase {

    func testStatableGeneratesAsyncValueMembers() throws {
        assertMacroExpansion(
            """
            @Statable(Profile.self)
            final class ProfileStore {
            }
            """,
            expandedSource: """

            final class ProfileStore {

                @ObservationIgnored
                private let _asyncValue = AsyncValue<Profile>()

                /// The value that can be shown right now; during a reload or after a failure it is the previous one.
                public var value: Profile? {
                    _asyncValue.value
                }

                /// The exclusive state behind every convenience property, exposed so a view can switch on it.
                public var state: AsyncState<Profile> {
                    _asyncValue.state
                }

                public var isLoading: Bool {
                    _asyncValue.isLoading
                }

                /// Whether a load is in flight with nothing to show yet — the only state in which a skeleton belongs.
                public var isInitialLoading: Bool {
                    _asyncValue.isInitialLoading
                }

                /// Whether a load is in flight while the previous value is still shown. Use it to avoid emptying the screen.
                public var isReloading: Bool {
                    _asyncValue.isReloading
                }

                public var isIdle: Bool {
                    _asyncValue.isIdle
                }

                public var isFailed: Bool {
                    _asyncValue.isFailed
                }

                /// Whether there is anything to show, including a value kept through a reload or a failure.
                public var hasValue: Bool {
                    _asyncValue.hasValue
                }

                /// Whether the last load finished successfully. A value left over from before a failure does not count.
                public var isLoaded: Bool {
                    _asyncValue.isLoaded
                }

                /// The error from the last load, or nil unless that load failed.
                public var error: StateError? {
                    _asyncValue.error
                }

                /// Stores a value directly, superseding a load that is still in flight.
                public func set(_ value: Profile) {
                    _asyncValue.set(value)
                }

                /// Records a failure while keeping the previous value, and supersedes a load that is still in flight.
                public func setError(_ error: StateError) {
                    _asyncValue.setError(error)
                }

                /// Marks a load as started, keeping the previous value so the screen stays filled.
                public func startLoading() {
                    _asyncValue.startLoading()
                }

                /// Drops the value and the error, and abandons a load that is still in flight.
                public func reset() {
                    _asyncValue.reset()
                }

                /// Runs an async operation and reflects its outcome; the last load started wins and cancellation is not a failure.
                public func load(_ operation: @Sendable () async throws -> Profile) async {
                    await _asyncValue.load(operation)
                }

                /// Loads only when no load has succeeded yet; a failure that left a previous value behind does not count as done.
                public func loadIfNeeded(_ operation: @Sendable () async throws -> Profile) async {
                    await _asyncValue.loadIfNeeded(operation)
                }
            }

            extension ProfileStore: Statable {
            }
            """,
            macros: testMacros
        )
    }

    func testStatablePreservesUserDefinedInit() throws {
        assertMacroExpansion(
            """
            @Statable(Profile.self)
            final class ProfileStore {
                public init() {}
            }
            """,
            expandedSource: """

            final class ProfileStore {
                public init() {}

                @ObservationIgnored
                private let _asyncValue = AsyncValue<Profile>()

                /// The value that can be shown right now; during a reload or after a failure it is the previous one.
                public var value: Profile? {
                    _asyncValue.value
                }

                /// The exclusive state behind every convenience property, exposed so a view can switch on it.
                public var state: AsyncState<Profile> {
                    _asyncValue.state
                }

                public var isLoading: Bool {
                    _asyncValue.isLoading
                }

                /// Whether a load is in flight with nothing to show yet — the only state in which a skeleton belongs.
                public var isInitialLoading: Bool {
                    _asyncValue.isInitialLoading
                }

                /// Whether a load is in flight while the previous value is still shown. Use it to avoid emptying the screen.
                public var isReloading: Bool {
                    _asyncValue.isReloading
                }

                public var isIdle: Bool {
                    _asyncValue.isIdle
                }

                public var isFailed: Bool {
                    _asyncValue.isFailed
                }

                /// Whether there is anything to show, including a value kept through a reload or a failure.
                public var hasValue: Bool {
                    _asyncValue.hasValue
                }

                /// Whether the last load finished successfully. A value left over from before a failure does not count.
                public var isLoaded: Bool {
                    _asyncValue.isLoaded
                }

                /// The error from the last load, or nil unless that load failed.
                public var error: StateError? {
                    _asyncValue.error
                }

                /// Stores a value directly, superseding a load that is still in flight.
                public func set(_ value: Profile) {
                    _asyncValue.set(value)
                }

                /// Records a failure while keeping the previous value, and supersedes a load that is still in flight.
                public func setError(_ error: StateError) {
                    _asyncValue.setError(error)
                }

                /// Marks a load as started, keeping the previous value so the screen stays filled.
                public func startLoading() {
                    _asyncValue.startLoading()
                }

                /// Drops the value and the error, and abandons a load that is still in flight.
                public func reset() {
                    _asyncValue.reset()
                }

                /// Runs an async operation and reflects its outcome; the last load started wins and cancellation is not a failure.
                public func load(_ operation: @Sendable () async throws -> Profile) async {
                    await _asyncValue.load(operation)
                }

                /// Loads only when no load has succeeded yet; a failure that left a previous value behind does not count as done.
                public func loadIfNeeded(_ operation: @Sendable () async throws -> Profile) async {
                    await _asyncValue.loadIfNeeded(operation)
                }
            }

            extension ProfileStore: Statable {
            }
            """,
            macros: testMacros
        )
    }

    func testStatableWithNestedType() throws {
        assertMacroExpansion(
            """
            @Statable(Module.Profile.self)
            final class ProfileStore {
            }
            """,
            expandedSource: """

            final class ProfileStore {

                @ObservationIgnored
                private let _asyncValue = AsyncValue<Module.Profile>()

                /// The value that can be shown right now; during a reload or after a failure it is the previous one.
                public var value: Module.Profile? {
                    _asyncValue.value
                }

                /// The exclusive state behind every convenience property, exposed so a view can switch on it.
                public var state: AsyncState<Module.Profile> {
                    _asyncValue.state
                }

                public var isLoading: Bool {
                    _asyncValue.isLoading
                }

                /// Whether a load is in flight with nothing to show yet — the only state in which a skeleton belongs.
                public var isInitialLoading: Bool {
                    _asyncValue.isInitialLoading
                }

                /// Whether a load is in flight while the previous value is still shown. Use it to avoid emptying the screen.
                public var isReloading: Bool {
                    _asyncValue.isReloading
                }

                public var isIdle: Bool {
                    _asyncValue.isIdle
                }

                public var isFailed: Bool {
                    _asyncValue.isFailed
                }

                /// Whether there is anything to show, including a value kept through a reload or a failure.
                public var hasValue: Bool {
                    _asyncValue.hasValue
                }

                /// Whether the last load finished successfully. A value left over from before a failure does not count.
                public var isLoaded: Bool {
                    _asyncValue.isLoaded
                }

                /// The error from the last load, or nil unless that load failed.
                public var error: StateError? {
                    _asyncValue.error
                }

                /// Stores a value directly, superseding a load that is still in flight.
                public func set(_ value: Module.Profile) {
                    _asyncValue.set(value)
                }

                /// Records a failure while keeping the previous value, and supersedes a load that is still in flight.
                public func setError(_ error: StateError) {
                    _asyncValue.setError(error)
                }

                /// Marks a load as started, keeping the previous value so the screen stays filled.
                public func startLoading() {
                    _asyncValue.startLoading()
                }

                /// Drops the value and the error, and abandons a load that is still in flight.
                public func reset() {
                    _asyncValue.reset()
                }

                /// Runs an async operation and reflects its outcome; the last load started wins and cancellation is not a failure.
                public func load(_ operation: @Sendable () async throws -> Module.Profile) async {
                    await _asyncValue.load(operation)
                }

                /// Loads only when no load has succeeded yet; a failure that left a previous value behind does not count as done.
                public func loadIfNeeded(_ operation: @Sendable () async throws -> Module.Profile) async {
                    await _asyncValue.loadIfNeeded(operation)
                }
            }

            extension ProfileStore: Statable {
            }
            """,
            macros: testMacros
        )
    }

    func testStatableWithOperations() throws {
        assertMacroExpansion(
            """
            @Statable([Activity].self, operations: Op.self)
            final class ActivityStore {
            }
            """,
            expandedSource: """

            final class ActivityStore {

                @ObservationIgnored
                private let _asyncValue = AsyncValue<[Activity]>()

                @ObservationIgnored
                private let _operations = OperationTracker<Op>()

                /// The value that can be shown right now; during a reload or after a failure it is the previous one.
                public var value: [Activity]? {
                    _asyncValue.value
                }

                /// The exclusive state behind every convenience property, exposed so a view can switch on it.
                public var state: AsyncState<[Activity]> {
                    _asyncValue.state
                }

                public var isLoading: Bool {
                    _asyncValue.isLoading
                }

                /// Whether a load is in flight with nothing to show yet — the only state in which a skeleton belongs.
                public var isInitialLoading: Bool {
                    _asyncValue.isInitialLoading
                }

                /// Whether a load is in flight while the previous value is still shown. Use it to avoid emptying the screen.
                public var isReloading: Bool {
                    _asyncValue.isReloading
                }

                public var isIdle: Bool {
                    _asyncValue.isIdle
                }

                public var isFailed: Bool {
                    _asyncValue.isFailed
                }

                /// Whether there is anything to show, including a value kept through a reload or a failure.
                public var hasValue: Bool {
                    _asyncValue.hasValue
                }

                /// Whether the last load finished successfully. A value left over from before a failure does not count.
                public var isLoaded: Bool {
                    _asyncValue.isLoaded
                }

                /// The error from the last load, or nil unless that load failed.
                public var error: StateError? {
                    _asyncValue.error
                }

                /// The running state and last error of each declared operation.
                public var operations: OperationTracker<Op> {
                    _operations
                }

                /// Stores a value directly, superseding a load that is still in flight.
                public func set(_ value: [Activity]) {
                    _asyncValue.set(value)
                }

                /// Records a failure while keeping the previous value, and supersedes a load that is still in flight.
                public func setError(_ error: StateError) {
                    _asyncValue.setError(error)
                }

                /// Marks a load as started, keeping the previous value so the screen stays filled.
                public func startLoading() {
                    _asyncValue.startLoading()
                }

                /// Drops the value and the error, and abandons a load that is still in flight.
                public func reset() {
                    _asyncValue.reset()
                }

                /// Runs an async operation and reflects its outcome; the last load started wins and cancellation is not a failure.
                public func load(_ operation: @Sendable () async throws -> [Activity]) async {
                    await _asyncValue.load(operation)
                }

                /// Loads only when no load has succeeded yet; a failure that left a previous value behind does not count as done.
                public func loadIfNeeded(_ operation: @Sendable () async throws -> [Activity]) async {
                    await _asyncValue.loadIfNeeded(operation)
                }
            }

            extension ActivityStore: Statable {
            }
            """,
            macros: testMacros
        )
    }
}

#else
final class StatableMacroTests: XCTestCase {
    func testMacrosNotAvailable() throws {
        XCTSkip("Macros are only supported when running tests for the host platform")
    }
}
#endif
