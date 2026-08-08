# Statable

[English](./README.md) | 日本語

SwiftUI向けの宣言的な状態管理マクロ。AsyncValueパターンとOperationTrackerを組み合わせ、非同期状態を型安全に管理する。

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![iOS 17+](https://img.shields.io/badge/iOS-17+-blue.svg)
![macOS 14+](https://img.shields.io/badge/macOS-14+-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 特徴

- **宣言的なマクロ**: `@Statable` マクロで状態管理のボイラープレートを削減
- **排他的状態表現**: `AsyncState<T>` enumで `.idle`, `.loading`, `.loaded`, `.failed` を型安全に表現
- **操作トラッキング**: `OperationTracker` で複数の並行操作を個別に追跡
- **@Observable統合**: SwiftUIの `@Observable` と完全に統合
- **メインアクターの上でだけ生きる**: `AsyncValue` と `OperationTracker` は `@MainActor`。
  状態の書き換えが SwiftUI の読み取りと競合しないことを、注記ではなくコンパイラが守る
- **重なったロードは後から始まった方が勝つ**: 遅い古い 1 本が、新しい答えを上書きしない
- **取り消しは失敗にしない**: やめたロードは前の答えへ戻る（`loading` に取り残されない）

## クイックスタート

```swift
import SwiftUI
import Statable

// シンプルなStore定義
@Statable(MetabolicProfile.self)
@MainActor @Observable
final class ProfileStore {
    public init() {}

    // カスタムcomputed properties
    var currentAge: Int { value?.age() ?? 0 }
}

// 操作トラッキング付きStore
enum WorkoutOperation: String, CaseIterable, Sendable {
    case fetch, recordStrength, recordCardio
}

@Statable([WorkoutActivity].self, operations: WorkoutOperation.self)
@MainActor @Observable
final class WorkoutStore {
    public init() {}

    var isRecording: Bool {
        operations.isActive(.recordStrength) || operations.isActive(.recordCardio)
    }
}
```

## インストール

### Swift Package Manager

`Package.swift` に以下を追加：

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-statable.git", from: "2.0.0")
]
```

ターゲットに追加：

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Statable", package: "swift-statable")
    ]
)
```

## 使い方

### 基本的なStore

```swift
@Statable(UserProfile.self)
@MainActor @Observable
final class UserStore {
    public init() {}
}

// View側での使用
struct ProfileView: View {
    @Environment(UserStore.self) private var store

    var body: some View {
        switch store.state {
        case .idle:
            Text("データ未取得")
        case .loading(let previous):
            VStack {
                ProgressView()
                if let prev = previous {
                    Text("前回: \(prev.name)")
                }
            }
        case .loaded(let profile):
            Text("こんにちは、\(profile.name)さん")
        case .failed(let error):
            Text("エラー: \(error.localizedMessage)")
        }
    }
}
```

### データのロード

```swift
// 基本的なロード
await store.load {
    try await api.fetchProfile()
}

// まだ一度も成功していないときだけロード
await store.loadIfNeeded {
    try await api.fetchProfile()
}
```

### 操作トラッキング

```swift
enum DataOperation: String, CaseIterable, Sendable {
    case fetch, save, delete
}

@Statable([Item].self, operations: DataOperation.self)
@MainActor @Observable
final class ItemStore {
    public init() {}
}

// 操作の追跡
struct ItemListView: View {
    @Environment(ItemStore.self) private var store

    var body: some View {
        List {
            if store.operations.isActive(.fetch) {
                ProgressView("読み込み中...")
            }

            ForEach(store.value ?? []) { item in
                ItemRow(item: item)
            }
        }
        .toolbar {
            Button("保存") {
                Task {
                    await store.operations.run(.save) {
                        try await api.saveItems(store.value ?? [])
                    }
                }
            }
            .disabled(store.operations.isActive(.save))
        }
    }
}
```

## API リファレンス

### @Statable マクロ

#### 生成されるプロパティ

| プロパティ | 型 | 説明 |
|----------|------|------|
| `value` | `T?` | 現在の値 |
| `state` | `AsyncState<T>` | 状態（switch用） |
| `isLoading` | `Bool` | ローディング中か |
| `isIdle` | `Bool` | 初期状態か |
| `isFailed` | `Bool` | 失敗状態か |
| `isInitialLoading` | `Bool` | まだ一度も答えを持たないままのロード中か（骨組みを出してよい唯一の状態） |
| `isReloading` | `Bool` | 前の答えを持ったままのロード中か（画面を空にしない） |
| `hasValue` | `Bool` | 見せられる値があるか（`loading` / `failed` でも前の値があれば true） |
| `isLoaded` | `Bool` | 最後のロードが成功して終わっているか |
| `error` | `StateError?` | エラー |
| `operations` | `OperationTracker<Op>` | 操作トラッカー（operations引数指定時のみ） |

#### 生成されるメソッド

| メソッド | 説明 |
|---------|------|
| `set(_:)` | 値を設定 |
| `setError(_:)` | エラーを設定 |
| `startLoading()` | ローディング開始 |
| `reset()` | 初期状態にリセット |
| `load(_:)` | 非同期操作を実行（重なりは後勝ち・取り消しは失敗にしない） |
| `loadIfNeeded(_:)` | まだ一度も成功していないときだけロード |

### AsyncState

```swift
public enum AsyncState<Value: Sendable>: Sendable {
    case idle                       // 初期状態
    case loading(previous: Value?)  // ロード中（見せていた値を保つ）
    case loaded(Value)              // ロード成功
    case failed(StateError, previous: Value?)  // ロード失敗（見せていた値を保つ）
}
```

`value` は `loading` でも `failed` でも前の値を返す。だから「見せるものがあるか」の判断は 1 つで済み、
画面はちょうど 3 つの顔に分かれる。

```swift
if let value = store.value {
    Content(value)                                  // 読み直し中も、失敗した後も出す
    if let error = store.error { Banner(error) }    // 失敗は画面を奪わず帯で言う
} else if let error = store.error {
    FailureFace(error)                              // 見せるものが無いときだけ画面を奪う
} else {
    Skeleton()                                      // まだ答えが無い
}
```

**`isLoading` だけを見て描かないこと。** 読み込み中かどうかは「画面を空にする理由」にならない。
空の配列は立派な答え（「無い」）なので、`value?.isEmpty` を「値が無い」と読み替えてはいけない
—— 読み替えると、0 件の利用者だけが読み直しのたびに骨組みを見ることになる。

### OperationTracker

```swift
// 操作の開始・完了
operations.start(.fetch)
operations.complete(.fetch)
operations.fail(.fetch, with: error)

// 状態の確認
operations.isActive(.fetch)
operations.hasActiveOperations
operations.error(for: .fetch)

// 便利メソッド
await operations.run(.fetch) {
    try await api.fetchData()
}
```

### StateError

```swift
public enum StateError: Error, Sendable, Equatable, Hashable {
    case network(NetworkError)
    case validation(ValidationError)
    case notFound(resource: String)
    case unauthorized
    case server(code: Int, message: String)
    case unknown(String)
}

// 便利プロパティ
error.localizedMessage  // ユーザー向けメッセージ
error.isRetryable       // リトライ可能かどうか

// 標準Errorからの変換
let stateError = StateError(from: someError)
```

## 設計原則

### 1 Store = 1 AsyncValue

各Storeは単一の型の非同期値を管理する。これにより：
- 状態の一貫性が保証される
- テストが容易になる
- 責務が明確になる

### SSOT (Single Source of Truth)

`AsyncState` enumは排他的な状態を表現し、矛盾した状態（例：`isLoading = true` かつ `error != nil`）を型レベルで防ぐ。

### ロード中も失敗後も、前の値を保つ

`loading` と `failed` の両方が前の値を運ぶ。捨てるかどうかを正しく決められるのは画面だけで、
状態が先に捨ててしまうと画面には選択肢が残らない。

### メインアクターの上でだけ生きる

`AsyncValue` と `OperationTracker` は `@MainActor`。これらは画面の状態そのもので、SwiftUI は
メインアクターで読む。別のスレッドから書き換えると Observation の無効化通知もそのスレッドから飛び、
取りこぼすと画面は最後に描いたもの——たいていは読み込み中の表示——のまま止まる。
1.x では `@unchecked Sendable` の隣に注記があるだけで、しかもその注記は嘘だった
（`load(_:)` が `nonisolated` な `async` 関数で、呼び出し元のアクターから外れて書き換えていた）。
いまは `IsolationTests` が書き換えの場所を実測して見張っている。

## 1.x からの移行

| 変わったこと | すること |
|---|---|
| `AsyncValue` / `OperationTracker` が `@MainActor` | `@MainActor` から呼ぶ。`@MainActor @Observable` で書いていたストアは変更不要 |
| `AsyncState.failed` が `previous` を持つ | `state` の網羅 `switch` を直す。`value` は失敗時も前の値を返すので、失敗の検出は `error` で見る |
| `reload(_:)` を削除 | `load(_:)` を使う（同じ振る舞いに別名が付いていただけ） |
| `loadIfNeeded(_:)` は成功したときだけ省略 | 前の値が残っている失敗の後は、もう一度読みに行く |
| `OperationTracker.run(_:task:)` が `Result?` を返す | `nil` は取り消し。取り消しはもう失敗として記録しない |
| `AsyncStateProvider` / `OperationTrackable` / `ActorIsolation` を削除 | 誰も準拠しておらず、既定実装は黙って nil と no-op を返していた |
| `AsyncValue` の `description` / `debugDescription` / `Equatable` を削除 | `store.state` を print・比較する |

## ドキュメント

詳細なAPIドキュメントは [GitHub Pages](https://no-problem-dev.github.io/swift-statable/documentation/statable/) で確認できる。

## 依存関係

| パッケージ | 用途 |
|-----------|------|
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | マクロ実装 |

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照。
