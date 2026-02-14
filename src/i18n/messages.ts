/**
 * ILE-RPG Coding Standards Checker - Internationalization Messages
 * Message definitions for English and Japanese
 */

export type Language = 'en' | 'ja';

export interface Messages {
  // General
  checkResult: string;
  file: string;
  summary: string;
  totalIssues: string;
  errors: string;
  warnings: string;
  infos: string;
  checkedLines: string;
  specificationStats: string;
  specStats: string;
  detectedIssues: string;
  noIssuesFound: string;
  noIssues: string;
  judgment: string;
  pass: string;
  fail: string;
  passed: string;
  failed: string;
  result: string;
  item: string;
  value: string;
  lines: string;
  unknown: string;
  comment: string;
  
  // Specification types
  hSpec: string;
  fSpec: string;
  dSpec: string;
  pSpec: string;
  iSpec: string;
  cSpec: string;
  oSpec: string;
  
  // Severity
  error: string;
  warning: string;
  info: string;
  
  // Categories
  structure: string;
  syntax: string;
  naming: string;
  bestPractice: string;
  deprecated: string;
  
  // Common messages
  line: string;
  column: string;
  rule: string;
  description: string;
  suggestion: string;
  code: string;
  before: string;
  after: string;
}

const englishMessages: Messages = {
  // General
  checkResult: 'ILE-RPG Coding Standards Check Result',
  file: 'File',
  summary: 'Summary',
  totalIssues: 'Total Issues',
  errors: 'Errors',
  warnings: 'Warnings',
  infos: 'Information',
  checkedLines: 'Checked Lines',
  specificationStats: 'Specification Statistics',
  specStats: 'Specification Statistics',
  detectedIssues: 'Detected Issues',
  noIssuesFound: 'No issues found.',
  noIssues: 'No issues found.',
  judgment: 'Judgment',
  pass: '✓ Pass',
  fail: '✗ Fail',
  passed: 'Passed',
  failed: 'Failed',
  result: 'Result',
  item: 'Item',
  value: 'Value',
  lines: ' lines',
  unknown: 'Unknown',
  comment: 'Comment',
  
  // Specification types
  hSpec: 'H-Spec',
  fSpec: 'F-Spec',
  dSpec: 'D-Spec',
  pSpec: 'P-Spec',
  iSpec: 'I-Spec',
  cSpec: 'C-Spec',
  oSpec: 'O-Spec',
  
  // Severity
  error: 'Error',
  warning: 'Warning',
  info: 'Info',
  
  // Categories
  structure: 'Structure',
  syntax: 'Syntax',
  naming: 'Naming',
  bestPractice: 'Best Practice',
  deprecated: 'Deprecated',
  
  // Common messages
  line: 'Line ',
  column: 'Column',
  rule: 'Rule',
  description: 'Description',
  suggestion: 'Suggestion',
  code: 'Code',
  before: 'Before',
  after: 'After'
};

const japaneseMessages: Messages = {
  // General
  checkResult: 'ILE-RPG コーディング標準チェック結果',
  file: 'ファイル',
  summary: 'サマリー',
  totalIssues: '総問題数',
  errors: 'エラー',
  warnings: '警告',
  infos: '情報',
  checkedLines: 'チェック行数',
  specificationStats: '仕様書タイプ別統計',
  specStats: '仕様書タイプ別統計',
  detectedIssues: '検出された問題',
  noIssuesFound: '問題は検出されませんでした。',
  noIssues: '問題は検出されませんでした。',
  judgment: '判定',
  pass: '✓ 合格',
  fail: '✗ 不合格',
  passed: '合格',
  failed: '不合格',
  result: '判定',
  item: '項目',
  value: '値',
  lines: '行',
  unknown: '不明',
  comment: 'コメント',
  
  // Specification types
  hSpec: 'H仕様書',
  fSpec: 'F仕様書',
  dSpec: 'D仕様書',
  pSpec: 'P仕様書',
  iSpec: 'I仕様書',
  cSpec: 'C仕様書',
  oSpec: 'O仕様書',
  
  // Severity
  error: 'エラー',
  warning: '警告',
  info: '情報',
  
  // Categories
  structure: '構造',
  syntax: '文法',
  naming: '命名規約',
  bestPractice: 'ベストプラクティス',
  deprecated: '非推奨',
  
  // Common messages
  line: '行',
  column: '桁',
  rule: 'ルール',
  description: '説明',
  suggestion: '提案',
  code: 'コード',
  before: '修正前',
  after: '修正後'
};

/**
 * Get messages for specified language
 */
export function getMessages(language: Language = 'en'): Messages {
  return language === 'ja' ? japaneseMessages : englishMessages;
}

/**
 * Message formatter with language support
 */
export class MessageFormatter {
  private messages: Messages;
  private language: Language;

  constructor(language: Language = 'en') {
    this.language = language;
    this.messages = getMessages(language);
  }

  /**
   * Get message by key
   */
  getMessage(key: keyof Messages): string {
    return this.messages[key];
  }

  /**
   * Format message with parameters
   */
  format(template: string, ...args: any[]): string {
    return template.replace(/{(\d+)}/g, (match, index) => {
      return typeof args[index] !== 'undefined' ? args[index] : match;
    });
  }

  /**
   * Get current language
   */
  getLanguage(): Language {
    return this.language;
  }

  /**
   * Set language
   */
  setLanguage(language: Language): void {
    this.language = language;
    this.messages = getMessages(language);
  }
}