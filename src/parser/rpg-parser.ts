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
    const trimmed = line.trim();
    
    // **FREE形式のチェック（完全自由形式）- 最優先でチェック
    if (trimmed.startsWith('**FREE')) return 'FREE';
    
    // 空行または短すぎる行
    if (line.length < 6) return 'UNKNOWN';
    
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
    
    // Fixed-format continuation line detection
    // A line is a continuation if its name field is completely blank
    if (specType !== 'FREE' && specType !== 'UNKNOWN') {
      switch (specType) {
        case 'F':
          // F-spec: filename field (columns 7-16) must be blank
          if (line.length >= 16) {
            const fileName = line.substring(6, 16).trim();
            return fileName.length === 0;
          }
          break;
          
        case 'D':
        case 'P':
          // D-spec and P-spec: name field (columns 7-21) must be blank
          if (line.length >= 21) {
            const name = line.substring(6, 21).trim();
            return name.length === 0;
          }
          break;
          
        case 'I':
          // I-spec: record name field (columns 7-16) must be blank
          if (line.length >= 16) {
            const recordName = line.substring(6, 16).trim();
            return recordName.length === 0;
          }
          break;
          
        case 'C':
          // C-spec: factor 1 field (columns 12-25) must be blank for continuation
          // Note: C-spec continuation is more complex, this is a simplified check
          if (line.length >= 25) {
            const factor1 = line.substring(11, 25).trim();
            return factor1.length === 0;
          }
          break;
          
        case 'O':
          // O-spec: filename field (columns 7-16) must be blank
          if (line.length >= 16) {
            const fileName = line.substring(6, 16).trim();
            return fileName.length === 0;
          }
          break;
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
   *
   * RPG IV固定形式D仕様書の桁位置 (1始まり → 0始まりインデックス):
   *   桁6(idx5):     仕様書種別 'D'
   *   桁7-21(idx6-20):  名前フィールド (15桁)
   *   桁22(idx21):   外部記述 (E/空白)
   *   桁23(idx22):   データ構造タイプ
   *   桁24-25(idx23-24): 宣言型 (PR/PI/DS/S/C/空白)
   *   桁26-32(idx25-31): From/To位置 (7桁)
   *   桁33-39(idx32-38): 内部長 (7桁、右詰め)
   *   桁40(idx39):   データ型
   *   桁41-42(idx40-41): 小数桁 (右詰め)
   *   桁43-80(idx42-79): キーワード
   *
   * @param line 行の内容
   * @returns D仕様書の桁データ
   */
  private extractDSpecData(line: string): DSpecColumnData {
    return {
      name: this.extractColumn(line, 6, 21),                  // 7-21桁: 名前 (15桁)
      externalDescription: this.extractColumn(line, 21, 22),  // 22桁: 外部記述
      dataStructureType: this.extractColumn(line, 22, 23),    // 23桁: DS型
      declarationType: this.extractColumn(line, 23, 25),      // 24-25桁: 宣言型 (2桁)
      fromPosition: this.extractColumn(line, 25, 32),         // 26-32桁: 開始位置
      toLength: this.extractColumn(line, 32, 39),             // 33-39桁: 内部長
      dataType: this.extractColumn(line, 39, 40),             // 40桁: データ型
      decimalPositions: this.extractColumn(line, 40, 42),     // 41-42桁: 小数桁
      keywords: this.extractColumn(line, 42, 80)              // 43-80桁: キーワード
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