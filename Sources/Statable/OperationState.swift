import Observation

/// 複数の並行操作を追跡するための状態管理
///
/// 個別の操作ごとに実行状態とエラーを追跡できます。
///
/// ## 使用例
///
/// ```swift
/// @Statable
/// final class WorkoutStore {
///     enum Operation: String, CaseIterable, Sendable {
///         case fetch
///         case recordStrength
///         case recordCardio
///     }
///
///     @Track(Operation.self) var operations
///     @Async var activities: [WorkoutActivity] = []
/// }
///
/// // 操作の開始・完了
/// store.operations.start(.fetch)
/// store.operations.complete(.fetch)
///
/// // 状態の確認
/// if store.operations.isActive(.recordStrength) {
///     ProgressView("記録中...")
/// }
/// ```
/// @MainActor で保護される前提のため @unchecked Sendable
@Observable
public final class OperationTracker<Operation: Hashable & Sendable>: @unchecked Sendable {
    // MARK: - State

    /// 実行中の操作
    private var activeOperations: Set<Operation> = []

    /// 操作ごとのエラー
    private var errors: [Operation: StateError] = [:]

    // MARK: - Initialization

    public init() {}

    // MARK: - Operation Management

    /// 操作を開始
    /// - Parameter operation: 開始する操作
    public func start(_ operation: Operation) {
        activeOperations.insert(operation)
        errors.removeValue(forKey: operation)
    }

    /// 操作を完了
    /// - Parameter operation: 完了した操作
    public func complete(_ operation: Operation) {
        activeOperations.remove(operation)
    }

    /// 操作を失敗として終了
    /// - Parameters:
    ///   - operation: 失敗した操作
    ///   - error: 発生したエラー
    public func fail(_ operation: Operation, with error: StateError) {
        activeOperations.remove(operation)
        errors[operation] = error
    }

    /// 操作を失敗として終了（標準Errorから変換）
    /// - Parameters:
    ///   - operation: 失敗した操作
    ///   - error: 発生したエラー
    public func fail(_ operation: Operation, with error: Error) {
        fail(operation, with: StateError(from: error))
    }

    // MARK: - Query Methods

    /// 特定の操作が実行中かどうか
    /// - Parameter operation: 確認する操作
    /// - Returns: 実行中の場合 true
    public func isActive(_ operation: Operation) -> Bool {
        activeOperations.contains(operation)
    }

    /// いずれかの操作が実行中かどうか
    public var hasActiveOperations: Bool {
        !activeOperations.isEmpty
    }

    /// 実行中の操作の一覧
    public var active: Set<Operation> {
        activeOperations
    }

    /// 特定の操作のエラーを取得
    /// - Parameter operation: 確認する操作
    /// - Returns: エラー（存在する場合）
    public func error(for operation: Operation) -> StateError? {
        errors[operation]
    }

    /// いずれかの操作でエラーが発生しているか
    public var hasErrors: Bool {
        !errors.isEmpty
    }

    /// 全てのエラー
    public var allErrors: [Operation: StateError] {
        errors
    }

    // MARK: - Error Management

    /// 特定の操作のエラーをクリア
    /// - Parameter operation: エラーをクリアする操作
    public func clearError(for operation: Operation) {
        errors.removeValue(forKey: operation)
    }

    /// 全てのエラーをクリア
    public func clearAllErrors() {
        errors.removeAll()
    }

    // MARK: - Convenience Methods

    /// 操作を実行し、結果を自動的に追跡
    ///
    /// ```swift
    /// await store.operations.run(.fetch) {
    ///     try await api.fetchActivities()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - operation: 追跡する操作
    ///   - task: 実行するタスク
    /// - Returns: タスクの結果
    @discardableResult
    public func run<T: Sendable>(
        _ operation: Operation,
        task: @Sendable () async throws -> T
    ) async -> Result<T, StateError> {
        start(operation)
        do {
            let result = try await task()
            complete(operation)
            return .success(result)
        } catch {
            let stateError = StateError(from: error)
            fail(operation, with: stateError)
            return .failure(stateError)
        }
    }

    /// 操作を実行し、結果をAsyncValueに設定
    ///
    /// ```swift
    /// await store.operations.run(.fetch, into: store.activities) {
    ///     try await api.fetchActivities()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - operation: 追跡する操作
    ///   - asyncValue: 結果を設定するAsyncValue
    ///   - task: 実行するタスク
    public func run<T: Sendable>(
        _ operation: Operation,
        into asyncValue: AsyncValue<T>,
        task: @Sendable () async throws -> T
    ) async {
        start(operation)
        asyncValue.startLoading()
        do {
            let result = try await task()
            asyncValue.set(result)
            complete(operation)
        } catch {
            let stateError = StateError(from: error)
            asyncValue.setError(stateError)
            fail(operation, with: stateError)
        }
    }
}

// MARK: - CustomStringConvertible

extension OperationTracker: CustomStringConvertible {
    public var description: String {
        let activeList = activeOperations.map { String(describing: $0) }.joined(separator: ", ")
        let errorCount = errors.count
        return "OperationTracker(active: [\(activeList)], errors: \(errorCount))"
    }
}
