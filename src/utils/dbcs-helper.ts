/**
 * ILE-RPG Coding Standards Checker - DBCS Helper
 * Utilities for handling Double-Byte Character Set (DBCS) strings
 */

/**
 * DBCS Helper class
 * Provides utilities for calculating actual byte length considering DBCS shift characters
 */
export class DBCSHelper {
  /**
   * Check if a character is a DBCS character
   * DBCS characters typically include:
   * - Japanese Hiragana, Katakana, Kanji
   * - Chinese characters
   * - Korean characters
   * @param char Character to check
   * @returns true if character is DBCS
   */
  static isDBCS(char: string): boolean {
    if (!char || char.length === 0) return false;
    
    const code = char.charCodeAt(0);
    
    // Japanese Hiragana (U+3040 to U+309F)
    if (code >= 0x3040 && code <= 0x309F) return true;
    
    // Japanese Katakana (U+30A0 to U+30FF)
    if (code >= 0x30A0 && code <= 0x30FF) return true;
    
    // CJK Unified Ideographs (U+4E00 to U+9FFF) - Common Kanji/Chinese
    if (code >= 0x4E00 && code <= 0x9FFF) return true;
    
    // CJK Compatibility Ideographs (U+F900 to U+FAFF)
    if (code >= 0xF900 && code <= 0xFAFF) return true;
    
    // Hangul Syllables (U+AC00 to U+D7AF) - Korean
    if (code >= 0xAC00 && code <= 0xD7AF) return true;
    
    // Full-width Latin characters (U+FF00 to U+FFEF)
    if (code >= 0xFF00 && code <= 0xFFEF) return true;
    
    return false;
  }

  /**
   * Calculate the actual byte length of a string considering DBCS shift characters
   * In RPG, DBCS strings are enclosed with shift-out (SO) and shift-in (SI) characters,
   * each taking 1 byte. The format is: SO + DBCS_chars + SI
   * 
   * @param str String to calculate
   * @returns Actual byte length including shift characters
   */
  static calculateByteLength(str: string): number {
    if (!str || str.length === 0) return 0;
    
    let byteLength = 0;
    let inDBCS = false;
    let hasDBCS = false;
    
    for (let i = 0; i < str.length; i++) {
      const char = str[i];
      const isCurrentDBCS = this.isDBCS(char);
      
      if (isCurrentDBCS) {
        hasDBCS = true;
        if (!inDBCS) {
          // Entering DBCS section - add SO (Shift-Out) character
          byteLength += 1;
          inDBCS = true;
        }
        // DBCS character takes 2 bytes
        byteLength += 2;
      } else {
        if (inDBCS) {
          // Leaving DBCS section - add SI (Shift-In) character
          byteLength += 1;
          inDBCS = false;
        }
        // Single-byte character
        byteLength += 1;
      }
    }
    
    // If string ends while in DBCS mode, add SI character
    if (inDBCS) {
      byteLength += 1;
    }
    
    return byteLength;
  }

  /**
   * Count DBCS characters in a string
   * @param str String to analyze
   * @returns Number of DBCS characters
   */
  static countDBCSCharacters(str: string): number {
    if (!str || str.length === 0) return 0;
    
    let count = 0;
    for (let i = 0; i < str.length; i++) {
      if (this.isDBCS(str[i])) {
        count++;
      }
    }
    return count;
  }

  /**
   * Check if string contains any DBCS characters
   * @param str String to check
   * @returns true if string contains DBCS characters
   */
  static containsDBCS(str: string): boolean {
    if (!str || str.length === 0) return false;
    
    for (let i = 0; i < str.length; i++) {
      if (this.isDBCS(str[i])) {
        return true;
      }
    }
    return false;
  }

  /**
   * Calculate the number of shift characters needed for a string
   * @param str String to analyze
   * @returns Number of shift characters (SO + SI pairs)
   */
  static calculateShiftCharacters(str: string): number {
    if (!str || str.length === 0) return 0;
    
    let shiftCount = 0;
    let inDBCS = false;
    
    for (let i = 0; i < str.length; i++) {
      const isCurrentDBCS = this.isDBCS(str[i]);
      
      if (isCurrentDBCS && !inDBCS) {
        // Entering DBCS section
        shiftCount += 2; // SO + eventual SI
        inDBCS = true;
      } else if (!isCurrentDBCS && inDBCS) {
        // Leaving DBCS section
        inDBCS = false;
      }
    }
    
    return shiftCount;
  }

  /**
   * Get detailed byte analysis of a string
   * @param str String to analyze
   * @returns Detailed analysis object
   */
  static analyzeString(str: string): {
    totalLength: number;
    byteLength: number;
    dbcsCount: number;
    sbcsCount: number;
    shiftCharacters: number;
    containsDBCS: boolean;
  } {
    const totalLength = str.length;
    const byteLength = this.calculateByteLength(str);
    const dbcsCount = this.countDBCSCharacters(str);
    const sbcsCount = totalLength - dbcsCount;
    const shiftCharacters = this.calculateShiftCharacters(str);
    const containsDBCS = this.containsDBCS(str);
    
    return {
      totalLength,
      byteLength,
      dbcsCount,
      sbcsCount,
      shiftCharacters,
      containsDBCS
    };
  }
}