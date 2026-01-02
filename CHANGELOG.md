# Changelog

このプロジェクトのすべての注目すべき変更はこのファイルに記録されます。

フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/lang/ja/) に従います。

## [未リリース]

なし

## [1.0.2] - 2026-01-02

### 変更

- **Swift 6.2 対応**: Swift 6.2 安定版に対応
  - `swift-tools-version`: 6.0 → 6.2
  - `swift-syntax`: 600.0.0 → 602.0.0
  - 依存関係指定を `.upToNextMajor` に統一

## [1.0.1] - 2026-01-01

### 変更

- **@Statable マクロ**: `public init()` の自動生成を削除
  - `@Observable` マクロとの相互作用問題を回避するため
  - ユーザーが明示的に `public init() {}` を定義する必要あり
  - 依存性注入などカスタム初期化が可能に

## [1.0.0] - 2025-01-01

### 追加

- **@Statable マクロ**: 宣言的な状態管理マクロ
  - 単一の非同期値を管理するストアクラスを定義
  - `@MainActor @Observable` との統合
  - オプションの `operations` パラメータで操作トラッキングを追加

- **AsyncState<T>**: 排他的な非同期状態表現
  - `.idle`: 初期状態
  - `.loading(previous:)`: ロード中（前回の値を保持可能）
  - `.loaded(Value)`: ロード成功
  - `.failed(StateError)`: ロード失敗

- **AsyncValue<T>**: @Observable準拠の非同期値ラッパー
  - `value`, `state`, `isLoading`, `hasValue`, `error` などのプロパティ
  - `set(_:)`, `setError(_:)`, `startLoading()`, `reset()` などの状態遷移メソッド
  - `load(_:)`, `loadIfNeeded(_:)`, `reload(_:)` などの便利メソッド

- **OperationTracker<Op>**: 複数操作の並行追跡
  - `start(_:)`, `complete(_:)`, `fail(_:with:)` で操作ライフサイクル管理
  - `isActive(_:)`, `hasActiveOperations`, `error(for:)` で状態確認
  - `run(_:task:)` で自動的な操作追跡

- **StateError**: 構造化されたエラー情報
  - `code`, `message`, `underlying` プロパティ
  - `init(from: Error)` で標準Errorから変換

### ドキュメント

- README.md（日本語・英語）
- RELEASE_PROCESS.md

[未リリース]: https://github.com/no-problem-dev/swift-statable/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/no-problem-dev/swift-statable/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/no-problem-dev/swift-statable/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/no-problem-dev/swift-statable/releases/tag/v1.0.0

<!-- Auto-generated on 2025-12-31T22:22:38Z by release workflow -->

<!-- Auto-generated on 2025-12-31T23:01:32Z by release workflow -->

<!-- Auto-generated on 2026-01-02T07:16:00Z by release workflow -->
