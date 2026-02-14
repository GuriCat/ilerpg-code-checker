# ILE-RPG コード・チェッカー

ILE-RPGコードの文法とコーディング標準に準拠しているかを簡易的にチェックするMCPサーバーです。

## 概要

このMCPサーバーは、ILE-RPGのソースコードを解析し、以下のような問題を検出します：

- 仕様書の順序エラー
- 桁位置ルール違反
- 行継続の誤り
- 命名規約違反
- 非推奨機能の使用
- ベストプラクティス違反

## 機能

### チェック機能

1. **構造チェック**
   - 仕様書の順序（H→F→D→P→I→C→O）、Pプロシージャセクション対応
   - 各仕様書の桁位置ルール（H/F/D/P/C）
   - D仕様書の高度な検証（名前継続`...`、宣言タイプ配置、末尾ピリオド検出）
   - 行の長さ制限（最大100桁）
   - DBCS（2バイト文字セット）サポート（シフト文字考慮）

2. **文法チェック**
   - 行継続ルールの検証
   - 複数命令の1行記述禁止
   - /FREE と /END-FREE の対応
   - **FREE形式の正しい使用
   - 括弧・文字列リテラルの整合性チェック

3. **命名規約チェック**
   - 変数名、プロシージャ名の規約
   - 特殊文字の使用制限
   - 意味のある名前の推奨
   - 予約語チェック（strictレベル）

4. **ベストプラクティスチェック**
   - 16種の非推奨機能の検出（GOTO、TAG、MOVE、MOVEL、Z-ADD、Z-SUB等）
   - 数字付き標識（*IN01-*IN99）の使用警告
   - 完全自由形式の推奨
   - カスタムルールサポート

5. **よくあるエラー検出**
   - F仕様書のスペース不足
   - D仕様書の桁位置エラー（カラムシフト・ヒューリスティクス含む）
   - 継続行の誤り

### チェックレベル

- **basic**: 基本的なチェック（仕様書順序、重大な文法エラー）
- **standard**: 標準チェック（basicに加えて桁位置、行継続など）
- **strict**: 厳格チェック（standardに加えて命名規約、ベストプラクティス）

### 多言語サポート

- **英語 (en)**: デフォルト言語
- **日本語 (ja)**: すべてのメッセージとレポートで完全な日本語サポート

### DBCSサポート

`considerDBCS`オプションを有効にすると、DBCS文字列（日本語、中国語、韓国語）で使用されるシフトイン（SI）とシフトアウト（SO）文字を考慮します。これにより、DBCS文字が存在する場合でも正確な桁位置検証が可能になります。

### カスタムルール

ユーザーはJSONファイルでカスタムベストプラクティスルールを定義できます。ルールは以下をサポート：
- パターンベースのマッチング（正規表現）
- カスタム重要度レベル
- 有効/無効機能
- ルールの説明と提案

## インストール

### 前提条件

- Node.js 18以上
- npm

### セットアップ

1. 依存関係のインストール：

```bash
cd /path/to/ilerpg-code-checker
npm install
```

2. ビルド：

```bash
npm run build
```

3. MCP設定ファイルへの追加：

#### IBM Bob IDE の場合

`c:\Users\user\AppData\Roaming\Bob-IDE\User\globalStorage\ibm.bob-code\settings\mcp_settings.json` に以下を追加：

```json
{
  "mcpServers": {
    "ilerpg-code-checker": {
      "command": "node",
      "args": ["<プロジェクトへのパス>\\build\\index.js"],
      "disabled": false,
      "alwaysAllow": [],
      "disabledTools": []
    }
  }
}
```

#### Claude Desktop の場合

Claude Desktop の MCP 設定ファイル（通常、macOS では `~/Library/Application Support/Claude/claude_desktop_config.json`、Windows では `%APPDATA%\Claude\claude_desktop_config.json`）に以下を追加：

```json
{
  "mcpServers": {
    "ilerpg-code-checker": {
      "command": "node",
      "args": ["<プロジェクトへのパス>/build/index.js"]
    }
  }
}
```

#### Cline (VS Code 拡張機能) の場合

VS Code の Cline MCP 設定に以下を追加：

```json
{
  "mcpServers": {
    "ilerpg-code-checker": {
      "command": "node",
      "args": ["<プロジェクトへのパス>/build/index.js"]
    }
  }
}
```

**注意:** `<プロジェクトへのパス>` を ilerpg-code-checker ディレクトリへの実際の絶対パスに置き換えてください。

## 使用方法

### MCPツール

**トークン効率化に関する注意:** ファイルをチェックする場合は、`check_rpg_code`よりも`check_rpg_file`の使用を推奨します。`check_rpg_file`ツールはサーバー側でファイルを直接読み込むため、`check_rpg_code`でコード全体を渡す場合と比較してトークン使用量を大幅に削減できます。特に大きなファイルや複数のファイルをチェックする場合に重要です。

#### 1. check_rpg_code

RPGソースコード全体をチェックします。**注意:** トークン効率を向上させるため、ファイルをチェックする場合は`check_rpg_file`の使用を検討してください。

```typescript
use_mcp_tool({
  server_name: "ilerpg-code-checker",
  tool_name: "check_rpg_code",
  arguments: {
    code: "H DFTACTGRP(*NO)\n...",
    checkLevel: "standard",  // "basic" | "standard" | "strict"
    language: "ja",          // "en" | "ja"
    considerDBCS: false,     // DBCS シフト文字を考慮する場合は true
    customRulesPath: "./custom-rules.json"  // オプション
  }
})
```

**戻り値:**
```json
{
  "valid": false,
  "issues": [
    {
      "severity": "error",
      "category": "structure",
      "line": 10,
      "column": 7,
      "message": "仕様書の順序が不正です...",
      "rule": "SPEC_ORDER",
      "suggestion": "..."
    }
  ],
  "summary": {
    "totalIssues": 5,
    "errors": 2,
    "warnings": 2,
    "infos": 1,
    "checkedLines": 100
  }
}
```

#### 2. check_specification_order

仕様書の順序のみをチェックします。

```typescript
use_mcp_tool({
  server_name: "ilerpg-code-checker",
  tool_name: "check_specification_order",
  arguments: {
    code: "H DFTACTGRP(*NO)\n...",
    language: "ja"  // "en" | "ja"
  }
})
```

#### 3. check_column_positions

桁位置ルールをチェックします。

```typescript
use_mcp_tool({
  server_name: "ilerpg-code-checker",
  tool_name: "check_column_positions",
  arguments: {
    code: "H DFTACTGRP(*NO)\n...",
    language: "ja",       // "en" | "ja"
    considerDBCS: false   // DBCS シフト文字を考慮する場合は true
  }
})
```

#### 4. check_naming_conventions

命名規約をチェックします。

```typescript
use_mcp_tool({
  server_name: "ilerpg-code-checker",
  tool_name: "check_naming_conventions",
  arguments: {
    code: "D MyVar           S             10A\n...",
    language: "ja"  // "en" | "ja"
  }
})
```

#### 5. check_best_practices

ベストプラクティスをチェックします。

```typescript
use_mcp_tool({
  server_name: "ilerpg-code-checker",
  tool_name: "check_best_practices",
  arguments: {
    code: "C                   GOTO      Label\n...",
    language: "ja",                         // "en" | "ja"
    customRulesPath: "./custom-rules.json"  // オプション
  }
})
```

#### 6. check_rpg_file

ファイル単位でチェックします。**推奨:** このツールは、サーバー側でファイルを直接読み込むため、`check_rpg_code`よりもトークン使用量を削減できます。

```typescript
use_mcp_tool({
  server_name: "ilerpg-code-checker",
  tool_name: "check_rpg_file",
  arguments: {
    filePath: "//your-server/path/to/your-file.rpg",
    checkLevel: "standard",
    language: "ja",          // "en" | "ja"
    considerDBCS: false,     // DBCS シフト文字を考慮する場合は true
    customRulesPath: "./custom-rules.json"  // オプション
  }
})
```

## カスタムルール

JSONファイルを作成してカスタムベストプラクティスルールを定義できます：

```json
{
  "rules": [
    {
      "id": "no-select-all",
      "name": "SELECT * を避ける",
      "description": "SELECT * の使用は推奨されません",
      "pattern": "SELECT\\s+\\*",
      "severity": "warning",
      "suggestion": "カラム名を明示的に指定してください",
      "enabled": true
    },
    {
      "id": "require-error-handling",
      "name": "エラー処理必須",
      "description": "すべてのファイル操作にはエラー処理が必要です",
      "pattern": "CHAIN|READ|WRITE|UPDATE|DELETE",
      "severity": "info",
      "suggestion": "%ERROR または *IN99 でエラー処理を追加してください",
      "enabled": true
    }
  ]
}
```

### カスタムルールのプロパティ

- `id`: ルールの一意識別子
- `name`: 表示名
- `description`: 詳細説明
- `pattern`: マッチする正規表現パターン
- `severity`: "error" | "warning" | "info"
- `suggestion`: 問題を修正するための推奨事項
- `enabled`: true | false

## 検出される問題の例

### 構造エラー

```text
F仕様書
H仕様書  ← エラー: H仕様書はF仕様書より前に配置する必要があります
```

### 桁位置エラー

```text
D MyVariable    S             10A  ← エラー: 変数名が正しい桁位置にありません
```

### 行継続エラー

```text
D MyLongVariableName
D-                    S             10A  ← エラー: 継続行の仕様書タイプが一致しません
```

### 命名規約違反

```text
D x               S             10A  ← 警告: 変数名が短すぎます
D 1stVar          S             10A  ← エラー: 変数名は数字で始められません
```

### 非推奨機能

```text
C                   GOTO      Label  ← 警告: GOTOは非推奨です
C     Label        TAG
```

### DBCS の例

`considerDBCS: true` の場合：

```text
D MyVar           S             10A   INZ('日本語')
  ↑ 桁位置チェックでシフト文字を正しく考慮します
```

## 開発

### プロジェクト構造

```
ilerpg-code-checker/
├── package.json
├── tsconfig.json
├── README.md                 # ドキュメント（英語）
├── README.ja.md              # ドキュメント（日本語）
├── DESIGN.md                 # アーキテクチャ・設計ドキュメント
├── custom-rules.example.json # カスタムルールの例
├── src/
│   ├── index.ts              # MCP サーバーエントリーポイント
│   ├── orchestrator.ts       # チェックオーケストレーション
│   ├── parser/
│   │   ├── rpg-parser.ts     # RPG コードパーサー
│   │   └── line-analyzer.ts  # 行解析
│   ├── checkers/
│   │   ├── structure-checker.ts     # 仕様書順序・桁位置検証
│   │   ├── syntax-checker.ts        # 文法・書式検証
│   │   ├── naming-checker.ts        # 命名規約検証
│   │   ├── best-practice-checker.ts # 非推奨機能・ベストプラクティス
│   │   └── common-errors-checker.ts # よくあるエラーパターン
│   ├── i18n/
│   │   └── messages.ts       # 多言語メッセージ（en/ja）
│   ├── config/
│   │   └── custom-rules.ts   # カスタムルールマネージャー
│   ├── types/
│   │   └── index.ts          # 型定義
│   └── utils/
│       ├── file-reader.ts    # ファイルI/O操作
│       ├── reporter.ts       # レポートフォーマット
│       └── dbcs-helper.ts    # DBCS サポートユーティリティ
└── build/                    # コンパイル出力
```

### ビルド

```bash
npm run build
```

### 開発モード（自動ビルド）

```bash
npm run watch
```

## トラブルシューティング

### MCPサーバーが起動しない

1. Node.jsのバージョンを確認：`node --version`（18以上が必要）
2. ビルドが完了しているか確認：`build/index.js`が存在するか
3. MCP設定ファイルのパスが正しいか確認

### チェック結果が表示されない

1. ソースコードのエンコーディングを確認（UTF-8推奨）
2. ファイルパスが正しいか確認
3. MCPサーバーのログを確認

## ライセンス

MIT

## 作成者

guricat

## バージョン

0.0.7

## 更新履歴

### 0.0.7 (2026-02-12)
- WCA4iテストケースの偽陽性（false positive）を修正
- パーサーの継続行処理のロバスト性を改善
- Pプロシージャセクション内のSPEC_ORDER偽陽性を修正

### 0.0.6 (2026-02-12)
- D仕様書のPhase 9コンパイル検出項目を追加
- 名前継続構文（`...`）の処理
- 宣言タイプの誤配置検出（桁22-23 vs 正しい桁24-25）
- フィールド名末尾のピリオド検出（RNF0622/RNF0623）
- サイズフィールドへのキーワード混入を検出するカラムシフト・ヒューリスティクス

### 0.0.5 (2026-02-12)
- D仕様書の桁位置検証を強化
- 各仕様書のより堅牢な桁位置チェック
- エラーメッセージと提案の改善

### 0.0.4 (2026-01-25)
- 完全自由形式（**FREE）の検出
- ツール説明文のトークン効率改善
- 行長チェック前の**FREE検出を修正

### 0.0.3 (2026-01-25)
- 完全自由形式の検出サポートを追加
- ツール説明文のトークン効率改善
- 「ILE RPG Code Checker」に名称変更
- 起動メッセージにバージョン番号を追加

### 0.0.2 (2026-01-25)
- ドキュメントの更新
- タイトルを「ILE-RPG コーディング・チェッカー」から「ILE-RPG コード・チェッカー」に変更
- 説明文を「文法とコーディング標準」に更新
- 例示のセンシティブ情報をマスク
- DBCS の例を日本語変数名から INZ を使用する形式に修正

### 0.0.1 (2026-01-25)
- 初版リリース
- 基本的なチェック機能の実装
- 6つのMCPツールの提供
- 多言語サポート（英語/日本語）
- DBCS文字サポート
- カスタムルール機能

## 参考資料

- IBM i Information Center - ILE RPG Reference

## サポート

問題や質問がある場合は、プロジェクトのIssueトラッカーに報告してください。