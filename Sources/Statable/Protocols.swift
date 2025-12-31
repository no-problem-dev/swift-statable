import Observation

// MARK: - Statable

/// 状態コンテナとして振る舞うための基本プロトコル
///
/// `@Statable` マクロを適用したクラスは自動的にこのプロトコルに準拠します。
///
/// ## 準拠による保証
///
/// - `@MainActor` または指定されたアクターで保護される
/// - `@Observable` として動作する
/// - `Sendable` に準拠する
///
/// ## 使用例
///
/// ```swift
/// @Statable
/// final class ProfileStore {
///     @Async var profile: MetabolicProfile?
/// }
/// // ProfileStore は自動的に Statable に準拠
/// ```
public protocol Statable: AnyObject, Observable, Sendable {}

// MARK: - AsyncStateProvider

/// 非同期状態を持つストアのプロトコル
///
/// `@Async` プロパティを1つ以上持つ `@Statable` クラスは
/// 自動的にこのプロトコルに準拠します。
///
/// ## 提供される機能
///
/// - 全ての `@Async` プロパティのローディング状態を集約
/// - 最初のエラーへのアクセス
/// - 一括エラークリア
///
/// ## 使用例
///
/// ```swift
/// @Statable
/// final class MetricsStore {
///     @Async var daily: DailyMetrics?
///     @Async var projections: [Projection] = []
/// }
///
/// // いずれかがローディング中か確認
/// if store.isLoading {
///     ProgressView()
/// }
/// ```
public protocol AsyncStateProvider: Statable {
    /// いずれかの非同期状態がロード中かどうか
    var isLoading: Bool { get }

    /// 最初に発生したエラー（存在する場合）
    var firstError: StateError? { get }

    /// 全てのエラーをクリア
    func clearErrors()
}

// MARK: - OperationTrackable

/// 複数の操作を追跡するストアのプロトコル
///
/// `@Track` プロパティを持つ `@Statable` クラスは
/// 自動的にこのプロトコルに準拠します。
///
/// ## 使用例
///
/// ```swift
/// @Statable
/// final class WorkoutStore {
///     enum Operation: Hashable, Sendable {
///         case fetch
///         case record
///     }
///
///     @Track(Operation.self) var operations
/// }
///
/// if store.hasActiveOperations {
///     // いずれかの操作が実行中
/// }
/// ```
public protocol OperationTrackable: Statable {
    /// 操作の型
    associatedtype Operation: Hashable & Sendable

    /// 特定の操作が実行中かどうか
    func isOperationActive(_ operation: Operation) -> Bool

    /// いずれかの操作が実行中かどうか
    var hasActiveOperations: Bool { get }

    /// 特定の操作のエラーを取得
    func operationError(_ operation: Operation) -> StateError?
}

// MARK: - ActorIsolation

/// マクロで指定可能なアクター分離レベル
///
/// `@Statable` マクロの引数として使用します。
///
/// ## 使用例
///
/// ```swift
/// @Statable(.mainActor)      // MainActorで保護（デフォルト）
/// @Statable(.nonisolated)    // アクター分離なし
/// @Statable(.actor(MyActor.self))  // カスタムアクター
/// ```
public enum ActorIsolation: Sendable {
    /// MainActorで保護（デフォルト）
    case mainActor

    /// アクター分離なし（Sendable準拠のみ）
    case nonisolated

    /// カスタムグローバルアクターで保護
    case actor(any Actor.Type)
}

// MARK: - Default Implementations

extension AsyncStateProvider {
    /// デフォルト実装: エラーがない場合はnil
    public var firstError: StateError? {
        nil
    }

    /// デフォルト実装: 何もしない
    public func clearErrors() {}
}
