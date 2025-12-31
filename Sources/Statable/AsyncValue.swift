import Observation

/// 非同期でロードされる値を管理する@Observableなラッパー
///
/// `AsyncState` を内部で保持し、状態遷移メソッドと便利なアクセサを提供します。
/// SwiftUIのビューから直接観察可能で、状態変更時に自動的に再描画されます。
///
/// ## 使用例
///
/// ```swift
/// @Statable
/// final class ProfileStore {
///     @Async var profile: MetabolicProfile?
/// }
///
/// // View側
/// switch store.profile.state {
/// case .loaded(let profile):
///     ProfileView(profile: profile)
/// // ...
/// }
///
/// // 操作
/// store.profile.set(newProfile)
/// store.profile.startLoading()
/// ```
/// @MainActor で保護される前提のため @unchecked Sendable
@Observable
public final class AsyncValue<Value: Sendable>: @unchecked Sendable {
    // MARK: - State

    /// 内部の状態（switch用に公開）
    public private(set) var state: AsyncState<Value>

    // MARK: - Initialization

    /// 初期状態で作成
    public init() {
        self.state = .idle
    }

    /// 初期値を指定して作成
    /// - Parameter initialValue: 初期値（loaded状態で開始）
    public init(initialValue: Value) {
        self.state = .loaded(initialValue)
    }

    /// 指定した状態で作成
    /// - Parameter state: 初期状態
    public init(state: AsyncState<Value>) {
        self.state = state
    }

    // MARK: - Computed Properties

    /// 現在の値（loaded または loading の previous）
    public var value: Value? {
        state.value
    }

    /// ロード中かどうか
    public var isLoading: Bool {
        state.isLoading
    }

    /// エラー（failed状態の場合のみ）
    public var error: StateError? {
        state.error
    }

    /// 値が存在するか（loaded状態）
    public var hasValue: Bool {
        state.hasValue
    }

    /// 初期状態かどうか
    public var isIdle: Bool {
        state.isIdle
    }

    /// 失敗状態かどうか
    public var isFailed: Bool {
        state.isFailed
    }

    // MARK: - State Transitions

    /// 値を設定（loaded状態に遷移）
    /// - Parameter value: 設定する値
    public func set(_ value: Value) {
        state = .loaded(value)
    }

    /// エラーを設定（failed状態に遷移）
    /// - Parameter error: 発生したエラー
    public func setError(_ error: StateError) {
        state = .failed(error)
    }

    /// 標準のErrorからStateErrorに変換して設定
    /// - Parameter error: 発生したエラー
    public func setError(from error: Error) {
        state = .failed(StateError(from: error))
    }

    /// ロード開始（loading状態に遷移）
    ///
    /// 前回の値がある場合は `loading(previous:)` として保持され、
    /// ローディング中も前回の値を表示するUXが可能になります。
    public func startLoading() {
        state.startLoading()
    }

    /// 初期状態にリセット
    public func reset() {
        state.reset()
    }

    // MARK: - Convenience Methods

    /// 非同期操作を実行し、結果を状態に反映
    ///
    /// ローディング開始、成功/失敗の状態遷移を自動的に処理します。
    ///
    /// ```swift
    /// await store.profile.load {
    ///     try await api.fetchProfile()
    /// }
    /// ```
    ///
    /// - Parameter operation: 実行する非同期操作
    public func load(_ operation: @Sendable () async throws -> Value) async {
        startLoading()
        do {
            let value = try await operation()
            set(value)
        } catch {
            setError(from: error)
        }
    }

    /// 条件付きでロード（値が存在しない場合のみ）
    ///
    /// ```swift
    /// await store.profile.loadIfNeeded {
    ///     try await api.fetchProfile()
    /// }
    /// ```
    ///
    /// - Parameter operation: 実行する非同期操作
    public func loadIfNeeded(_ operation: @Sendable () async throws -> Value) async {
        guard !hasValue else { return }
        await load(operation)
    }

    /// 強制リロード（loading中でも実行）
    ///
    /// - Parameter operation: 実行する非同期操作
    public func reload(_ operation: @Sendable () async throws -> Value) async {
        await load(operation)
    }
}

// MARK: - Equatable

extension AsyncValue: Equatable where Value: Equatable {
    public static func == (lhs: AsyncValue<Value>, rhs: AsyncValue<Value>) -> Bool {
        lhs.state == rhs.state
    }
}

// MARK: - CustomStringConvertible

extension AsyncValue: CustomStringConvertible {
    public var description: String {
        switch state {
        case .idle:
            "AsyncValue(.idle)"
        case .loading(let previous):
            "AsyncValue(.loading(previous: \(String(describing: previous))))"
        case .loaded(let value):
            "AsyncValue(.loaded(\(value)))"
        case .failed(let error):
            "AsyncValue(.failed(\(error)))"
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension AsyncValue: CustomDebugStringConvertible {
    public var debugDescription: String {
        "AsyncValue<\(Value.self)>(state: \(state))"
    }
}
