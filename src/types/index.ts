/**
 * ILE-RPG コーディング標準チェッカー - 型定義
 */

// ============================================================================
// 基本型定義
// ============================================================================

/**
 * 問題の重要度
 */
export type Severity = 'error' | 'warning' | 'info';

/**
 * 問題のカテゴリ
 */
export type Category = 
  | 'structure'      // 構造的な問題
  | 'syntax'         // 文法的な問題
  | 'naming'         // 命名規約の問題
  | 'best-practice'  // ベストプラクティス違反
  | 'deprecated';    // 非推奨機能の使用

/**
 * チェックレベル
 */
export type CheckLevel = 'basic' | 'standard' | 'strict';

/**
 * 仕様書タイプ
 */
export type SpecificationType = 
  | 'H'        // 制御仕様書
  | 'F'        // ファイル記述仕様書
  | 'D'        // 定義仕様書
  | 'P'        // プロシージャ仕様書
  | 'I'        // 入力仕様書
  | 'C'        // 演算仕様書
  | 'O'        // 出力仕様書
  | 'FREE'     // 完全自由形式
  | 'COMMENT'  // コメント行
  | 'UNKNOWN'; // 不明

// ============================================================================
// 問題・結果関連の型定義
// ============================================================================

/**
 * 検出された問題の詳細
 */
export interface Issue {
  /** 重要度 */
  severity: Severity;
  /** カテゴリ */
  category: Category;
  /** 行番号（1始まり） */
  line: number;
  /** 開始桁位置（オプション） */
  column?: number;
  /** 終了桁位置（オプション） */
  endColumn?: number;
  /** 問題の説明メッセージ */
  message: string;
  /** ルールID */
  rule: string;
  /** ルールの詳細説明（オプション） */
  ruleDescription?: string;
  /** 修正提案（オプション） */
  suggestion?: string;
  /** 問題のあるコードスニペット（オプション、Before行） */
  codeSnippet?: string;
  /** 修正後のコード（オプション、After行 — codeSnippetとの対で提示） */
  correctedCode?: string;
}

/**
 * チェック結果のサマリー
 */
export interface Summary {
  /** 総問題数 */
  totalIssues: number;
  /** エラー数 */
  errors: number;
  /** 警告数 */
  warnings: number;
  /** 情報数 */
  infos: number;
  /** チェックした行数 */
  checkedLines: number;
  /** 仕様書タイプ別の行数 */
  specificationCounts: Record<SpecificationType, number>;
}

/**
 * チェック結果
 */
export interface CheckResult {
  /** チェックが成功したか（エラーがない場合true） */
  valid: boolean;
  /** 検出された問題のリスト */
  issues: Issue[];
  /** サマリー情報 */
  summary: Summary;
  /** チェックしたファイルパス（オプション） */
  filePath?: string;
}

// ============================================================================
// パーサー関連の型定義
// ============================================================================

/**
 * パース済み行情報
 */
export interface ParsedLine {
  /** 行番号（1始まり） */
  lineNumber: number;
  /** 元の行内容（改行なし） */
  rawContent: string;
  /** トリム済み行内容 */
  trimmedContent: string;
  /** 仕様書タイプ */
  specificationType: SpecificationType;
  /** コメント行かどうか */
  isComment: boolean;
  /** 継続行かどうか */
  isContinuation: boolean;
  /** 桁位置別のデータ（仕様書タイプに応じて） */
  columnData?: ColumnData;
}

/**
 * 桁位置別データ（仕様書タイプごとに異なる）
 */
export interface ColumnData {
  [key: string]: string | undefined;
}

/**
 * H仕様書の桁データ
 */
export interface HSpecColumnData extends ColumnData {
  keyword?: string;      // 7-80桁: キーワード
}

/**
 * F仕様書の桁データ
 */
export interface FSpecColumnData extends ColumnData {
  fileName?: string;     // 7-16桁: ファイル名
  fileType?: string;     // 17桁: ファイルタイプ
  fileDesignation?: string; // 18桁: ファイル指定
  endOfFile?: string;    // 19桁: ファイル終了
  fileAddition?: string; // 20桁: ファイル追加
  sequence?: string;     // 21桁: 順序
  fileFormat?: string;   // 22桁: ファイル形式
  recordLength?: string; // 23-27桁: レコード長
  limits?: string;       // 28桁: 制限処理
  lengthOfKey?: string;  // 29-33桁: キー長
  recordAddressType?: string; // 34桁: レコードアドレスタイプ
  fileOrganization?: string;  // 35桁: ファイル編成
  device?: string;       // 36-42桁: 装置
  keywords?: string;     // 44-80桁: キーワード
}

/**
 * D仕様書の桁データ
 *
 * RPG IV固定形式D仕様書の桁位置ルール:
 *   桁6:     仕様書種別 'D'
 *   桁7-21:  名前フィールド (15桁)
 *            - 宣言名(DS/PR/PI等): 桁7開始
 *            - サブフィールド: 桁8開始(1スペース後)
 *            - 無名行(継続行等): 全て空白
 *   桁22:    外部記述 (E/空白)
 *   桁23:    データ構造タイプ
 *   桁24-25: 宣言型 (PR/PI/DS/S/C/空白)
 *   桁26-32: From/To位置 (7桁)
 *   桁33-39: 内部長 (7桁、右詰め)
 *   桁40:    データ型 (A/B/C/D/F/G/I/N/O/P/S/T/U/Z/*)
 *   桁41-42: 小数桁 (右詰め)
 *   桁43-80: キーワード
 */
export interface DSpecColumnData extends ColumnData {
  name?: string;                    // 7-21桁: 名前 (15桁)
  externalDescription?: string;     // 22桁: 外部記述 (E/空白)
  dataStructureType?: string;       // 23桁: データ構造タイプ
  declarationType?: string;         // 24-25桁: 宣言型 (PR/PI/DS/S/C/空白)
  fromPosition?: string;            // 26-32桁: 開始位置 (7桁)
  toLength?: string;                // 33-39桁: 内部長/終了位置 (7桁、右詰め)
  dataType?: string;                // 40桁: データ型
  decimalPositions?: string;        // 41-42桁: 小数点以下桁数 (右詰め)
  keywords?: string;                // 43-80桁: キーワード
}

/**
 * P仕様書の桁データ
 */
export interface PSpecColumnData extends ColumnData {
  name?: string;         // 7-21桁: プロシージャ名
  beginEnd?: string;     // 24桁: B(開始)またはE(終了)
  keywords?: string;     // 44-80桁: キーワード
}

/**
 * C仕様書の桁データ
 */
export interface CSpecColumnData extends ColumnData {
  controlLevel?: string; // 7-8桁: 制御レベル
  indicators?: string;   // 9-17桁: 標識
  factor1?: string;      // 12-25桁: 因数1
  opcode?: string;       // 26-35桁: 命令コード
  factor2?: string;      // 36-49桁: 因数2
  result?: string;       // 50-63桁: 結果フィールド
  resultIndicators?: string; // 71-76桁: 結果標識
}

// ============================================================================
// ルール関連の型定義
// ============================================================================

/**
 * チェックコンテキスト
 */
export interface CheckContext {
  /** 全ての行 */
  allLines: ParsedLine[];
  /** 現在の行のインデックス */
  currentIndex: number;
  /** 前の仕様書タイプ */
  previousSpec?: SpecificationType;
  /** 自由形式内かどうか */
  inFreeForm: boolean;
  /** 自由形式のネスト深度 */
  freeFormDepth: number;
}

/**
 * ルール定義
 */
export interface Rule {
  /** ルールID */
  id: string;
  /** ルール名 */
  name: string;
  /** ルールの説明 */
  description: string;
  /** カテゴリ */
  category: Category;
  /** デフォルトの重要度 */
  severity: Severity;
  /** 適用されるチェックレベル */
  checkLevel: CheckLevel;
  /** チェック関数 */
  check: (line: ParsedLine, context: CheckContext) => Issue | null;
}

/**
 * ルールセット
 */
export interface RuleSet {
  /** ルールセット名 */
  name: string;
  /** ルールのリスト */
  rules: Rule[];
}

// ============================================================================
// チェッカー関連の型定義
// ============================================================================

/**
 * チェッカーインターフェース
 */
export interface Checker {
  /** チェッカー名 */
  name: string;
  /** チェック実行 */
  check(lines: ParsedLine[], checkLevel: CheckLevel): Issue[];
}

/**
 * チェッカーオプション
 */
export interface CheckerOptions {
  /** チェックレベル */
  checkLevel: CheckLevel;
  /** 特定のルールを無効化 */
  disabledRules?: string[];
  /** カスタムルール */
  customRules?: Rule[];
}

// ============================================================================
// ユーティリティ型
// ============================================================================

/**
 * ファイル情報
 */
export interface FileInfo {
  /** ファイルパス */
  path: string;
  /** ファイル内容 */
  content: string;
  /** エンコーディング */
  encoding?: string;
}

/**
 * Language type for internationalization
 */
export type Language = 'en' | 'ja';

/**
 * Check options
 */
export interface CheckOptions {
  /** Check level */
  checkLevel?: CheckLevel;
  /** Language for messages */
  language?: Language;
  /** Consider DBCS shift characters in length calculation */
  considerDBCS?: boolean;
  /** Custom rules configuration file path */
  customRulesPath?: string;
}

/**
 * レポートオプション
 */
export interface ReportOptions {
  /** 詳細表示 */
  verbose?: boolean;
  /** カラー出力 */
  color?: boolean;
  /** 出力形式 */
  format?: 'text' | 'json' | 'markdown';
  /** Language for report */
  language?: Language;
}