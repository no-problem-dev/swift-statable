// MARK: - @Statable Macro

/// 単一の非同期状態を管理するストアクラスを定義するマクロ
///
/// クラスに AsyncValue のラッパー機能を自動生成し、
/// `Statable`, `Sendable` プロトコルへの準拠を追加する。
///
/// ## 基本的な使い方
///
/// ```swift
/// @Statable(MetabolicProfile.self)
/// @MainActor @Observable
/// final class ProfileStore {
///     // カスタム computed properties
///     var currentAge: Int { value?.age() ?? 0 }
/// }
/// ```
///
/// ## 操作トラッキング付きの使い方
///
/// ```swift
/// enum WorkoutOperation: String, CaseIterable, Sendable {
///     case fetch, record, delete
/// }
///
/// @Statable([WorkoutActivity].self, operations: WorkoutOperation.self)
/// @MainActor @Observable
/// final class WorkoutStore {
///     // operations.isActive(.fetch), operations.run(.record) { ... } などが使える
/// }
/// ```
///
/// ## 生成されるメンバー
///
/// ### AsyncValue関連
/// - `value: T?` - いま見せられる値（読み直し中・失敗後も前の値が残る）
/// - `state: AsyncState<T>` - 状態（switch用）
/// - `isLoading: Bool` - ローディング中か
/// - `isInitialLoading: Bool` - まだ一度も答えを持たないままのロード中か（骨組みを出す唯一の状態）
/// - `isReloading: Bool` - 前の答えを持ったままのロード中か（画面を空にしない）
/// - `hasValue: Bool` - 見せられる値があるか
/// - `isLoaded: Bool` - 最後のロードが成功して終わっているか
/// - `error: StateError?` - エラー
/// - `set(_:)` - 値を設定
/// - `setError(_:)` - エラーを設定
/// - `startLoading()` - ローディング開始
/// - `reset()` - 初期状態にリセット
/// - `load(_:)` - 非同期操作を実行（重なりは後勝ち・取り消しは失敗にしない）
/// - `loadIfNeeded(_:)` - まだ一度も成功していないときだけロード
///
/// ### OperationTracker関連（operations引数指定時のみ）
/// - `operations: OperationTracker<Op>` - トラッカーインスタンス
///
/// ## View側での使用
///
/// ```swift
/// // 値へのアクセス
/// if let profile = store.value {
///     Text(profile.name)
/// }
///
/// // 画面は 3 つの顔で出し分ける（`isLoading` だけを見て描かない）
/// if let profile = store.value {
///     ProfileView(profile: profile)
///     if let error = store.error { Banner(error) }
/// } else if let error = store.error {
///     FailureFace(error)
/// } else {
///     Skeleton()
/// }
///
/// // 操作（operations付きの場合）
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

/// 操作トラッキング付きの `@Statable`
///
/// `operations:` に `Hashable & Sendable` な列挙型を渡すと、
/// `OperationTracker<Op>` インスタンスが `operations` プロパティとして生成される。
/// `operations.run(.fetch) { ... }` で操作ごとの実行状態を自動追跡できる。
///
/// - SeeAlso: ``Statable(_:)``
@attached(member, names: named(_asyncValue), named(_operations), named(value), named(state), named(isLoading), named(isIdle), named(isFailed), named(isInitialLoading), named(isReloading), named(hasValue), named(isLoaded), named(error), named(operations), named(set), named(setError), named(startLoading), named(reset), named(load), named(loadIfNeeded))
@attached(extension, conformances: Statable, Sendable)
public macro Statable<T: Sendable, Op: Hashable & Sendable>(
    _ valueType: T.Type,
    operations operationType: Op.Type
) = #externalMacro(module: "StatableMacros", type: "StatableMacro")

// MARK: - @Track Macro

/// ストアに独立した操作トラッカーを追加するマクロ
///
/// `@Statable` クラスの変数宣言に適用することで、`OperationTracker<Op>` の
/// ストレージと getter を自動生成する。
///
/// ## 基本的な使い方
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
/// // 使用側
/// if store.operations.isActive(.fetch) {
///     ProgressView()
/// }
/// await store.operations.run(.fetch) {
///     try await api.fetchProfile()
/// }
/// ```
///
/// ## 生成されるメンバー
///
/// - `private let _<name> = OperationTracker<Op>()` — 内部ストレージ
/// - `var <name>: OperationTracker<Op> { get }` — 読み取り専用アクセサ
@attached(accessor, names: named(get))
@attached(peer, names: prefixed(_))
public macro Track<Op: Hashable & Sendable>(
    _ operationType: Op.Type
) = #externalMacro(module: "StatableMacros", type: "TrackMacro")
