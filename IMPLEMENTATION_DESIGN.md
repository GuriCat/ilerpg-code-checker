# ILE-RPG コーディング標準チェッカー - 実装設計書

## 1. アーキテクチャ概要

### 1.1 システム構成

```
┌─────────────────────────────────────────────────────────┐
│                    MCP Client (Bob)                      │
└─────────────────────┬───────────────────────────────────┘
                      │ MCP Protocol
┌─────────────────────▼───────────────────────────────────┐
│              RPG Standards Checker MCP Server            │
│  ┌───────────────────────────────────────────────────┐  │
│  │              Tool Interface Layer                  │  │
│  │  - check_rpg_code                                 │  │
│  │  - check_specification_order                      │  │
│  │  - check_column_positions                         │  │
│  │  - check_naming_conventions                       │  │
│  │  - check_best_practices                           │  │
│  │  - check_rpg_file                                 │  │
│  └───────────────────┬───────────────────────────────┘  │
│  ┌───────────────────▼───────────────────────────────┐  │
│  │           Orchestration Layer                      │  │
│  │  - Check level management (basic/standard/strict) │  │
│  │  - Result aggregation                             │  │
│  │  - Report generation                              │  │
│  └───────────────────┬───────────────────────────────┘  │
│  ┌───────────────────▼───────────────────────────────┐  │
│  │              Parser Layer                          │  │
│  │  - Line-by-line parsing                           │  │
│  │  - Specification type detection                   │  │
│  │  - Token extraction                               │  │
│  └───────────────────┬───────────────────────────────┘  │
│  ┌───────────────────▼───────────────────────────────┐  │
│  │              Checker Layer                         │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │ Structure Checker                           │  │  │
│  │  │ - Specification order                       │  │  │
│  │  │ - Column positions                          │  │  │
│  │  │ - Line length                               │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │ Syntax Checker                              │  │  │
│  │  │ - Line continuation                         │  │  │
│  │  │ - Multiple statements                       │  │  │
│  │  │ - FREE/END-FREE matching                    │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │ Naming Checker                              │  │  │
│  │  │ - Variable naming conventions               │  │  │
│  │  │ - Procedure naming conventions              │  │  │
│  │  │ - Special character restrictions            │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │ Best Practice Checker                       │  │  │
│  │  │ - Deprecated features                       │  │  │
│  │  │ - Indicator usage                           │  │  │
│  │  │ - FREE format recommendation                │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │ Common Errors Checker                       │  │  │
│  │  │ - F-spec space issues                       │  │  │
│  │  │ - D-spec column errors                      │  │  │
│  │  │ - Continuation errors                       │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │              Rules Engine                          │  │
│  │  - Rule definitions from standards document       │  │
│  │  - Rule evaluation logic                          │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 2. データ構造

### 2.1 コア型定義

```typescript
// 問題の重要度
type Severity = 'error' | 'warning' | 'info';

// 問題のカテゴリ
type Category = 
  | 'structure'      // 構造的な問題
  | 'syntax'         // 文法的な問題
  | 'naming'         // 命名規約の問題
  | 'best-practice'  // ベストプラクティス違反
  | 'deprecated';    // 非推奨機能の使用

// チェックレベル
type CheckLevel = 'basic' | 'standard' | 'strict';

// 仕様書タイプ
type SpecificationType = 
  | 'H'  // 制御仕様書
  | 'F'  // ファイル記述仕様書
  | 'D'  // 定義仕様書
  | 'P'  // プロシージャ仕様書
  | 'I'  // 入力仕様書
  | 'C'  // 演算仕様書
  | 'O'  // 出力仕様書
  | 'FREE'      // 完全自由形式
  | 'COMMENT'   // コメント行
  | 'UNKNOWN';  // 不明

// 問題の詳細
interface Issue {
  severity: Severity;
  category: Category;
  line: number;
  column?: number;
  endColumn?: number;
  message: string;
  rule: string;
  ruleDescription?: string;
  suggestion?: string;
  codeSnippet?: string;
}

// チェック結果のサマリー
interface Summary {
  totalIssues: number;
  errors: number;
  warnings: number;
  infos: number;
  checkedLines: number;
  specificationCounts: Record<SpecificationType, number>;
}

// チェック結果
interface CheckResult {
  valid: boolean;
  issues: Issue[];
  summary: Summary;
}

// パース済み行情報
interface ParsedLine {
  lineNumber: number;
  rawContent: string;
  trimmedContent: string;
  specificationType: SpecificationType;
  isComment: boolean;
  isContinuation: boolean;
  columnData?: {
    [key: string]: string;
  };
}
```

### 2.2 ルール定義

```typescript
interface Rule {
  id: string;
  name: string;
  description: string;
  category: Category;
  severity: Severity;
  checkLevel: CheckLevel;
  check: (line: ParsedLine, context: CheckContext) => Issue | null;
}

interface CheckContext {
  allLines: ParsedLine[];
  currentIndex: number;
  previousSpec?: SpecificationType;
  inFreeForm: boolean;
  freeFormDepth: number;
}
```

## 3. 主要コンポーネントの実装詳細

### 3.1 RPGParser (src/parser/rpg-parser.ts)

```typescript
class RPGParser {
  /**
   * RPGソースコードを行単位でパース
   */
  parse(code: string): ParsedLine[] {
    const lines = code.split('\n');
    const parsedLines: ParsedLine[] = [];
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const parsedLine = this.parseLine(line, i + 1);
      parsedLines.push(parsedLine);
    }
    
    return parsedLines;
  }
  
  /**
   * 1行をパース
   */
  private parseLine(line: string, lineNumber: number): ParsedLine {
    // 仕様書タイプの判定
    const specType = this.detectSpecificationType(line);
    
    // コメント行の判定
    const isComment = this.isCommentLine(line);
    
    // 継続行の判定
    const isContinuation = this.isContinuationLine(line, specType);
    
    // 桁データの抽出
    const columnData = this.extractColumnData(line, specType);
    
    return {
      lineNumber,
      rawContent: line,
      trimmedContent: line.trim(),
      specificationType: specType,
      isComment,
      isContinuation,
      columnData
    };
  }
  
  /**
   * 仕様書タイプを検出
   */
  private detectSpecificationType(line: string): SpecificationType {
    if (line.length < 6) return 'UNKNOWN';
    
    const col6 = line[5];
    
    // **FREE形式のチェック
    if (line.trim().startsWith('**FREE')) return 'FREE';
    
    // コメント行のチェック
    if (col6 === '*') return 'COMMENT';
    
    // 各仕様書タイプのチェック
    switch (col6.toUpperCase()) {
      case 'H': return 'H';
      case 'F': return 'F';
      case 'D': return 'D';
      case 'P': return 'P';
      case 'I': return 'I';
      case 'C': return 'C';
      case 'O': return 'O';
      default: return 'UNKNOWN';
    }
  }
  
  /**
   * コメント行かどうかを判定
   */
  private isCommentLine(line: string): boolean {
    if (line.length < 7) return false;
    return line[6] === '*';
  }
  
  /**
   * 継続行かどうかを判定
   */
  private isContinuationLine(line: string, specType: SpecificationType): boolean {
    if (line.length < 7) return false;
    
    // 桁固定形式の継続行判定
    if (specType !== 'FREE') {
      return line[6] === '-' || line[6] === '+';
    }
    
    return false;
  }
  
  /**
   * 桁データを抽出
   */
  private extractColumnData(line: string, specType: SpecificationType): Record<string, string> | undefined {
    // 仕様書タイプごとの桁位置定義に基づいてデータを抽出
    // 実装は仕様書タイプごとに異なる
    return undefined;
  }
}
```

### 3.2 StructureChecker (src/checkers/structure-checker.ts)

```typescript
class StructureChecker {
  /**
   * 仕様書の順序をチェック
   */
  checkSpecificationOrder(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    const expectedOrder = ['H', 'F', 'D', 'P', 'I', 'C', 'O'];
    let lastSpecIndex = -1;
    
    for (const line of lines) {
      if (line.isComment || line.specificationType === 'UNKNOWN') continue;
      
      const currentSpecIndex = expectedOrder.indexOf(line.specificationType);
      if (currentSpecIndex === -1) continue;
      
      if (currentSpecIndex < lastSpecIndex) {
        issues.push({
          severity: 'error',
          category: 'structure',
          line: line.lineNumber,
          message: `仕様書の順序が不正です。${line.specificationType}仕様書は${expectedOrder[lastSpecIndex]}仕様書の後に配置できません。`,
          rule: 'SPEC_ORDER',
          ruleDescription: '仕様書は H→F→D→P→I→C→O の順序で記述する必要があります。',
          suggestion: `${line.specificationType}仕様書を適切な位置に移動してください。`
        });
      }
      
      lastSpecIndex = currentSpecIndex;
    }
    
    return issues;
  }
  
  /**
   * 桁位置をチェック
   */
  checkColumnPositions(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    
    for (const line of lines) {
      if (line.isComment) continue;
      
      const columnIssues = this.checkLineColumnPositions(line);
      issues.push(...columnIssues);
    }
    
    return issues;
  }
  
  /**
   * 1行の桁位置をチェック
   */
  private checkLineColumnPositions(line: ParsedLine): Issue[] {
    const issues: Issue[] = [];
    
    switch (line.specificationType) {
      case 'H':
        return this.checkHSpecColumns(line);
      case 'F':
        return this.checkFSpecColumns(line);
      case 'D':
        return this.checkDSpecColumns(line);
      // 他の仕様書タイプも同様に実装
      default:
        return [];
    }
  }
  
  /**
   * H仕様書の桁位置チェック
   */
  private checkHSpecColumns(line: ParsedLine): Issue[] {
    // H仕様書の桁位置ルールに基づいてチェック
    // 6桁目: 'H'
    // 7-80桁目: キーワード
    return [];
  }
  
  /**
   * 行の長さをチェック
   */
  checkLineLength(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    const maxLength = 100;
    
    for (const line of lines) {
      if (line.rawContent.length > maxLength) {
        issues.push({
          severity: 'error',
          category: 'structure',
          line: line.lineNumber,
          column: maxLength + 1,
          message: `行の長さが制限を超えています（${line.rawContent.length}文字 > ${maxLength}文字）。`,
          rule: 'LINE_LENGTH',
          ruleDescription: '1行は最大100桁までです。',
          suggestion: '行を分割するか、継続行を使用してください。'
        });
      }
    }
    
    return issues;
  }
}
```

### 3.3 SyntaxChecker (src/checkers/syntax-checker.ts)

```typescript
class SyntaxChecker {
  /**
   * 行継続ルールをチェック
   */
  checkLineContinuation(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      
      if (line.isContinuation) {
        // 継続行の前の行が存在するかチェック
        if (i === 0) {
          issues.push({
            severity: 'error',
            category: 'syntax',
            line: line.lineNumber,
            column: 7,
            message: '継続行の前に継続元の行がありません。',
            rule: 'CONTINUATION_NO_PREVIOUS',
            suggestion: '継続行マーカー（-または+）を削除するか、前の行を追加してください。'
          });
        } else {
          const prevLine = lines[i - 1];
          
          // 前の行が同じ仕様書タイプかチェック
          if (prevLine.specificationType !== line.specificationType) {
            issues.push({
              severity: 'error',
              category: 'syntax',
              line: line.lineNumber,
              column: 7,
              message: `継続行の仕様書タイプ（${line.specificationType}）が前の行（${prevLine.specificationType}）と一致しません。`,
              rule: 'CONTINUATION_TYPE_MISMATCH'
            });
          }
        }
      }
    }
    
    return issues;
  }
  
  /**
   * 複数命令の1行記述をチェック
   */
  checkMultipleStatements(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    
    for (const line of lines) {
      // 桁固定形式・桁制限付き自由形式では1行に1命令のみ
      if (line.specificationType === 'C' && !line.isComment) {
        const semicolonCount = (line.rawContent.match(/;/g) || []).length;
        
        if (semicolonCount > 1) {
          issues.push({
            severity: 'error',
            category: 'syntax',
            line: line.lineNumber,
            message: '1行に複数の命令が記述されています。',
            rule: 'MULTIPLE_STATEMENTS',
            ruleDescription: '桁固定形式・桁制限付き自由形式では、1行に1つの命令のみ記述できます。',
            suggestion: '各命令を別々の行に分割してください。'
          });
        }
      }
    }
    
    return issues;
  }
  
  /**
   * /FREEと/END-FREEの対応をチェック
   */
  checkFreeFormMatching(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    const freeStack: number[] = [];
    
    for (const line of lines) {
      const trimmed = line.trimmedContent.toUpperCase();
      
      if (trimmed.startsWith('/FREE')) {
        freeStack.push(line.lineNumber);
      } else if (trimmed.startsWith('/END-FREE')) {
        if (freeStack.length === 0) {
          issues.push({
            severity: 'error',
            category: 'syntax',
            line: line.lineNumber,
            message: '対応する/FREEがない/END-FREEが見つかりました。',
            rule: 'UNMATCHED_END_FREE'
          });
        } else {
          freeStack.pop();
        }
      }
    }
    
    // 閉じられていない/FREEをチェック
    for (const lineNum of freeStack) {
      issues.push({
        severity: 'error',
        category: 'syntax',
        line: lineNum,
        message: '/FREEに対応する/END-FREEがありません。',
        rule: 'UNMATCHED_FREE'
      });
    }
    
    return issues;
  }
}
```

### 3.4 NamingChecker (src/checkers/naming-checker.ts)

```typescript
class NamingChecker {
  /**
   * 変数名の命名規約をチェック
   */
  checkVariableNaming(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    
    for (const line of lines) {
      if (line.specificationType !== 'D') continue;
      
      // D仕様書から変数名を抽出
      const varName = this.extractVariableName(line);
      if (!varName) continue;
      
      // 命名規約のチェック
      const namingIssues = this.validateVariableName(varName, line.lineNumber);
      issues.push(...namingIssues);
    }
    
    return issues;
  }
  
  /**
   * 変数名を抽出
   */
  private extractVariableName(line: ParsedLine): string | null {
    // D仕様書の7-21桁目から変数名を抽出
    if (line.rawContent.length < 21) return null;
    return line.rawContent.substring(6, 21).trim();
  }
  
  /**
   * 変数名を検証
   */
  private validateVariableName(name: string, lineNumber: number): Issue[] {
    const issues: Issue[] = [];
    
    // 1文字の変数名は避ける（ループカウンタを除く）
    if (name.length === 1 && !['I', 'J', 'K', 'X', 'Y', 'Z'].includes(name.toUpperCase())) {
      issues.push({
        severity: 'warning',
        category: 'naming',
        line: lineNumber,
        message: `変数名 '${name}' は短すぎます。より説明的な名前を使用してください。`,
        rule: 'VAR_NAME_TOO_SHORT',
        suggestion: '変数の目的を表す、より長い名前を使用してください。'
      });
    }
    
    // 特殊文字のチェック
    if (/[^A-Za-z0-9_#@$]/.test(name)) {
      issues.push({
        severity: 'error',
        category: 'naming',
        line: lineNumber,
        message: `変数名 '${name}' に使用できない文字が含まれています。`,
        rule: 'VAR_NAME_INVALID_CHARS',
        ruleDescription: '変数名には英数字、アンダースコア、#、@、$のみ使用できます。'
      });
    }
    
    // 数字で始まる名前のチェック
    if (/^[0-9]/.test(name)) {
      issues.push({
        severity: 'error',
        category: 'naming',
        line: lineNumber,
        message: `変数名 '${name}' は数字で始まっています。`,
        rule: 'VAR_NAME_STARTS_WITH_DIGIT',
        ruleDescription: '変数名は数字で始めることができません。'
      });
    }
    
    return issues;
  }
  
  /**
   * プロシージャ名の命名規約をチェック
   */
  checkProcedureNaming(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    
    for (const line of lines) {
      if (line.specificationType !== 'P') continue;
      
      // P仕様書からプロシージャ名を抽出
      const procName = this.extractProcedureName(line);
      if (!procName) continue;
      
      // 命名規約のチェック
      const namingIssues = this.validateProcedureName(procName, line.lineNumber);
      issues.push(...namingIssues);
    }
    
    return issues;
  }
  
  /**
   * プロシージャ名を抽出
   */
  private extractProcedureName(line: ParsedLine): string | null {
    // P仕様書の7-21桁目からプロシージャ名を抽出
    if (line.rawContent.length < 21) return null;
    return line.rawContent.substring(6, 21).trim();
  }
  
  /**
   * プロシージャ名を検証
   */
  private validateProcedureName(name: string, lineNumber: number): Issue[] {
    const issues: Issue[] = [];
    
    // プロシージャ名は動詞で始めることを推奨
    const verbPrefixes = ['get', 'set', 'calc', 'check', 'validate', 'process', 'update', 'delete', 'create', 'read', 'write'];
    const startsWithVerb = verbPrefixes.some(verb => name.toLowerCase().startsWith(verb));
    
    if (!startsWithVerb && name.length > 3) {
      issues.push({
        severity: 'info',
        category: 'naming',
        line: lineNumber,
        message: `プロシージャ名 '${name}' は動詞で始めることを推奨します。`,
        rule: 'PROC_NAME_VERB_PREFIX',
        suggestion: 'get, set, calc, check, validate, process などの動詞で始めてください。'
      });
    }
    
    return issues;
  }
}
```

### 3.5 BestPracticeChecker (src/checkers/best-practice-checker.ts)

```typescript
class BestPracticeChecker {
  /**
   * 非推奨機能の使用をチェック
   */
  checkDeprecatedFeatures(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    
    const deprecatedOps = ['GOTO', 'TAG', 'CABXX', 'CASXX', 'COMP', 'LOKUP', 'XFOOT', 'Z-ADD', 'Z-SUB'];
    
    for (const line of lines) {
      if (line.specificationType !== 'C') continue;
      
      const content = line.trimmedContent.toUpperCase();
      
      for (const op of deprecatedOps) {
        if (content.includes(op)) {
          issues.push({
            severity: 'warning',
            category: 'deprecated',
            line: line.lineNumber,
            message: `非推奨の命令 '${op}' が使用されています。`,
            rule: 'DEPRECATED_OPERATION',
            ruleDescription: `${op}は陳腐化した機能です。代替手段を使用してください。`,
            suggestion: this.getDeprecatedOpSuggestion(op)
          });
        }
      }
    }
    
    return issues;
  }
  
  /**
   * 非推奨命令の代替案を取得
   */
  private getDeprecatedOpSuggestion(op: string): string {
    const suggestions: Record<string, string> = {
      'GOTO': 'IF/ELSE/ENDIFやDOW/ENDDOなどの構造化命令を使用してください。',
      'TAG': 'GOTOの代わりに構造化命令を使用してください。',
      'CABXX': 'SELECT/WHEN/ENDSLを使用してください。',
      'CASXX': 'SELECT/WHEN/ENDSLを使用してください。',
      'COMP': '比較演算子（=, <, >, <=, >=, <>）を使用してください。',
      'LOKUP': '%LOOKUPまたは%SCANを使用してください。',
      'XFOOT': '%XFOOTを使用してください。',
      'Z-ADD': 'EVAL命令を使用してください。',
      'Z-SUB': 'EVAL命令を使用してください。'
    };
    
    return suggestions[op] || '代替手段を検討してください。';
  }
  
  /**
   * 数字付き標識の使用をチェック
   */
  checkIndicatorUsage(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    
    const indicatorPattern = /\*IN\d{2}/gi;
    
    for (const line of lines) {
      const matches = line.rawContent.match(indicatorPattern);
      
      if (matches) {
        issues.push({
          severity: 'warning',
          category: 'best-practice',
          line: line.lineNumber,
          message: `数字付き標識（${matches.join(', ')}）が使用されています。`,
          rule: 'NUMERIC_INDICATOR',
          ruleDescription: '数字付き標識の使用は避け、名前付きブール変数を使用してください。',
          suggestion: '意味のある名前のブール変数（IND型）を定義して使用してください。'
        });
      }
    }
    
    return issues;
  }
  
  /**
   * 完全自由形式の推奨
   */
  checkFreeFormRecommendation(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    
    // **FREEが使用されていない場合に推奨
    const hasFreeFormat = lines.some(line => 
      line.trimmedContent.toUpperCase().startsWith('**FREE')
    );
    
    if (!hasFreeFormat && lines.length > 10) {
      issues.push({
        severity: 'info',
        category: 'best-practice',
        line: 1,
        message: '完全自由形式（**FREE）の使用を推奨します。',
        rule: 'RECOMMEND_FREE_FORMAT',
        ruleDescription: '新規コードでは**FREE形式を使用することが推奨されます。',
        suggestion: 'ソースの先頭に**FREEを追加して、完全自由形式で記述してください。'
      });
    }
    
    return issues;
  }
}
```

## 4. MCPツールの実装

### 4.1 index.ts (メインエントリーポイント)

```typescript
#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { RPGParser } from "./parser/rpg-parser.js";
import { StructureChecker } from "./checkers/structure-checker.js";
import { SyntaxChecker } from "./checkers/syntax-checker.js";
import { NamingChecker } from "./checkers/naming-checker.js";
import { BestPracticeChecker } from "./checkers/best-practice-checker.js";
import { CommonErrorsChecker } from "./checkers/common-errors-checker.js";
import { CheckOrchestrator } from "./orchestrator.js";
import * as fs from 'fs';

const server = new McpServer({
  name: "rpg-standards-checker",
  version: "0.1.0"
});

const parser = new RPGParser();
const orchestrator = new CheckOrchestrator(
  parser,
  new StructureChecker(),
  new SyntaxChecker(),
  new NamingChecker(),
  new BestPracticeChecker(),
  new CommonErrorsChecker()
);

// ツール1: RPGコードの全体チェック
server.tool(
  "check_rpg_code",
  {
    code: z.string().describe("チェックするRPGソースコード"),
    checkLevel: z.enum(['basic', 'standard', 'strict'])
      .optional()
      .default('standard')
      .describe("チェックレベル: basic（基本）, standard（標準）, strict（厳格）")
  },
  async ({ code, checkLevel }) => {
    try {
      const result = orchestrator.checkCode(code, checkLevel);
      
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(result, null, 2)
          }
        ]
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: `エラー: ${error instanceof Error ? error.message : String(error)}`
          }
        ],
        isError: true
      };
    }
  }
);

// ツール2: 仕様書順序のチェック
server.tool(
  "check_specification_order",
  {
    code: z.string().describe("チェックするRPGソースコード")
  },
  async ({ code }) => {
    try {
      const lines = parser.parse(code);
      const checker = new StructureChecker();
      const issues = checker.checkSpecificationOrder(lines);
      
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              valid: issues.length === 0,
              issues
            }, null, 2)
          }
        ]
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: `エラー: ${error instanceof Error ? error.message : String(error)}`
          }
        ],
        isError: true
      };
    }
  }
);

// ツール3: 桁位置のチェック
server.tool(
  "check_column_positions",
  {
    code: z.string().describe("チェックするRPGソースコード")
  },
  async ({ code }) => {
    try {
      const lines = parser.parse(code);
      const checker = new StructureChecker();
      const issues = checker.checkColumnPositions(lines);
      
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              valid: issues.length === 0,
              issues
            }, null, 2)
          }
        ]
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: `エラー: ${error instanceof Error ? error.message : String(error)}`
          }
        ],
        isError: true
      };
    }
  }
);

// ツール4: 命名規約のチェック
server.tool(
  "check_naming_conventions",
  {
    code: z.string().describe("チェックするRPGソースコード")
  },
  async ({ code }) => {
    try {
      const lines = parser.parse(code);
      const checker = new NamingChecker();
      const varIssues = checker.checkVariableNaming(lines);
      const procIssues = checker.checkProcedureNaming(lines);
      const issues = [...varIssues, ...procIssues];
      
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              valid: issues.length === 0,
              issues
            }, null, 2)
          }
        ]
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: `エラー: ${error instanceof Error ? error.message : String(error)}`
          }
        ],
        isError: true
      };
    }
  }
);

// ツール5: ベストプラクティスのチェック
server.tool(
  "check_best_practices",
  {
    code: z.string().describe("チェックするRPGソースコード")
  },
  async ({ code }) => {
    try {
      const lines = parser.parse(code);
      const checker = new BestPracticeChecker();
      const deprecatedIssues = checker.checkDeprecatedFeatures(lines);
      const indicatorIssues = checker.checkIndicatorUsage(lines);
      const freeFormIssues = checker.checkFreeFormRecommendation(lines);
      const issues = [...deprecatedIssues, ...indicatorIssues, ...freeFormIssues];
      
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              valid: issues.length === 0,
              issues
            }, null, 2)
          }
        ]
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: `エラー: ${error instanceof Error ? error.message : String(error)}`
          }
        ],
        isError: true
      };
    }
  }
);

// ツール6: ファイル単位のチェック
server.tool(
  "check_rpg_file",
  {
    filePath: z.string().describe("チェックするRPGファイルのパス"),
    checkLevel: z.enum(['basic', 'standard', 'strict'])
      .optional()
      .default('standard')
      .describe("チェックレベル: basic（基本）, standard（標準）, strict（厳格）")
  },
  async ({ filePath, checkLevel }) => {
    try {
      // ファイルを読み込み
      const code = fs.readFileSync(filePath, 'utf-8');
      
      // チェック実行
      const result = orchestrator.checkCode(code, checkLevel);
      
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              ...result,
              filePath
            }, null, 2)
          }
        ]
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: `エラー: ${error instanceof Error ? error.message : String(error)}`
          }
        ],
        isError: true
      };
    }
  }
);

// サーバー起動
const transport = new StdioServerTransport();
await server.connect(transport);
console.error('RPG Standards Checker MCP server running on stdio');
```

## 5. チェックレベルの定義

### 5.1 Basic（基本）
- 仕様書の順序
- 重大な文法エラー
- 行の長さ制限

### 5.2 Standard（標準）
- Basicの全て
- 桁位置ルール
- 行継続ルール
- 複数命令チェック
- よくあるエラー

### 5.3 Strict（厳格）
- Standardの全て
- 命名規約
- ベストプラクティス
- 非推奨機能の使用
- コーディングスタイル

## 6. 今後の拡張可能性

### 6.1 追加機能候補
- 自動修正機能（可能な問題の自動修正）
- カスタムルールの定義
- チーム固有の規約の追加
- レポート出力形式の選択（JSON, HTML, Markdown）
- CI/CDパイプラインとの統合

### 6.2 パフォーマンス最適化
- 大規模ファイルの並列処理
- インクリメンタルチェック
- キャッシング機構

## 7. テスト戦略

### 7.1 ユニットテスト
- 各チェッカーの個別テスト
- パーサーのテスト
- ルールエンジンのテスト

### 7.2 統合テスト
- 実際のRPGコードを使用したテスト
- エッジケースのテスト
- パフォーマンステスト

### 7.3 テストデータ
- 正常なコードサンプル
- 各種エラーを含むコードサンプル
- 実際のプロジェクトからのコード

## 8. ドキュメント

### 8.1 ユーザードキュメント
- インストールガイド
- 使用方法
- チェックルールの説明
- トラブルシューティング

### 8.2 開発者ドキュメント
- アーキテクチャ説明
- 新規ルールの追加方法
- コントリビューションガイド