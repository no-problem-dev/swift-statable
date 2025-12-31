// MARK: - @Statable Macro

/// 単一の非同期状態を管理するストアクラスを定義するマクロ
///
/// クラスに AsyncValue のラッパー機能を自動生成し、
/// `Statable`, `Sendable` プロトコルへの準拠を追加します。
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
/// - `value: T?` - 現在の値
/// - `state: AsyncState<T>` - 状態（switch用）
/// - `isLoading: Bool` - ローディング中か
/// - `hasValue: Bool` - 値が存在するか
/// - `error: StateError?` - エラー
/// - `set(_:)` - 値を設定
/// - `setError(_:)` - エラーを設定
/// - `startLoading()` - ローディング開始
/// - `reset()` - 初期状態にリセット
/// - `load(_:)` - 非同期操作を実行
/// - `loadIfNeeded(_:)` - 値がない場合のみロード
/// - `reload(_:)` - 強制リロード
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
/// // 状態でswitch
/// switch store.state {
/// case .idle:
///     Text("未取得")
/// case .loading(let prev):
///     ProgressView()
/// case .loaded(let profile):
///     ProfileView(profile: profile)
/// case .failed(let error):
///     ErrorView(error: error)
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
@attached(member, names: named(_asyncValue), named(_operations), named(value), named(state), named(isLoading), named(isIdle), named(isFailed), named(hasValue), named(error), named(operations), named(set), named(setError), named(startLoading), named(reset), named(load), named(loadIfNeeded), named(reload))
@attached(extension, conformances: Statable, Sendable)
public macro Statable<T: Sendable>(
    _ valueType: T.Type
) = #externalMacro(module: "StatableMacros", type: "StatableMacro")

/// 操作トラッキング付きの@Statable
@attached(member, names: named(_asyncValue), named(_operations), named(value), named(state), named(isLoading), named(isIdle), named(isFailed), named(hasValue), named(error), named(operations), named(set), named(setError), named(startLoading), named(reset), named(load), named(loadIfNeeded), named(reload))
@attached(extension, conformances: Statable, Sendable)
public macro Statable<T: Sendable, Op: Hashable & Sendable>(
    _ valueType: T.Type,
    operations operationType: Op.Type
) = #externalMacro(module: "StatableMacros", type: "StatableMacro")
