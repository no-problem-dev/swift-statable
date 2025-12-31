# AsyncState ガイド

排他的な非同期状態表現の詳細な使い方を学びます。

## Overview

`AsyncState<T>`は、非同期でロードされる値の状態を排他的に表現するenumです。
SSOT（Single Source of Truth）原則に基づき、1つのenumで全ての状態を排他的に表現します。

## 状態の種類

```swift
public enum AsyncState<Value: Sendable>: Sendable {
    case idle                       // 初期状態
    case loading(previous: Value?)  // ロード中（前回の値を保持可能）
    case loaded(Value)              // ロード成功
    case failed(StateError)         // ロード失敗
}
```

### idle - 初期状態

まだデータがロードされていない状態です。アプリ起動直後や、
明示的にリセットした後の状態がこれに該当します。

```swift
if store.isIdle {
    Text("データ未取得")
}
```

### loading - ロード中

データを取得中の状態です。`previous`パラメータにより、
リロード時に前回の値を保持できます。これにより、
ローディング中も前回のデータを表示し続けるUXが可能になります。

```swift
case .loading(let previous):
    VStack {
        ProgressView()
        if let prev = previous {
            // リロード中も前回のデータを薄く表示
            ContentView(data: prev)
                .opacity(0.5)
        }
    }
```

### loaded - ロード成功

データの取得に成功した状態です。
値に直接アクセスできます。

```swift
case .loaded(let profile):
    ProfileView(profile: profile)
```

### failed - ロード失敗

エラーが発生した状態です。
`StateError`にはエラーの詳細情報が含まれます。

```swift
case .failed(let error):
    VStack {
        Image(systemName: "exclamationmark.triangle")
        Text(error.message)
        Button("再試行") {
            Task { await store.reload { ... } }
        }
    }
```

## 便利なプロパティ

`AsyncState`には状態を簡単に確認するためのプロパティがあります：

| プロパティ | 説明 |
|----------|------|
| `value` | 現在の値（`loaded`または`loading`の`previous`） |
| `isLoading` | `loading`状態かどうか |
| `isIdle` | `idle`状態かどうか |
| `isFailed` | `failed`状態かどうか |
| `hasValue` | `loaded`状態かどうか |
| `error` | エラー（`failed`状態の場合のみ） |

## AsyncValue

`AsyncValue<T>`は、`AsyncState<T>`を内部で保持する`@Observable`なラッパークラスです。
`@Statable`マクロはこれを内部で使用しています。

### 状態遷移メソッド

```swift
// 値を設定（loaded状態に遷移）
store.set(newProfile)

// エラーを設定（failed状態に遷移）
store.setError(StateError(code: "NOT_FOUND", message: "見つかりません"))

// ローディング開始（loading状態に遷移）
store.startLoading()

// 初期状態にリセット（idle状態に遷移）
store.reset()
```

### 便利メソッド

```swift
// 非同期操作を実行し、結果を状態に反映
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

## ベストプラクティス

### switch文での完全なハンドリング

全ての状態を明示的にハンドリングすることで、
状態の漏れを防ぎます：

```swift
switch store.state {
case .idle:
    // 初期表示
case .loading(let previous):
    // ローディング表示（前回の値があれば利用）
case .loaded(let value):
    // メインコンテンツ
case .failed(let error):
    // エラー表示とリトライUI
}
```

### 条件付きレンダリング

簡単な条件分岐には便利プロパティを使用：

```swift
if store.isLoading {
    ProgressView()
}

if let profile = store.value {
    Text(profile.name)
}
```

## 関連項目

- ``AsyncState``
- ``AsyncValue``
- ``StateError``
