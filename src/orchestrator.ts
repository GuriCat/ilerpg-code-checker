/**
 * ILE-RPG Coding Standards Checker - Orchestrator
 * Integrates all checkers and executes validation according to check level
 */

import { ParsedLine, CheckResult, CheckLevel, Issue, Summary, SpecificationType, CheckOptions } from './types/index.js';
import { RPGParser } from './parser/rpg-parser.js';
import { LineAnalyzer } from './parser/line-analyzer.js';
import { StructureChecker } from './checkers/structure-checker.js';
import { SyntaxChecker } from './checkers/syntax-checker.js';
import { NamingChecker } from './checkers/naming-checker.js';
import { BestPracticeChecker } from './checkers/best-practice-checker.js';
import { CommonErrorsChecker } from './checkers/common-errors-checker.js';

/**
 * Orchestrator class
 * Integrates all checkers and performs comprehensive code validation
 */
export class Orchestrator {
  private parser: RPGParser;
  private analyzer: LineAnalyzer;
  private considerDBCS: boolean;
  private customRulesPath?: string;

  constructor(options?: CheckOptions) {
    this.parser = new RPGParser();
    this.analyzer = new LineAnalyzer();
    this.considerDBCS = options?.considerDBCS || false;
    this.customRulesPath = options?.customRulesPath;
  }

  /**
   * Comprehensively check RPG code
   * @param code RPG source code
   * @param checkLevel チェックレベル
   * @param filePath ファイルパス（オプション）
   * @returns チェック結果
   */
  checkCode(code: string, checkLevel: CheckLevel = 'standard', filePath?: string): CheckResult {
    // コードをパース
    const lines = this.parser.parse(code);

    // 完全自由形式（**FREE）のチェック
    const hasFreeFormat = lines.some(line => line.specificationType === 'FREE');
    if (hasFreeFormat) {
      return {
        valid: false,
        issues: [{
          severity: 'error',
          category: 'structure',
          line: lines.findIndex(line => line.specificationType === 'FREE') + 1,
          column: 1,
          message: '完全自由形式（**FREE）のRPGコードは現在サポートされていません。',
          rule: 'UNSUPPORTED_FREE_FORMAT',
          ruleDescription: 'このツールは固定形式および桁制限付き自由形式のRPGコードのみをサポートしています。',
          codeSnippet: lines.find(line => line.specificationType === 'FREE')?.rawContent || ''
        }],
        summary: {
          totalIssues: 1,
          errors: 1,
          warnings: 0,
          infos: 0,
          checkedLines: 0,
          specificationCounts: {} as Record<SpecificationType, number>
        },
        filePath
      };
    }

    // 全てのチェッカーを実行
    const issues = this.runAllCheckers(lines, checkLevel);

    // サマリーを生成
    const summary = this.generateSummary(lines, issues);

    // 結果を返す
    return {
      valid: issues.filter(i => i.severity === 'error').length === 0,
      issues: this.sortIssues(issues),
      summary,
      filePath
    };
  }

  /**
   * Check specification order only
   * @param code RPG source code
   * @returns Check result
   */
  checkSpecificationOrder(code: string): { valid: boolean; issues: Issue[] } {
    const lines = this.parser.parse(code);
    
    // 完全自由形式（**FREE）のチェック
    const hasFreeFormat = lines.some(line => line.specificationType === 'FREE');
    if (hasFreeFormat) {
      return {
        valid: false,
        issues: [{
          severity: 'error',
          category: 'structure',
          line: lines.findIndex(line => line.specificationType === 'FREE') + 1,
          column: 1,
          message: '完全自由形式（**FREE）のRPGコードは現在サポートされていません。',
          rule: 'UNSUPPORTED_FREE_FORMAT',
          codeSnippet: lines.find(line => line.specificationType === 'FREE')?.rawContent || ''
        }]
      };
    }
    
    const structureChecker = new StructureChecker(this.considerDBCS);
    const issues = structureChecker.check(lines, 'basic')
      .filter((issue: Issue) => issue.rule === 'SPEC_ORDER');

    return {
      valid: issues.length === 0,
      issues
    };
  }

  /**
   * Check column positions only
   * @param code RPG source code
   * @returns Check result
   */
  checkColumnPositions(code: string): { valid: boolean; issues: Issue[] } {
    const lines = this.parser.parse(code);
    
    // 完全自由形式（**FREE）のチェック
    const hasFreeFormat = lines.some(line => line.specificationType === 'FREE');
    if (hasFreeFormat) {
      return {
        valid: false,
        issues: [{
          severity: 'error',
          category: 'structure',
          line: lines.findIndex(line => line.specificationType === 'FREE') + 1,
          column: 1,
          message: '完全自由形式（**FREE）のRPGコードは現在サポートされていません。',
          rule: 'UNSUPPORTED_FREE_FORMAT',
          codeSnippet: lines.find(line => line.specificationType === 'FREE')?.rawContent || ''
        }]
      };
    }
    
    const structureChecker = new StructureChecker(this.considerDBCS);
    const issues = structureChecker.check(lines, 'standard')
      .filter((issue: Issue) =>
        issue.rule?.includes('_SPEC_COL') ||
        issue.rule?.includes('_SPEC_') ||
        issue.rule === 'LINE_LENGTH'
      );

    return {
      valid: issues.filter((i: Issue) => i.severity === 'error').length === 0,
      issues
    };
  }

  /**
   * Check naming conventions only
   * @param code RPG source code
   * @returns Check result
   */
  checkNamingConventions(code: string): { valid: boolean; issues: Issue[] } {
    const lines = this.parser.parse(code);
    
    // 完全自由形式（**FREE）のチェック
    const hasFreeFormat = lines.some(line => line.specificationType === 'FREE');
    if (hasFreeFormat) {
      return {
        valid: false,
        issues: [{
          severity: 'error',
          category: 'structure',
          line: lines.findIndex(line => line.specificationType === 'FREE') + 1,
          column: 1,
          message: '完全自由形式（**FREE）のRPGコードは現在サポートされていません。',
          rule: 'UNSUPPORTED_FREE_FORMAT',
          codeSnippet: lines.find(line => line.specificationType === 'FREE')?.rawContent || ''
        }]
      };
    }
    
    const namingChecker = new NamingChecker();
    const issues = namingChecker.check(lines, 'standard');

    return {
      valid: issues.filter((i: Issue) => i.severity === 'error').length === 0,
      issues
    };
  }

  /**
   * Check best practices only
   * @param code RPG source code
   * @returns Check result
   */
  checkBestPractices(code: string): { valid: boolean; issues: Issue[] } {
    const lines = this.parser.parse(code);
    
    // 完全自由形式（**FREE）のチェック
    const hasFreeFormat = lines.some(line => line.specificationType === 'FREE');
    if (hasFreeFormat) {
      return {
        valid: false,
        issues: [{
          severity: 'error',
          category: 'structure',
          line: lines.findIndex(line => line.specificationType === 'FREE') + 1,
          column: 1,
          message: '完全自由形式（**FREE）のRPGコードは現在サポートされていません。',
          rule: 'UNSUPPORTED_FREE_FORMAT',
          codeSnippet: lines.find(line => line.specificationType === 'FREE')?.rawContent || ''
        }]
      };
    }
    
    const bestPracticeChecker = new BestPracticeChecker(this.customRulesPath);
    const issues = bestPracticeChecker.check(lines, 'standard');

    return {
      valid: issues.filter((i: Issue) => i.severity === 'error').length === 0,
      issues
    };
  }

  /**
   * Run all checkers
   * @param lines Parsed lines array
   * @param checkLevel Check level
   * @returns All detected issues
   */
  private runAllCheckers(lines: ParsedLine[], checkLevel: CheckLevel): Issue[] {
    const allIssues: Issue[] = [];

    // Create checkers with options
    const structureChecker = new StructureChecker(this.considerDBCS);
    const syntaxChecker = new SyntaxChecker();
    const namingChecker = new NamingChecker();
    const bestPracticeChecker = new BestPracticeChecker(this.customRulesPath);
    const commonErrorsChecker = new CommonErrorsChecker();

    // Run each checker
    allIssues.push(...structureChecker.check(lines, checkLevel));
    allIssues.push(...syntaxChecker.check(lines, checkLevel));
    allIssues.push(...namingChecker.check(lines, checkLevel));
    allIssues.push(...bestPracticeChecker.check(lines, checkLevel));
    allIssues.push(...commonErrorsChecker.check(lines, checkLevel));

    return allIssues;
  }

  /**
   * サマリーを生成
   * @param lines パース済み行の配列
   * @param issues 検出された問題の配列
   * @returns サマリー情報
   */
  private generateSummary(lines: ParsedLine[], issues: Issue[]): Summary {
    const stats = this.analyzer.getStatistics(lines);

    // 重要度別のカウント
    const errors = issues.filter(i => i.severity === 'error').length;
    const warnings = issues.filter(i => i.severity === 'warning').length;
    const infos = issues.filter(i => i.severity === 'info').length;

    // 仕様書タイプ別のカウントを変換
    const specificationCounts: Record<SpecificationType, number> = {
      'H': 0,
      'F': 0,
      'D': 0,
      'P': 0,
      'I': 0,
      'C': 0,
      'O': 0,
      'FREE': 0,
      'COMMENT': 0,
      'UNKNOWN': 0
    };

    stats.specificationCounts.forEach((count, type) => {
      specificationCounts[type] = count;
    });

    return {
      totalIssues: issues.length,
      errors,
      warnings,
      infos,
      checkedLines: lines.length,
      specificationCounts
    };
  }

  /**
   * 問題を行番号と重要度でソート
   * @param issues 問題の配列
   * @returns ソート済みの問題の配列
   */
  private sortIssues(issues: Issue[]): Issue[] {
    const severityOrder = { error: 0, warning: 1, info: 2 };

    return issues.sort((a, b) => {
      // まず行番号でソート
      if (a.line !== b.line) {
        return a.line - b.line;
      }
      // 同じ行の場合は重要度でソート
      return severityOrder[a.severity] - severityOrder[b.severity];
    });
  }

  /**
   * 統計情報を取得
   * @param code RPGソースコード
   * @returns 統計情報
   */
  getStatistics(code: string): {
    totalLines: number;
    commentLines: number;
    codeLines: number;
    continuationLines: number;
    emptyLines: number;
    specificationCounts: Map<SpecificationType, number>;
  } {
    const lines = this.parser.parse(code);
    return this.analyzer.getStatistics(lines);
  }

  /**
   * 仕様書の順序を取得
   * @param code RPGソースコード
   * @returns 仕様書タイプの配列
   */
  getSpecificationOrder(code: string): SpecificationType[] {
    const lines = this.parser.parse(code);
    return this.analyzer.getSpecificationOrder(lines);
  }

  /**
   * /FREEブロックを検出
   * @param code RPGソースコード
   * @returns /FREEブロックの配列
   */
  findFreeBlocks(code: string): Array<{ start: number; end: number | null }> {
    const lines = this.parser.parse(code);
    return this.analyzer.findFreeBlocks(lines);
  }

  /**
   * 非推奨命令を検出
   * @param code RPGソースコード
   * @returns 非推奨命令を使用している行の配列
   */
  findDeprecatedOpcodes(code: string): Array<{ lineNumber: number; opcode: string; line: string }> {
    const lines = this.parser.parse(code);
    const results = this.analyzer.findDeprecatedOpcodes(lines);
    
    return results.map(r => ({
      lineNumber: r.line.lineNumber,
      opcode: r.opcode,
      line: r.line.rawContent
    }));
  }

  /**
   * 標識の使用を検出
   * @param code RPGソースコード
   * @returns 標識を使用している行の配列
   */
  findIndicatorUsage(code: string): Array<{ lineNumber: number; line: string }> {
    const lines = this.parser.parse(code);
    const results = this.analyzer.findIndicatorUsage(lines);
    
    return results.map(line => ({
      lineNumber: line.lineNumber,
      line: line.rawContent
    }));
  }
}