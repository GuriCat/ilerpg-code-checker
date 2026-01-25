/**
 * ILE-RPG コーディング標準チェッカー - 命名規約チェッカー
 * 変数名、プロシージャ名などの命名規約をチェック
 */

import { ParsedLine, Issue, CheckLevel, Checker } from '../types/index.js';
import { LineAnalyzer } from '../parser/line-analyzer.js';

/**
 * 命名規約チェッカークラス
 * RPGコードの命名規約に関する問題を検出
 */
export class NamingChecker implements Checker {
  name = 'NamingChecker';
  private analyzer: LineAnalyzer;

  constructor() {
    this.analyzer = new LineAnalyzer();
  }

  /**
   * 命名規約チェックを実行
   * @param lines パース済み行の配列
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  check(lines: ParsedLine[], checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    // 変数名のチェック
    issues.push(...this.checkVariableNaming(lines, checkLevel));

    // プロシージャ名のチェック（standardレベル以上）
    if (checkLevel !== 'basic') {
      issues.push(...this.checkProcedureNaming(lines, checkLevel));
    }

    // ファイル名のチェック（strictレベル）
    if (checkLevel === 'strict') {
      issues.push(...this.checkFileNaming(lines));
    }

    return issues;
  }

  /**
   * 変数名の命名規約をチェック
   * @param lines パース済み行の配列
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  private checkVariableNaming(lines: ParsedLine[], checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    for (const line of lines) {
      if (line.specificationType !== 'D' || line.isComment) continue;

      // 変数名を抽出
      const varName = this.analyzer.extractVariableName(line);
      if (!varName) continue;

      // 命名規約のチェック
      const namingIssues = this.validateVariableName(varName, line.lineNumber, checkLevel);
      issues.push(...namingIssues);
    }

    return issues;
  }

  /**
   * 変数名を検証
   * @param name 変数名
   * @param lineNumber 行番号
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  private validateVariableName(name: string, lineNumber: number, checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    // 1文字の変数名は避ける（ループカウンタを除く）
    if (name.length === 1) {
      const commonLoopVars = ['I', 'J', 'K', 'X', 'Y', 'Z'];
      if (!commonLoopVars.includes(name.toUpperCase())) {
        issues.push({
          severity: 'warning',
          category: 'naming',
          line: lineNumber,
          column: 7,
          endColumn: 21,
          message: `変数名 '${name}' は短すぎます。より説明的な名前を使用してください。`,
          rule: 'VAR_NAME_TOO_SHORT',
          ruleDescription: '変数名は1文字ではなく、その目的を表す説明的な名前を使用すべきです。',
          suggestion: '変数の目的を表す、より長い名前を使用してください（例: counter, index, total）。'
        });
      }
    }

    // 特殊文字のチェック
    if (/[^A-Za-z0-9_#@$]/.test(name)) {
      issues.push({
        severity: 'error',
        category: 'naming',
        line: lineNumber,
        column: 7,
        endColumn: 21,
        message: `変数名 '${name}' に使用できない文字が含まれています。`,
        rule: 'VAR_NAME_INVALID_CHARS',
        ruleDescription: '変数名には英数字、アンダースコア（_）、ハッシュ（#）、アットマーク（@）、ドル記号（$）のみ使用できます。',
        suggestion: '使用できない文字を削除または置換してください。'
      });
    }

    // 数字で始まる名前のチェック
    if (/^[0-9]/.test(name)) {
      issues.push({
        severity: 'error',
        category: 'naming',
        line: lineNumber,
        column: 7,
        endColumn: 21,
        message: `変数名 '${name}' は数字で始まっています。`,
        rule: 'VAR_NAME_STARTS_WITH_DIGIT',
        ruleDescription: '変数名は数字で始めることができません。英字、アンダースコア、#、@、$で始める必要があります。',
        suggestion: '変数名を英字で始めてください（例: var1, item1）。'
      });
    }

    // 予約語のチェック（strictレベル）
    if (checkLevel === 'strict') {
      const reservedWords = [
        'IF', 'ELSE', 'ENDIF', 'DO', 'ENDDO', 'FOR', 'ENDFOR', 
        'SELECT', 'WHEN', 'OTHER', 'ENDSL', 'DOU', 'DOW'
      ];
      if (reservedWords.includes(name.toUpperCase())) {
        issues.push({
          severity: 'error',
          category: 'naming',
          line: lineNumber,
          column: 7,
          endColumn: 21,
          message: `変数名 '${name}' は予約語です。`,
          rule: 'VAR_NAME_RESERVED',
          ruleDescription: 'RPGの予約語を変数名として使用することはできません。',
          suggestion: '別の名前を使用してください。'
        });
      }
    }

    // 意味のある名前の推奨（standardレベル以上）
    if (checkLevel !== 'basic') {
      const meaninglessPatterns = [
        /^temp\d*$/i,
        /^tmp\d*$/i,
        /^var\d*$/i,
        /^data\d*$/i,
        /^value\d*$/i,
        /^x\d*$/i,
        /^y\d*$/i,
        /^z\d*$/i
      ];

      if (meaninglessPatterns.some(pattern => pattern.test(name))) {
        issues.push({
          severity: 'info',
          category: 'naming',
          line: lineNumber,
          column: 7,
          endColumn: 21,
          message: `変数名 '${name}' は汎用的すぎます。より具体的な名前を推奨します。`,
          rule: 'VAR_NAME_GENERIC',
          ruleDescription: '変数名は、その変数が何を表すのかを明確に示すべきです。',
          suggestion: '変数の用途や内容を表す具体的な名前を使用してください（例: customerName, orderTotal）。'
        });
      }
    }

    // 長すぎる名前のチェック（strictレベル）
    if (checkLevel === 'strict' && name.length > 15) {
      issues.push({
        severity: 'info',
        category: 'naming',
        line: lineNumber,
        column: 7,
        endColumn: 21,
        message: `変数名 '${name}' は長すぎる可能性があります（${name.length}文字）。`,
        rule: 'VAR_NAME_TOO_LONG',
        ruleDescription: '変数名は15文字以内に収めることを推奨します。',
        suggestion: 'より短く、かつ意味が明確な名前を検討してください。'
      });
    }

    return issues;
  }

  /**
   * プロシージャ名の命名規約をチェック
   * @param lines パース済み行の配列
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  private checkProcedureNaming(lines: ParsedLine[], checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    for (const line of lines) {
      if (line.specificationType !== 'P' || line.isComment) continue;

      // プロシージャ名を抽出
      const procName = this.analyzer.extractProcedureName(line);
      if (!procName) continue;

      // 開始行のみチェック（24桁目が'B'）
      if (line.columnData?.beginEnd?.toUpperCase() !== 'B') continue;

      // 命名規約のチェック
      const namingIssues = this.validateProcedureName(procName, line.lineNumber, checkLevel);
      issues.push(...namingIssues);
    }

    return issues;
  }

  /**
   * プロシージャ名を検証
   * @param name プロシージャ名
   * @param lineNumber 行番号
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  private validateProcedureName(name: string, lineNumber: number, checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    // 基本的な文字チェック（変数名と同じルール）
    if (/[^A-Za-z0-9_#@$]/.test(name)) {
      issues.push({
        severity: 'error',
        category: 'naming',
        line: lineNumber,
        column: 7,
        endColumn: 21,
        message: `プロシージャ名 '${name}' に使用できない文字が含まれています。`,
        rule: 'PROC_NAME_INVALID_CHARS',
        ruleDescription: 'プロシージャ名には英数字、アンダースコア、#、@、$のみ使用できます。'
      });
    }

    // 数字で始まる名前のチェック
    if (/^[0-9]/.test(name)) {
      issues.push({
        severity: 'error',
        category: 'naming',
        line: lineNumber,
        column: 7,
        endColumn: 21,
        message: `プロシージャ名 '${name}' は数字で始まっています。`,
        rule: 'PROC_NAME_STARTS_WITH_DIGIT',
        ruleDescription: 'プロシージャ名は数字で始めることができません。'
      });
    }

    // プロシージャ名は動詞で始めることを推奨（standardレベル以上）
    if (checkLevel !== 'basic' && name.length > 3) {
      const verbPrefixes = [
        'get', 'set', 'calc', 'calculate', 'check', 'validate', 
        'process', 'update', 'delete', 'create', 'read', 'write',
        'load', 'save', 'init', 'initialize', 'open', 'close',
        'add', 'remove', 'find', 'search', 'format', 'parse',
        'build', 'generate', 'convert', 'transform'
      ];
      
      const startsWithVerb = verbPrefixes.some(verb => 
        name.toLowerCase().startsWith(verb)
      );

      if (!startsWithVerb) {
        issues.push({
          severity: 'info',
          category: 'naming',
          line: lineNumber,
          column: 7,
          endColumn: 21,
          message: `プロシージャ名 '${name}' は動詞で始めることを推奨します。`,
          rule: 'PROC_NAME_VERB_PREFIX',
          ruleDescription: 'プロシージャ名は、その処理内容を表す動詞で始めることで、可読性が向上します。',
          suggestion: 'get, set, calc, check, validate, process などの動詞で始めてください。'
        });
      }
    }

    // キャメルケースまたはスネークケースの推奨（strictレベル）
    if (checkLevel === 'strict' && name.length > 1) {
      const isCamelCase = /^[a-z][a-zA-Z0-9]*$/.test(name);
      const isPascalCase = /^[A-Z][a-zA-Z0-9]*$/.test(name);
      const isSnakeCase = /^[a-z][a-z0-9_]*$/.test(name);
      const isUpperSnakeCase = /^[A-Z][A-Z0-9_]*$/.test(name);

      if (!isCamelCase && !isPascalCase && !isSnakeCase && !isUpperSnakeCase) {
        issues.push({
          severity: 'info',
          category: 'naming',
          line: lineNumber,
          column: 7,
          endColumn: 21,
          message: `プロシージャ名 '${name}' は一貫した命名規則に従うことを推奨します。`,
          rule: 'PROC_NAME_CASE_STYLE',
          ruleDescription: 'キャメルケース（camelCase）、パスカルケース（PascalCase）、またはスネークケース（snake_case）を使用してください。',
          suggestion: '例: getUserData, GetUserData, get_user_data'
        });
      }
    }

    return issues;
  }

  /**
   * ファイル名の命名規約をチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkFileNaming(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    for (const line of lines) {
      if (line.specificationType !== 'F' || line.isComment) continue;

      // ファイル名を抽出
      const fileName = line.columnData?.fileName;
      if (!fileName) continue;

      // ファイル名の検証
      if (fileName.length > 10) {
        issues.push({
          severity: 'warning',
          category: 'naming',
          line: line.lineNumber,
          column: 7,
          endColumn: 16,
          message: `ファイル名 '${fileName}' は10文字を超えています（${fileName.length}文字）。`,
          rule: 'FILE_NAME_LENGTH',
          ruleDescription: 'ファイル名は10文字以内に収めることを推奨します。',
          suggestion: 'より短いファイル名を使用してください。'
        });
      }

      // 特殊文字のチェック
      if (/[^A-Za-z0-9_#@$]/.test(fileName)) {
        issues.push({
          severity: 'error',
          category: 'naming',
          line: line.lineNumber,
          column: 7,
          endColumn: 16,
          message: `ファイル名 '${fileName}' に使用できない文字が含まれています。`,
          rule: 'FILE_NAME_INVALID_CHARS',
          ruleDescription: 'ファイル名には英数字、アンダースコア、#、@、$のみ使用できます。'
        });
      }
    }

    return issues;
  }
}