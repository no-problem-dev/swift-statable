import SwiftSyntax
import SwiftSyntaxMacros

/// @Statable マクロの実装
///
/// クラスに AsyncValue のラッパー機能を自動生成:
/// - 内部 AsyncValue ストレージ
/// - パススルー properties (value, state, isLoading, etc.)
/// - パススルー methods (set, startLoading, load, etc.)
/// - Statable, Sendable プロトコルへの準拠
///
/// オプションで OperationTracker も生成:
/// - 内部 OperationTracker ストレージ
/// - operations プロパティ
public struct StatableMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    /// メンバー（AsyncValue関連のプロパティとメソッド）を生成
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // クラス宣言であることを確認
        guard declaration.as(ClassDeclSyntax.self) != nil else {
            throw StatableMacroError.notAClass
        }

        // 引数を抽出
        let args = try extractArguments(from: node)
        let valueType = args.valueType
        let operationType = args.operationType

        // 既存のinitがあるか確認
        let hasExistingInit = declaration.memberBlock.members.contains { member in
            if let initDecl = member.decl.as(InitializerDeclSyntax.self) {
                return initDecl.signature.parameterClause.parameters.isEmpty
            }
            return false
        }

        var members: [DeclSyntax] = []

        // 1. 内部 AsyncValue ストレージ
        members.append(
            """
            @ObservationIgnored
            private let _asyncValue = AsyncValue<\(raw: valueType)>()
            """
        )

        // 2. 内部 OperationTracker ストレージ（operationType指定時のみ）
        if let opType = operationType {
            members.append(
                """
                @ObservationIgnored
                private let _operations = OperationTracker<\(raw: opType)>()
                """
            )
        }

        // 3. init（既存がなければ生成）
        if !hasExistingInit {
            members.append(
                """
                public init() {
                }
                """
            )
        }

        // 4. Computed Properties (パススルー)
        members.append(contentsOf: [
            """
            /// 現在の値
            public var value: \(raw: valueType)? {
                _asyncValue.value
            }
            """,
            """
            /// 内部状態（switch用）
            public var state: AsyncState<\(raw: valueType)> {
                _asyncValue.state
            }
            """,
            """
            /// ロード中かどうか
            public var isLoading: Bool {
                _asyncValue.isLoading
            }
            """,
            """
            /// 初期状態かどうか
            public var isIdle: Bool {
                _asyncValue.isIdle
            }
            """,
            """
            /// 失敗状態かどうか
            public var isFailed: Bool {
                _asyncValue.isFailed
            }
            """,
            """
            /// 値が存在するか
            public var hasValue: Bool {
                _asyncValue.hasValue
            }
            """,
            """
            /// エラー（failed状態の場合のみ）
            public var error: StateError? {
                _asyncValue.error
            }
            """,
        ])

        // 5. Operations プロパティ（operationType指定時のみ）
        if let opType = operationType {
            members.append(
                """
                /// 操作トラッカー
                public var operations: OperationTracker<\(raw: opType)> {
                    _operations
                }
                """
            )
        }

        // 6. Methods (パススルー)
        members.append(contentsOf: [
            """
            /// 値を設定（loaded状態に遷移）
            public func set(_ value: \(raw: valueType)) {
                _asyncValue.set(value)
            }
            """,
            """
            /// エラーを設定（failed状態に遷移）
            public func setError(_ error: StateError) {
                _asyncValue.setError(error)
            }
            """,
            """
            /// ロード開始（loading状態に遷移）
            public func startLoading() {
                _asyncValue.startLoading()
            }
            """,
            """
            /// 初期状態にリセット
            public func reset() {
                _asyncValue.reset()
            }
            """,
            """
            /// 非同期操作を実行し、結果を状態に反映
            public func load(_ operation: @Sendable () async throws -> \(raw: valueType)) async {
                await _asyncValue.load(operation)
            }
            """,
            """
            /// 条件付きでロード（値が存在しない場合のみ）
            public func loadIfNeeded(_ operation: @Sendable () async throws -> \(raw: valueType)) async {
                await _asyncValue.loadIfNeeded(operation)
            }
            """,
            """
            /// 強制リロード
            public func reload(_ operation: @Sendable () async throws -> \(raw: valueType)) async {
                await _asyncValue.reload(operation)
            }
            """,
        ])

        return members
    }

    // MARK: - ExtensionMacro

    /// プロトコル準拠のためのextensionを生成
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let statableExtension = try ExtensionDeclSyntax(
            """
            extension \(type.trimmed): Statable {}
            """
        )

        return [statableExtension]
    }

    // MARK: - Helper Methods

    /// マクロ引数から型を抽出
    private static func extractArguments(from node: AttributeSyntax) throws -> (valueType: String, operationType: String?) {
        guard let arguments = node.arguments,
              case .argumentList(let argList) = arguments else {
            throw StatableMacroError.missingTypeArgument
        }

        var valueType: String?
        var operationType: String?

        for arg in argList {
            // ラベルなしの第1引数 = valueType
            if arg.label == nil {
                if let memberAccess = arg.expression.as(MemberAccessExprSyntax.self),
                   let base = memberAccess.base {
                    valueType = base.trimmedDescription
                }
            }
            // operations: ラベル付き引数 = operationType
            else if arg.label?.text == "operations" {
                if let memberAccess = arg.expression.as(MemberAccessExprSyntax.self),
                   let base = memberAccess.base {
                    operationType = base.trimmedDescription
                }
            }
        }

        guard let vType = valueType else {
            throw StatableMacroError.missingTypeArgument
        }

        return (vType, operationType)
    }
}

// MARK: - Errors

enum StatableMacroError: Error, CustomStringConvertible {
    case notAClass
    case missingTypeArgument

    var description: String {
        switch self {
        case .notAClass:
            "@Statable can only be applied to classes"
        case .missingTypeArgument:
            "@Statable requires a type argument (e.g., @Statable(Profile.self))"
        }
    }
}
