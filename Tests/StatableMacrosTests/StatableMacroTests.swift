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

                public init() {
                }

                /// 現在の値
                public var value: Profile? {
                    _asyncValue.value
                }

                /// 内部状態（switch用）
                public var state: AsyncState<Profile> {
                    _asyncValue.state
                }

                /// ロード中かどうか
                public var isLoading: Bool {
                    _asyncValue.isLoading
                }

                /// 初期状態かどうか
                public var isIdle: Bool {
                    _asyncValue.isIdle
                }

                /// 失敗状態かどうか
                public var isFailed: Bool {
                    _asyncValue.isFailed
                }

                /// 値が存在するか
                public var hasValue: Bool {
                    _asyncValue.hasValue
                }

                /// エラー（failed状態の場合のみ）
                public var error: StateError? {
                    _asyncValue.error
                }

                /// 値を設定（loaded状態に遷移）
                public func set(_ value: Profile) {
                    _asyncValue.set(value)
                }

                /// エラーを設定（failed状態に遷移）
                public func setError(_ error: StateError) {
                    _asyncValue.setError(error)
                }

                /// ロード開始（loading状態に遷移）
                public func startLoading() {
                    _asyncValue.startLoading()
                }

                /// 初期状態にリセット
                public func reset() {
                    _asyncValue.reset()
                }

                /// 非同期操作を実行し、結果を状態に反映
                public func load(_ operation: @Sendable () async throws -> Profile) async {
                    await _asyncValue.load(operation)
                }

                /// 条件付きでロード（値が存在しない場合のみ）
                public func loadIfNeeded(_ operation: @Sendable () async throws -> Profile) async {
                    await _asyncValue.loadIfNeeded(operation)
                }

                /// 強制リロード
                public func reload(_ operation: @Sendable () async throws -> Profile) async {
                    await _asyncValue.reload(operation)
                }
            }

            extension ProfileStore: Statable {
            }
            """,
            macros: testMacros
        )
    }

    func testStatableDoesNotGenerateInitIfExists() throws {
        assertMacroExpansion(
            """
            @Statable(Profile.self)
            final class ProfileStore {
                init() {
                    print("custom init")
                }
            }
            """,
            expandedSource: """

            final class ProfileStore {
                init() {
                    print("custom init")
                }

                @ObservationIgnored
                private let _asyncValue = AsyncValue<Profile>()

                /// 現在の値
                public var value: Profile? {
                    _asyncValue.value
                }

                /// 内部状態（switch用）
                public var state: AsyncState<Profile> {
                    _asyncValue.state
                }

                /// ロード中かどうか
                public var isLoading: Bool {
                    _asyncValue.isLoading
                }

                /// 初期状態かどうか
                public var isIdle: Bool {
                    _asyncValue.isIdle
                }

                /// 失敗状態かどうか
                public var isFailed: Bool {
                    _asyncValue.isFailed
                }

                /// 値が存在するか
                public var hasValue: Bool {
                    _asyncValue.hasValue
                }

                /// エラー（failed状態の場合のみ）
                public var error: StateError? {
                    _asyncValue.error
                }

                /// 値を設定（loaded状態に遷移）
                public func set(_ value: Profile) {
                    _asyncValue.set(value)
                }

                /// エラーを設定（failed状態に遷移）
                public func setError(_ error: StateError) {
                    _asyncValue.setError(error)
                }

                /// ロード開始（loading状態に遷移）
                public func startLoading() {
                    _asyncValue.startLoading()
                }

                /// 初期状態にリセット
                public func reset() {
                    _asyncValue.reset()
                }

                /// 非同期操作を実行し、結果を状態に反映
                public func load(_ operation: @Sendable () async throws -> Profile) async {
                    await _asyncValue.load(operation)
                }

                /// 条件付きでロード（値が存在しない場合のみ）
                public func loadIfNeeded(_ operation: @Sendable () async throws -> Profile) async {
                    await _asyncValue.loadIfNeeded(operation)
                }

                /// 強制リロード
                public func reload(_ operation: @Sendable () async throws -> Profile) async {
                    await _asyncValue.reload(operation)
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

                public init() {
                }

                /// 現在の値
                public var value: Module.Profile? {
                    _asyncValue.value
                }

                /// 内部状態（switch用）
                public var state: AsyncState<Module.Profile> {
                    _asyncValue.state
                }

                /// ロード中かどうか
                public var isLoading: Bool {
                    _asyncValue.isLoading
                }

                /// 初期状態かどうか
                public var isIdle: Bool {
                    _asyncValue.isIdle
                }

                /// 失敗状態かどうか
                public var isFailed: Bool {
                    _asyncValue.isFailed
                }

                /// 値が存在するか
                public var hasValue: Bool {
                    _asyncValue.hasValue
                }

                /// エラー（failed状態の場合のみ）
                public var error: StateError? {
                    _asyncValue.error
                }

                /// 値を設定（loaded状態に遷移）
                public func set(_ value: Module.Profile) {
                    _asyncValue.set(value)
                }

                /// エラーを設定（failed状態に遷移）
                public func setError(_ error: StateError) {
                    _asyncValue.setError(error)
                }

                /// ロード開始（loading状態に遷移）
                public func startLoading() {
                    _asyncValue.startLoading()
                }

                /// 初期状態にリセット
                public func reset() {
                    _asyncValue.reset()
                }

                /// 非同期操作を実行し、結果を状態に反映
                public func load(_ operation: @Sendable () async throws -> Module.Profile) async {
                    await _asyncValue.load(operation)
                }

                /// 条件付きでロード（値が存在しない場合のみ）
                public func loadIfNeeded(_ operation: @Sendable () async throws -> Module.Profile) async {
                    await _asyncValue.loadIfNeeded(operation)
                }

                /// 強制リロード
                public func reload(_ operation: @Sendable () async throws -> Module.Profile) async {
                    await _asyncValue.reload(operation)
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

                public init() {
                }

                /// 現在の値
                public var value: [Activity]? {
                    _asyncValue.value
                }

                /// 内部状態（switch用）
                public var state: AsyncState<[Activity]> {
                    _asyncValue.state
                }

                /// ロード中かどうか
                public var isLoading: Bool {
                    _asyncValue.isLoading
                }

                /// 初期状態かどうか
                public var isIdle: Bool {
                    _asyncValue.isIdle
                }

                /// 失敗状態かどうか
                public var isFailed: Bool {
                    _asyncValue.isFailed
                }

                /// 値が存在するか
                public var hasValue: Bool {
                    _asyncValue.hasValue
                }

                /// エラー（failed状態の場合のみ）
                public var error: StateError? {
                    _asyncValue.error
                }

                /// 操作トラッカー
                public var operations: OperationTracker<Op> {
                    _operations
                }

                /// 値を設定（loaded状態に遷移）
                public func set(_ value: [Activity]) {
                    _asyncValue.set(value)
                }

                /// エラーを設定（failed状態に遷移）
                public func setError(_ error: StateError) {
                    _asyncValue.setError(error)
                }

                /// ロード開始（loading状態に遷移）
                public func startLoading() {
                    _asyncValue.startLoading()
                }

                /// 初期状態にリセット
                public func reset() {
                    _asyncValue.reset()
                }

                /// 非同期操作を実行し、結果を状態に反映
                public func load(_ operation: @Sendable () async throws -> [Activity]) async {
                    await _asyncValue.load(operation)
                }

                /// 条件付きでロード（値が存在しない場合のみ）
                public func loadIfNeeded(_ operation: @Sendable () async throws -> [Activity]) async {
                    await _asyncValue.loadIfNeeded(operation)
                }

                /// 強制リロード
                public func reload(_ operation: @Sendable () async throws -> [Activity]) async {
                    await _asyncValue.reload(operation)
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
