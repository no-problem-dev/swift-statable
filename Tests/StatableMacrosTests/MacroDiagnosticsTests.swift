import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(StatableMacros)
import StatableMacros

/// @Statable / @Track の誤用時 diagnostics を検証するテスト
///
/// StatableMacroError / TrackMacroError の全ケースを網羅する:
/// - StatableMacroError: notAClass / missingTypeArgument
/// - TrackMacroError: invalidDeclaration / missingOperationType / invalidOperationType
final class MacroDiagnosticsTests: XCTestCase {

    // MARK: - StatableMacroError.notAClass

    func testStatableOnStructEmitsNotAClassDiagnostic() throws {
        assertMacroExpansion(
            """
            @Statable(Profile.self)
            struct ProfileStore {
            }
            """,
            expandedSource: """

            struct ProfileStore {
            }

            extension ProfileStore: Statable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Statable can only be applied to classes", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testStatableOnEnumEmitsNotAClassDiagnostic() throws {
        assertMacroExpansion(
            """
            @Statable(Profile.self)
            enum ProfileStore {
            }
            """,
            expandedSource: """

            enum ProfileStore {
            }

            extension ProfileStore: Statable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Statable can only be applied to classes", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    // MARK: - StatableMacroError.missingTypeArgument

    func testStatableWithoutArgumentsEmitsMissingTypeArgumentDiagnostic() throws {
        assertMacroExpansion(
            """
            @Statable
            final class ProfileStore {
            }
            """,
            expandedSource: """

            final class ProfileStore {
            }

            extension ProfileStore: Statable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Statable requires a type argument (e.g., @Statable(Profile.self))",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
    }

    func testStatableWithNonTypeArgumentEmitsMissingTypeArgumentDiagnostic() throws {
        assertMacroExpansion(
            """
            @Statable(42)
            final class ProfileStore {
            }
            """,
            expandedSource: """

            final class ProfileStore {
            }

            extension ProfileStore: Statable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Statable requires a type argument (e.g., @Statable(Profile.self))",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
    }

    // MARK: - TrackMacroError.invalidDeclaration

    func testTrackOnFunctionEmitsInvalidDeclarationDiagnostic() throws {
        assertMacroExpansion(
            """
            @Track(Operation.self)
            func operations() {
            }
            """,
            expandedSource: """
            func operations() {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Track can only be applied to variable declarations", line: 1, column: 1)
            ],
            macros: trackMacros
        )
    }

    // MARK: - TrackMacroError.missingOperationType

    func testTrackWithoutArgumentsEmitsMissingOperationTypeDiagnostic() throws {
        assertMacroExpansion(
            """
            @Track var operations
            """,
            expandedSource: """
            var operations {
                get {
                    _operations
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Track requires an operation type (e.g., @Track(Operation.self))",
                    line: 1,
                    column: 1
                )
            ],
            macros: trackMacros
        )
    }

    // MARK: - TrackMacroError.invalidOperationType

    func testTrackWithNonTypeArgumentEmitsInvalidOperationTypeDiagnostic() throws {
        assertMacroExpansion(
            """
            @Track("Operation") var operations
            """,
            expandedSource: """
            var operations {
                get {
                    _operations
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Track requires a valid type reference (e.g., @Track(Operation.self))",
                    line: 1,
                    column: 1
                )
            ],
            macros: trackMacros
        )
    }
}

#else
final class MacroDiagnosticsTests: XCTestCase {
    func testDiagnosticsMacrosNotAvailable() throws {
        XCTSkip("Macros are only supported when running tests for the host platform")
    }
}
#endif
