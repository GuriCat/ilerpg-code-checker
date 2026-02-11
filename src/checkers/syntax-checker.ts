/**
 * ILE-RPG コーディング標準チェッカー - 文法チェッカー
 * 行継続、複数命令、FREE形式の対応などの文法的な問題をチェック
 */

import { ParsedLine, Issue, CheckLevel, Checker } from '../types/index.js';
import { LineAnalyzer } from '../parser/line-analyzer.js';

/**
 * 文法チェッカークラス
 * RPGコードの文法的な問題を検出
 */
export class SyntaxChecker implements Checker {
  name = 'SyntaxChecker';
  private analyzer: LineAnalyzer;

  constructor() {
    this.analyzer = new LineAnalyzer();
  }

  /**
   * 文法チェックを実行
   * @param lines パース済み行の配列
   * @param checkLevel チェックレベル
   * @returns 検出された問題の配列
   */
  check(lines: ParsedLine[], checkLevel: CheckLevel): Issue[] {
    const issues: Issue[] = [];

    // 行継続のチェック
    issues.push(...this.checkLineContinuation(lines));

    // 複数命令のチェック（standardレベル以上）
    if (checkLevel !== 'basic') {
      issues.push(...this.checkMultipleStatements(lines));
    }

    // /FREEと/END-FREEの対応チェック
    issues.push(...this.checkFreeFormMatching(lines));

    // **FREE形式のチェック（strictレベル）
    if (checkLevel === 'strict') {
      issues.push(...this.checkFullyFreeFormat(lines));
    }

    return issues;
  }

  /**
   * 行継続ルールをチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkLineContinuation(lines: ParsedLine[]): Issue[] {
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
            ruleDescription: '継続行（7桁目が-または+）は、前の行の続きとして記述する必要があります。',
            suggestion: '継続行マーカー（-または+）を削除するか、前の行を追加してください。',
            codeSnippet: line.rawContent
          });
        } else {
          // コメント行をスキップして、直前の実コード行を検索
          // RPGではD仕様書の定数継続行やC仕様書の間にコメントを挟むことが一般的
          let prevCodeLine = lines[i - 1];
          let prevCodeIdx = i - 1;
          while (prevCodeIdx > 0 && prevCodeLine.isComment) {
            prevCodeIdx--;
            prevCodeLine = lines[prevCodeIdx];
          }

          // 直前のコード行がコメントしかない場合（ファイル先頭付近）
          if (prevCodeLine.isComment) {
            issues.push({
              severity: 'error',
              category: 'syntax',
              line: line.lineNumber,
              column: 7,
              message: '継続行の前にコメント行のみがあります。',
              rule: 'CONTINUATION_AFTER_COMMENT',
              suggestion: 'コメント行の後に継続行を配置することはできません。',
              codeSnippet: line.rawContent
            });
          }

          // 前のコード行が同じ仕様書タイプかチェック
          if (!prevCodeLine.isComment &&
              prevCodeLine.specificationType !== line.specificationType &&
              prevCodeLine.specificationType !== 'UNKNOWN' &&
              line.specificationType !== 'UNKNOWN') {
            issues.push({
              severity: 'error',
              category: 'syntax',
              line: line.lineNumber,
              column: 7,
              message: `継続行の仕様書タイプ（${line.specificationType}）が前の行（${prevCodeLine.specificationType}）と一致しません。`,
              rule: 'CONTINUATION_TYPE_MISMATCH',
              ruleDescription: '継続行は前の行と同じ仕様書タイプである必要があります。',
              codeSnippet: line.rawContent
            });
          }
        }

        // Note: Continuation lines are identified by blank name fields, not by markers
        // No additional marker validation needed here
      }
    }

    return issues;
  }

  /**
   * 複数命令の1行記述をチェック
   *
   * DSPEC_COLUMN_FIX.md 7.5:
   * C仕様書（自由形式）で1行に複数文を書くことはできない（RNF5508）。
   * **FREE形式でも同様。
   *
   * 間違い例:
   *   outArr(1) = 65; outArr(2) = 768;
   * 修正:
   *   outArr(1) = 65;
   *   outArr(2) = 768;
   *
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkMultipleStatements(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    let inFreeBlock = false;
    // **FREE形式かどうか
    const isFullyFree = lines.some(l => l.specificationType === 'FREE');

    for (const line of lines) {
      // /FREE ブロックの追跡
      const trimmedUpper = line.trimmedContent.toUpperCase();
      if (trimmedUpper.startsWith('/FREE')) {
        inFreeBlock = true;
        continue;
      }
      if (trimmedUpper.startsWith('/END-FREE')) {
        inFreeBlock = false;
        continue;
      }

      if (line.isComment) continue;

      // 文字列リテラル内のセミコロンを除外してカウント
      const contentWithoutStrings = line.rawContent.replace(/'[^']*'/g, '');
      const semicolonCount = (contentWithoutStrings.match(/;/g) || []).length;

      // C仕様書（自由形式計算部分）
      if (line.specificationType === 'C' && semicolonCount > 1) {
        issues.push({
          severity: 'error',
          category: 'syntax',
          line: line.lineNumber,
          message: `1行に複数の命令が記述されています（セミコロン${semicolonCount}個）。RPGでは1行に1文のみ記述可能です。`,
          rule: 'MULTIPLE_STATEMENTS',
          ruleDescription: 'RPGの自由形式では、1行に1つの命令のみ記述できます（RNF5508）。',
          suggestion: '各命令を別々の行に分割してください。',
          codeSnippet: line.rawContent
        });
      }

      // /FREE ブロック内の行
      if (inFreeBlock && semicolonCount > 1) {
        issues.push({
          severity: 'error',
          category: 'syntax',
          line: line.lineNumber,
          message: `1行に複数の命令が記述されています（セミコロン${semicolonCount}個）。/FREEブロック内では1行に1文のみ記述可能です。`,
          rule: 'MULTIPLE_STATEMENTS',
          ruleDescription: '/FREEブロック内では、1行に1つの命令のみ記述できます（RNF5508）。',
          suggestion: '各命令を別々の行に分割してください。',
          codeSnippet: line.rawContent
        });
      }

      // **FREE形式の行（仕様書タイプがUNKNOWNで、**FREE行以降の通常コード行）
      if (isFullyFree && line.specificationType === 'UNKNOWN' &&
          line.trimmedContent.length > 0 && !line.trimmedContent.startsWith('**') &&
          !line.trimmedContent.startsWith('//') && semicolonCount > 1) {
        issues.push({
          severity: 'error',
          category: 'syntax',
          line: line.lineNumber,
          message: `1行に複数の命令が記述されています（セミコロン${semicolonCount}個）。**FREE形式では1行に1文のみ記述可能です。`,
          rule: 'MULTIPLE_STATEMENTS',
          ruleDescription: '**FREE形式では、1行に1つの命令のみ記述できます（RNF5508）。',
          suggestion: '各命令を別々の行に分割してください。',
          codeSnippet: line.rawContent
        });
      }
    }

    return issues;
  }

  /**
   * /FREEと/END-FREEの対応をチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkFreeFormMatching(lines: ParsedLine[]): Issue[] {
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
            rule: 'UNMATCHED_END_FREE',
            ruleDescription: '/END-FREEには対応する/FREEが必要です。',
            suggestion: '対応する/FREEを追加するか、この/END-FREEを削除してください。',
            codeSnippet: line.rawContent
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
        rule: 'UNMATCHED_FREE',
        ruleDescription: '/FREEには対応する/END-FREEが必要です。',
        suggestion: '対応する/END-FREEを追加してください。'
      });
    }

    return issues;
  }

  /**
   * **FREE形式（完全自由形式）のチェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkFullyFreeFormat(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    let hasFullyFree = false;
    let hasMixedFormat = false;

    // **FREEの存在チェック
    for (const line of lines) {
      if (line.specificationType === 'FREE') {
        hasFullyFree = true;
      } else if (['H', 'F', 'D', 'P', 'C', 'I', 'O'].includes(line.specificationType)) {
        if (!line.isComment) {
          hasMixedFormat = true;
        }
      }
    }

    // **FREEと桁固定形式が混在している場合
    if (hasFullyFree && hasMixedFormat) {
      issues.push({
        severity: 'warning',
        category: 'syntax',
        line: 1,
        message: '**FREE形式と桁固定形式が混在しています。',
        rule: 'MIXED_FORMAT',
        ruleDescription: '**FREE形式を使用する場合は、全体を完全自由形式で記述することを推奨します。',
        suggestion: '可能であれば、全体を**FREE形式に統一してください。'
      });
    }

    // **FREEの位置チェック（ファイルの先頭に配置すべき）
    if (hasFullyFree) {
      let foundFree = false;
      for (const line of lines) {
        if (line.specificationType === 'FREE') {
          foundFree = true;
          break;
        }
        // **FREEより前に他の仕様書がある場合
        if (['H', 'F', 'D', 'P', 'C', 'I', 'O'].includes(line.specificationType) && !line.isComment) {
          issues.push({
            severity: 'warning',
            category: 'syntax',
            line: line.lineNumber,
            message: '**FREEはファイルの先頭に配置することを推奨します。',
            rule: 'FREE_POSITION',
            suggestion: '**FREEをファイルの最初の行に移動してください。',
            codeSnippet: line.rawContent
          });
          break;
        }
      }
    }

    return issues;
  }

  /**
   * /FREEブロック内の文法チェック
   * @param lines パース済み行の配列
   * @returns 検出された問題の配列
   */
  private checkFreeBlockSyntax(lines: ParsedLine[]): Issue[] {
    const issues: Issue[] = [];
    const freeBlocks = this.analyzer.findFreeBlocks(lines);

    for (const block of freeBlocks) {
      // ブロック内の行を取得
      const blockLines = lines.filter(line => 
        line.lineNumber > block.start && 
        (block.end === null || line.lineNumber < block.end)
      );

      // /FREEブロック内では桁固定形式の記述は不可
      for (const line of blockLines) {
        if (['H', 'F', 'D', 'P', 'C', 'I', 'O'].includes(line.specificationType)) {
          issues.push({
            severity: 'error',
            category: 'syntax',
            line: line.lineNumber,
            message: '/FREEブロック内で桁固定形式の仕様書が使用されています。',
            rule: 'FIXED_FORMAT_IN_FREE',
            ruleDescription: '/FREEブロック内では自由形式の記述のみ使用できます。',
            suggestion: '桁固定形式の記述を自由形式に変換してください。',
            codeSnippet: line.rawContent
          });
        }
      }
    }

    return issues;
  }
}