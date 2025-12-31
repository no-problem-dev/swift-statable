import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct StatablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StatableMacro.self,
    ]
}
