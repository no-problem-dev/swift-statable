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

## 使い方

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

### 画面での出し分け

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

struct ItemListView: View {
    @Environment(ItemStore.self) private var store

    var body: some View {
        List {
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

## ドキュメント

API リファレンスとガイドは
[GitHub Pages](https://no-problem-dev.github.io/swift-statable/documentation/statable/) にある。
設計の理由は
[Design Principles](https://no-problem-dev.github.io/swift-statable/documentation/statable/designprinciples)
を参照。

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

## 依存関係

| パッケージ | 用途 |
|-----------|------|
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | マクロ実装 |

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照。
