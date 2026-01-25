/**
 * ILE-RPG コーディング標準チェッカー - ファイル読み込みユーティリティ
 * ファイルの読み込みとエンコーディング処理
 */

import * as fs from 'fs';
import * as path from 'path';
import { FileInfo } from '../types/index.js';

/**
 * ファイル読み込みクラス
 * RPGソースファイルの読み込みとエンコーディング処理を提供
 */
export class FileReader {
  /**
   * ファイルを読み込む
   * @param filePath ファイルパス
   * @param encoding エンコーディング（デフォルト: utf-8）
   * @returns ファイル情報
   */
  async readFile(filePath: string, encoding: BufferEncoding = 'utf-8'): Promise<FileInfo> {
    try {
      // ファイルの存在確認
      if (!fs.existsSync(filePath)) {
        throw new Error(`ファイルが見つかりません: ${filePath}`);
      }

      // ファイルの読み込み
      const content = await fs.promises.readFile(filePath, encoding);

      return {
        path: filePath,
        content: content.toString(),
        encoding
      };
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`ファイルの読み込みに失敗しました: ${error.message}`);
      }
      throw error;
    }
  }

  /**
   * ファイルを同期的に読み込む
   * @param filePath ファイルパス
   * @param encoding エンコーディング（デフォルト: utf-8）
   * @returns ファイル情報
   */
  readFileSync(filePath: string, encoding: BufferEncoding = 'utf-8'): FileInfo {
    try {
      // ファイルの存在確認
      if (!fs.existsSync(filePath)) {
        throw new Error(`ファイルが見つかりません: ${filePath}`);
      }

      // ファイルの読み込み
      const content = fs.readFileSync(filePath, encoding);

      return {
        path: filePath,
        content: content.toString(),
        encoding
      };
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`ファイルの読み込みに失敗しました: ${error.message}`);
      }
      throw error;
    }
  }

  /**
   * 複数のファイルを読み込む
   * @param filePaths ファイルパスの配列
   * @param encoding エンコーディング（デフォルト: utf-8）
   * @returns ファイル情報の配列
   */
  async readFiles(filePaths: string[], encoding: BufferEncoding = 'utf-8'): Promise<FileInfo[]> {
    const results: FileInfo[] = [];

    for (const filePath of filePaths) {
      try {
        const fileInfo = await this.readFile(filePath, encoding);
        results.push(fileInfo);
      } catch (error) {
        // エラーが発生しても他のファイルの読み込みを続行
        console.error(`ファイル読み込みエラー: ${filePath}`, error);
      }
    }

    return results;
  }

  /**
   * ディレクトリ内のRPGファイルを検索
   * @param dirPath ディレクトリパス
   * @param extensions 検索する拡張子（デフォルト: ['.rpgle', '.rpg', '.sqlrpgle']）
   * @param recursive 再帰的に検索するか（デフォルト: false）
   * @returns ファイルパスの配列
   */
  findRPGFiles(
    dirPath: string,
    extensions: string[] = ['.rpgle', '.rpg', '.sqlrpgle'],
    recursive: boolean = false
  ): string[] {
    const files: string[] = [];

    try {
      if (!fs.existsSync(dirPath)) {
        throw new Error(`ディレクトリが見つかりません: ${dirPath}`);
      }

      const entries = fs.readdirSync(dirPath, { withFileTypes: true });

      for (const entry of entries) {
        const fullPath = path.join(dirPath, entry.name);

        if (entry.isDirectory() && recursive) {
          // 再帰的にサブディレクトリを検索
          files.push(...this.findRPGFiles(fullPath, extensions, recursive));
        } else if (entry.isFile()) {
          // 拡張子をチェック
          const ext = path.extname(entry.name).toLowerCase();
          if (extensions.includes(ext)) {
            files.push(fullPath);
          }
        }
      }
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`ファイル検索に失敗しました: ${error.message}`);
      }
      throw error;
    }

    return files;
  }

  /**
   * ファイルが存在するかチェック
   * @param filePath ファイルパス
   * @returns 存在する場合true
   */
  fileExists(filePath: string): boolean {
    return fs.existsSync(filePath);
  }

  /**
   * ファイルの情報を取得
   * @param filePath ファイルパス
   * @returns ファイル統計情報
   */
  getFileStats(filePath: string): fs.Stats | null {
    try {
      if (!fs.existsSync(filePath)) {
        return null;
      }
      return fs.statSync(filePath);
    } catch (error) {
      return null;
    }
  }

  /**
   * ファイルサイズを取得（バイト単位）
   * @param filePath ファイルパス
   * @returns ファイルサイズ、エラーの場合は-1
   */
  getFileSize(filePath: string): number {
    const stats = this.getFileStats(filePath);
    return stats ? stats.size : -1;
  }

  /**
   * ファイルの最終更新日時を取得
   * @param filePath ファイルパス
   * @returns 最終更新日時、エラーの場合はnull
   */
  getLastModified(filePath: string): Date | null {
    const stats = this.getFileStats(filePath);
    return stats ? stats.mtime : null;
  }

  /**
   * 相対パスを絶対パスに変換
   * @param relativePath 相対パス
   * @param basePath 基準パス（デフォルト: カレントディレクトリ）
   * @returns 絶対パス
   */
  resolveFilePath(relativePath: string, basePath?: string): string {
    if (path.isAbsolute(relativePath)) {
      return relativePath;
    }
    return path.resolve(basePath || process.cwd(), relativePath);
  }

  /**
   * ファイルパスを正規化
   * @param filePath ファイルパス
   * @returns 正規化されたパス
   */
  normalizeFilePath(filePath: string): string {
    return path.normalize(filePath);
  }

  /**
   * ファイル名を取得（拡張子なし）
   * @param filePath ファイルパス
   * @returns ファイル名（拡張子なし）
   */
  getFileNameWithoutExtension(filePath: string): string {
    return path.basename(filePath, path.extname(filePath));
  }

  /**
   * ディレクトリパスを取得
   * @param filePath ファイルパス
   * @returns ディレクトリパス
   */
  getDirectoryPath(filePath: string): string {
    return path.dirname(filePath);
  }
}