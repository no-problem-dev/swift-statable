import SwiftSyntax
import SwiftSyntaxMacros

/// The implementation of the `@Statable` macro.
///
/// It gives a class the wrapper members of an AsyncValue:
/// - the AsyncValue storage behind them
/// - pass-through properties (value, state, isLoading, and so on)
/// - pass-through methods (set, startLoading, load, and so on)
/// - conformance to the Statable and Sendable protocols
///
/// It optionally generates an OperationTracker as well:
/// - the OperationTracker storage
/// - the operations property
public struct StatableMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    /// Generates the members that pass through to the stored AsyncValue.
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Only a class can hold the generated members.
        guard declaration.as(ClassDeclSyntax.self) != nil else {
            throw StatableMacroError.notAClass
        }

        // Pull the types out of the attribute.
        let args = try extractArguments(from: node)
        let valueType = args.valueType
        let operationType = args.operationType

        var members: [DeclSyntax] = []

        // 1. The AsyncValue storage
        members.append(
            """
            @ObservationIgnored
            private let _asyncValue = AsyncValue<\(raw: valueType)>()
            """
        )

        // 2. The OperationTracker storage, only when an operation type was given
        if let opType = operationType {
            members.append(
                """
                @ObservationIgnored
                private let _operations = OperationTracker<\(raw: opType)>()
                """
            )
        }

        // 3. Pass-through computed properties
        members.append(contentsOf: [
            """
            /// The value that can be shown right now; during a reload or after a failure it is the previous one.
            public var value: \(raw: valueType)? {
                _asyncValue.value
            }
            """,
            """
            /// The exclusive state behind every convenience property, exposed so a view can switch on it.
            public var state: AsyncState<\(raw: valueType)> {
                _asyncValue.state
            }
            """,
            """
            public var isLoading: Bool {
                _asyncValue.isLoading
            }
            """,
            """
            /// Whether a load is in flight with nothing to show yet — the only state in which a skeleton belongs.
            public var isInitialLoading: Bool {
                _asyncValue.isInitialLoading
            }
            """,
            """
            /// Whether a load is in flight while the previous value is still shown. Use it to avoid emptying the screen.
            public var isReloading: Bool {
                _asyncValue.isReloading
            }
            """,
            """
            public var isIdle: Bool {
                _asyncValue.isIdle
            }
            """,
            """
            public var isFailed: Bool {
                _asyncValue.isFailed
            }
            """,
            """
            /// Whether there is anything to show, including a value kept through a reload or a failure.
            public var hasValue: Bool {
                _asyncValue.hasValue
            }
            """,
            """
            /// Whether the last load finished successfully. A value left over from before a failure does not count.
            public var isLoaded: Bool {
                _asyncValue.isLoaded
            }
            """,
            """
            /// The error from the last load, or nil unless that load failed.
            public var error: StateError? {
                _asyncValue.error
            }
            """,
        ])

        // 4. The operations property, only when an operation type was given
        if let opType = operationType {
            members.append(
                """
                /// The running state and last error of each declared operation.
                public var operations: OperationTracker<\(raw: opType)> {
                    _operations
                }
                """
            )
        }

        // 5. Pass-through methods
        members.append(contentsOf: [
            """
            /// Stores a value directly, superseding a load that is still in flight.
            public func set(_ value: \(raw: valueType)) {
                _asyncValue.set(value)
            }
            """,
            """
            /// Records a failure while keeping the previous value, and supersedes a load that is still in flight.
            public func setError(_ error: StateError) {
                _asyncValue.setError(error)
            }
            """,
            """
            /// Marks a load as started, keeping the previous value so the screen stays filled.
            public func startLoading() {
                _asyncValue.startLoading()
            }
            """,
            """
            /// Drops the value and the error, and abandons a load that is still in flight.
            public func reset() {
                _asyncValue.reset()
            }
            """,
            """
            /// Runs an async operation and reflects its outcome; the last load started wins and cancellation is not a failure.
            public func load(_ operation: @Sendable () async throws -> \(raw: valueType)) async {
                await _asyncValue.load(operation)
            }
            """,
            """
            /// Loads only when no load has succeeded yet; a failure that left a previous value behind does not count as done.
            public func loadIfNeeded(_ operation: @Sendable () async throws -> \(raw: valueType)) async {
                await _asyncValue.loadIfNeeded(operation)
            }
            """,
        ])

        return members
    }

    // MARK: - ExtensionMacro

    /// Generates the extension that carries the protocol conformance.
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

    /// Extracts the value type and the optional operation type from the attribute's arguments.
    private static func extractArguments(from node: AttributeSyntax) throws -> (valueType: String, operationType: String?) {
        guard let arguments = node.arguments,
              case .argumentList(let argList) = arguments else {
            throw StatableMacroError.missingTypeArgument
        }

        var valueType: String?
        var operationType: String?

        for arg in argList {
            // The unlabelled first argument is the value type.
            if arg.label == nil {
                if let memberAccess = arg.expression.as(MemberAccessExprSyntax.self),
                   let base = memberAccess.base {
                    valueType = base.trimmedDescription
                }
            }
            // The argument labelled `operations:` is the operation type.
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
