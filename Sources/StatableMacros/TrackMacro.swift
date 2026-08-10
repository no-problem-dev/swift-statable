import SwiftSyntax
import SwiftSyntaxMacros

/// The implementation of the `@Track` macro.
///
/// It generates an `OperationTracker<Operation>` to track operations with.
///
/// ## Input
/// ```swift
/// @Track(Operation.self) var operations
/// ```
///
/// ## Expansion
/// ```swift
/// private let _operations = OperationTracker<Operation>()
/// var operations: OperationTracker<Operation> {
///     _operations
/// }
/// ```
public struct TrackMacro: AccessorMacro, PeerMacro {

    // MARK: - AccessorMacro

    /// Generates the getter that reads the generated storage.
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

        // Build the getter.
        let getter = AccessorDeclSyntax(accessorSpecifier: .keyword(.get)) {
            "_\(raw: propertyName)"
        }

        return [getter]
    }

    // MARK: - PeerMacro

    /// Generates the storage the accessor reads from, named after the property with a leading underscore.
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

        // Pull the operation type out of the attribute.
        let operationType = try extractOperationType(from: node)

        // Name the storage after the property.
        let storageName = "_\(propertyName)"

        return [
            """
            @ObservationIgnored
            private let \(raw: storageName) = OperationTracker<\(raw: operationType)>()
            """
        ]
    }

    // MARK: - Helper Methods

    /// Extracts the operation type from the attribute's arguments.
    private static func extractOperationType(from node: AttributeSyntax) throws -> String {
        // Take Operation out of @Track(Operation.self).
        guard let arguments = node.arguments,
              case .argumentList(let argumentList) = arguments,
              let firstArg = argumentList.first else {
            throw TrackMacroError.missingOperationType
        }

        // Parse the Operation.self form.
        let expression = firstArg.expression

        // MemberAccessExprSyntax: Operation.self
        if let memberAccess = expression.as(MemberAccessExprSyntax.self),
           memberAccess.declName.baseName.text == "self",
           let base = memberAccess.base {
            return base.trimmedDescription
        }

        // DeclReferenceExprSyntax: a bare type reference
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
