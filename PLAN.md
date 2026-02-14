# Before/After 修正コード提示機能

## 変更概要
エラー検出時に `codeSnippet`（Before）と `correctedCode`（After）を対で提示する。

## 変更ファイル

### 1. `src/types/index.ts` — Issue インターフェースに `correctedCode` フィールド追加
### 2. `src/checkers/structure-checker.ts` — D/F/P仕様書の桁位置エラーで修正コード生成
### 3. `src/checkers/common-errors-checker.ts` — D仕様書桁ずれ、F仕様書スペーシングで修正コード生成
### 4. `src/checkers/syntax-checker.ts` — 修正コード生成可能なルールで対応
### 5. `src/utils/reporter.ts` — Before/After表示をMarkdown/Text出力に追加

## 修正コード生成対象ルール

| ルール | 修正方法 | 自動生成可否 |
|--------|----------|-------------|
| D_SPEC_DECL_TYPE_MISPLACED | col22-23のDS/PR/PIをcol24-25に移動 | ○ |
| D_SPEC_POINTER_POSITION | col39の`*`をcol40に移動 | ○ |
| D_SPEC_COLUMN_SHIFT | サイズフィールドの「数値+型」を分離 | ○ |
| D_SPEC_TRAILING_PERIOD | 名前末尾のピリオドを除去 | ○ |
| F_SPEC_SPACING | col17にスペース挿入 | ○ |
| SPEC_ORDER | 行移動が必要 → 提示不可 | × (sugestionのみ) |
| UNMATCHED_END_FREE | 行削除が必要 → 提示不可 | × |
| D_AFTER_C | 行移動が必要 → 提示不可 | × |
