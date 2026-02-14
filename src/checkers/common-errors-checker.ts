/**
 * ILE-RPG Coding Standards Checker - Common Errors Checker
 * Detects common error patterns in RPG programming
 */

import { ParsedLine, Issue, CheckLevel, Checker } from '../types/index.js';
import { LineAnalyzer } from '../parser/line-analyzer.js';

/**
 * Common Errors Checker class
 * Detects common error patterns in RPG code
 */
export class CommonErrorsChecker implements Checker {
  name = 'CommonErrorsChecker';
  private analyzer: LineAnalyzer;

  constructor() {
    this.analyzer = new LineAnalyzer();
  }

  /**
   * Execute common errors check
   * @param lines Array of parsed lines
   * @param checkLevel Check level
   * @returns Array of detected issues
   */
  check(lines: ParsedLine[], checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    // Check F-spec spacing issues
    issues.push(...this.checkFSpecSpacing(lines));

    // Check D-spec column errors
    issues.push(...this.checkDSpecColumnErrors(lines));

    // Check continuation line errors
    issues.push(...this.checkContinuationErrors(lines));

    // Check /FREE misuse
    issues.push(...this.checkFreeFormMisuse(lines));

    // Check specification order errors in detail
    issues.push(...this.checkSpecificationOrderErrors(lines));

    // Check parentheses matching (standard level and above)
    if (checkLevel !== 'basic') {
      issues.push(...this.checkParenthesesMatching(lines));
    }

    // Check string literals (standard level and above)
    if (checkLevel !== 'basic') {
      issues.push(...this.checkStringLiterals(lines));
    }

    return issues;
  }

  /**
   * Check F-spec spacing issues
   * @param lines Array of parsed lines
   * @returns Array of detected issues
   */
  private checkFSpecSpacing(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    for (const line of lines) {
      if (line.specificationType !== 'F' || line.isComment) continue;

      // Check if there's no space after filename field (columns 7-16)
      if (line.rawContent.length >= 17) {
        const fileName = line.rawContent.substring(6, 16);
        const nextChar = line.rawContent[16];

        // If filename uses all 10 characters and next column is not a space
        if (fileName.trim().length === 10 && nextChar !== ' ') {
          // 修正コード生成: col17にスペースを挿入
          const corrected = line.rawContent.substring(0, 16) + ' ' + line.rawContent.substring(16);
          issues.push({
            severity: 'error',
            category: 'structure',
            line: line.lineNumber,
            column: 17,
            message: 'F仕様書のファイル名フィールドの後にスペースが必要です。',
            rule: 'F_SPEC_SPACING',
            ruleDescription: 'ファイル名が10文字の場合、17桁目はスペースである必要があります。',
            suggestion: '17桁目にスペースを挿入してください。',
            codeSnippet: line.rawContent,
            correctedCode: corrected
          });
        }
      }
    }

    return issues;
  }

  /**
   * Check D-spec column errors
   *
   * RPG IV固定形式D仕様書の桁位置ルール:
   *   桁6:     仕様書種別 'D'
   *   桁7-21:  名前フィールド (15桁)
   *   桁22:    外部記述 (E/空白)
   *   桁23:    データ構造タイプ
   *   桁24-25: 宣言型 (PR/PI/DS/S/C/空白)
   *   桁26-32: From/To位置 (7桁)
   *   桁33-39: 内部長 (7桁、右詰め)
   *   桁40:    データ型 (A/B/C/D/F/G/I/N/O/P/S/T/U/Z/*)
   *   桁41-42: 小数桁 (右詰め)
   *   桁43-80: キーワード
   *
   * @param lines Array of parsed lines
   * @returns Array of detected issues
   */
  private checkDSpecColumnErrors(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    for (const line of lines) {
      if (line.specificationType !== 'D' || line.isComment || line.isContinuation) continue;

      // 名前継続行（...で終わる行）はスキップ — 桁位置ルールが通常と異なる
      // col81-100はコメント領域のため、col1-80のみで判定する。
      const codeArea = line.rawContent.substring(0, Math.min(80, line.rawContent.length)).trimEnd();
      if (codeArea.endsWith('...')) continue;

      // If name field (columns 7-21) is empty but other fields have values
      const name = line.rawContent.substring(6, Math.min(21, line.rawContent.length)).trim();
      const hasOtherData = line.rawContent.length > 21 && line.rawContent.substring(21).trim().length > 0;

      if (name.length === 0 && hasOtherData) {
        // 宣言型がある場合は名前なしでも正常なケースがある
        // （例: TEMPLATE単独行、継続的なキーワード行）
        const declType = line.rawContent.length >= 25 ? line.rawContent.substring(23, 25).trim().toUpperCase() : '';
        const kw = line.rawContent.length > 42 ? line.rawContent.substring(42).trim().toUpperCase() : '';
        const isAcceptableNameless = declType.length > 0 ||
          /^(TEMPLATE|LIKEDS|LIKE|EXTPROC|EXTPGM|BASED|QUALIFIED)/.test(kw);

        if (!isAcceptableNameless) {
          issues.push({
            severity: 'error',
            category: 'structure',
            line: line.lineNumber,
            column: 7,
            endColumn: 21,
            message: 'D仕様書の名前フィールドが空ですが、他のフィールドに値があります。',
            rule: 'D_SPEC_MISSING_NAME',
            ruleDescription: 'D仕様書で定義を行う場合、名前フィールドは必須です。TEMPLATE行やキーワード継続行では名前なしが許容されます。',
            suggestion: '7-21桁目に変数名またはデータ構造名を記述してください。',
            codeSnippet: line.rawContent
          });
        }
      }

      // Check consistency of from/to positions (columns 26-32 and 33-39)
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
              ruleDescription: '開始位置（26-32桁）は終了位置（33-39桁）以下である必要があります。',
              suggestion: '開始位置と終了位置の値を確認してください。',
              codeSnippet: line.rawContent
            });
          }
        }
      }

      // Check for data type character appearing in the size field (column shift indicator)
      // Pattern: "10I", "20U", "65535A" etc. in the wrong position
      if (line.rawContent.length >= 40) {
        const sizeAndType = line.rawContent.substring(32, 40); // 桁33-40
        // サイズ+データ型のパターン（例: "    10I " → 正常: サイズ"     10" + 型"I"）
        // 桁ずれの場合: "   10I  " → サイズ位置に"10I"が入る
        const sizeField = line.rawContent.substring(32, 39).trim();
        if (sizeField.length > 0 && /^\d+[A-Z*]$/i.test(sizeField) && sizeField.length >= 2) {
          // サイズフィールドに「数値+型文字」パターンがある = 桁ずれの可能性
          const expectedSize = sizeField.slice(0, -1);
          const expectedType = sizeField.slice(-1);
          // 修正コード生成: サイズを右詰め7桁 + データ型1桁に分離
          const raw = line.rawContent;
          const padded = raw.padEnd(42);
          const correctedSize = expectedSize.padStart(7);
          const corrected = padded.substring(0, 32) + correctedSize + expectedType.toUpperCase() + padded.substring(40);
          issues.push({
            severity: 'error',
            category: 'structure',
            line: line.lineNumber,
            column: 33,
            endColumn: 40,
            message: `D仕様書の桁位置がずれている可能性があります。サイズフィールド（33-39桁）に'${sizeField}'（サイズ+データ型）が検出されました。`,
            rule: 'D_SPEC_COLUMN_SHIFT',
            ruleDescription: `サイズ（33-39桁）には数値のみ、データ型（40桁）には型文字のみ記述します。'${expectedSize}'をサイズフィールドに右詰め、'${expectedType}'を40桁に配置してください。`,
            suggestion: `桁位置を修正してください。正しくは: サイズ'${expectedSize}'（33-39桁、右詰め）+ データ型'${expectedType}'（40桁）。`,
            codeSnippet: line.rawContent,
            correctedCode: corrected
          });
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

    // メインセクションのD仕様書とC仕様書の最初の出現位置を記録
    // （P仕様書のB-Eブロック内のD/Cは除外）
    let inProcedure = false;
    let firstMainCLine: number | null = null;
    let firstMainDAfterC: number | null = null;

    for (const line of lines) {
      if (line.isComment || line.specificationType === 'UNKNOWN' ||
          line.specificationType === 'FREE' || line.specificationType === 'COMMENT') {
        continue;
      }

      // P仕様書のB/E追跡
      if (line.specificationType === 'P' && line.rawContent.length >= 24) {
        const pCodeArea = line.rawContent.substring(0, Math.min(80, line.rawContent.length)).trimEnd();
        if (!pCodeArea.endsWith('...')) {
          const beginEnd = line.rawContent[23].toUpperCase();
          if (beginEnd === 'B') inProcedure = true;
          else if (beginEnd === 'E') inProcedure = false;
        }
      }

      // サブプロシージャ内のD/Cは順序チェック対象外
      if (inProcedure) continue;

      // メインセクションでのC仕様書の最初の出現
      if (line.specificationType === 'C' && firstMainCLine === null) {
        firstMainCLine = line.lineNumber;
      }

      // メインセクションでC仕様書の後にD仕様書がある場合
      if (line.specificationType === 'D' && firstMainCLine !== null && firstMainDAfterC === null) {
        firstMainDAfterC = line.lineNumber;
      }
    }

    if (firstMainCLine !== null && firstMainDAfterC !== null) {
      issues.push({
        severity: 'error',
        category: 'structure',
        line: firstMainDAfterC,
        message: 'D仕様書がC仕様書の後に配置されています。',
        rule: 'D_AFTER_C',
        ruleDescription: 'メインセクションのD仕様書（定義）はC仕様書（演算）の前に配置する必要があります。サブプロシージャ内のD仕様書は別です。',
        suggestion: `D仕様書を行${firstMainCLine}より前に移動してください。`
      });
    }

    return issues;
  }

  /**
   * 括弧の対応をチェック
   *
   * RPGでは以下のケースで1行内の括弧が不一致になることがある:
   * - D仕様書の継続行（DIM(x), OVERLAY(x:y) 等が複数行にまたがる）
   * - C仕様書の継続行（EVAL等の式が複数行にまたがる）
   * - 文字列リテラル内の括弧
   *
   * 継続行パターンを考慮し、継続行は前の行とまとめてチェックする。
   *
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkParenthesesMatching(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    for (const line of lines) {
      if (line.isComment || line.specificationType === 'UNKNOWN' ||
          line.specificationType === 'FREE' || line.specificationType === 'COMMENT') continue;

      // 継続行は前の行の一部なのでスキップ（まとめてチェックしない簡易版）
      if (line.isContinuation) continue;

      // 次の継続行をまとめて括弧をカウント
      const idx = lines.indexOf(line);
      let combined = line.rawContent;
      for (let j = idx + 1; j < lines.length; j++) {
        if (lines[j].isContinuation && lines[j].specificationType === line.specificationType) {
          combined += lines[j].rawContent;
        } else if (!lines[j].isComment) {
          break;
        }
      }

      // 文字列リテラル内の括弧を除外
      const withoutStrings = combined.replace(/'[^']*'/g, '');
      const openCount = (withoutStrings.match(/\(/g) || []).length;
      const closeCount = (withoutStrings.match(/\)/g) || []).length;

      if (openCount !== closeCount) {
        issues.push({
          severity: 'warning',
          category: 'syntax',
          line: line.lineNumber,
          message: `括弧の対応が取れていません（開き括弧: ${openCount}、閉じ括弧: ${closeCount}）。`,
          rule: 'UNMATCHED_PARENTHESES',
          ruleDescription: '開き括弧と閉じ括弧の数は一致する必要があります。',
          suggestion: '括弧の数を確認し、不足している括弧を追加してください。継続行で閉じている場合は問題ありません。',
          codeSnippet: line.rawContent
        });
      }
    }

    return issues;
  }

  /**
   * 文字列リテラルのチェック
   *
   * RPGでは以下のケースで1行内のクォートが不一致になることがある:
   * - D仕様書のhex定数（X'4142...'が複数行にまたがる）
   * - 継続行で文字列が分割されている場合
   *
   * 継続行の場合はスキップし、hex定数の行末不一致は許容する。
   *
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkStringLiterals(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];

    for (const line of lines) {
      if (line.isComment || line.specificationType === 'UNKNOWN' ||
          line.specificationType === 'FREE' || line.specificationType === 'COMMENT') continue;

      // 継続行はスキップ（前の行と合わせて文字列が完結する可能性がある）
      if (line.isContinuation) continue;

      // hex定数（X'...'）や継続される定数のパターンはスキップ
      // 行末にハイフン('-')がある場合は継続行の開始
      const trimmedEnd = line.rawContent.trimEnd();
      if (trimmedEnd.endsWith('-') || trimmedEnd.endsWith('+')) continue;

      // 次の継続行をまとめてクォートをカウント
      const idx = lines.indexOf(line);
      let combined = line.rawContent;
      for (let j = idx + 1; j < lines.length; j++) {
        if (lines[j].isContinuation && lines[j].specificationType === line.specificationType) {
          combined += lines[j].rawContent;
        } else if (!lines[j].isComment) {
          break;
        }
      }

      const singleQuotes = (combined.match(/'/g) || []).length;
      if (singleQuotes % 2 !== 0) {
        issues.push({
          severity: 'warning',
          category: 'syntax',
          line: line.lineNumber,
          message: 'シングルクォート（\'）の対応が取れていません。',
          rule: 'UNMATCHED_QUOTES',
          ruleDescription: '文字列リテラルは開始と終了のクォートが必要です。',
          suggestion: '不足しているクォートを追加してください。継続行で閉じている場合は問題ありません。',
          codeSnippet: line.rawContent
        });
      }
    }

    return issues;
  }
}