/// 非同期でロードされる値の状態。1つの enum が全てを排他的に表す（SSOT）。
///
/// **`loading` も `failed` も、前の値を持ったまま遷移する。**
/// 読み直しや失敗のたびに前の値を捨てると、画面は「さっきまで読めていたもの」まで失う。
/// 捨てるかどうかは画面が決めることで、状態が先に決めてしまうと画面には選択肢が残らない。
///
/// ## 画面はこの 3 つで出し分ける
///
/// ```swift
/// if let value = store.value {
///     Content(value)                       // 読み直し中も、失敗した後も、前の答えを出す
///     if let error = store.error { Banner(error) }   // 失敗は画面を奪わず帯で言う
/// } else if let error = store.error {
///     FailureFace(error)                   // 見せるものが無いときだけ画面を奪う
/// } else {
///     Skeleton()                           // まだ一度も答えを持っていない
/// }
/// ```
///
/// **`isLoading` だけを見て描かないこと。** 読み込み中かどうかは「画面を空にする理由」にならない。
public enum AsyncState<Value: Sendable>: Sendable {
    /// 初期状態（まだ何も頼まれていない）
    case idle

    /// ロード中
    /// - Parameter previous: 直前まで見せていた値（あれば）
    case loading(previous: Value?)

    /// ロード成功
    /// - Parameter value: ロードされた値
    case loaded(Value)

    /// ロード失敗
    /// - Parameters:
    ///   - error: 発生したエラー
    ///   - previous: 直前まで見せていた値（あれば）。**失敗しても捨てない**
    case failed(StateError, previous: Value?)
}

// MARK: - Computed Properties

extension AsyncState {
    /// いま見せられる値。**どの状態でも「見せるものがあるか」はこれ 1 つで判断する。**
    ///
    /// 空の配列も辞書も立派な値（「無い」という答え）なので、
    /// 呼ぶ側が `value?.isEmpty` を「値が無い」と読み替えてはいけない
    /// —— 読み替えると、0 件の利用者だけが読み直しのたびに骨組みを見ることになる。
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

    /// ロード中かどうか
    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// まだ一度も答えを持たないままのロード中か。
    ///
    /// 骨組み（skeleton）を出してよいのはここが true のときだけ。
    public var isInitialLoading: Bool {
        if case .loading(let previous) = self {
            return previous == nil
        }
        return false
    }

    /// 前の答えを持ったままのロード中か（読み直し）。
    ///
    /// **画面を空にしない。** 前の答えを出したまま静かに差し替える。
    public var isReloading: Bool {
        if case .loading(let previous) = self {
            return previous != nil
        }
        return false
    }

    /// エラーを取得（failed状態の場合のみ）
    public var error: StateError? {
        if case .failed(let error, _) = self {
            return error
        }
        return nil
    }

    /// 見せられる値があるか（`value != nil` と同じ）
    public var hasValue: Bool {
        value != nil
    }

    /// 最後のロードが成功して終わっているか（`loaded` そのもの）。
    ///
    /// `hasValue` と違い、失敗して前の値だけが残っている状態は含まない
    /// —— `loadIfNeeded` が「もう読まなくていい」と判断してよいのはこちら。
    public var isLoaded: Bool {
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
    /// ロード開始（前の値を持ったまま遷移する）
    public mutating func startLoading() {
        self = .loading(previous: value)
    }

    /// ロード成功
    /// - Parameter value: ロードされた値
    public mutating func succeed(with value: Value) {
        self = .loaded(value)
    }

    /// ロード失敗（前の値を持ったまま遷移する）
    /// - Parameter error: 発生したエラー
    public mutating func fail(with error: StateError) {
        self = .failed(error, previous: value)
    }

    /// 取り消された。**失敗にはしない。**
    ///
    /// 画面を離れた・入力し直したなどで読み込みをやめただけなので、人に見せる失敗ではない。
    /// 前の答えがあれば戻し、無ければ初期状態へ戻す
    /// —— ここで何もしないと `loading` のまま取り残され、回りっぱなしの表示になる。
    public mutating func cancelLoading() {
        self = value.map { .loaded($0) } ?? .idle
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
