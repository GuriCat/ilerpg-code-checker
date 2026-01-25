/**
 * ILE-RPG コーディング標準チェッカー - RPGパーサー
 * RPGソースコードを行単位で解析し、構造化されたデータに変換する
 */

import {
  ParsedLine,
  SpecificationType,
  ColumnData,
  HSpecColumnData,
  FSpecColumnData,
  DSpecColumnData,
  PSpecColumnData,
  CSpecColumnData
} from '../types/index.js';

/**
 * RPGパーサークラス
 * RPGソースコードを解析し、各行の情報を抽出する
 */
export class RPGParser {
  /**
   * RPGソースコードを行単位でパース
   * @param code RPGソースコード
   * @returns パース済み行情報の配列
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
   * @param line 行の内容
   * @param lineNumber 行番号（1始まり）
   * @returns パース済み行情報
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
   * @param line 行の内容
   * @returns 仕様書タイプ
   */
  private detectSpecificationType(line: string): SpecificationType {
    // 空行または短すぎる行
    if (line.length < 6) return 'UNKNOWN';
    
    const trimmed = line.trim();
    
    // **FREE形式のチェック（完全自由形式）
    if (trimmed.startsWith('**FREE')) return 'FREE';
    
    // 6桁目（インデックス5）で仕様書タイプを判定
    const col6 = line[5];
    
    // コメント行のチェック（6桁目が'*'）
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
   * @param line 行の内容
   * @returns コメント行の場合true
   */
  private isCommentLine(line: string): boolean {
    if (line.length < 7) return false;
    
    // 7桁目（インデックス6）が'*'の場合はコメント行
    return line[6] === '*';
  }
  
  /**
   * 継続行かどうかを判定
   * @param line 行の内容
   * @param specType 仕様書タイプ
   * @returns 継続行の場合true
   */
  private isContinuationLine(line: string, specType: SpecificationType): boolean {
    if (line.length < 7) return false;
    
    // 桁固定形式の継続行判定
    if (specType !== 'FREE' && specType !== 'UNKNOWN') {
      const col7 = line[6];
      
      // 7桁目が'-'または'+'の場合は継続行
      if (col7 === '-' || col7 === '+') {
        return true;
      }
      
      // F仕様書の場合、ファイル名フィールド（7-16桁）が空白なら継続行
      if (specType === 'F' && line.length >= 16) {
        const fileName = line.substring(6, 16).trim();
        if (fileName.length === 0) {
          return true;
        }
      }
    }
    
    return false;
  }
  
  /**
   * 桁データを抽出
   * @param line 行の内容
   * @param specType 仕様書タイプ
   * @returns 桁位置別データ
   */
  private extractColumnData(line: string, specType: SpecificationType): ColumnData | undefined {
    switch (specType) {
      case 'H':
        return this.extractHSpecData(line);
      case 'F':
        return this.extractFSpecData(line);
      case 'D':
        return this.extractDSpecData(line);
      case 'P':
        return this.extractPSpecData(line);
      case 'C':
        return this.extractCSpecData(line);
      default:
        return undefined;
    }
  }
  
  /**
   * H仕様書の桁データを抽出
   * @param line 行の内容
   * @returns H仕様書の桁データ
   */
  private extractHSpecData(line: string): HSpecColumnData {
    return {
      keyword: this.extractColumn(line, 6, 80) // 7-80桁（インデックス6-79）
    };
  }
  
  /**
   * F仕様書の桁データを抽出
   * @param line 行の内容
   * @returns F仕様書の桁データ
   */
  private extractFSpecData(line: string): FSpecColumnData {
    return {
      fileName: this.extractColumn(line, 6, 16),           // 7-16桁
      fileType: this.extractColumn(line, 16, 17),          // 17桁
      fileDesignation: this.extractColumn(line, 17, 18),   // 18桁
      endOfFile: this.extractColumn(line, 18, 19),         // 19桁
      fileAddition: this.extractColumn(line, 19, 20),      // 20桁
      sequence: this.extractColumn(line, 20, 21),          // 21桁
      fileFormat: this.extractColumn(line, 21, 22),        // 22桁
      recordLength: this.extractColumn(line, 22, 27),      // 23-27桁
      limits: this.extractColumn(line, 27, 28),            // 28桁
      lengthOfKey: this.extractColumn(line, 28, 33),       // 29-33桁
      recordAddressType: this.extractColumn(line, 33, 34), // 34桁
      fileOrganization: this.extractColumn(line, 34, 35),  // 35桁
      device: this.extractColumn(line, 35, 42),            // 36-42桁
      keywords: this.extractColumn(line, 43, 80)           // 44-80桁
    };
  }
  
  /**
   * D仕様書の桁データを抽出
   * @param line 行の内容
   * @returns D仕様書の桁データ
   */
  private extractDSpecData(line: string): DSpecColumnData {
    return {
      name: this.extractColumn(line, 6, 21),                  // 7-21桁
      externalDescription: this.extractColumn(line, 21, 22),  // 22桁
      dataStructureType: this.extractColumn(line, 22, 23),    // 23桁
      definitionType: this.extractColumn(line, 23, 24),       // 24桁
      fromPosition: this.extractColumn(line, 25, 32),         // 26-32桁
      toPosition: this.extractColumn(line, 32, 39),           // 33-39桁
      dataType: this.extractColumn(line, 39, 40),             // 40桁
      decimalPositions: this.extractColumn(line, 40, 42),     // 41-42桁
      keywords: this.extractColumn(line, 43, 80)              // 44-80桁
    };
  }
  
  /**
   * P仕様書の桁データを抽出
   * @param line 行の内容
   * @returns P仕様書の桁データ
   */
  private extractPSpecData(line: string): PSpecColumnData {
    return {
      name: this.extractColumn(line, 6, 21),      // 7-21桁
      beginEnd: this.extractColumn(line, 23, 24), // 24桁
      keywords: this.extractColumn(line, 43, 80)  // 44-80桁
    };
  }
  
  /**
   * C仕様書の桁データを抽出
   * @param line 行の内容
   * @returns C仕様書の桁データ
   */
  private extractCSpecData(line: string): CSpecColumnData {
    return {
      controlLevel: this.extractColumn(line, 6, 8),      // 7-8桁
      indicators: this.extractColumn(line, 8, 17),       // 9-17桁
      factor1: this.extractColumn(line, 11, 25),         // 12-25桁
      opcode: this.extractColumn(line, 25, 35),          // 26-35桁
      factor2: this.extractColumn(line, 35, 49),         // 36-49桁
      result: this.extractColumn(line, 49, 63),          // 50-63桁
      resultIndicators: this.extractColumn(line, 70, 76) // 71-76桁
    };
  }
  
  /**
   * 指定された桁位置から文字列を抽出
   * @param line 行の内容
   * @param startCol 開始桁（0始まりのインデックス）
   * @param endCol 終了桁（0始まりのインデックス、この桁は含まない）
   * @returns 抽出された文字列（トリム済み）、範囲外の場合はundefined
   */
  private extractColumn(line: string, startCol: number, endCol: number): string | undefined {
    if (line.length <= startCol) return undefined;
    
    const extracted = line.substring(startCol, Math.min(endCol, line.length));
    const trimmed = extracted.trim();
    
    return trimmed.length > 0 ? trimmed : undefined;
  }
}