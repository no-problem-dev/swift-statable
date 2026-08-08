import Observation

/// 非同期でロードされる値を持つ、観測可能な容器。**メインアクターの上でだけ生きる。**
///
/// ## なぜ `@MainActor` なのか
///
/// これは画面の状態そのもので、SwiftUI はメインアクターで読む。書き換えが別のスレッドから来ると、
/// Observation の無効化通知もそのスレッドから飛ぶので、SwiftUI が取りこぼすことがある。
/// **取りこぼすと画面は最後に描いた状態のまま止まる**（「読み込み中が消えない」として現れる）。
///
/// 1.x では `@unchecked Sendable` に「`@MainActor` で保護される前提」と注記していたが、
/// `load(_:)` が `nonisolated` な `async` 関数だったので、`@MainActor` のストアから呼んでも
/// 呼んだ瞬間に汎用エグゼキュータへ移り、`startLoading()` も `set()` もそこで走っていた
/// （`AsyncValueIsolationTests` が実測で押さえている）。**前提は注記ではなく宣言で守る。**
///
/// 通信そのものは外へ出る —— `operation` は `@Sendable` なので、メインアクターを塞がない。
/// メインに留まるのは状態の書き換えだけ。
///
/// ## 使用例
///
/// ```swift
/// @Statable(UserProfile.self)
/// @MainActor @Observable
/// final class ProfileStore {
///     func load() async {
///         await load { try await api.fetchProfile() }
///     }
/// }
/// ```
@MainActor
@Observable
public final class AsyncValue<Value: Sendable> {
    // MARK: - State

    /// 内部の状態（switch用に公開）
    public private(set) var state: AsyncState<Value>

    /// いま状態を書き戻してよい呼び出しの番号。
    ///
    /// **後から始まった方が勝つ。** 同じ値へのロードが重なると、遅く始まった 1 本ではなく
    /// 遅く終わった 1 本が勝ってしまい、新しい成功を古い失敗が塗り潰すことがある。
    /// 開始した順に番号を振り、書き戻す前にまだ自分の番号かを確かめる。
    ///
    /// `set` / `setError` / `reset` / `startLoading` も番号を進める
    /// —— 明示的に置かれた値は、走っている途中のロードより新しい情報だから。
    private var generation: UInt64 = 0

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

    /// いま見せられる値（`loading` / `failed` のときは直前の値）
    public var value: Value? { state.value }

    /// ロード中かどうか
    public var isLoading: Bool { state.isLoading }

    /// まだ一度も答えを持たないままのロード中か（骨組みを出してよい唯一の状態）
    public var isInitialLoading: Bool { state.isInitialLoading }

    /// 前の答えを持ったままのロード中か（画面を空にしない）
    public var isReloading: Bool { state.isReloading }

    /// エラー（failed状態の場合のみ）
    public var error: StateError? { state.error }

    /// 見せられる値があるか
    public var hasValue: Bool { state.hasValue }

    /// 最後のロードが成功して終わっているか
    public var isLoaded: Bool { state.isLoaded }

    /// 初期状態かどうか
    public var isIdle: Bool { state.isIdle }

    /// 失敗状態かどうか
    public var isFailed: Bool { state.isFailed }

    // MARK: - State Transitions

    /// 値を設定（loaded状態に遷移）
    /// - Parameter value: 設定する値
    public func set(_ value: Value) {
        claim()
        state = .loaded(value)
    }

    /// エラーを設定（failed状態に遷移・前の値は保つ）
    /// - Parameter error: 発生したエラー
    public func setError(_ error: StateError) {
        claim()
        state.fail(with: error)
    }

    /// 標準のErrorからStateErrorに変換して設定
    /// - Parameter error: 発生したエラー
    public func setError(from error: Error) {
        setError(StateError(from: error))
    }

    /// ロード開始（loading状態に遷移・前の値は保つ）
    public func startLoading() {
        claim()
        state.startLoading()
    }

    /// 初期状態にリセット
    public func reset() {
        claim()
        state.reset()
    }

    // MARK: - Convenience Methods

    /// 非同期操作を実行し、結果を状態に反映する。
    ///
    /// ロード開始・成功・失敗・取り消しの遷移をここが引き受ける。
    ///
    /// - 重なったロードは**後から始まった方が勝つ**（古い方は結果を捨てて黙って抜ける）
    /// - 取り消し（`Task` のキャンセル）は失敗にしない。前の答えへ戻す
    ///
    /// ```swift
    /// await store.profile.load {
    ///     try await api.fetchProfile()
    /// }
    /// ```
    ///
    /// - Parameter operation: 実行する非同期操作
    public func load(_ operation: @Sendable () async throws -> Value) async {
        let token = claim()
        state.startLoading()
        do {
            let value = try await operation()
            guard token == generation else { return }
            state = .loaded(value)
        } catch {
            guard token == generation else { return }
            // やめただけのものを失敗として見せない。**同時に、取り消しで `loading` に
            // 取り残されるのも防ぐ**（画面を離れて戻ると回りっぱなし、の正体）。
            // URLSession は取り消しを `URLError(.cancelled)` で返すので、
            // 投げられた型ではなくタスクの現在地で判断する。
            if Task.isCancelled || error is CancellationError {
                state.cancelLoading()
            } else {
                state.fail(with: StateError(from: error))
            }
        }
    }

    /// まだ一度も成功していないときだけロードする。
    ///
    /// 失敗して前の値だけが残っている状態は「済んでいる」に数えない（もう一度読みに行く）。
    ///
    /// - Parameter operation: 実行する非同期操作
    public func loadIfNeeded(_ operation: @Sendable () async throws -> Value) async {
        guard !isLoaded else { return }
        await load(operation)
    }

    /// 状態を書き戻す権利を取り、その番号を返す。
    @discardableResult
    private func claim() -> UInt64 {
        generation &+= 1
        return generation
    }
}
