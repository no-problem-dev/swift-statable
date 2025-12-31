# Statable

[English](README_EN.md) | 日本語

SwiftUI向けの宣言的な状態管理マクロ。AsyncValueパターンとOperationTrackerを組み合わせ、非同期状態を型安全に管理します。

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![iOS 17+](https://img.shields.io/badge/iOS-17+-blue.svg)
![macOS 14+](https://img.shields.io/badge/macOS-14+-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 特徴

- **宣言的なマクロ**: `@Statable` マクロで状態管理のボイラープレートを削減
- **排他的状態表現**: `AsyncState<T>` enumで `.idle`, `.loading`, `.loaded`, `.failed` を型安全に表現
- **操作トラッキング**: `OperationTracker` で複数の並行操作を個別に追跡
- **@Observable統合**: SwiftUIの `@Observable` と完全に統合
- **Sendable準拠**: Strict Concurrency対応

## クイックスタート

```swift
import SwiftUI
import Statable

// シンプルなStore定義
@Statable(MetabolicProfile.self)
@MainActor @Observable
final class ProfileStore {
    // マクロが value, state, isLoading などを自動生成

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
    // value, state, operations などが自動生成

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
    .package(url: "https://github.com/no-problem-dev/swift-statable.git", from: "1.0.0")
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
            Text("エラー: \(error.message)")
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

// 値がない場合のみロード
await store.loadIfNeeded {
    try await api.fetchProfile()
}

// 強制リロード
await store.reload {
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
| `hasValue` | `Bool` | 値が存在するか |
| `error` | `StateError?` | エラー |
| `operations` | `OperationTracker<Op>` | 操作トラッカー（operations引数指定時のみ） |

#### 生成されるメソッド

| メソッド | 説明 |
|---------|------|
| `set(_:)` | 値を設定 |
| `setError(_:)` | エラーを設定 |
| `startLoading()` | ローディング開始 |
| `reset()` | 初期状態にリセット |
| `load(_:)` | 非同期操作を実行 |
| `loadIfNeeded(_:)` | 値がない場合のみロード |
| `reload(_:)` | 強制リロード |

### AsyncState

```swift
public enum AsyncState<Value: Sendable>: Sendable {
    case idle                       // 初期状態
    case loading(previous: Value?)  // ロード中（前回の値を保持）
    case loaded(Value)              // ロード成功
    case failed(StateError)         // ロード失敗
}
```

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
public struct StateError: Error, Equatable, Sendable {
    public let code: String
    public let message: String
    public let underlying: String?

    public init(from error: Error)
    public init(code: String, message: String)
}
```

## 設計原則

### 1 Store = 1 AsyncValue

各Storeは単一の型の非同期値を管理します。これにより：
- 状態の一貫性が保証される
- テストが容易になる
- 責務が明確になる

### SSOT (Single Source of Truth)

`AsyncState` enumは排他的な状態を表現し、矛盾した状態（例：`isLoading = true` かつ `error != nil`）を型レベルで防ぎます。

### Loading中の前回値保持

`loading(previous: Value?)` により、リロード中も前回の値を表示し続けることができ、UXが向上します。

## ドキュメント

詳細なAPIドキュメントは [GitHub Pages](https://no-problem-dev.github.io/swift-statable/documentation/statable/) で確認できます。

## 依存関係

| パッケージ | 用途 |
|-----------|------|
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | マクロ実装 |

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照してください。
