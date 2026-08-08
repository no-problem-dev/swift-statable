import Observation

// MARK: - Statable

/// 状態コンテナとして振る舞うための基本プロトコル。
///
/// `@Statable` マクロを適用したクラスが自動的に準拠する。
///
/// ## 準拠による保証
///
/// - `@MainActor`（またはグローバルアクター）で保護される
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
///
/// - Note: 中身の ``AsyncValue`` と ``OperationTracker`` は `@MainActor` なので、
///   `@MainActor` を付けないクラスに `@Statable` を付けると**コンパイルが通らない**。
///   これは意図した設計で、実行時に競合する代わりに書いた時点で分かるようにしてある。
public protocol Statable: AnyObject, Observable, Sendable {}
