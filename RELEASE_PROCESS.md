# リリースプロセス

このドキュメントでは、swift-statable のリリース手順を説明します。

## 概要

リリースは GitHub Actions による自動化されたパイプラインで行われます：

1. リリースブランチ (`release/vX.Y.Z`) を作成
2. CHANGELOG.md を更新
3. Pull Request を作成してマージ
4. 自動的にタグ作成、GitHub Release 公開、次バージョンブランチ作成

## 詳細手順

### Phase 1: リリースブランチの準備

```bash
# 最新の main を取得
git checkout main
git pull origin main

# リリースブランチを作成
git checkout -b release/v1.0.1
```

### Phase 2: CHANGELOG の更新

1. `CHANGELOG.md` を開く
2. `[未リリース]` セクションの内容を新しいバージョンセクションに移動
3. リリース日を追加

```markdown
## [1.0.1] - 2025-12-28

### 追加
- 新機能の説明

### 修正
- バグ修正の説明
```

4. ファイル末尾の比較リンクを更新

```markdown
[未リリース]: https://github.com/no-problem-dev/swift-statable/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/no-problem-dev/swift-statable/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/no-problem-dev/swift-statable/releases/tag/v1.0.0
```

### Phase 3: テストの実行

```bash
# 全テストを実行
swift test

# 詳細出力で実行（オプション）
swift test --verbose
```

### Phase 4: Pull Request の作成

```bash
# 変更をコミット
git add CHANGELOG.md
git commit -m "chore: prepare release v1.0.1"

# リモートにプッシュ
git push origin release/v1.0.1
```

GitHub で Pull Request を作成：
- Base: `main`
- Compare: `release/v1.0.1`
- Title: `Release v1.0.1`

### Phase 5: 自動リリース

PR がマージされると、`auto-release-on-merge.yml` が以下を自動実行：

1. ブランチ名からバージョンを抽出
2. CHANGELOG.md のバージョンセクションを検証
3. Git タグを作成してプッシュ
4. GitHub Release を作成（CHANGELOG から生成されたノート付き）
5. 次のリリースブランチを自動作成
6. 次のリリース用ドラフト PR を作成

## バージョニング規則

[Semantic Versioning](https://semver.org/) に従います：

| 変更タイプ | バージョン | 例 |
|-----------|-----------|-----|
| 破壊的変更 | MAJOR | 1.0.0 → 2.0.0 |
| 新機能（後方互換） | MINOR | 1.0.0 → 1.1.0 |
| バグ修正 | PATCH | 1.0.0 → 1.0.1 |

### プレリリース

開発中のバージョンには接尾辞を付与：

- Alpha: `1.0.1-alpha.1`
- Beta: `1.0.1-beta.1`
- Release Candidate: `1.0.1-rc.1`

## 手動リリース（緊急時）

自動化が失敗した場合：

```bash
# タグを作成
git tag v1.0.1
git push origin v1.0.1

# GitHub Web UI でリリースを作成
```

## ロールバック

問題が発生した場合：

```bash
# ローカルタグを削除
git tag -d v1.0.1

# リモートタグを削除
git push origin :refs/tags/v1.0.1

# GitHub Web UI でリリースを削除
```

## チェックリスト

リリース前の確認事項：

- [ ] 全テストがパス
- [ ] CHANGELOG.md が更新済み
- [ ] バージョン番号が正しい
- [ ] 破壊的変更がある場合は MAJOR バージョンを上げている
- [ ] ドキュメントが最新
