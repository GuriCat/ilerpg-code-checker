/**
 * ILE-RPG Coding Standards Checker - Structure Checker
 * Checks structural issues such as specification order, column positions, and line length
 */

import { ParsedLine, Issue, CheckLevel, Checker } from '../types/index.js';
import { LineAnalyzer } from '../parser/line-analyzer.js';
import { DBCSHelper } from '../utils/dbcs-helper.js';

/**
 * Structure Checker class
 * Detects structural issues in RPG code
 */
export class StructureChecker implements Checker {
  name = 'StructureChecker';
  private analyzer: LineAnalyzer;
  private considerDBCS: boolean;

  constructor(considerDBCS: boolean = false) {
    this.analyzer = new LineAnalyzer();
    this.considerDBCS = considerDBCS;
  }

  /**
   * 構造チェックを実行
   * @param lines パース済み行の配列
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  check(lines: ParsedLine[], checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    // 仕様書順序のチェック
    issues.push(...this.checkSpecificationOrder(lines));

    // 桁位置のチェック
    issues.push(...this.checkColumnPositions(lines, checkLevel));

    // 行の長さのチェック
    issues.push(...this.checkLineLength(lines));

    return issues;
  }

  /**
   * 仕様書の順序をチェック
   * H→F→D→P→I→C→O の順序で記述されているかを確認
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkSpecificationOrder(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    const expectedOrder = ['H', 'F', 'D', 'P', 'I', 'C', 'O'];
    let lastSpecIndex = -1;

    for (const line of lines) {
      // コメント行、UNKNOWN、FREE形式はスキップ
      if (line.isComment || line.specificationType === 'UNKNOWN' || 
          line.specificationType === 'FREE' || line.specificationType === 'COMMENT') {
        continue;
      }

      const currentSpecIndex = expectedOrder.indexOf(line.specificationType);
      if (currentSpecIndex === -1) continue;

      // 順序が逆転している場合
      if (currentSpecIndex < lastSpecIndex) {
        issues.push({
          severity: 'error',
          category: 'structure',
          line: line.lineNumber,
          column: 6,
          message: `仕様書の順序が不正です。${line.specificationType}仕様書は${expectedOrder[lastSpecIndex]}仕様書の後に配置できません。`,
          rule: 'SPEC_ORDER',
          ruleDescription: '仕様書は H→F→D→P→I→C→O の順序で記述する必要があります。',
          suggestion: `${line.specificationType}仕様書を適切な位置に移動してください。`,
          codeSnippet: line.rawContent
        });
      }

      lastSpecIndex = currentSpecIndex;
    }

    return issues;
  }

  /**
   * 桁位置をチェック
   * @param lines パース済み行の配列
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  private checkColumnPositions(lines: ParsedLine[], checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    for (const line of lines) {
      if (line.isComment) continue;

      const columnIssues = this.checkLineColumnPositions(line, checkLevel);
      issues.push(...columnIssues);
    }

    return issues;
  }

  /**
   * 1行の桁位置をチェック
   * @param line パース済み行
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  private checkLineColumnPositions(line: ParsedLine, checkLevel: CheckLevel): Issue[] {
    switch (line.specificationType) {
      case 'H':
        return this.checkHSpecColumns(line, checkLevel);
      case 'F':
        return this.checkFSpecColumns(line, checkLevel);
      case 'D':
        return this.checkDSpecColumns(line, checkLevel);
      case 'P':
        return this.checkPSpecColumns(line, checkLevel);
      case 'C':
        return this.checkCSpecColumns(line, checkLevel);
      default:
        return [];
    }
  }

  /**
   * H仕様書の桁位置チェック
   * @param line パース済み行
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  private checkHSpecColumns(line: ParsedLine, checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    // 6桁目が'H'であることを確認
    if (line.rawContent.length >= 6 && line.rawContent[5].toUpperCase() !== 'H') {
      issues.push({
        severity: 'error',
        category: 'structure',
        line: line.lineNumber,
        column: 6,
        message: 'H仕様書の6桁目は\'H\'である必要があります。',
        rule: 'H_SPEC_COL6',
        codeSnippet: line.rawContent
      });
    }

    // 7-80桁目にキーワードが記述されているか（strictレベルのみ）
    if (checkLevel === 'strict' && line.rawContent.length > 6) {
      const keyword = line.rawContent.substring(6).trim();
      if (keyword.length === 0) {
        issues.push({
          severity: 'warning',
          category: 'structure',
          line: line.lineNumber,
          column: 7,
          message: 'H仕様書にキーワードが記述されていません。',
          rule: 'H_SPEC_KEYWORD',
          suggestion: 'DFTACTGRP、ACTGRP、BNDDIRなどのキーワードを記述してください。'
        });
      }
    }

    return issues;
  }

  /**
   * F仕様書の桁位置チェック
   * @param line パース済み行
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  private checkFSpecColumns(line: ParsedLine, checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    // 6桁目が'F'であることを確認
    if (line.rawContent.length >= 6 && line.rawContent[5].toUpperCase() !== 'F') {
      issues.push({
        severity: 'error',
        category: 'structure',
        line: line.lineNumber,
        column: 6,
        message: 'F仕様書の6桁目は\'F\'である必要があります。',
        rule: 'F_SPEC_COL6',
        codeSnippet: line.rawContent
      });
    }

    // ファイル名（7-16桁）のチェック（継続行は除外）
    if (line.rawContent.length >= 16 && !line.isContinuation) {
      const fileName = line.rawContent.substring(6, 16).trim();
      if (fileName.length === 0 && checkLevel !== 'basic') {
        issues.push({
          severity: 'error',
          category: 'structure',
          line: line.lineNumber,
          column: 7,
          endColumn: 16,
          message: 'F仕様書のファイル名（7-16桁）が空です。',
          rule: 'F_SPEC_FILENAME',
          codeSnippet: line.rawContent
        });
      }
    }

    return issues;
  }

  /**
   * D仕様書の桁位置チェック
   * @param line パース済み行
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  private checkDSpecColumns(line: ParsedLine, checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    // 6桁目が'D'であることを確認
    if (line.rawContent.length >= 6 && line.rawContent[5].toUpperCase() !== 'D') {
      issues.push({
        severity: 'error',
        category: 'structure',
        line: line.lineNumber,
        column: 6,
        message: 'D仕様書の6桁目は\'D\'である必要があります。',
        rule: 'D_SPEC_COL6',
        codeSnippet: line.rawContent
      });
    }

    // 名前（7-21桁）のチェック
    if (line.rawContent.length >= 21 && checkLevel !== 'basic') {
      const name = line.rawContent.substring(6, 21).trim();
      if (name.length === 0 && !line.isContinuation) {
        issues.push({
          severity: 'warning',
          category: 'structure',
          line: line.lineNumber,
          column: 7,
          endColumn: 21,
          message: 'D仕様書の名前フィールド（7-21桁）が空です。',
          rule: 'D_SPEC_NAME',
          suggestion: '変数名またはデータ構造名を記述してください。',
          codeSnippet: line.rawContent
        });
      }
    }

    // データ型（40桁）のチェック（standardレベル以上）
    if (line.rawContent.length >= 40 && checkLevel !== 'basic') {
      const dataType = line.rawContent[39];
      const validTypes = ['A', 'B', 'C', 'D', 'F', 'G', 'I', 'N', 'O', 'P', 'S', 'T', 'U', 'Z', '*', ' '];
      if (!validTypes.includes(dataType.toUpperCase()) && !line.isContinuation) {
        issues.push({
          severity: 'error',
          category: 'structure',
          line: line.lineNumber,
          column: 40,
          message: `D仕様書のデータ型（40桁）が不正です: '${dataType}'`,
          rule: 'D_SPEC_DATATYPE',
          ruleDescription: '有効なデータ型: A, B, C, D, F, G, I, N, O, P, S, T, U, Z, *, または空白',
          codeSnippet: line.rawContent
        });
      }
    }

    return issues;
  }

  /**
   * P仕様書の桁位置チェック
   * @param line パース済み行
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  private checkPSpecColumns(line: ParsedLine, checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    // 6桁目が'P'であることを確認
    if (line.rawContent.length >= 6 && line.rawContent[5].toUpperCase() !== 'P') {
      issues.push({
        severity: 'error',
        category: 'structure',
        line: line.lineNumber,
        column: 6,
        message: 'P仕様書の6桁目は\'P\'である必要があります。',
        rule: 'P_SPEC_COL6',
        codeSnippet: line.rawContent
      });
    }

    // 24桁目がBまたはEであることを確認（standardレベル以上）
    if (line.rawContent.length >= 24 && checkLevel !== 'basic') {
      const beginEnd = line.rawContent[23].toUpperCase();
      if (beginEnd !== 'B' && beginEnd !== 'E' && beginEnd !== ' ') {
        issues.push({
          severity: 'error',
          category: 'structure',
          line: line.lineNumber,
          column: 24,
          message: `P仕様書の24桁目は'B'（開始）または'E'（終了）である必要があります: '${beginEnd}'`,
          rule: 'P_SPEC_BEGIN_END',
          codeSnippet: line.rawContent
        });
      }
    }

    return issues;
  }

  /**
   * C仕様書の桁位置チェック
   * @param line パース済み行
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  private checkCSpecColumns(line: ParsedLine, checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    // 6桁目が'C'であることを確認
    if (line.rawContent.length >= 6 && line.rawContent[5].toUpperCase() !== 'C') {
      issues.push({
        severity: 'error',
        category: 'structure',
        line: line.lineNumber,
        column: 6,
        message: 'C仕様書の6桁目は\'C\'である必要があります。',
        rule: 'C_SPEC_COL6',
        codeSnippet: line.rawContent
      });
    }

    return issues;
  }

  /**
   * Check line length
   * @param lines Parsed lines array
   * @returns Detected issues array
   */
  private checkLineLength(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    const maxLength = 100;

    for (const line of lines) {
      // Calculate actual length considering DBCS if enabled
      const actualLength = this.considerDBCS
        ? DBCSHelper.calculateByteLength(line.rawContent)
        : line.rawContent.length;

      if (actualLength > maxLength) {
        let message = `Line length exceeds limit (${actualLength} > ${maxLength}).`;
        let suggestion = 'Split the line or use continuation lines.';

        // Add DBCS information if applicable
        if (this.considerDBCS && DBCSHelper.containsDBCS(line.rawContent)) {
          const analysis = DBCSHelper.analyzeString(line.rawContent);
          message += ` (Contains ${analysis.dbcsCount} DBCS characters with ${analysis.shiftCharacters} shift characters)`;
        }

        issues.push({
          severity: 'error',
          category: 'structure',
          line: line.lineNumber,
          column: maxLength + 1,
          message,
          rule: 'LINE_LENGTH',
          ruleDescription: 'A line must be at most 100 columns.',
          suggestion,
          codeSnippet: line.rawContent.substring(0, 50) + '...'
        });
      }
    }

    return issues;
  }
}