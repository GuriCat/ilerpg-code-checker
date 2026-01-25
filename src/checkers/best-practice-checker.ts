/**
 * ILE-RPG Coding Standards Checker - Best Practice Checker
 * Checks best practices such as deprecated features, indicator usage, and structured programming
 */

import { ParsedLine, Issue, CheckLevel, Checker } from '../types/index.js';
import { LineAnalyzer } from '../parser/line-analyzer.js';
import { CustomRulesManager } from '../config/custom-rules.js';

/**
 * Best Practice Checker class
 * Detects best practice issues in RPG code
 */
export class BestPracticeChecker implements Checker {
  name = 'BestPracticeChecker';
  private analyzer: LineAnalyzer;
  private customRulesManager?: CustomRulesManager;

  constructor(customRulesPath?: string) {
    this.analyzer = new LineAnalyzer();
    if (customRulesPath) {
      try {
        this.customRulesManager = new CustomRulesManager(customRulesPath);
      } catch (error) {
        console.error('Failed to load custom rules:', error);
      }
    }
  }

  /**
   * Execute best practice checks
   * @param lines Parsed lines array
   * @param checkLevel Check level
   * @returns Detected issues array
   */
  check(lines: ParsedLine[], checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    // Check deprecated features
    issues.push(...this.checkDeprecatedFeatures(lines));

    // Check indicator usage (standard level and above)
    if (checkLevel !== 'basic') {
      issues.push(...this.checkIndicatorUsage(lines));
    }

    // Recommend fully free format (strict level)
    if (checkLevel === 'strict') {
      issues.push(...this.recommendFullyFreeFormat(lines));
    }

    // Check structured programming (standard level and above)
    if (checkLevel !== 'basic') {
      issues.push(...this.checkStructuredProgramming(lines));
    }

    // Check custom rules if available
    if (this.customRulesManager) {
      for (const line of lines) {
        issues.push(...this.customRulesManager.checkLine(line));
      }
    }

    return issues;
  }

  /**
   * 非推奨機能の使用をチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkDeprecatedFeatures(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    // 非推奨命令のリスト
    const deprecatedOpcodes = [
      { code: 'GOTO', reason: '構造化プログラミングに反する', alternative: 'IF/ELSE、DO/ENDDOなどの構造化命令を使用' },
      { code: 'TAG', reason: 'GOTOと共に使用される非推奨機能', alternative: '構造化命令を使用' },
      { code: 'CABXX', reason: '古い比較命令', alternative: 'IF文を使用' },
      { code: 'CASXX', reason: '古い比較命令', alternative: 'SELECT/WHENを使用' },
      { code: 'COMP', reason: '古い比較命令', alternative: 'IF文を使用' },
      { code: 'LOKUP', reason: '古い検索命令', alternative: '%LOOKUPまたは%SCANを使用' },
      { code: 'XFOOT', reason: '古い集計命令', alternative: 'DOループと加算を使用' },
      { code: 'Z-ADD', reason: '古い代入命令', alternative: 'EVAL文を使用' },
      { code: 'Z-SUB', reason: '古い減算命令', alternative: 'EVAL文を使用' },
      { code: 'MOVE', reason: '古い移動命令', alternative: 'EVAL文を使用' },
      { code: 'MOVEL', reason: '古い移動命令', alternative: 'EVAL文を使用' },
      { code: 'MHHZO', reason: '古い移動命令', alternative: 'EVAL文を使用' },
      { code: 'MHLZO', reason: '古い移動命令', alternative: 'EVAL文を使用' },
      { code: 'MLHZO', reason: '古い移動命令', alternative: 'EVAL文を使用' },
      { code: 'MLLZO', reason: '古い移動命令', alternative: 'EVAL文を使用' }
    ];

    for (const line of lines) {
      if (line.specificationType !== 'C' || line.isComment) continue;

      const opcode = this.analyzer.extractOpcode(line);
      if (!opcode) continue;

      // 非推奨命令のチェック
      for (const deprecated of deprecatedOpcodes) {
        if (opcode.toUpperCase().includes(deprecated.code)) {
          issues.push({
            severity: 'warning',
            category: 'deprecated',
            line: line.lineNumber,
            column: 26,
            endColumn: 35,
            message: `非推奨命令 '${deprecated.code}' が使用されています。${deprecated.reason}。`,
            rule: 'DEPRECATED_OPCODE',
            ruleDescription: `${deprecated.code}命令は非推奨です。`,
            suggestion: deprecated.alternative,
            codeSnippet: line.rawContent
          });
          break;
        }
      }
    }

    return issues;
  }

  /**
   * 標識の使用をチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkIndicatorUsage(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    // *INxx形式の標識を検索
    const indicatorLines = this.analyzer.findIndicatorUsage(lines);

    for (const line of indicatorLines) {
      // 標識のパターンを抽出
      const matches = line.rawContent.match(/\*IN(\d{2})/gi);
      if (!matches) continue;

      for (const match of matches) {
        const indicatorNum = match.substring(3);
        
        issues.push({
          severity: 'warning',
          category: 'best-practice',
          line: line.lineNumber,
          message: `数字付き標識 '${match}' の使用は避けるべきです。`,
          rule: 'INDICATOR_USAGE',
          ruleDescription: '数字付き標識（*IN01-*IN99）は可読性を低下させます。',
          suggestion: '名前付き標識（論理変数）を使用してください（例: isValid, hasError）。',
          codeSnippet: line.rawContent
        });
      }
    }

    return issues;
  }

  /**
   * 完全自由形式（**FREE）の推奨
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private recommendFullyFreeFormat(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    // **FREEの使用状況をチェック
    let hasFullyFree = false;
    let hasFixedFormat = false;

    for (const line of lines) {
      if (line.specificationType === 'FREE') {
        hasFullyFree = true;
      } else if (['H', 'F', 'D', 'P', 'C', 'I', 'O'].includes(line.specificationType) && !line.isComment) {
        hasFixedFormat = true;
      }
    }

    // 桁固定形式のみの場合、**FREEを推奨
    if (!hasFullyFree && hasFixedFormat) {
      issues.push({
        severity: 'info',
        category: 'best-practice',
        line: 1,
        message: '完全自由形式（**FREE）の使用を推奨します。',
        rule: 'RECOMMEND_FULLY_FREE',
        ruleDescription: '**FREE形式は、より読みやすく、保守しやすいコードを実現します。',
        suggestion: 'ファイルの先頭に**FREEを追加し、コードを自由形式に変換してください。'
      });
    }

    return issues;
  }

  /**
   * 構造化プログラミングのチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkStructuredProgramming(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    // GOTOの使用をチェック（既に非推奨機能でチェック済みだが、追加の警告）
    for (const line of lines) {
      if (line.specificationType !== 'C' || line.isComment) continue;

      const opcode = this.analyzer.extractOpcode(line);
      if (!opcode) continue;

      // GOTOの使用
      if (opcode.toUpperCase().includes('GOTO')) {
        issues.push({
          severity: 'error',
          category: 'best-practice',
          line: line.lineNumber,
          column: 26,
          endColumn: 35,
          message: 'GOTO命令は構造化プログラミングに反します。',
          rule: 'NO_GOTO',
          ruleDescription: 'GOTO命令はコードの流れを複雑にし、保守性を低下させます。',
          suggestion: 'IF/ELSE、DO/ENDDO、SELECT/WHENなどの構造化命令を使用してください。',
          codeSnippet: line.rawContent
        });
      }
    }

    return issues;
  }

  /**
   * コメントの品質をチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkCommentQuality(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    let codeLineCount = 0;
    let commentLineCount = 0;

    for (const line of lines) {
      if (line.isComment) {
        commentLineCount++;
      } else if (line.specificationType !== 'UNKNOWN' && line.trimmedContent.length > 0) {
        codeLineCount++;
      }
    }

    // コメント率のチェック（10%未満の場合警告）
    if (codeLineCount > 0) {
      const commentRatio = commentLineCount / codeLineCount;
      if (commentRatio < 0.1) {
        issues.push({
          severity: 'info',
          category: 'best-practice',
          line: 1,
          message: `コメントが少なすぎます（コメント率: ${(commentRatio * 100).toFixed(1)}%）。`,
          rule: 'INSUFFICIENT_COMMENTS',
          ruleDescription: 'コードの可読性と保守性を向上させるため、適切なコメントを追加してください。',
          suggestion: '複雑なロジック、重要な処理、パラメータの説明などにコメントを追加してください。'
        });
      }
    }

    return issues;
  }

  /**
   * マジックナンバーのチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkMagicNumbers(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    // マジックナンバーのパターン（0, 1, -1以外の数値リテラル）
    const magicNumberPattern = /\b(?!0\b|1\b|-1\b)\d+\b/g;

    for (const line of lines) {
      if (line.isComment || line.specificationType === 'UNKNOWN') continue;

      const matches = line.rawContent.match(magicNumberPattern);
      if (matches && matches.length > 0) {
        issues.push({
          severity: 'info',
          category: 'best-practice',
          line: line.lineNumber,
          message: 'マジックナンバーが使用されています。定数として定義することを推奨します。',
          rule: 'MAGIC_NUMBER',
          ruleDescription: '数値リテラルを直接使用すると、その意味が不明確になります。',
          suggestion: 'D仕様書で定数を定義し、意味のある名前を付けてください。',
          codeSnippet: line.rawContent
        });
      }
    }

    return issues;
  }

  /**
   * プロシージャの長さをチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkProcedureLength(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    const maxProcedureLines = 100;

    let currentProcStart: number | null = null;
    let currentProcName: string | null = null;

    for (const line of lines) {
      if (line.specificationType === 'P') {
        const beginEnd = line.columnData?.beginEnd?.toUpperCase();
        const procName = line.columnData?.name;

        if (beginEnd === 'B' && procName) {
          // プロシージャ開始
          currentProcStart = line.lineNumber;
          currentProcName = procName;
        } else if (beginEnd === 'E' && currentProcStart !== null) {
          // プロシージャ終了
          const procLength = line.lineNumber - currentProcStart;
          
          if (procLength > maxProcedureLines) {
            issues.push({
              severity: 'warning',
              category: 'best-practice',
              line: currentProcStart,
              message: `プロシージャ '${currentProcName}' が長すぎます（${procLength}行）。`,
              rule: 'PROCEDURE_TOO_LONG',
              ruleDescription: `プロシージャは${maxProcedureLines}行以内に収めることを推奨します。`,
              suggestion: 'プロシージャを複数の小さなプロシージャに分割してください。'
            });
          }

          currentProcStart = null;
          currentProcName = null;
        }
      }
    }

    return issues;
  }
}