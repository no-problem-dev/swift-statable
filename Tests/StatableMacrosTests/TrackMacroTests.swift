import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(StatableMacros)
import StatableMacros

let trackMacros: [String: Macro.Type] = [
    "Track": TrackMacro.self,
]

final class TrackMacroTests: XCTestCase {

    func testTrackGeneratesOperationTracker() throws {
        assertMacroExpansion(
            """
            @Track(Operation.self) var operations
            """,
            expandedSource: """
            var operations {
                get {
                    _operations
                }
            }

            @ObservationIgnored
            private let _operations = OperationTracker<Operation>()
            """,
            macros: trackMacros
        )
    }

    func testTrackWithNestedType() throws {
        assertMacroExpansion(
            """
            @Track(WorkoutStore.Operation.self) var ops
            """,
            expandedSource: """
            var ops {
                get {
                    _ops
                }
            }

            @ObservationIgnored
            private let _ops = OperationTracker<WorkoutStore.Operation>()
            """,
            macros: trackMacros
        )
    }
}

#else
final class TrackMacroTests: XCTestCase {
    func testMacrosNotAvailable() throws {
        XCTSkip("Macros are only supported when running tests for the host platform")
    }
}
#endif
