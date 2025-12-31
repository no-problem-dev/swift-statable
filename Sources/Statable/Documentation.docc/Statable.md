# ``Statable``

SwiftUI向けの宣言的な状態管理マクロライブラリ。

@Metadata {
    @PageColor(blue)
}

## Overview

Statableは、SwiftUIアプリケーションで非同期状態を型安全に管理するためのライブラリです。
`@Statable`マクロにより、状態管理のボイラープレートを大幅に削減し、
`AsyncState<T>`enumで排他的な状態表現を実現します。

### 特徴

- **宣言的なマクロ**: `@Statable` マクロで状態管理コードを自動生成
- **排他的状態表現**: `AsyncState<T>` enumで `.idle`, `.loading`, `.loaded`, `.failed` を型安全に表現
- **操作トラッキング**: `OperationTracker` で複数の並行操作を個別に追跡
- **@Observable統合**: SwiftUIの `@Observable` と完全に統合
- **Sendable準拠**: Strict Concurrency対応

### 設計原則

**1 Store = 1 AsyncValue パターン**

各Storeは単一の型の非同期値を管理します。これにより状態の一貫性が保証され、
テストが容易になり、責務が明確になります。

**SSOT (Single Source of Truth)**

`AsyncState` enumは排他的な状態を表現し、矛盾した状態
（例：`isLoading = true` かつ `error != nil`）を型レベルで防ぎます。

### クイックスタート

```swift
import SwiftUI
import Statable

// シンプルなStore定義
@Statable(UserProfile.self)
@MainActor @Observable
final class ProfileStore {
    public init() {}

    // カスタムcomputed properties
    var displayName: String { value?.name ?? "ゲスト" }
}

// View側での使用
struct ProfileView: View {
    @Environment(ProfileStore.self) private var store

    var body: some View {
        switch store.state {
        case .idle:
            Text("データ未取得")
        case .loading:
            ProgressView()
        case .loaded(let profile):
            Text("こんにちは、\(profile.name)さん")
        case .failed(let error):
            Text("エラー: \(error.message)")
        }
    }
}
```

## Topics

### はじめに

- <doc:GettingStarted>

### @Statable マクロ

- ``Statable(_:)``
- ``Statable(_:operations:)``

### 状態管理

- ``AsyncState``
- ``AsyncValue``
- <doc:AsyncStateGuide>

### 操作トラッキング

- ``OperationTracker``
- <doc:OperationTrackerGuide>

### エラー処理

- ``StateError``

### プロトコル

- ``StatableProtocol``
