import SwiftSyntax
import SwiftSyntaxMacros

/// @Track マクロの実装
///
/// 操作追跡用の `OperationTracker<Operation>` を生成します。
///
/// ## 入力
/// ```swift
/// @Track(Operation.self) var operations
/// ```
///
/// ## 展開結果
/// ```swift
/// private let _operations = OperationTracker<Operation>()
/// var operations: OperationTracker<Operation> {
///     _operations
/// }
/// ```
public struct TrackMacro: AccessorMacro, PeerMacro {

    // MARK: - AccessorMacro

    /// getter を生成
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
            throw TrackMacroError.invalidDeclaration
        }

        let propertyName = identifier.identifier.text

        // getter を生成
        let getter = AccessorDeclSyntax(accessorSpecifier: .keyword(.get)) {
            "_\(raw: propertyName)"
        }

        return [getter]
    }

    // MARK: - PeerMacro

    /// 内部ストレージ (_propertyName) を生成
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
            throw TrackMacroError.invalidDeclaration
        }

        let propertyName = identifier.identifier.text

        // マクロ引数から Operation 型を抽出
        let operationType = try extractOperationType(from: node)

        // 内部ストレージを生成
        let storageName = "_\(propertyName)"

        return [
            """
            @ObservationIgnored
            private let \(raw: storageName) = OperationTracker<\(raw: operationType)>()
            """
        ]
    }

    // MARK: - Helper Methods

    /// マクロ引数から Operation 型を抽出
    private static func extractOperationType(from node: AttributeSyntax) throws -> String {
        // @Track(Operation.self) から Operation を抽出
        guard let arguments = node.arguments,
              case .argumentList(let argumentList) = arguments,
              let firstArg = argumentList.first else {
            throw TrackMacroError.missingOperationType
        }

        // Operation.self の形式をパース
        let expression = firstArg.expression

        // MemberAccessExprSyntax: Operation.self
        if let memberAccess = expression.as(MemberAccessExprSyntax.self),
           memberAccess.declName.baseName.text == "self",
           let base = memberAccess.base {
            return base.trimmedDescription
        }

        // DeclReferenceExprSyntax: 直接の型参照
        if let declRef = expression.as(DeclReferenceExprSyntax.self) {
            return declRef.baseName.text
        }

        throw TrackMacroError.invalidOperationType
    }
}

// MARK: - Errors

enum TrackMacroError: Error, CustomStringConvertible {
    case invalidDeclaration
    case missingOperationType
    case invalidOperationType

    var description: String {
        switch self {
        case .invalidDeclaration:
            "@Track can only be applied to variable declarations"
        case .missingOperationType:
            "@Track requires an operation type (e.g., @Track(Operation.self))"
        case .invalidOperationType:
            "@Track requires a valid type reference (e.g., @Track(Operation.self))"
        }
    }
}
