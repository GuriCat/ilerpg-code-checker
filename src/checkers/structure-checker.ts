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

    // Skip further checks for continuation lines (blank filename field is normal for continuation)
    if (line.isContinuation) {
      return issues;
    }

    // Check filename field (columns 7-16)
    if (line.rawContent.length >= 16 && checkLevel !== 'basic') {
      const fileName = line.rawContent.substring(6, 16).trim();
      if (fileName.length === 0) {
        issues.push({
          severity: 'error',
          category: 'structure',
          line: line.lineNumber,
          column: 7,
          endColumn: 16,
          message: 'F仕様書のファイル名（7-16桁）が空です。',
          rule: 'F_SPEC_FILENAME',
          ruleDescription: 'F仕様書の7-16桁にはファイル名を記述する必要があります。継続行の場合はファイル名フィールドを空白にします。',
          suggestion: 'ファイル名を記述してください。',
          codeSnippet: line.rawContent
        });
      }
    }

    // Check file type (column 17) for standard level and above
    if (line.rawContent.length >= 17 && checkLevel !== 'basic') {
      const fileType = line.rawContent[16].toUpperCase();
      const validTypes = ['I', 'O', 'U', 'C', ' '];
      if (!validTypes.includes(fileType)) {
        issues.push({
          severity: 'error',
          category: 'structure',
          line: line.lineNumber,
          column: 17,
          message: `F仕様書のファイルタイプ（17桁）が不正です: '${fileType}'`,
          rule: 'F_SPEC_FILE_TYPE',
          ruleDescription: '有効なファイルタイプ: I（入力）, O（出力）, U（更新）, C（組合せ）, または空白',
          codeSnippet: line.rawContent
        });
      }
    }

    // デバイス（36-42桁）のチェック（standardレベル以上）
    if (line.rawContent.length >= 42 && checkLevel !== 'basic') {
      const device = line.rawContent.substring(35, 42).trim();
      if (device.length > 0) {
        const validDevices = ['DISK', 'PRINTER', 'WORKSTN', 'SPECIAL'];
        const deviceUpper = device.toUpperCase();
        if (!validDevices.some(valid => deviceUpper.startsWith(valid))) {
          issues.push({
            severity: 'warning',
            category: 'structure',
            line: line.lineNumber,
            column: 36,
            endColumn: 42,
            message: `F仕様書のデバイス（36-42桁）が一般的でない値です: '${device}'`,
            rule: 'F_SPEC_DEVICE',
            ruleDescription: '一般的なデバイス: DISK, PRINTER, WORKSTN, SPECIAL',
            suggestion: 'デバイス名が正しいか確認してください。',
            codeSnippet: line.rawContent
          });
        }
      }
    }

    return issues;
  }

  /**
   * D仕様書の桁位置チェック
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

    // コメント行・継続行はこれ以上のチェックをスキップ
    if (line.isComment || line.isContinuation) {
      return issues;
    }

    // 名前（7-21桁）のチェック（standardレベル以上）
    if (line.rawContent.length >= 21 && checkLevel !== 'basic') {
      const name = line.rawContent.substring(6, 21).trim();
      // 桁22以降にデータがある場合のみ警告（宣言型やキーワードのみの行は除外）
      const hasFieldData = line.rawContent.length > 21 && line.rawContent.substring(21).trim().length > 0;
      if (name.length === 0 && hasFieldData) {
        // 宣言型のみの行（TEMPLATE等）は名前なしでも正常
        const declType = line.rawContent.length >= 25 ? line.rawContent.substring(23, 25).trim() : '';
        const kw = line.rawContent.length > 42 ? line.rawContent.substring(42).trim() : '';
        const isTemplateOrKwOnly = declType.length > 0 || /^(TEMPLATE|LIKEDS|LIKE|EXTPROC|EXTPGM)/.test(kw);
        if (!isTemplateOrKwOnly) {
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
    }

    // --- standardレベル以上のチェック ---
    if (checkLevel === 'basic') {
      return issues;
    }

    // 宣言型フィールド（桁24-25）のチェック
    issues.push(...this.checkDSpecDeclarationType(line));

    // データ型（桁40）のチェック
    issues.push(...this.checkDSpecDataType(line));

    // サイズフィールド（桁33-39）のチェック
    issues.push(...this.checkDSpecSizeField(line));

    // 小数桁フィールド（桁41-42）のチェック
    issues.push(...this.checkDSpecDecimalField(line));

    // 桁ずれ検出（ヒューリスティック）
    issues.push(...this.checkDSpecColumnShift(line));

    // --- strictレベルのチェック ---
    if (checkLevel === 'strict') {
      // 名前フィールドの配置検証
      issues.push(...this.checkDSpecNamePosition(line));
    }

    return issues;
  }

  /**
   * D仕様書の宣言型フィールド（桁24-25）をチェック
   * 有効値: PR, PI, DS, S, C, E, 空白
   */
  private checkDSpecDeclarationType(line: ParsedLine): Issue[] {
    const issues: Issue[] = [];
    if (line.rawContent.length < 25) return issues;

    const declField = line.rawContent.substring(23, 25);
    const declTrimmed = declField.trim();

    if (declTrimmed.length === 0) return issues; // 空白は正常

    const validDeclTypes = ['PR', 'PI', 'DS', 'S', 'C', 'E'];
    // 1文字の場合は右側が空白 (例: "S ", "C ", "E ")
    const normalizedDecl = declTrimmed.toUpperCase();

    if (!validDeclTypes.includes(normalizedDecl)) {
      issues.push({
        severity: 'error',
        category: 'structure',
        line: line.lineNumber,
        column: 24,
        endColumn: 25,
        message: `D仕様書の宣言型（24-25桁）が不正です: '${declField}'`,
        rule: 'D_SPEC_DECL_TYPE',
        ruleDescription: '有効な宣言型: PR（プロトタイプ）, PI（プロシージャI/F）, DS（データ構造）, S（スタンドアロン）, C（定数）, E（列挙型）, または空白',
        suggestion: '24-25桁目の宣言型を確認してください。桁ずれの可能性があります。',
        codeSnippet: line.rawContent
      });
    }

    return issues;
  }

  /**
   * D仕様書のデータ型（桁40）をチェック
   * 有効値: A, B, C, D, F, G, I, N, O, P, S, T, U, Z, *, 空白
   */
  private checkDSpecDataType(line: ParsedLine): Issue[] {
    const issues: Issue[] = [];
    if (line.rawContent.length < 40) return issues;

    const dataType = line.rawContent[39];
    const validTypes = ['A', 'B', 'C', 'D', 'F', 'G', 'I', 'N', 'O', 'P', 'S', 'T', 'U', 'Z', '*', ' '];

    if (!validTypes.includes(dataType.toUpperCase())) {
      issues.push({
        severity: 'error',
        category: 'structure',
        line: line.lineNumber,
        column: 40,
        message: `D仕様書のデータ型（40桁）が不正です: '${dataType}'`,
        rule: 'D_SPEC_DATATYPE',
        ruleDescription: '有効なデータ型: A, B, C, D, F, G, I, N, O, P, S, T, U, Z, *, または空白',
        suggestion: '40桁目のデータ型を確認してください。桁ずれの可能性があります。',
        codeSnippet: line.rawContent
      });
    }

    return issues;
  }

  /**
   * D仕様書のサイズフィールド（桁33-39）をチェック
   * - 数値のみ（存在する場合）で右詰め
   * - 非数値文字がサイズ位置にある場合は桁ずれの可能性
   * - ポインタ型(*)の場合は桁40に配置されるべき
   */
  private checkDSpecSizeField(line: ParsedLine): Issue[] {
    const issues: Issue[] = [];
    if (line.rawContent.length < 39) return issues;

    const sizeField = line.rawContent.substring(32, 39); // 桁33-39 (0-indexed: 32-38)
    const sizeTrimmed = sizeField.trim();

    if (sizeTrimmed.length === 0) return issues; // 空白は正常（LIKEDS等）

    // 数値のみであるべき（右詰め）
    if (!/^\d+$/.test(sizeTrimmed)) {
      // ポインタ型の場合: 桁39(idx38)に'*'があるのは正常（桁40=idx39へ配置すべきだが、
      // 実際にはサイズフィールドの最後の桁にポインタ型が入ることがある）
      // ただし '*' 単独で桁39にある場合はデータ型として桁40に配置すべき
      if (sizeTrimmed === '*') {
        // 桁39に'*'があるが、これは桁40(データ型)に配置されるべき
        // ただしRPGでは桁40に*が来るので、この位置にあるのは桁ずれ
        // ※extractColumnがtrimするため、ここでは生データで確認
        const rawChar39 = line.rawContent[38]; // 桁39 (0-indexed: 38)
        if (rawChar39 === '*') {
          // 桁39に*がある（桁40ではない）= 桁ずれ
          issues.push({
            severity: 'error',
            category: 'structure',
            line: line.lineNumber,
            column: 33,
            endColumn: 39,
            message: 'D仕様書のサイズフィールド（33-39桁）にポインタ型\'*\'があります。ポインタ型は40桁に配置してください。',
            rule: 'D_SPEC_POINTER_POSITION',
            ruleDescription: 'ポインタ型(*)はデータ型フィールド（40桁）に配置する必要があります。サイズフィールド（33-39桁）には数値のみ記述できます。',
            suggestion: '桁位置がずれている可能性があります。ポインタ型\'*\'を40桁に配置してください。',
            codeSnippet: line.rawContent
          });
        }
      } else {
        // キーワードやデータ型文字がサイズ位置に入っている = 桁ずれの可能性大
        issues.push({
          severity: 'error',
          category: 'structure',
          line: line.lineNumber,
          column: 33,
          endColumn: 39,
          message: `D仕様書のサイズフィールド（33-39桁）に非数値が含まれています: '${sizeTrimmed}'`,
          rule: 'D_SPEC_SIZE_FIELD',
          ruleDescription: 'サイズフィールド（33-39桁）には数値（内部長）のみ記述できます。非数値文字がある場合、桁位置がずれている可能性があります。',
          suggestion: '桁位置を確認してください。サイズは33-39桁に右詰めで記述します。',
          codeSnippet: line.rawContent
        });
      }
    }

    return issues;
  }

  /**
   * D仕様書の小数桁フィールド（桁41-42）をチェック
   * - 数値のみ（存在する場合）で右詰め
   * - 有効範囲: 0-63
   */
  private checkDSpecDecimalField(line: ParsedLine): Issue[] {
    const issues: Issue[] = [];
    if (line.rawContent.length < 42) return issues;

    const decField = line.rawContent.substring(40, 42); // 桁41-42 (0-indexed: 40-41)
    const decTrimmed = decField.trim();

    if (decTrimmed.length === 0) return issues; // 空白は正常

    // 数値のみであるべき
    if (!/^\d+$/.test(decTrimmed)) {
      issues.push({
        severity: 'warning',
        category: 'structure',
        line: line.lineNumber,
        column: 41,
        endColumn: 42,
        message: `D仕様書の小数桁（41-42桁）に非数値が含まれています: '${decTrimmed}'`,
        rule: 'D_SPEC_DECIMAL',
        ruleDescription: '小数桁フィールド（41-42桁）には数値のみ記述できます。桁位置がずれている可能性があります。',
        suggestion: '桁位置を確認してください。小数桁は41-42桁に右詰めで記述します。',
        codeSnippet: line.rawContent
      });
    } else {
      // 範囲チェック (0-63)
      const decValue = parseInt(decTrimmed, 10);
      if (decValue < 0 || decValue > 63) {
        issues.push({
          severity: 'warning',
          category: 'structure',
          line: line.lineNumber,
          column: 41,
          endColumn: 42,
          message: `D仕様書の小数桁（41-42桁）が有効範囲外です: ${decValue}`,
          rule: 'D_SPEC_DECIMAL',
          ruleDescription: '小数桁フィールドの有効範囲は0-63です。',
          suggestion: '小数桁の値を確認してください。',
          codeSnippet: line.rawContent
        });
      }
    }

    return issues;
  }

  /**
   * D仕様書の桁ずれを検出するヒューリスティックチェック
   *
   * DSPEC_COLUMN_FIX.mdで報告された典型的な桁ずれパターン:
   * - キーワード（LIKEDS, CONST, VARYING等）がサイズフィールド(33-39)に侵入
   * - データ型+サイズ（例: "10I"）が本来の桁位置から1桁以上ずれ
   * - 名前フィールドの余分なスペースにより全体が右にシフト
   */
  private checkDSpecColumnShift(line: ParsedLine): Issue[] {
    const issues: Issue[] = [];
    if (line.rawContent.length < 43) return issues;

    // サイズフィールド（桁33-39）にキーワードが含まれていないか
    const sizeField = line.rawContent.substring(32, 39);
    const knownKeywords = [
      'LIKEDS', 'LIKE', 'CONST', 'VARYING', 'VALUE', 'INZ',
      'DIM', 'EXTPROC', 'EXTPGM', 'OVERLAY', 'BASED', 'TEMPLATE',
      'QUALIFIED', 'NOOPT', 'STATIC', 'DTAARA', 'PREFIX', 'EXPORT',
      'IMPORT', 'ALIGN', 'OPTIONS', 'ASCEND', 'DESCEND', 'CTDATA'
    ];

    for (const kw of knownKeywords) {
      if (sizeField.toUpperCase().includes(kw.substring(0, Math.min(kw.length, 7)))) {
        issues.push({
          severity: 'error',
          category: 'structure',
          line: line.lineNumber,
          column: 33,
          endColumn: 42,
          message: `D仕様書の桁位置がずれています。サイズフィールド（33-39桁）にキーワード'${kw}'の一部が検出されました。`,
          rule: 'D_SPEC_COLUMN_SHIFT',
          ruleDescription: 'キーワードは43桁以降に記述する必要があります。サイズフィールド（33-39桁）にキーワードが含まれている場合、名前フィールドの桁位置がずれている可能性があります。',
          suggestion: '名前フィールド（7-21桁、15桁固定）の長さを確認し、桁位置を修正してください。宣言名は桁7開始、サブフィールドは桁8開始です。',
          codeSnippet: line.rawContent
        });
        break; // 1つ検出したら十分
      }
    }

    return issues;
  }

  /**
   * D仕様書の名前フィールド配置検証（strictレベル）
   *
   * DSPEC_COLUMN_FIX.mdに基づく配置規則:
   * - 宣言名（DS名, PR名, 定数名等）: 桁7開始（'D'の直後）
   * - サブフィールド: 桁8開始（'D'の後に1つスペース）
   * - 無名行（継続行, TEMPLATE等）: 桁7-21は全て空白
   */
  private checkDSpecNamePosition(line: ParsedLine): Issue[] {
    const issues: Issue[] = [];
    if (line.rawContent.length < 25) return issues;

    const nameField = line.rawContent.substring(6, 21); // 桁7-21 (15桁)
    const nameTrimmed = nameField.trim();
    if (nameTrimmed.length === 0) return issues; // 無名行はスキップ

    // 宣言型を取得（桁24-25）
    const declType = line.rawContent.length >= 25 ? line.rawContent.substring(23, 25).trim().toUpperCase() : '';
    const hasDeclType = ['PR', 'PI', 'DS', 'S', 'C', 'E'].includes(declType);

    if (hasDeclType) {
      // 宣言名は桁7開始: nameField[0]（桁7）が非空白であるべき
      if (nameField[0] === ' ') {
        issues.push({
          severity: 'warning',
          category: 'structure',
          line: line.lineNumber,
          column: 7,
          endColumn: 21,
          message: `D仕様書の宣言名'${nameTrimmed}'は桁7から開始する必要があります（現在、先頭にスペースがあります）。`,
          rule: 'D_SPEC_NAME_POSITION',
          ruleDescription: 'DS/PR/PI/S/C等の宣言名は桁7（D仕様書識別子の直後）から開始します。',
          suggestion: `'${nameTrimmed}'の前の余分なスペースを削除してください。`,
          codeSnippet: line.rawContent
        });
      }
    } else {
      // サブフィールドは桁8開始: nameField[0]（桁7）が空白、nameField[1]（桁8）が非空白
      if (nameTrimmed.length > 0 && nameField[0] !== ' ') {
        issues.push({
          severity: 'warning',
          category: 'structure',
          line: line.lineNumber,
          column: 7,
          endColumn: 21,
          message: `D仕様書のサブフィールド'${nameTrimmed}'は桁8から開始する必要があります（桁7にスペースが必要です）。`,
          rule: 'D_SPEC_NAME_POSITION',
          ruleDescription: 'サブフィールド（宣言型なし）は桁8から開始します（桁7は空白）。宣言名（DS/PR/PI等）と区別するためです。',
          suggestion: `'${nameTrimmed}'の前にスペースを1つ追加してください。`,
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