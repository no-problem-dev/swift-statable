import Testing
import Observation
@testable import Statable

/// A store must be creatable where no actor is guaranteed: the default value of a SwiftUI
/// environment entry is evaluated outside the main actor. 2.0.0 made that impossible, because the
/// storage the macro generates could only be created on the main actor.
@Statable([String].self, operations: NonisolatedCreationTests.Operation.self)
@MainActor @Observable
final class NonisolatedStore {
    nonisolated init() {}
}

/// Stands in for `EnvironmentKey.defaultValue`, which is a nonisolated requirement.
private enum NonisolatedDefault {
    static let store = NonisolatedStore()
}

@Suite("Creating storage outside the main actor")
struct NonisolatedCreationTests {
    enum Operation: Hashable, Sendable { case fetch }

    @Test
    nonisolated func storeCreatedOffTheMainActorStartsIdle() async {
        let store = NonisolatedStore()
        await MainActor.run {
            #expect(store.value == nil)
            #expect(store.isLoading == false)
            #expect(store.operations.isActive(.fetch) == false)
        }
    }

    @Test @MainActor
    func storeFromANonisolatedDefaultStillLoadsOnTheMainActor() async {
        let store = NonisolatedDefault.store
        await store.load { ["a"] }
        #expect(store.value == ["a"])
    }

    @Test
    nonisolated func storageCreatedOffTheMainActorKeepsItsInitialState() async {
        let preset = AsyncValue<Int>(initialValue: 1)
        let explicit = AsyncValue<Int>(state: .idle)
        await MainActor.run {
            #expect(preset.value == 1)
            #expect(explicit.value == nil)
        }
    }
}
