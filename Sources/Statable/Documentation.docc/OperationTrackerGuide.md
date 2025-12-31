# OperationTracker ガイド

複数の並行操作を個別に追跡する方法を学びます。

## Overview

`OperationTracker<Op>`は、複数の並行操作を個別に追跡するための状態管理クラスです。
例えば「データ取得中」と「保存中」を同時に追跡し、それぞれの状態に応じたUIを表示できます。

## 基本的な使い方

### 操作の定義

まず、追跡したい操作をenumで定義します：

```swift
enum DataOperation: String, CaseIterable, Sendable {
    case fetch      // データ取得
    case save       // 保存
    case delete     // 削除
}
```

### Storeへの組み込み

`@Statable`マクロの`operations`パラメータで操作型を指定します：

```swift
@Statable([Item].self, operations: DataOperation.self)
@MainActor @Observable
final class ItemStore {
    public init() {}
}
```

これにより、`operations`プロパティが自動生成されます。

## 操作ライフサイクル

### 手動管理

```swift
// 操作開始
store.operations.start(.fetch)

// 操作完了
store.operations.complete(.fetch)

// 操作失敗
store.operations.fail(.fetch, with: error)
```

### 自動管理（推奨）

`run`メソッドを使用すると、開始・完了・失敗を自動的に管理できます：

```swift
// 基本的な使い方
let result = await store.operations.run(.fetch) {
    try await api.fetchItems()
}

switch result {
case .success(let items):
    store.set(items)
case .failure(let error):
    // エラーハンドリング（既にoperationsにはエラーが記録されている）
}
```

### AsyncValueとの連携

`run(_:into:task:)`メソッドで、操作結果を直接AsyncValueに設定できます：

```swift
await store.operations.run(.fetch, into: store._asyncValue) {
    try await api.fetchItems()
}
// これにより、store.valueが自動的に更新される
```

## 状態の確認

### 個別の操作

```swift
// 特定の操作が実行中か
if store.operations.isActive(.save) {
    ProgressView("保存中...")
}

// 特定の操作のエラー
if let error = store.operations.error(for: .fetch) {
    Text("取得エラー: \(error.message)")
}
```

### 全体の状態

```swift
// いずれかの操作が実行中か
if store.operations.hasActiveOperations {
    // 何らかの処理中
}

// 実行中の操作一覧
for operation in store.operations.active {
    print("\(operation) is running")
}

// エラーがあるか
if store.operations.hasErrors {
    // エラー一覧を表示
    for (op, error) in store.operations.allErrors {
        print("\(op): \(error.message)")
    }
}
```

## エラー管理

```swift
// 特定の操作のエラーをクリア
store.operations.clearError(for: .fetch)

// 全てのエラーをクリア
store.operations.clearAllErrors()
```

## 実践的な例

### CRUDアプリケーション

```swift
enum TodoOperation: String, CaseIterable, Sendable {
    case fetch, create, update, delete
}

@Statable([Todo].self, operations: TodoOperation.self)
@MainActor @Observable
final class TodoStore {
    public init() {}

    var isModifying: Bool {
        operations.isActive(.create) ||
        operations.isActive(.update) ||
        operations.isActive(.delete)
    }
}

struct TodoListView: View {
    @Environment(TodoStore.self) private var store

    var body: some View {
        List {
            if store.operations.isActive(.fetch) {
                ProgressView("読み込み中...")
            }

            ForEach(store.value ?? []) { todo in
                TodoRow(todo: todo)
            }
            .deleteDisabled(store.isModifying)
        }
        .toolbar {
            if store.isModifying {
                ProgressView()
            }
        }
        .task {
            await store.operations.run(.fetch, into: store._asyncValue) {
                try await api.fetchTodos()
            }
        }
    }
}
```

### 複数の独立した操作

```swift
// 同時に複数の操作を実行
await withTaskGroup(of: Void.self) { group in
    group.addTask {
        await store.operations.run(.fetchProfile) {
            try await api.fetchProfile()
        }
    }
    group.addTask {
        await store.operations.run(.fetchSettings) {
            try await api.fetchSettings()
        }
    }
}
```

## ベストプラクティス

### 操作の粒度

操作は、UIで個別に状態を表示する必要があるかどうかで粒度を決めます：

```swift
// 良い例：UIで個別に表示が必要
enum GoodOperations {
    case fetchList      // リスト取得中
    case saveItem       // アイテム保存中
    case deleteItem     // アイテム削除中
}

// 悪い例：粒度が細かすぎる
enum BadOperations {
    case fetchListStart
    case fetchListProcess
    case fetchListComplete  // 状態遷移は自動管理されるべき
}
```

### エラーハンドリング

```swift
// 操作失敗時のリトライUI
if let error = store.operations.error(for: .fetch) {
    VStack {
        Text(error.message)
        Button("再試行") {
            store.operations.clearError(for: .fetch)
            Task {
                await store.operations.run(.fetch) { ... }
            }
        }
    }
}
```

## 関連項目

- ``OperationTracker``
- ``StateError``
- <doc:GettingStarted>
