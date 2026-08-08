import Foundation
import Observation
import Testing
@testable import Statable

/// 状態の書き換えが**メインアクターの外**で起きていないことを、機械が見張る。
///
/// これは目で見つけられない種類の不具合で、症状（読み込み中の表示が消えない）が出るかどうかは
/// その時の実行順に左右される。手で触って「出なかった」を確かめても意味がないので、
/// **書いている場所そのもの**を測る。
///
/// Observation の `onChange` は `willSet` と同じ実行文脈で同期に呼ばれるので、
/// 「いま `state` を書き換えているのは誰か」がそのまま分かる。
///
/// 1.x はここで落ちる —— `AsyncValue.load` が `nonisolated` な `async` 関数で、
/// `@MainActor` のストアから呼んでも汎用エグゼキュータへ移り、`startLoading()` も `set()` も
/// そこで走っていた。`@MainActor` を外すと、このテストがそれを言う。
@MainActor
@Suite("隔離 — 状態の書き換えはメインアクターの上でだけ起きる")
struct IsolationTests {

    /// 書き換えが起きた場所を数える。`onChange` は `@Sendable` なので箱に入れて渡す。
    private final class Recorder: @unchecked Sendable {
        private(set) var writes = 0
        private(set) var offMainWrites = 0

        func record() {
            writes += 1
            if pthread_main_np() == 0 { offMainWrites += 1 }
        }
    }

    /// 次の 1 回の書き換えを見張る（`withObservationTracking` は 1 回で外れるので、都度張り直す）。
    private func watchNextWrite(of value: AsyncValue<Int>, into recorder: Recorder) {
        withObservationTracking {
            _ = value.state
        } onChange: {
            recorder.record()
        }
    }

    @Test("load の開始と成功の書き換えが、どちらもメインアクターで起きる")
    func loadWritesOnMainActor() async {
        let value = AsyncValue<Int>()
        let recorder = Recorder()

        // 1 回目 = startLoading
        watchNextWrite(of: value, into: recorder)
        await value.load {
            // 通信そのものは外へ出てよい。ここが main でないのは正しい姿
            #expect(pthread_main_np() == 0)
            // 2 回目 = set。操作が返る前に張り直す
            await MainActor.run { self.watchNextWrite(of: value, into: recorder) }
            return 1
        }

        #expect(value.value == 1)
        #expect(recorder.writes == 2)
        #expect(recorder.offMainWrites == 0)
    }

    @Test("失敗したときの書き換えも、メインアクターで起きる")
    func failureWritesOnMainActor() async {
        let value = AsyncValue<Int>()
        let recorder = Recorder()

        watchNextWrite(of: value, into: recorder)
        await value.load {
            await MainActor.run { self.watchNextWrite(of: value, into: recorder) }
            throw IsolationTestError.simulated
        }

        #expect(value.isFailed)
        #expect(recorder.writes == 2)
        #expect(recorder.offMainWrites == 0)
    }

    /// 次の 1 回の書き換えを見張る（``OperationTracker`` 版）。
    private func watchNextWrite(of tracker: OperationTracker<String>, into recorder: Recorder) {
        withObservationTracking {
            _ = tracker.hasActiveOperations
        } onChange: {
            recorder.record()
        }
    }

    @Test("OperationTracker の追跡も、メインアクターで起きる")
    func operationTrackerWritesOnMainActor() async {
        let tracker = OperationTracker<String>()
        let recorder = Recorder()

        watchNextWrite(of: tracker, into: recorder)  // 1 回目 = start
        await tracker.run("fetch") {
            // 2 回目 = complete
            await MainActor.run { self.watchNextWrite(of: tracker, into: recorder) }
            return 1
        }

        #expect(!tracker.hasActiveOperations)
        #expect(recorder.writes == 2)
        #expect(recorder.offMainWrites == 0)
    }
}

private enum IsolationTestError: Error {
    case simulated
}
