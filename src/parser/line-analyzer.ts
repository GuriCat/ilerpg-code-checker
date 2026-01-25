/**
 * ILE-RPG コーディング標準チェッカー - 行解析ユーティリティ
 * パース済み行に対する追加の分析機能を提供
 */

import { ParsedLine, SpecificationType } from '../types/index.js';

/**
 * 行解析ユーティリティクラス
 * パース済み行に対する高度な分析機能を提供
 */
export class LineAnalyzer {
  /**
   * 指定された仕様書タイプの行を抽出
   * @param lines パース済み行の配列
   * @param specType 抽出する仕様書タイプ
   * @returns 指定された仕様書タイプの行の配列
   */
  filterBySpecificationType(lines: ParsedLine[], specType: SpecificationType): ParsedLine[] {
    return lines.filter(line => line.specificationType === specType);
  }

  /**
   * コメント行を除外
   * @param lines パース済み行の配列
   * @returns コメント行を除いた行の配列
   */
  excludeComments(lines: ParsedLine[]): ParsedLine[] {
    return lines.filter(line => !line.isComment);
  }

  /**
   * 継続行を除外
   * @param lines パース済み行の配列
   * @returns 継続行を除いた行の配列
   */
  excludeContinuations(lines: ParsedLine[]): ParsedLine[] {
    return lines.filter(line => !line.isContinuation);
  }

  /**
   * 仕様書の順序を取得
   * @param lines パース済み行の配列
   * @returns 出現順の仕様書タイプの配列（重複なし）
   */
  getSpecificationOrder(lines: ParsedLine[]): SpecificationType[] {
    const order: SpecificationType[] = [];
    const seen = new Set<SpecificationType>();

    for (const line of lines) {
      if (line.isComment || line.specificationType === 'UNKNOWN') continue;
      
      if (!seen.has(line.specificationType)) {
        order.push(line.specificationType);
        seen.add(line.specificationType);
      }
    }

    return order;
  }

  /**
   * 仕様書タイプごとの行数をカウント
   * @param lines パース済み行の配列
   * @returns 仕様書タイプごとの行数のマップ
   */
  countBySpecificationType(lines: ParsedLine[]): Map<SpecificationType, number> {
    const counts = new Map<SpecificationType, number>();

    for (const line of lines) {
      const current = counts.get(line.specificationType) || 0;
      counts.set(line.specificationType, current + 1);
    }

    return counts;
  }

  /**
   * /FREEブロックを検出
   * @param lines パース済み行の配列
   * @returns /FREEブロックの開始・終了行番号のペアの配列
   */
  findFreeBlocks(lines: ParsedLine[]): Array<{ start: number; end: number | null }> {
    const blocks: Array<{ start: number; end: number | null }> = [];
    let currentBlock: { start: number; end: number | null } | null = null;

    for (const line of lines) {
      const trimmed = line.trimmedContent.toUpperCase();

      if (trimmed.startsWith('/FREE')) {
        if (currentBlock) {
          // 前のブロックが閉じられていない
          blocks.push(currentBlock);
        }
        currentBlock = { start: line.lineNumber, end: null };
      } else if (trimmed.startsWith('/END-FREE')) {
        if (currentBlock) {
          currentBlock.end = line.lineNumber;
          blocks.push(currentBlock);
          currentBlock = null;
        }
      }
    }

    // 閉じられていないブロックがあれば追加
    if (currentBlock) {
      blocks.push(currentBlock);
    }

    return blocks;
  }

  /**
   * 指定された行が/FREEブロック内かどうかを判定
   * @param lineNumber 行番号
   * @param freeBlocks /FREEブロックの配列
   * @returns /FREEブロック内の場合true
   */
  isInFreeBlock(lineNumber: number, freeBlocks: Array<{ start: number; end: number | null }>): boolean {
    for (const block of freeBlocks) {
      if (lineNumber > block.start) {
        if (block.end === null || lineNumber < block.end) {
          return true;
        }
      }
    }
    return false;
  }

  /**
   * D仕様書から変数名を抽出
   * @param line パース済み行
   * @returns 変数名、抽出できない場合はnull
   */
  extractVariableName(line: ParsedLine): string | null {
    if (line.specificationType !== 'D') return null;
    if (!line.columnData || !line.columnData.name) return null;
    return line.columnData.name;
  }

  /**
   * P仕様書からプロシージャ名を抽出
   * @param line パース済み行
   * @returns プロシージャ名、抽出できない場合はnull
   */
  extractProcedureName(line: ParsedLine): string | null {
    if (line.specificationType !== 'P') return null;
    if (!line.columnData || !line.columnData.name) return null;
    return line.columnData.name;
  }

  /**
   * C仕様書から命令コードを抽出
   * @param line パース済み行
   * @returns 命令コード、抽出できない場合はnull
   */
  extractOpcode(line: ParsedLine): string | null {
    if (line.specificationType !== 'C') return null;
    if (!line.columnData || !line.columnData.opcode) return null;
    return line.columnData.opcode;
  }

  /**
   * 継続行をグループ化
   * @param lines パース済み行の配列
   * @returns 継続行をグループ化した配列
   */
  groupContinuationLines(lines: ParsedLine[]): ParsedLine[][] {
    const groups: ParsedLine[][] = [];
    let currentGroup: ParsedLine[] = [];

    for (const line of lines) {
      if (line.isContinuation) {
        // 継続行の場合、現在のグループに追加
        currentGroup.push(line);
      } else {
        // 継続行でない場合
        if (currentGroup.length > 0) {
          // 前のグループを保存
          groups.push(currentGroup);
          currentGroup = [];
        }
        // 新しいグループを開始
        currentGroup = [line];
      }
    }

    // 最後のグループを追加
    if (currentGroup.length > 0) {
      groups.push(currentGroup);
    }

    return groups;
  }

  /**
   * 指定された行番号の前後の行を取得
   * @param lines パース済み行の配列
   * @param lineNumber 行番号
   * @param contextLines 前後の行数
   * @returns コンテキストを含む行の配列
   */
  getContextLines(lines: ParsedLine[], lineNumber: number, contextLines: number = 2): ParsedLine[] {
    const index = lines.findIndex(line => line.lineNumber === lineNumber);
    if (index === -1) return [];

    const start = Math.max(0, index - contextLines);
    const end = Math.min(lines.length, index + contextLines + 1);

    return lines.slice(start, end);
  }

  /**
   * 空行を検出
   * @param lines パース済み行の配列
   * @returns 空行の行番号の配列
   */
  findEmptyLines(lines: ParsedLine[]): number[] {
    return lines
      .filter(line => line.trimmedContent.length === 0)
      .map(line => line.lineNumber);
  }

  /**
   * 指定されたパターンに一致する行を検索
   * @param lines パース済み行の配列
   * @param pattern 検索パターン（正規表現）
   * @returns 一致した行の配列
   */
  searchLines(lines: ParsedLine[], pattern: RegExp): ParsedLine[] {
    return lines.filter(line => pattern.test(line.rawContent));
  }

  /**
   * 標識の使用を検出
   * @param lines パース済み行の配列
   * @returns 標識を使用している行の配列
   */
  findIndicatorUsage(lines: ParsedLine[]): ParsedLine[] {
    // *INxx形式の標識を検索
    const indicatorPattern = /\*IN\d{2}/i;
    return this.searchLines(lines, indicatorPattern);
  }

  /**
   * 非推奨命令の使用を検出
   * @param lines パース済み行の配列
   * @returns 非推奨命令を使用している行の配列
   */
  findDeprecatedOpcodes(lines: ParsedLine[]): Array<{ line: ParsedLine; opcode: string }> {
    const deprecated = ['GOTO', 'TAG', 'CABXX', 'CASXX', 'COMP', 'LOKUP', 'XFOOT', 'Z-ADD', 'Z-SUB'];
    const results: Array<{ line: ParsedLine; opcode: string }> = [];

    for (const line of lines) {
      if (line.specificationType !== 'C') continue;
      
      const opcode = this.extractOpcode(line);
      if (opcode && deprecated.some(dep => opcode.toUpperCase().includes(dep))) {
        results.push({ line, opcode });
      }
    }

    return results;
  }

  /**
   * 行の統計情報を取得
   * @param lines パース済み行の配列
   * @returns 統計情報
   */
  getStatistics(lines: ParsedLine[]): {
    totalLines: number;
    commentLines: number;
    codeLines: number;
    continuationLines: number;
    emptyLines: number;
    specificationCounts: Map<SpecificationType, number>;
  } {
    const commentLines = lines.filter(line => line.isComment).length;
    const continuationLines = lines.filter(line => line.isContinuation).length;
    const emptyLines = this.findEmptyLines(lines).length;
    const codeLines = lines.length - commentLines - emptyLines;

    return {
      totalLines: lines.length,
      commentLines,
      codeLines,
      continuationLines,
      emptyLines,
      specificationCounts: this.countBySpecificationType(lines)
    };
  }
}