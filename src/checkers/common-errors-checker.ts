/**
 * ILE-RPG コーディング標準チェッカー - よくあるエラーチェッカー
 * RPGプログラミングでよく発生するエラーパターンを検出
 */

import { ParsedLine, Issue, CheckLevel, Checker } from '../types/index.js';
import { LineAnalyzer } from '../parser/line-analyzer.js';

/**
 * よくあるエラーチェッカークラス
 * RPGコードでよく発生するエラーパターンを検出
 */
export class CommonErrorsChecker implements Checker {
  name = 'CommonErrorsChecker';
  private analyzer: LineAnalyzer;

  constructor() {
    this.analyzer = new LineAnalyzer();
  }

  /**
   * よくあるエラーのチェックを実行
   * @param lines パース済み行の配列
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  check(lines: ParsedLine[], checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    // F仕様書のスペース不足チェック
    issues.push(...this.checkFSpecSpacing(lines));

    // D仕様書の桁位置エラーチェック
    issues.push(...this.checkDSpecColumnErrors(lines));

    // 継続行の誤りチェック
    issues.push(...this.checkContinuationErrors(lines));

    // /FREEの誤用チェック
    issues.push(...this.checkFreeFormMisuse(lines));

    // 仕様書順序エラーの詳細チェック
    issues.push(...this.checkSpecificationOrderErrors(lines));

    // 括弧の対応チェック（standardレベル以上）
    if (checkLevel !== 'basic') {
      issues.push(...this.checkParenthesesMatching(lines));
    }

    // 文字列リテラルのチェック（standardレベル以上）
    if (checkLevel !== 'basic') {
      issues.push(...this.checkStringLiterals(lines));
    }

    return issues;
  }

  /**
   * F仕様書のスペース不足をチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkFSpecSpacing(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    for (const line of lines) {
      if (line.specificationType !== 'F' || line.isComment) continue;

      // ファイル名フィールド（7-16桁）の後にスペースがない場合
      if (line.rawContent.length >= 17) {
        const fileName = line.rawContent.substring(6, 16);
        const nextChar = line.rawContent[16];

        // ファイル名が10文字使用されており、次の桁にスペースがない場合
        if (fileName.trim().length === 10 && nextChar !== ' ') {
          issues.push({
            severity: 'error',
            category: 'structure',
            line: line.lineNumber,
            column: 17,
            message: 'F仕様書のファイル名フィールドの後にスペースが必要です。',
            rule: 'F_SPEC_SPACING',
            ruleDescription: 'ファイル名が10文字の場合、17桁目はスペースである必要があります。',
            suggestion: '17桁目にスペースを挿入してください。',
            codeSnippet: line.rawContent
          });
        }
      }
    }

    return issues;
  }

  /**
   * D仕様書の桁位置エラーをチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkDSpecColumnErrors(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    for (const line of lines) {
      if (line.specificationType !== 'D' || line.isComment || line.isContinuation) continue;

      // 名前フィールド（7-21桁）が空で、他のフィールドに値がある場合
      const name = line.rawContent.substring(6, 21).trim();
      const hasOtherData = line.rawContent.length > 21 && line.rawContent.substring(21).trim().length > 0;

      if (name.length === 0 && hasOtherData) {
        issues.push({
          severity: 'error',
          category: 'structure',
          line: line.lineNumber,
          column: 7,
          endColumn: 21,
          message: 'D仕様書の名前フィールドが空ですが、他のフィールドに値があります。',
          rule: 'D_SPEC_MISSING_NAME',
          ruleDescription: 'D仕様書で定義を行う場合、名前フィールドは必須です。',
          suggestion: '7-21桁目に変数名またはデータ構造名を記述してください。',
          codeSnippet: line.rawContent
        });
      }

      // 開始位置と終了位置の整合性チェック
      if (line.rawContent.length >= 39) {
        const fromPos = line.rawContent.substring(25, 32).trim();
        const toPos = line.rawContent.substring(32, 39).trim();

        if (fromPos && toPos) {
          const fromNum = parseInt(fromPos, 10);
          const toNum = parseInt(toPos, 10);

          if (!isNaN(fromNum) && !isNaN(toNum) && fromNum > toNum) {
            issues.push({
              severity: 'error',
              category: 'structure',
              line: line.lineNumber,
              column: 26,
              endColumn: 39,
              message: `開始位置（${fromNum}）が終了位置（${toNum}）より大きくなっています。`,
              rule: 'D_SPEC_POSITION_ERROR',
              ruleDescription: '開始位置は終了位置以下である必要があります。',
              suggestion: '開始位置と終了位置の値を確認してください。',
              codeSnippet: line.rawContent
            });
          }
        }
      }
    }

    return issues;
  }

  /**
   * 継続行の誤りをチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkContinuationErrors(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // 継続行でない行の7桁目に'-'または'+'がある場合（誤って継続行マーカーを付けた可能性）
      if (!line.isContinuation && line.rawContent.length >= 7) {
        const col7 = line.rawContent[6];
        if ((col7 === '-' || col7 === '+') && line.specificationType !== 'UNKNOWN') {
          // 前の行が同じ仕様書タイプでない場合、誤り
          if (i === 0 || lines[i - 1].specificationType !== line.specificationType) {
            issues.push({
              severity: 'error',
              category: 'syntax',
              line: line.lineNumber,
              column: 7,
              message: '7桁目に継続行マーカーがありますが、前の行と仕様書タイプが一致しません。',
              rule: 'INVALID_CONTINUATION',
              ruleDescription: '継続行マーカー（-または+）は、前の行と同じ仕様書タイプの場合のみ使用できます。',
              suggestion: '継続行マーカーを削除するか、前の行の仕様書タイプを確認してください。',
              codeSnippet: line.rawContent
            });
          }
        }
      }

      // 継続行の後に空行がある場合（継続が途切れる）
      if (line.isContinuation && i < lines.length - 1) {
        const nextLine = lines[i + 1];
        if (nextLine.trimmedContent.length === 0) {
          issues.push({
            severity: 'warning',
            category: 'syntax',
            line: line.lineNumber,
            message: '継続行の後に空行があります。継続が途切れる可能性があります。',
            rule: 'CONTINUATION_FOLLOWED_BY_BLANK',
            suggestion: '空行を削除するか、継続行マーカーを確認してください。',
            codeSnippet: line.rawContent
          });
        }
      }
    }

    return issues;
  }

  /**
   * /FREEの誤用をチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkFreeFormMisuse(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    for (const line of lines) {
      const trimmed = line.trimmedContent.toUpperCase();

      // /FREEと**FREEの混同
      if (trimmed.startsWith('/FREE') && !trimmed.startsWith('/END-FREE')) {
        // 同じファイルに**FREEがある場合、混同の可能性
        const hasFullyFree = lines.some(l => l.specificationType === 'FREE');
        if (hasFullyFree) {
          issues.push({
            severity: 'warning',
            category: 'syntax',
            line: line.lineNumber,
            message: '/FREEと**FREEが混在しています。',
            rule: 'FREE_FORMAT_CONFUSION',
            ruleDescription: '/FREE（桁制限付き自由形式）と**FREE（完全自由形式）は異なります。',
            suggestion: '**FREEを使用する場合は、/FREEを削除してください。',
            codeSnippet: line.rawContent
          });
        }
      }

      // /FREEの前に桁固定形式のコードがある場合の警告
      if (trimmed.startsWith('/FREE')) {
        let hasPreviousCode = false;
        for (let i = 0; i < lines.length && lines[i].lineNumber < line.lineNumber; i++) {
          if (['C', 'I', 'O'].includes(lines[i].specificationType) && !lines[i].isComment) {
            hasPreviousCode = true;
            break;
          }
        }

        if (hasPreviousCode) {
          issues.push({
            severity: 'info',
            category: 'best-practice',
            line: line.lineNumber,
            message: '/FREEの前に桁固定形式のコードがあります。',
            rule: 'FREE_AFTER_FIXED',
            ruleDescription: '/FREEは通常、ファイルの先頭付近に配置します。',
            suggestion: '可能であれば、全体を**FREE形式に統一することを検討してください。',
            codeSnippet: line.rawContent
          });
        }
      }
    }

    return issues;
  }

  /**
   * 仕様書順序エラーの詳細チェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkSpecificationOrderErrors(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    const expectedOrder = ['H', 'F', 'D', 'P', 'I', 'C', 'O'];

    // 各仕様書タイプの最初の出現位置を記録
    const firstOccurrence = new Map<string, number>();

    for (const line of lines) {
      if (line.isComment || line.specificationType === 'UNKNOWN' || 
          line.specificationType === 'FREE' || line.specificationType === 'COMMENT') {
        continue;
      }

      if (!firstOccurrence.has(line.specificationType)) {
        firstOccurrence.set(line.specificationType, line.lineNumber);
      }
    }

    // C仕様書の後にD仕様書がある場合（よくあるエラー）
    const cLine = firstOccurrence.get('C');
    const dLine = firstOccurrence.get('D');
    if (cLine && dLine && dLine > cLine) {
      issues.push({
        severity: 'error',
        category: 'structure',
        line: dLine,
        message: 'D仕様書がC仕様書の後に配置されています。',
        rule: 'D_AFTER_C',
        ruleDescription: 'D仕様書（定義）はC仕様書（演算）の前に配置する必要があります。',
        suggestion: `D仕様書を行${cLine}より前に移動してください。`
      });
    }

    return issues;
  }

  /**
   * 括弧の対応をチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkParenthesesMatching(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    for (const line of lines) {
      if (line.isComment || line.specificationType === 'UNKNOWN') continue;

      // 括弧のカウント
      const openCount = (line.rawContent.match(/\(/g) || []).length;
      const closeCount = (line.rawContent.match(/\)/g) || []).length;

      if (openCount !== closeCount) {
        issues.push({
          severity: 'error',
          category: 'syntax',
          line: line.lineNumber,
          message: `括弧の対応が取れていません（開き括弧: ${openCount}、閉じ括弧: ${closeCount}）。`,
          rule: 'UNMATCHED_PARENTHESES',
          ruleDescription: '開き括弧と閉じ括弧の数は一致する必要があります。',
          suggestion: '括弧の数を確認し、不足している括弧を追加してください。',
          codeSnippet: line.rawContent
        });
      }
    }

    return issues;
  }

  /**
   * 文字列リテラルのチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkStringLiterals(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    for (const line of lines) {
      if (line.isComment || line.specificationType === 'UNKNOWN') continue;

      // シングルクォートの対応チェック
      const singleQuotes = (line.rawContent.match(/'/g) || []).length;
      if (singleQuotes % 2 !== 0) {
        issues.push({
          severity: 'error',
          category: 'syntax',
          line: line.lineNumber,
          message: 'シングルクォート（\'）の対応が取れていません。',
          rule: 'UNMATCHED_QUOTES',
          ruleDescription: '文字列リテラルは開始と終了のクォートが必要です。',
          suggestion: '不足しているクォートを追加してください。',
          codeSnippet: line.rawContent
        });
      }
    }

    return issues;
  }
}