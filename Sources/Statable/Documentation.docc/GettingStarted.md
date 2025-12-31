# はじめに

Statableを使って非同期状態を管理する基本的な方法を学びます。

## Overview

Statableは、SwiftUIアプリケーションで非同期状態を型安全に管理するためのライブラリです。
`@Statable`マクロにより、状態管理のボイラープレートを大幅に削減できます。

## インストール

### Swift Package Manager

`Package.swift`に以下を追加してください：

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

## 基本的な使い方

### Storeの定義

`@Statable`マクロを使用してStoreを定義します：

```swift
import Statable

@Statable(UserProfile.self)
@MainActor @Observable
final class ProfileStore {
    public init() {}
}
```

このマクロにより、以下のプロパティとメソッドが自動生成されます：

| プロパティ | 型 | 説明 |
|----------|------|------|
| `value` | `T?` | 現在の値 |
| `state` | `AsyncState<T>` | 状態（switch用） |
| `isLoading` | `Bool` | ローディング中か |
| `hasValue` | `Bool` | 値が存在するか |
| `error` | `StateError?` | エラー |

### データのロード

```swift
// 非同期操作を実行
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

### Viewでの使用

```swift
struct ProfileView: View {
    @Environment(ProfileStore.self) private var store

    var body: some View {
        VStack {
            switch store.state {
            case .idle:
                Text("データ未取得")
                Button("取得") {
                    Task {
                        await store.load {
                            try await api.fetchProfile()
                        }
                    }
                }

            case .loading(let previous):
                ProgressView()
                if let prev = previous {
                    Text("前回: \(prev.name)")
                        .foregroundStyle(.secondary)
                }

            case .loaded(let profile):
                Text("こんにちは、\(profile.name)さん")

            case .failed(let error):
                VStack {
                    Text("エラー: \(error.message)")
                    Button("再試行") {
                        Task { await store.reload { try await api.fetchProfile() } }
                    }
                }
            }
        }
    }
}
```

## 操作トラッキング

複数の操作を個別に追跡する場合は、`operations`パラメータを使用します：

```swift
enum DataOperation: String, CaseIterable, Sendable {
    case fetch, save, delete
}

@Statable([Item].self, operations: DataOperation.self)
@MainActor @Observable
final class ItemStore {
    public init() {}

    var isSaving: Bool {
        operations.isActive(.save)
    }
}
```

詳細は <doc:OperationTrackerGuide> を参照してください。

## 次のステップ

- <doc:AsyncStateGuide>: AsyncStateの詳細な使い方
- <doc:OperationTrackerGuide>: 複数操作の追跡方法
