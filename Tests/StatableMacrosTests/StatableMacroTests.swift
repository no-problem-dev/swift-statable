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

                /// まだ一度も答えを持たないままのロード中か（骨組みを出してよい唯一の状態）
                public var isInitialLoading: Bool {
                    _asyncValue.isInitialLoading
                }

                /// 前の答えを持ったままのロード中か（画面を空にしない）
                public var isReloading: Bool {
                    _asyncValue.isReloading
                }

                /// 初期状態かどうか
                public var isIdle: Bool {
                    _asyncValue.isIdle
                }

                /// 失敗状態かどうか
                public var isFailed: Bool {
                    _asyncValue.isFailed
                }

                /// 見せられる値があるか（`loading` / `failed` でも前の値があれば true）
                public var hasValue: Bool {
                    _asyncValue.hasValue
                }

                /// 最後のロードが成功して終わっているか
                public var isLoaded: Bool {
                    _asyncValue.isLoaded
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

                /// まだ一度も成功していないときだけロード
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

                /// まだ一度も答えを持たないままのロード中か（骨組みを出してよい唯一の状態）
                public var isInitialLoading: Bool {
                    _asyncValue.isInitialLoading
                }

                /// 前の答えを持ったままのロード中か（画面を空にしない）
                public var isReloading: Bool {
                    _asyncValue.isReloading
                }

                /// 初期状態かどうか
                public var isIdle: Bool {
                    _asyncValue.isIdle
                }

                /// 失敗状態かどうか
                public var isFailed: Bool {
                    _asyncValue.isFailed
                }

                /// 見せられる値があるか（`loading` / `failed` でも前の値があれば true）
                public var hasValue: Bool {
                    _asyncValue.hasValue
                }

                /// 最後のロードが成功して終わっているか
                public var isLoaded: Bool {
                    _asyncValue.isLoaded
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

                /// まだ一度も成功していないときだけロード
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

                /// まだ一度も答えを持たないままのロード中か（骨組みを出してよい唯一の状態）
                public var isInitialLoading: Bool {
                    _asyncValue.isInitialLoading
                }

                /// 前の答えを持ったままのロード中か（画面を空にしない）
                public var isReloading: Bool {
                    _asyncValue.isReloading
                }

                /// 初期状態かどうか
                public var isIdle: Bool {
                    _asyncValue.isIdle
                }

                /// 失敗状態かどうか
                public var isFailed: Bool {
                    _asyncValue.isFailed
                }

                /// 見せられる値があるか（`loading` / `failed` でも前の値があれば true）
                public var hasValue: Bool {
                    _asyncValue.hasValue
                }

                /// 最後のロードが成功して終わっているか
                public var isLoaded: Bool {
                    _asyncValue.isLoaded
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

                /// まだ一度も成功していないときだけロード
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

                /// まだ一度も答えを持たないままのロード中か（骨組みを出してよい唯一の状態）
                public var isInitialLoading: Bool {
                    _asyncValue.isInitialLoading
                }

                /// 前の答えを持ったままのロード中か（画面を空にしない）
                public var isReloading: Bool {
                    _asyncValue.isReloading
                }

                /// 初期状態かどうか
                public var isIdle: Bool {
                    _asyncValue.isIdle
                }

                /// 失敗状態かどうか
                public var isFailed: Bool {
                    _asyncValue.isFailed
                }

                /// 見せられる値があるか（`loading` / `failed` でも前の値があれば true）
                public var hasValue: Bool {
                    _asyncValue.hasValue
                }

                /// 最後のロードが成功して終わっているか
                public var isLoaded: Bool {
                    _asyncValue.isLoaded
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

                /// まだ一度も成功していないときだけロード
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
