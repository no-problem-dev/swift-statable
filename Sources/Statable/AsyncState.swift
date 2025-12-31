/// 非同期でロードされる値の状態を排他的に表現するenum
///
/// Single Source of Truth (SSOT) 原則に基づき、
/// 1つのenumで全ての状態を排他的に表現します。
///
/// ## 使用例
///
/// ```swift
/// switch store.profile.state {
/// case .idle:
///     Text("データ未取得")
/// case .loading(let previous):
///     ProgressView()
/// case .loaded(let profile):
///     ProfileView(profile: profile)
/// case .failed(let error):
///     ErrorView(error: error)
/// }
/// ```
public enum AsyncState<Value: Sendable>: Sendable {
    /// 初期状態（まだロードされていない）
    case idle

    /// ロード中
    /// - Parameter previous: 前回ロードされた値（再ロード時のUX向上用）
    case loading(previous: Value?)

    /// ロード成功
    /// - Parameter value: ロードされた値
    case loaded(Value)

    /// ロード失敗
    /// - Parameter error: 発生したエラー
    case failed(StateError)
}

// MARK: - Computed Properties

extension AsyncState {
    /// 現在の値を取得
    ///
    /// - `loaded` の場合: ロードされた値
    /// - `loading` の場合: 前回の値（あれば）
    /// - その他: nil
    public var value: Value? {
        switch self {
        case .idle:
            nil
        case .loading(let previous):
            previous
        case .loaded(let value):
            value
        case .failed:
            nil
        }
    }

    /// ロード中かどうか
    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// エラーを取得（failed状態の場合のみ）
    public var error: StateError? {
        if case .failed(let error) = self {
            return error
        }
        return nil
    }

    /// 値が存在するか（loaded状態）
    public var hasValue: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }

    /// 初期状態かどうか
    public var isIdle: Bool {
        if case .idle = self {
            return true
        }
        return false
    }

    /// 失敗状態かどうか
    public var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

// MARK: - State Transitions

extension AsyncState {
    /// ロード開始（前回の値を保持してUX向上）
    public mutating func startLoading() {
        self = .loading(previous: value)
    }

    /// ロード成功
    /// - Parameter value: ロードされた値
    public mutating func succeed(with value: Value) {
        self = .loaded(value)
    }

    /// ロード失敗
    /// - Parameter error: 発生したエラー
    public mutating func fail(with error: StateError) {
        self = .failed(error)
    }

    /// 初期状態にリセット
    public mutating func reset() {
        self = .idle
    }
}

// MARK: - Equatable

extension AsyncState: Equatable where Value: Equatable {}

// MARK: - Hashable

extension AsyncState: Hashable where Value: Hashable {}
