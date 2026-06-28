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
/// @Statable(MetabolicProfile.self)
/// @MainActor @Observable
/// final class ProfileStore {
///     public init() {}
/// }
/// // ProfileStore は自動的に Statable に準拠
/// ```
public protocol Statable: AnyObject, Observable, Sendable {}

// MARK: - AsyncStateProvider

/// 非同期状態を持つストアのプロトコル
///
/// `@Statable` クラスが複数の非同期値を持つ場合に準拠することで、
/// ローディング状態の集約やエラー管理を統一できます。
///
/// ## 提供される機能
///
/// - 全ての非同期状態のローディング状態を集約
/// - 最初のエラーへのアクセス
/// - 一括エラークリア
///
/// ## 使用例
///
/// ```swift
/// @Statable(DailyMetrics.self)
/// @MainActor @Observable
/// final class MetricsStore: AsyncStateProvider {
///     public init() {}
///
///     // isLoading は @Statable が生成するものを使用
///     // firstError / clearErrors は必要に応じてオーバーライド
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
/// `@Track` マクロで生成された `OperationTracker` を持つ `@Statable` クラスが
/// 準拠することで、操作状態の問い合わせ方法を統一できます。
///
/// ## 使用例
///
/// ```swift
/// @Statable([WorkoutActivity].self)
/// @MainActor @Observable
/// final class WorkoutStore: OperationTrackable {
///     enum Operation: Hashable, Sendable {
///         case fetch
///         case record
///     }
///
///     @Track(Operation.self) var operations
///
///     func isOperationActive(_ operation: Operation) -> Bool {
///         operations.isActive(operation)
///     }
///
///     var hasActiveOperations: Bool {
///         operations.hasActiveOperations
///     }
///
///     func operationError(_ operation: Operation) -> StateError? {
///         operations.error(for: operation)
///     }
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

/// アクター分離レベルの列挙（将来の拡張用）
///
/// 現在は `@Statable` を適用するクラスに `@MainActor` を直接付与することで
/// アクター分離を制御します。この型は将来のマクロ拡張のために予約されています。
///
/// ## 現在の推奨パターン
///
/// ```swift
/// // MainActor で保護する場合（推奨）
/// @Statable(UserProfile.self)
/// @MainActor @Observable
/// final class ProfileStore {
///     public init() {}
/// }
/// ```
public enum ActorIsolation: Sendable {
    /// MainActorで保護
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
