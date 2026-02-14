      *===============================================================
      * PDFGEN - PDF文書ビルダー
      * Version: 3.0.0  Date: 2026-02-12
      *
      * 高レベルAPI: LoadFont, AddPage, AddText, AddTextU, SavePDF
      * PDF 1.4形式のファイルを生成し、TrueTypeサブセットフォントを
      * 埋め込む。CIDFont/Type0構造でUnicode文字を出力する。
      *
      * 処理の流れ:
      *   1. LoadFont()  - TTFフォントを解析・登録
      *   2. AddPage()   - ページを追加（デフォルトA4）
      *   3. AddText()   - EBCDIC文字列をUTF-8変換して配置
      *      AddTextU()  - Unicodeコードポイント配列で直接配置
      *   4. SavePDF()   - PDF構造を構築しファイルに出力
      *
      * 依存モジュール:
      *   TTFPARSER  - フォント解析（parseTTF, getGlyphIdForCP等）
      *   TTFSUBSET  - サブセット生成（createSubset）
      *   PDFTTFCMAP - CMap/ToUnicode生成
      *   UNICODENM  - NFC正規化
      *===============================================================
     H NOMAIN
      /COPY QSYSINC/QRPGLESRC,SYSTYPES
      /COPY QSYSINC/QRPGLESRC,SYSSTAT
      /COPY QSYSINC/QRPGLESRC,FCNTL
      /COPY QSYSINC/QRPGLESRC,UNISTD

      *-------------------------------------------------------------
      * iconv API - EBCDIC(CCSID 5035)からUTF-32への文字コード変換
      *-------------------------------------------------------------
     D QtqIconvOpen    PR            52A                                        iconv変換Open
     D                                     EXTPROC('QtqIconvOpen')
     D   toCode                      32A   CONST                                変換先コード定義
     D   fromCode                    32A   CONST                                変換元コード定義
     D iconv           PR            10U 0                                      文字コード変換
     D                                     EXTPROC('iconv')
     D   cd                          52A   VALUE                                変換記述子
     D   inBuf                         *                                        入力バッファptr
     D   inLeft                      10U 0                                      入力残バイト数
     D   outBuf                        *                                        出力バッファptr
     D   outLeft                     10U 0                                      出力残バイト数




      *-------------------------------------------------------------
      * 外部プロシージャ宣言 - TTFPARSERモジュール
      * フォントの解析・情報取得・COLR色絵文字レイヤー取得
      *-------------------------------------------------------------
     D parseTTF        PR              *   EXTPROC(*CL:'parseTTF')              TTF解析
     D   fontPath                   256A   CONST VARYING                        フォントIFSパス
     D   fontIndex                   10I 0 VALUE OPTIONS(*NOPASS)               内フォント番号
     D closeTTF        PR                  EXTPROC(*CL:'closeTTF')              TTFクローズ
     D   fontData                      *                                        フォントデータptr
     D getGlyphIdForCP...                                                       CP→グリフID
     D                 PR            10I 0 EXTPROC(*CL:'getGlyphIdForCP')
     D   fontData                      *   CONST                                フォントデータptr
     D   codepoint                   10U 0 CONST                                値
     D getGlyphWidth   PR            10I 0 EXTPROC(*CL:'getGlyphWidth')         グリフ幅取得
     D   fontData                      *   CONST                                フォントデータptr
     D   glyphId                     10I 0 CONST                                グリフID
     D getUnitsPerEm   PR            10I 0 EXTPROC(*CL:'getUnitsPerEm')         Em単位取得
     D   fontData                      *   CONST                                フォントデータptr
     D getAscent       PR            10I 0 EXTPROC(*CL:'getAscent')             上端取得
     D   fontData                      *   CONST                                フォントデータptr
     D getDescent      PR            10I 0 EXTPROC(*CL:'getDescent')            下端取得
     D   fontData                      *   CONST                                フォントデータptr
     D getCapHeight    PR            10I 0 EXTPROC(*CL:'getCapHeight')          大文字高取得
     D   fontData                      *   CONST                                フォントデータptr
      *-------------------------------------------------------------
      * 外部プロシージャ宣言 - TTFSUBSETモジュール
      * 使用グリフだけを含むサブセットフォントを生成
      *-------------------------------------------------------------
     D createSubset    PR            10I 0 EXTPROC(*CL:'createSubset')          サブセット生成
     D   fontData                      *   CONST                                フォントデータ
     D   glyphIds                      *   CONST                                グリフID配列
     D   numGlyphs                   10I 0 CONST                                グリフ数
     D   outPath                    256A   CONST VARYING                        出力パス
      *-------------------------------------------------------------
      * 外部プロシージャ宣言 - PDFTTFCMAPモジュール
      * ToUnicode CMap生成、コードポイント取得、16進変換
      *-------------------------------------------------------------
     D generateToUnicode...                                                     ToUnicode生成
     D                 PR          4096A   VARYING
     D                                     EXTPROC(*CL:'generateToUnicode')
     D   glyphIds                      *   CONST                                グリフID配列ptr
     D   codepoints                    *   CONST                                配列ポインタ
     D   numChars                    10I 0 CONST                                文字数
     D getCodepoint    PR            10U 0 EXTPROC(*CL:'getCodepoint')          CP取得
     D   utf8Str                    256A   CONST VARYING                         入力文字列
     D   pos                         10I 0                                      走査位置
     D toHex4          PR             4A   EXTPROC(*CL:'toHex4')                4桁16進変換
     D   val                         10U 0 CONST                                変換元数値
      *-------------------------------------------------------------
      * COLR/CPAL - 色絵文字テーブル参照
      * hasCOLR: COLR v0テーブルの有無を判定
      * getCOLRLayers: グリフのカラーレイヤーを取得
      *-------------------------------------------------------------
     D hasCOLR         PR            10I 0 EXTPROC(*CL:'hasCOLR')               COLR有無判定
     D   fontData                      *   CONST                                フォントデータptr
     D getCOLRLayers   PR            10I 0 EXTPROC(*CL:                         COLRレイヤ取得
     D                                     'getCOLRLayers')
     D   fontData                      *   CONST                                フォントデータptr
     D   glyphId                     10I 0 CONST                                対象グリフID
     D   outLayGids                    *   CONST                                レイヤーGID出力
     D   outLayClrs                    *   CONST                                レイヤー色出力
     D   maxLayers                   10I 0 CONST                                最大レイヤー数
     D getTable        PR              *   EXTPROC(*CL:'getTable')              テーブル取得
     D   fontData                      *   CONST                                フォントデータptr
     D   tag                          4A   CONST                                テーブルタグ4B

      *-------------------------------------------------------------
      * 内部プロシージャ宣言
      *-------------------------------------------------------------
      * cvt5035: EBCDIC(5035)文字列→Unicodeコードポイント配列変換
     D cvt5035         PR            10I 0                                      5035→UTF32変換
     D   inStr                      256A   CONST VARYING                        入力文字列
     D   outCPs                        *   VALUE                                出力先CP配列ptr
      * writeStr: 可変長文字列をFDに書き込み
     D writeStr        PR            10I 0                                      文字列書込
     D   fd                          10I 0 CONST                                出力先ファイルFD
     D   str                      32767A   CONST VARYING                        書込み文字列
      * writeN: バッファをN バイト書き込み
     D writeN          PR            10I 0                                      Nバイト書込
     D   fd                          10I 0 CONST                                出力先ファイルFD
     D   buffer                        *   VALUE                                書込みバッファptr
     D   length                      10U 0 CONST                                書込みバイト数
     D intToStr        PR            12A   VARYING                              整数→文字列
     D   val                         10I 0 CONST                                変換元整数値
     D uintToStr       PR            12A   VARYING                              符号なし→文字
     D   val                         10U 0 CONST                                変換元符号なし値

      *-------------------------------------------------------------
      * 公開API プロトタイプ
      *-------------------------------------------------------------
      * LoadFont - TTFフォントファイルを読み込み登録する
      *   fontPath: IFSパス（例: /home/user/fonts/Noto.ttf）
      *   fontIndex: TTC内のフォント番号（省略時=0）
      *   戻り値: フォントID（1〜16）、失敗時-1
     D LoadFont        PR            10I 0 EXTPROC(*CL:'LoadFont')              フォント読込
     D   fontPath                   256A   CONST VARYING                        フォントパス
     D   fontIndex                   10I 0 VALUE OPTIONS(*NOPASS)               TTC内番号

      * AddPage - 新規ページを追加する
      *   width/height: ページサイズ（省略時A4: 595x842pt）
      *   戻り値: ページ番号
     D AddPage         PR            10I 0 EXTPROC(*CL:'AddPage')               ページ追加
     D   width                       10I 0 VALUE OPTIONS(*NOPASS)               ページ幅(pt)
     D   height                      10I 0 VALUE OPTIONS(*NOPASS)               ページ高(pt)

      * AddText - EBCDIC文字列をテキストとして配置する
      *   内部でCCSID 5035→UTF-32変換を行い、グリフIDを収集
      *   text: EBCDIC文字列（RPGリテラル等）
      *   x,y: 配置座標（ポイント）  fontSize: フォントサイズ
     D AddText         PR                   EXTPROC(*CL:'AddText')              テキスト追加
     D   text                       256A   CONST VARYING                        テキスト文字列
     D   x                            7P 2 CONST                                X座標(pt)
     D   y                            7P 2 CONST                                Y座標(pt)
     D   fontSize                     5P 2 CONST                                フォントサイズ
     D   fontId                      10I 0 CONST                                フォントID

      * AddTextU - Unicodeコードポイント配列でテキストを配置する
      *   NFC正規化を適用後、コードポイントを4バイトパックして
      *   内部textOps配列に格納。グリフIDも同時に収集する
     D AddTextU        PR                  EXTPROC(*CL:'AddTextU')              Unicode文追加
     D   cpArr                         *   CONST                                CP配列ポインタ
     D   cpCount                     10I 0 CONST                                CP数
     D   x                            7P 2 CONST                                X座標(pt)
     D   y                            7P 2 CONST                                Y座標(pt)
     D   fontSize                     5P 2 CONST                                フォントサイズ
     D   fontId                      10I 0 CONST                                フォントID

      * normalizeNFC - Unicode NFC正規化（UNICODENMモジュール）
     D normalizeNFC    PR            10I 0                                      NFC正規化
     D                                     EXTPROC('NORMALIZENFC')
     D inCP                          10U 0 DIM(4096) CONST                      入力CP配列
     D inCount                       10I 0 CONST                                入力CP数
     D outCP                         10U 0 DIM(4096)                            出力CP配列
     D maxOut                        10I 0 CONST                                出力最大数

      * SavePDF - PDF文書を構築しファイルに出力する
      *   outPath: 出力先IFSパス（例: /home/user/output.pdf）
      *   戻り値: 0=成功、負数=エラー
     D SavePDF         PR            10I 0 EXTPROC(*CL:'SavePDF')               PDF保存
     D   outPath                    256A   CONST VARYING                        出力パス

      *-------------------------------------------------------------
      * 定数
      *-------------------------------------------------------------
     D MAX_FONTS       C                   CONST(16)                            フォント上限
     D MAX_PAGES       C                   CONST(100)                           ページ上限
     D MAX_OPS         C                   CONST(10000)                         テキスト操作上限
     D MAX_GLYPHS      C                   CONST(4096)                          グリフ上限

      *-------------------------------------------------------------
      * データ構造 - フォント情報
      *   fontData: parseTTFが返すフォントデータポインタ
      *   glyphIds/codepoints: 使用文字のグリフID⇔CP対応表
      *-------------------------------------------------------------
     D FontInfo_t      DS                  QUALIFIED TEMPLATE                   フォント情報DS
     D   fontData                      *                                        フォントデータ
     D   fontPath                   256A   VARYING                              フォントパス
     D   fontIndex                   10I 0                                      TTC内番号
     D   fontName                    64A   VARYING                              フォント名
     D   glyphIds                    10I 0 DIM(4096)                            グリフID配列
     D   codepoints                  10U 0 DIM(4096)                            コードポイント
     D   numGlyphs                   10I 0                                      グリフ数
     D   active                       1N                                        使用中フラグ

      * データ構造 - テキスト操作（配置情報1件分）
     D TextOp_t        DS                  QUALIFIED TEMPLATE                   テキスト操作DS
     D   text                       256A   VARYING                              テキスト文字列
     D   x                            7P 2                                      X座標(pt)
     D   y                            7P 2                                      Y座標(pt)
     D   fontSize                     5P 2                                      フォントサイズ
     D   fontId                      10I 0                                      フォントID
     D   pageId                      10I 0                                      ページID

      * データ構造 - ページ情報
     D PageInfo_t      DS                  QUALIFIED TEMPLATE                   ページ情報DS
     D   width                       10I 0                                      ページ幅(pt)
     D   height                      10I 0                                      ページ高(pt)

      *-------------------------------------------------------------
      * モジュールレベル変数 - フォント・ページ・テキスト操作の管理
      *-------------------------------------------------------------
     D fonts           DS                  LIKEDS(FontInfo_t)                   フォント情報配列
     D                                     DIM(16)
     D numFonts        S             10I 0 INZ(0)                               登録フォント数
     D pages           DS                  LIKEDS(PageInfo_t)                   ページ情報配列
     D                                     DIM(100)
     D numPages        S             10I 0 INZ(0)                               現在ページ数
     D textOps         DS                  LIKEDS(TextOp_t)                     テキスト操作配列
     D                                     DIM(10000)
     D numTextOps      S             10I 0 INZ(0)                               テキスト操作数

      *===============================================================
      * LoadFont - フォント読み込み
      * TTFファイルを解析し、フォント配列に登録する。
      * TTC形式の場合はfontIndexで個別フォントを指定可能。
      *===============================================================
     P LoadFont        B                   EXPORT
     D LoadFont        PI            10I 0                                      フォント読込
     D   fontPath                   256A   CONST VARYING                        フォントパス
     D   fontIndex                   10I 0 VALUE OPTIONS(*NOPASS)               内番号
     D pFont           S               *                                        解析結果ptr
     D idx             S             10I 0                                      フォント配列添字
     D fIdx            S             10I 0                                      内番号
       // TTC内フォント番号（省略時は0）
       fIdx = 0;
       IF %PARMS >= 2;
         fIdx = fontIndex;
       ENDIF;
       // TTFファイルを解析してフォントデータポインタを取得
       IF fIdx > 0;
         pFont = parseTTF(fontPath: fIdx);
       ELSE;
         pFont = parseTTF(fontPath);
       ENDIF;
       IF pFont = *NULL;
         RETURN -1;
       ENDIF;
       // フォント配列に登録して番号を返す
       numFonts = numFonts + 1;
       idx = numFonts;
       fonts(idx).fontData = pFont;
       fonts(idx).fontPath = fontPath;
       fonts(idx).fontIndex = fIdx;
       fonts(idx).fontName = 'Font' + %CHAR(idx);
       fonts(idx).numGlyphs = 0;
       fonts(idx).active = '1';
       RETURN idx;
     P                 E

      *===============================================================
      * AddPage - ページ追加
      * 幅・高さ省略時はA4サイズ（595x842ポイント）を使用
      *===============================================================
     P AddPage         B                   EXPORT
     D AddPage         PI            10I 0                                      ページ追加
     D   width                       10I 0 VALUE OPTIONS(*NOPASS)               ページ幅(pt)
     D   height                      10I 0 VALUE OPTIONS(*NOPASS)               ページ高さ(pt)
       numPages = numPages + 1;
       // 引数省略時はA4サイズ（595x842pt）を使用
       IF %PARMS >= 2;
         pages(numPages).width = width;
         pages(numPages).height = height;
       ELSE;
         pages(numPages).width = 595;
         pages(numPages).height = 842;
       ENDIF;
       RETURN numPages;
     P                 E

      *===============================================================
      * AddText - EBCDIC文字列テキスト配置
      * EBCDIC(CCSID 5035)文字列をcvt5035でUnicodeに変換し、
      * 使用グリフIDをフォント情報に登録する。
      * SavePDF時にCIDFont用16進文字列に変換される。
      *===============================================================
     P AddText         B                   EXPORT
     D AddText         PI                                                       テキスト追加
     D   text                       256A   CONST VARYING                        入力文字列
     D   x                            7P 2 CONST                                座標(pt)
     D   y                            7P 2 CONST                                座標(pt)
     D   fontSize                     5P 2 CONST                                文字サイズ(pt)
     D   fontId                      10I 0 CONST                                フォント番号
     D pos             S             10I 0                                      配列位置
     D cp              S             10U 0                                      値
     D gid             S             10I 0                                      グリフID
     D i               S             10I 0                                      ループ添字
     D found           S              1N                                        重複検出フラグ
     D cpArr           S             10U 0 DIM(256)                             変換後CP配列
     D nCPs            S             10I 0                                      数
       // テキスト操作を配列に登録
       numTextOps = numTextOps + 1;
       textOps(numTextOps).text = text;
       textOps(numTextOps).x = x;
       textOps(numTextOps).y = y;
       textOps(numTextOps).fontSize = fontSize;
       textOps(numTextOps).fontId = fontId;
       textOps(numTextOps).pageId = numPages;

       // EBCDIC→Unicode変換し、使用グリフIDを収集
       IF fontId >= 1 AND fontId <= numFonts;
         nCPs = cvt5035(text: %ADDR(cpArr));
         FOR pos = 1 TO nCPs;
           cp = cpArr(pos);
           IF cp > 0;
             // コードポイント→グリフID変換
             gid = getGlyphIdForCP(fonts(fontId).fontData: cp);
             // 重複チェック：未登録ならフォント情報に追加
             found = '0';
             FOR i = 1 TO fonts(fontId).numGlyphs;
               IF fonts(fontId).glyphIds(i) = gid;
                 found = '1';
                 LEAVE;
               ENDIF;
             ENDFOR;
             IF NOT found;
               fonts(fontId).numGlyphs = fonts(fontId).numGlyphs + 1;
               i = fonts(fontId).numGlyphs;
               fonts(fontId).glyphIds(i) = gid;
               fonts(fontId).codepoints(i) = cp;
             ENDIF;
           ENDIF;
         ENDFOR;
       ENDIF;
     P                 E

      *===============================================================
      * AddTextU - Unicodeコードポイント配列テキスト配置
      * コードポイント配列を受け取り、NFC正規化を適用後、
      * 4バイトパック形式でtextOpsに格納する。
      * 色絵文字（COLR）フォントにも対応。
      *===============================================================
     P AddTextU        B                   EXPORT
     D AddTextU        PI                                                       Unicode文追加
     D   cpArr                         *   CONST                                配列ポインタ
     D   cpCount                     10I 0 CONST                                配列の要素数
     D   x                            7P 2 CONST                                座標(pt)
     D   y                            7P 2 CONST                                座標(pt)
     D   fontSize                     5P 2 CONST                                文字サイズ(pt)
     D   fontId                      10I 0 CONST                                フォント番号
     D inCPs           S             10U 0 DIM(256)                             入力CP配列
     D                                     BASED(cpArr)
     D gid             S             10I 0                                      グリフID
     D i               S             10I 0                                      外側ループ添字
     D j               S             10I 0                                      内側ループ添字
     D found           S              1N                                        重複検出フラグ
     D cp              S             10U 0                                      処理中のCP値
     D packBuf         S            256A                                        パック作業域
     D pBuf            S               *                                        のptr
     D pkDS            DS                                                       バイト←→数値変換
     D  pkChar                        1A                                        バイト文字
     D  pkVal                         3U 0 OVERLAY(pkDS:1)                      数値(0-255)
     D bArr            S              1A   DIM(256)                             バイト配列ビュー
     D                                     BASED(pBuf)
     D nPack           S             10I 0                                      パック文字数
      * NFC normalization
     D nfcIn           S             10U 0 DIM(4096)                            入力用
     D nfcOut          S             10U 0 DIM(4096)                            出力用
     D nfcCount        S             10I 0                                      結果数
       // NFC正規化を適用（濁点合成等）
       FOR i = 1 TO cpCount;
         nfcIn(i) = inCPs(i);
       ENDFOR;
       nfcCount = normalizeNFC(nfcIn: cpCount: nfcOut: 4096);
       // 正規化失敗時は元のコードポイントをそのまま使用
       IF nfcCount <= 0;
         nfcCount = cpCount;
         FOR i = 1 TO cpCount;
           nfcOut(i) = inCPs(i);
         ENDFOR;
       ENDIF;

       // コードポイントを4バイトBEでパック（先頭x'00'がマーカー）
       // SavePDFで先頭バイトx'00'を見てパック形式と判定する
       nPack = nfcCount;
       IF nPack > 63;
         nPack = 63;
       ENDIF;
       pBuf = %ADDR(packBuf);
       pkVal = 0;
       bArr(1) = pkChar;
       FOR i = 1 TO nPack;
         cp = nfcOut(i);
         pkVal = %DIV(cp: 16777216);
         bArr(2 + (i-1)*4) = pkChar;
         pkVal = %REM(%DIV(cp:65536):256);
         bArr(3 + (i-1)*4) = pkChar;
         pkVal = %REM(%DIV(cp:256):256);
         bArr(4 + (i-1)*4) = pkChar;
         pkVal = %REM(cp: 256);
         bArr(5 + (i-1)*4) = pkChar;
       ENDFOR;
       // パック済みデータをテキスト操作配列に登録
       numTextOps = numTextOps + 1;
       textOps(numTextOps).text = %SUBST(packBuf: 1: 1 + nPack * 4);
       textOps(numTextOps).x = x;
       textOps(numTextOps).y = y;
       textOps(numTextOps).fontSize = fontSize;
       textOps(numTextOps).fontId = fontId;
       textOps(numTextOps).pageId = numPages;
       IF fontId >= 1 AND fontId <= numFonts;
         FOR i = 1 TO nPack;
           cp = nfcOut(i);
           IF cp > 0;
             gid = getGlyphIdForCP(fonts(fontId).fontData: cp);
             found = '0';
             FOR j = 1 TO fonts(fontId).numGlyphs;
               IF fonts(fontId).glyphIds(j) = gid;
                 found = '1';
                 LEAVE;
               ENDIF;
             ENDFOR;
             IF NOT found;
               fonts(fontId).numGlyphs = fonts(fontId).numGlyphs + 1;
               j = fonts(fontId).numGlyphs;
               fonts(fontId).glyphIds(j) = gid;
               fonts(fontId).codepoints(j) = cp;
             ENDIF;
           ENDIF;
         ENDFOR;
       ENDIF;
     P                 E

      *===============================================================
      * SavePDF - PDF文書をファイルに出力
      *
      * PDF 1.4構造を構築して書き出す。処理ステップ:
      *   1. COLRフォントのレイヤーグリフIDを事前登録
      *   2. PDFヘッダー・カタログ・ページツリー出力
      *   3. 各ページのコンテンツストリーム生成
      *      - テキスト→CIDFont用16進文字列変換
      *      - COLR色レイヤーは個別RGB色で描画
      *   4. フォントオブジェクト出力
      *      (Type0 → CIDFont → FontDescriptor → サブセットTTF)
      *   5. ToUnicode CMapストリーム出力
      *   6. 相互参照表(xref)・トレーラー・%%EOF出力
      *===============================================================
     P SavePDF         B                   EXPORT
     D SavePDF         PI            10I 0                                      PDF保存
     D   outPath                    256A   CONST VARYING                        出力IFSパス
     D fd              S             10I 0                                      出力ファイルFD
     D pathNull        S            257A                                        終端パス
     D oflag           S             10I 0                                      フラグ
     D omode           S             10U 0                                      モード

     D objOffsets      S             10U 0 DIM(200)                             各obj先頭位置
     D numObjs         S             10I 0 INZ(0)                               総数
     D curOffset       S             10U 0 INZ(0)                               現在書込位置
     D xrefOff         S             10U 0                                      開始位置
     D buf             S          32767A   VARYING                              出力バッファ

     D f               S             10I 0                                      フォント添字
     D p               S             10I 0                                      ページ添字
     D t               S             10I 0                                      テキスト操作添字
     D catalogObj      S             10I 0                                      のobj番号
     D pagesObj        S             10I 0                                      のobj番号
     D pageObjStart    S             10I 0                                      開始番号
     D streamObjStart  S             10I 0                                      開始番号
     D fontObjStart    S             10I 0                                      開始番号
     D pageContent     S          16384A   VARYING                              ページ内容
     D streamLen       S             10I 0                                      ストリーム長
     D pos             S             10I 0                                      文字位置
     D cp              S             10U 0                                      値
     D gid             S             10I 0                                      グリフID
     D hex4            S              4A                                        進4桁文字列
     D toUnicode       S           4096A   VARYING                              ToUnicode CMap
     D toUniLen        S             10I 0                                      長
     D i               S             10I 0                                      汎用ループ添字
     D rc              S             10I 0                                      戻り値
     D tPos            S             10I 0                                      テキスト内位置
     D svCPA           S             10U 0 DIM(256)                             復元CP配列
     D svNCp           S             10I 0                                      復元CP数
     D subPath         S            256A   VARYING                              一時パス
     D subRc           S             10I 0                                      戻り値
     D subFd           S             10I 0                                      ファイルFD
     D subLen          S             10U 0                                      サイズ
     D binPtr          S               *                                        バイナリ読込ptr
     D rdLen           S             10U 0                                      戻り長
     D pUB2            S               *                                        参照ptr
     D ub2DS           DS                  BASED(pUB2)                          バイト分解
     D  ub2H                          3U 0                                      上位バイト
     D  ub2L                          3U 0                                      下位バイト

     D g               S             10I 0                                      グリフ添字
     D gw              S             10I 0                                      グリフ幅(FUnit)
     D gwS             S             10I 0                                      グリフ幅(1000)
     D upm             S             10I 0                                      値
     D fAsc            S             10I 0                                      Ascent(1000)
     D fDsc            S             10I 0                                      Descent(1000)
     D fCap            S             10I 0                                      CapHeight(1000)
     D dbgFd           S             10I 0                                      デバッグログFD
     D dbgBuf          S            128A                                        デバッグバッファ
     D dbgLen          S             10U 0                                      デバッグ書込長
     D newGIds         S             10I 0 DIM(4096)                            新GID配列
     D newCPs          S             10U 0 DIM(4096)                            新CP配列
     D newNumGl        S             10I 0                                      新グリフ総数
     D nIdx            S             10I 0                                      新配列添字
     D foundIdx        S             10I 0                                      検索結果添字
     D isCOLR          S             10I 0                                      有無(0/1)
     D layGids         S             10I 0 DIM(64)                              レイヤーGID配列
     D layClrs         S             10U 0 DIM(64)                              レイヤー色配列
     D numLays         S             10I 0                                      レイヤー数
     D lIdx            S             10I 0                                      レイヤー添字
     D layR            S             10I 0                                      レイヤー赤(R)
     D layG            S             10I 0                                      レイヤー緑(G)
     D layB            S             10I 0                                      レイヤー青(B)
     D layA            S             10I 0                                      レイヤー透明(A)
     D layFIdx         S             10I 0                                      レイヤー配列添字
     D layHex          S              4A                                        レイヤー16進GID
     D origGid         S             10I 0                                      元グリフID
     D gwPt            S              7P 2                                      幅(ポイント)
     D curX            S              7P 2                                      現在X座標
       // デバッグログを開く
       dbgFd = open('/home/GURICAT/rpgsrc/save.log': 74: 511);
       dbgBuf = 'SAVE START' + x'0A';
       callp write(dbgFd: %ADDR(dbgBuf): 11);
       // 出力PDFファイルをオープン（O_CREAT|O_TRUNC|O_WRONLY）
       oflag = 106;
       omode = 420;
       fd = open(%TRIMR(outPath): oflag: omode: 65535);
       IF fd < 0;
         RETURN -1;
       ENDIF;

       // ---- ステップ1: COLRレイヤーグリフIDの事前登録 ----
       // COLRフォントの各文字は複数レイヤー（各レイヤーが
       // 別グリフ+色）で構成される。サブセットTTFに全レイヤー
       // のグリフIDを含めないと描画できないため、ここで事前に
       // 収集・登録する。
       FOR f = 1 TO numFonts;
         IF hasCOLR(fonts(f).fontData) = 1;
           g = fonts(f).numGlyphs;
           FOR i = 1 TO g;
             origGid = fonts(f).glyphIds(i);
             numLays = getCOLRLayers(
               fonts(f).fontData: origGid:
               %ADDR(layGids): %ADDR(layClrs): 64);
             FOR lIdx = 1 TO numLays;
               foundIdx = 0;
               FOR nIdx = 1 TO fonts(f).numGlyphs;
                 IF fonts(f).glyphIds(nIdx) = layGids(lIdx);
                   foundIdx = 1;
                   LEAVE;
                 ENDIF;
               ENDFOR;
               IF foundIdx = 0;
                 fonts(f).numGlyphs = fonts(f).numGlyphs + 1;
                 nIdx = fonts(f).numGlyphs;
                 fonts(f).glyphIds(nIdx) = layGids(lIdx);
                 fonts(f).codepoints(nIdx) = 0;
               ENDIF;
             ENDFOR;
           ENDFOR;
         ENDIF;
       ENDFOR;

       // ---- ステップ2: PDFヘッダー・カタログ・ページツリー ----
       // %PDF-1.4ヘッダーとバイナリマーカー
       buf = '%PDF-1.4' + x'0A' +
       // x'E2E3CFD3' = PDF binary marker
             '%' + x'E2E3CFD3' + x'0A';
       rc = writeStr(fd: buf);
       curOffset = %LEN(buf);

       // obj 1: カタログ（ドキュメントルート）
       numObjs = numObjs + 1;
       catalogObj = numObjs;
       objOffsets(numObjs) = curOffset;
       buf = %CHAR(numObjs)+' 0 obj' + x'0A'
         + '<<' + x'0A'
         + '/Type /Catalog' + x'0A'
         + '/Pages 2 0 R' + x'0A'
         + '>>' + x'0A'
         + 'endobj' + x'0A';
       rc = writeStr(fd: buf);
       curOffset = curOffset + %LEN(buf);

       // obj 2: ページツリー（全ページの親）
       numObjs = numObjs + 1;
       pagesObj = numObjs;
       objOffsets(numObjs) = curOffset;
       buf = %CHAR(numObjs)+' 0 obj' + x'0A'
         + '<<' + x'0A'
         + '/Type /Pages' + x'0A'
         + '/Kids [';
       pageObjStart = 3;
       FOR p = 1 TO numPages;
         buf = buf +
           %CHAR(pageObjStart + (p-1)*2) +
           ' 0 R ';
       ENDFOR;
       buf = buf + ']' + x'0A'
         + '/Count '+%CHAR(numPages) + x'0A'
         + '>>' + x'0A'
         + 'endobj' + x'0A';
       rc = writeStr(fd: buf);
       curOffset = curOffset + %LEN(buf);

       // フォントオブジェクトの開始番号を計算
       fontObjStart = 3 + numPages * 2;

       // ---- ステップ3: 各ページのオブジェクトとコンテンツストリーム ----
       FOR p = 1 TO numPages;
         numObjs = numObjs + 1;
         objOffsets(numObjs) = curOffset;
         buf = %CHAR(numObjs)+' 0 obj'+x'0A'
           + '<<' + x'0A'
           + '/Type /Page' + x'0A'
           + '/Parent 2 0 R' + x'0A'
           + '/MediaBox [0 0 '
           + %CHAR(pages(p).width)
           + ' ' + %CHAR(pages(p).height)
           + ']' + x'0A'
           + '/Contents '
           + %CHAR(numObjs+1) + ' 0 R' + x'0A'
           + '/Resources <<' + x'0A'
           + '  /Font <<' + x'0A';
         FOR f = 1 TO numFonts;
           buf = buf + '    /F'
             + %CHAR(f) + ' '
             + %CHAR(fontObjStart + (f-1)*5)
             + ' 0 R' + x'0A';
         ENDFOR;
         buf = buf + '  >>' + x'0A'
           + '>>' + x'0A'
           + '>>' + x'0A'
           + 'endobj' + x'0A';
         rc = writeStr(fd: buf);
         curOffset = curOffset + %LEN(buf);

         // コンテンツストリームを組み立て（BT...ET）
         pageContent = '';
         pageContent = pageContent + 'BT' + x'0A';
         FOR t = 1 TO numTextOps;
           IF textOps(t).pageId = p;
             pageContent = pageContent +
               '/F' + %CHAR(textOps(t).fontId)
               + ' ' +
               %CHAR(%INT(textOps(t).fontSize))
               + ' Tf' + x'0A';
             pageContent = pageContent +
               '1 0 0 1 ' +
               %CHAR(%INT(textOps(t).x)) +
               ' ' +
               %CHAR(%INT(textOps(t).y)) +
               ' Tm' + x'0A';
             dbgBuf = 'CVT T=' + %CHAR(t) + x'0A';
             dbgLen = %LEN(%TRIMR(dbgBuf));
             callp write(dbgFd: %ADDR(dbgBuf): dbgLen);
             // テキストデータのデコード（2種類の形式を判別）
             // AddTextU由来: 先頭x'00'+4バイトBEパック
             //   → 各4バイトからCPを復元
             // AddText由来: EBCDIC文字列
             //   → cvt5035でUCS-2経由でCPに変換
             // 結果のsvCPA配列をグリフID変換に使う
             IF %LEN(textOps(t).text)>0
                AND %SUBST(textOps(t).text:1:1) = x'00';
               svNCp = (%LEN(textOps(t).text)-1)/4;
               FOR tPos = 1 TO svNCp;
                 pUB2 = %ADDR(textOps(t).text)+3 + (tPos-1)*4;
                 svCPA(tPos) = ub2H * 16777216;
                 pUB2 = pUB2 + 1;
                 svCPA(tPos) = svCPA(tPos) + ub2H * 65536;
                 pUB2 = pUB2 + 1;
                 svCPA(tPos) = svCPA(tPos) + ub2H * 256;
                 pUB2 = pUB2 + 1;
                 svCPA(tPos) = svCPA(tPos) + ub2H;
               ENDFOR;
             ELSE;
               svNCp = cvt5035(textOps(t).text: %ADDR(svCPA));
             ENDIF;
             dbgBuf = 'CVT OK N=' + %CHAR(svNCp) + x'0A';
             dbgLen = %LEN(%TRIMR(dbgBuf));
             callp write(dbgFd: %ADDR(dbgBuf): dbgLen);
             // COLR有無で描画方式を分岐
             isCOLR = hasCOLR(fonts(textOps(t).fontId).fontData);
             // 通常フォント：グリフIDを16進変換してTjで出力
             IF isCOLR = 0;
               pageContent = pageContent + '<';
               FOR tPos = 1 TO svNCp;
                 cp = svCPA(tPos);
                 IF cp > 0;
                   gid = getGlyphIdForCP(
                     fonts(textOps(t).fontId).fontData: cp);
                   foundIdx = 0;
                   FOR nIdx = 1 TO fonts(textOps(t).fontId).numGlyphs;
                     IF fonts(textOps(t).fontId).glyphIds(nIdx) = gid;
                       foundIdx = nIdx;
                       LEAVE;
                     ENDIF;
                   ENDFOR;
                   hex4 = toHex4(foundIdx);
                   pageContent = pageContent + hex4;
                 ENDIF;
               ENDFOR;
               pageContent = pageContent + '> Tj' + x'0A';
             ELSE;
               // COLR v0フォントの描画手順:
               // 1. 各CPのレイヤー情報を取得(getCOLRLayers)
               // 2. 各レイヤーごとにTmで絶対位置を設定
               //    （同じ位置に重ね描き）
               // 3. レイヤー色(ARGB)からRGBを抽出し
               //    rg演算子で設定
               // 4. レイヤーのグリフIDで<hex> Tjを出力
               // 5. 全レイヤー描画後に黒(0 0 0 rg)に戻す
               // 6. グリフ幅分だけcurXを進めて次の文字へ
               upm = getUnitsPerEm(fonts(textOps(t).fontId).fontData);
               IF upm <= 0;
                 upm = 1000;
               ENDIF;
               curX = textOps(t).x;
               FOR tPos = 1 TO svNCp;
                 cp = svCPA(tPos);
                 IF cp > 0;
                   origGid = getGlyphIdForCP(
                     fonts(textOps(t).fontId).fontData: cp);
                   numLays = getCOLRLayers(
                     fonts(textOps(t).fontId).fontData:
                     origGid: %ADDR(layGids): %ADDR(layClrs): 64);
                   IF numLays > 0;
                     gw = getGlyphWidth(
                       fonts(textOps(t).fontId).fontData: origGid);
                     gwPt = gw * textOps(t).fontSize / upm;
                     FOR lIdx = 1 TO numLays;
                       pageContent = pageContent +
                         '1 0 0 1 ' +
                         %CHAR(%INT(curX)) + ' ' +
                         %CHAR(%INT(textOps(t).y)) +
                         ' Tm' + x'0A';
                       layR = %DIV(layClrs(lIdx):16777216);
                       layG = %REM(%DIV(layClrs(lIdx):65536):256);
                       layB = %REM(%DIV(layClrs(lIdx):256):256);
                       pageContent = pageContent +
                         %CHAR(%DEC(layR / 255.0 :5:3)) + ' ' +
                         %CHAR(%DEC(layG / 255.0 :5:3)) + ' ' +
                         %CHAR(%DEC(layB / 255.0 :5:3)) +
                         ' rg' + x'0A';
                       layFIdx = 0;
                       FOR nIdx = 1 TO fonts(textOps(t).fontId).numGlyphs;
                         IF fonts(textOps(t).fontId).glyphIds(nIdx)
                            = layGids(lIdx);
                           layFIdx = nIdx;
                           LEAVE;
                         ENDIF;
                       ENDFOR;
                       layHex = toHex4(layFIdx);
                       pageContent = pageContent +
                         '<' + layHex + '> Tj' + x'0A';
                     ENDFOR;
                     curX = curX + gwPt;
                     pageContent = pageContent +
                       '0 0 0 rg' + x'0A';
                   ELSE;
                     foundIdx = 0;
                     FOR nIdx = 1 TO fonts(textOps(t).fontId).numGlyphs;
                       IF fonts(textOps(t).fontId).glyphIds(nIdx)
                          = origGid;
                         foundIdx = nIdx;
                         LEAVE;
                       ENDIF;
                     ENDFOR;
                     hex4 = toHex4(foundIdx);
                     pageContent = pageContent +
                       '<' + hex4 + '> Tj' + x'0A';
                   ENDIF;
                 ENDIF;
               ENDFOR;
             ENDIF;
           ENDIF;
         ENDFOR;
         pageContent = pageContent+'ET'+x'0A';

         numObjs = numObjs + 1;
         objOffsets(numObjs) = curOffset;
         streamLen = %LEN(pageContent)-1;
         buf = %CHAR(numObjs)+' 0 obj'+x'0A'
           + '<<' + x'0A'
           + '/Length ' + %CHAR(streamLen)
           + x'0A'
           + '>>' + x'0A'
           + 'stream' + x'0A'
           + pageContent
           + 'endstream' + x'0A'
           + 'endobj' + x'0A';
         rc = writeStr(fd: buf);
         curOffset = curOffset + %LEN(buf);
       ENDFOR;

       // ---- ステップ4: フォントオブジェクト群の出力 ----
       // 各フォントにつき5オブジェクト:
       //   Type0, CIDFontType2, FontDescriptor, ToUnicode, FontFile2
       // PDFフォントオブジェクト階層:
       //  - Type0: 最上位。Identity-H(CIDによる文字選択)
       //  - CIDFontType2: TrueTypeベースCIDフォント。
       //    /W配列でグリフ幅を指定
       //  - FontDescriptor: メトリクス情報
       //    (Ascent/Descent/CapHeight等)
       //  - ToUnicode: CID→Unicodeの逆変換マップ
       //    （テキスト検索・コピー用）
       //  - FontFile2: サブセットTTFバイナリの埋め込み
       FOR f = 1 TO numFonts;
         // GID 0（.notdef）を先頭に含む新グリフ配列を構築
         newNumGl = fonts(f).numGlyphs+1;
         newGIds(1) = 0;
         newCPs(1) = 0;
         FOR nIdx = 1 TO fonts(f).numGlyphs;
           newGIds(nIdx + 1) = nIdx;
           newCPs(nIdx + 1) = fonts(f).codepoints(nIdx);
         ENDFOR;

         // Type0フォントオブジェクト
         numObjs = numObjs + 1;
         objOffsets(numObjs) = curOffset;
         buf = %CHAR(numObjs)+' 0 obj'+x'0A'
           + '<<' + x'0A'
           + '/Type /Font' + x'0A'
           + '/Subtype /Type0' + x'0A'
           + '/BaseFont /' +
           %TRIMR(fonts(f).fontName) + x'0A'
           + '/Encoding /Identity-H' + x'0A'
           + '/DescendantFonts ['
           + %CHAR(numObjs+1)
           + ' 0 R]' + x'0A'
           + '/ToUnicode '
           + %CHAR(numObjs+3)
           + ' 0 R' + x'0A'
           + '>>' + x'0A'
           + 'endobj' + x'0A';
         rc = writeStr(fd: buf);
         curOffset = curOffset + %LEN(buf);

         // CIDFontType2オブジェクト（/W幅配列を含む）
         numObjs = numObjs + 1;
         objOffsets(numObjs) = curOffset;
         buf = %CHAR(numObjs)+' 0 obj'+x'0A'
           + '<<' + x'0A'
           + '/Type /Font' + x'0A'
           + '/Subtype /CIDFontType2' + x'0A'
           + '/BaseFont /' +
           %TRIMR(fonts(f).fontName) + x'0A'
           + '/CIDSystemInfo <<' + x'0A'
           + '  /Registry (Adobe)' + x'0A'
           + '  /Ordering (Identity)' + x'0A'
           + '  /Supplement 0' + x'0A'
           + '>>' + x'0A'
           + '/FontDescriptor '
           + %CHAR(numObjs+1)
           + ' 0 R' + x'0A';

         // グリフ幅をFUnit→1000単位に変換して/W配列を構築
         upm = getUnitsPerEm(fonts(f).fontData);
         IF upm <= 0;
           upm = 1000;
         ENDIF;
         buf = buf + '/W [' + x'0A';
         gw = getGlyphWidth(fonts(f).fontData: 0);
         gwS = gw*1000/upm;
         buf = buf + '0 ['
           + %CHAR(gwS)
           + ']' + x'0A';
         FOR g = 1 TO fonts(f).numGlyphs;
           gw = getGlyphWidth(fonts(f).fontData: fonts(f).glyphIds(g));
           gwS = gw*1000/upm;
           buf = buf +
             %CHAR(g)
             + ' [' +
             %CHAR(gwS)
             + ']' + x'0A';
         ENDFOR;
         buf = buf + ']' + x'0A'
           + '/DW 1000' + x'0A'
           + '/CIDToGIDMap /Identity'
           + x'0A'
           + '>>' + x'0A'
           + 'endobj' + x'0A';
         rc = writeStr(fd: buf);
         curOffset = curOffset + %LEN(buf);

         // FontDescriptorオブジェクト（メトリクス・FontFile2参照）
         numObjs = numObjs + 1;
         objOffsets(numObjs) = curOffset;
         buf = %CHAR(numObjs)+' 0 obj'+x'0A'
           + '<<' + x'0A'
           + '/Type /FontDescriptor' + x'0A'
           + '/FontName /' +
           %TRIMR(fonts(f).fontName) + x'0A'
           + '/Flags 4' + x'0A';

         upm = getUnitsPerEm(fonts(f).fontData);
         IF upm <= 0;
           upm = 1000;
         ENDIF;
         fAsc = getAscent(fonts(f).fontData) * 1000 / upm;
         fDsc = getDescent(fonts(f).fontData) * 1000 / upm;
         fCap = getCapHeight(fonts(f).fontData) * 1000 / upm;

         buf = buf
           + '/FontBBox [0 '
           + %CHAR(fDsc)
           + ' 1000 '
           + %CHAR(fAsc)
           + ']' + x'0A'
           + '/ItalicAngle 0' + x'0A'
           + '/Ascent '
           + %CHAR(fAsc) + x'0A'
           + '/Descent '
           + %CHAR(fDsc) + x'0A'
           + '/CapHeight '
           + %CHAR(fCap) + x'0A'
           + '/StemV 80' + x'0A'
           + '/FontFile2 '
           + %CHAR(numObjs+2)
           + ' 0 R' + x'0A'
           + '>>' + x'0A'
           + 'endobj' + x'0A';
         rc = writeStr(fd: buf);
         curOffset = curOffset + %LEN(buf);

         // ToUnicode CMapストリーム（テキスト検索・コピー用）
         toUnicode = generateToUnicode(
           %ADDR(newGIds):
           %ADDR(newCPs):
           newNumGl);
         toUniLen = %LEN(toUnicode) - 1;
         numObjs = numObjs + 1;
         objOffsets(numObjs) = curOffset;
         buf = %CHAR(numObjs)+' 0 obj'+x'0A'
           + '<<' + x'0A'
           + '/Length ' + %CHAR(toUniLen)
           + x'0A'
           + '>>' + x'0A'
           + 'stream' + x'0A'
           + toUnicode
           + 'endstream' + x'0A'
           + 'endobj' + x'0A';
         rc = writeStr(fd: buf);
         curOffset = curOffset + %LEN(buf);

         dbgBuf = 'SUBSET F=' + %CHAR(f) + x'0A';
         dbgLen = %LEN(%TRIMR(dbgBuf));
         callp write(dbgFd: %ADDR(dbgBuf): dbgLen);
         // ---- ステップ5: サブセットTTFを生成して埋め込み ----
         subPath = '/tmp/pdfsub' + %CHAR(f) + '.ttf';
         newGIds(1) = 0;
         FOR nIdx = 1 TO fonts(f).numGlyphs;
           newGIds(nIdx + 1) = fonts(f).glyphIds(nIdx);
         ENDFOR;
         subRc = createSubset(
           fonts(f).fontData:
           %ADDR(newGIds):
           newNumGl:
           subPath);

         // サブセットTTFファイルのサイズを取得
         subFd = -1;
         subLen = 0;
         IF subRc >= 0;
           subFd = open(%TRIMR(subPath): 1);
         ENDIF;
         IF subFd >= 0;
           subLen = lseek(subFd: 0: 2);
           callp lseek(subFd: 0: 0);
         ENDIF;

         numObjs = numObjs + 1;
         objOffsets(numObjs) = curOffset;
         buf = %CHAR(numObjs)
           + ' 0 obj' + x'0A'
           + '<<' + x'0A'
           + '/Length '
           + %CHAR(subLen)
           + x'0A'
           + '/Length1 '
           + %CHAR(subLen)
           + x'0A'
           + '>>' + x'0A'
           + 'stream' + x'0A';
         rc = writeStr(fd: buf);
         curOffset = curOffset + %LEN(buf);

         // サブセットTTFをPDFストリームにバイナリコピー
         IF subFd >= 0 AND subLen > 0;
           binPtr = %ALLOC(subLen);
           rdLen = read(subFd: binPtr: subLen);
           IF rdLen > 0;
             rc = write(fd: binPtr: rdLen);
             curOffset = curOffset + rdLen;
           ENDIF;
           DEALLOC binPtr;
           callp close(subFd);
         ENDIF;
         // 一時ファイルを削除
         callp unlink(%TRIMR(subPath));

         buf = x'0A'
           + 'endstream' + x'0A'
           + 'endobj' + x'0A';
         rc = writeStr(fd: buf);
         curOffset = curOffset + %LEN(buf);
       ENDFOR;

       // ---- ステップ6: 相互参照表(xref)・トレーラー ----
       // xrefテーブルは各オブジェクトのファイル内バイト
       // オフセットをPDFビューアに伝える。各エントリは
       // 「10桁オフセット + 世代番号 + n/f」の
       // 固定20バイト形式。
       xrefOff = curOffset;
       buf = 'xref' + x'0A'
         + '0 ' + %CHAR(numObjs+1) + x'0A'
         + '0000000000 65535 f ' + x'0A';
       FOR i = 1 TO numObjs;
         buf = buf +
           %XLATE(' ':'0':
           %EDITW(objOffsets(i):
           '0         '))
           + ' 00000 n ' + x'0A';
       ENDFOR;
       rc = writeStr(fd: buf);
       curOffset = curOffset + %LEN(buf);

       buf = 'trailer' + x'0A'
         + '<<' + x'0A'
         + '/Size ' + %CHAR(numObjs+1)
         + x'0A'
         + '/Root 1 0 R' + x'0A'
         + '>>' + x'0A'
         + 'startxref' + x'0A'
         + %CHAR(xrefOff) + x'0A'
         + '%%EOF' + x'0A';
       rc = writeStr(fd: buf);

       dbgBuf = 'CLOSE' + x'0A';
       callp write(dbgFd: %ADDR(dbgBuf): 6);
       callp close(dbgFd);
       callp close(fd);

       // フォントデータを解放し、状態をリセット
       FOR f = 1 TO numFonts;
         IF fonts(f).fontData <> *NULL;
           closeTTF(fonts(f).fontData);
         ENDIF;
       ENDFOR;
       numFonts = 0;
       numPages = 0;
       numTextOps = 0;

       RETURN 0;
     P                 E


      *===============================================================
      * cvt5035 - EBCDIC(CCSID 5035)→Unicodeコードポイント変換
      * QtqIconvOpenでCCSID 5035→13488(UCS-2)変換器を開き、
      * UCS-2の各2バイトをUnicodeコードポイント(10U 0)配列に展開。
      * 変換器は静的変数で保持し、初回のみオープンする。
      *===============================================================
     P cvt5035         B                   EXPORT
     D cvt5035         PI            10I 0                                      5035→UTF32変換
     D   inStr                      256A   CONST VARYING                        入力文字列
     D   pOutCPs                       *   VALUE                                出力CP配列ptr
     D outCPs          S             10U 0 DIM(256)                             出力CP配列
     D                                     BASED(pOutCPs)
     D QtqCode_t       DS                  QUALIFIED                            変換定義
     D   CCSID                       10I 0                                      文字コードID
     D   convAlt                     10I 0                                      変換代替
     D   subsAlt                     10I 0                                      置換代替
     D   shiftAlt                    10I 0                                      シフト代替
     D   inpLenOp                    10I 0                                      入力長オプション
     D   errOpt                      10I 0                                      エラーオプション
     D   reserved                    12A                                        予約域
     D fromCode        DS                  LIKEDS(QtqCode_t)                    変換元(5035)
     D                                     STATIC INZ
     D toCode          DS                  LIKEDS(QtqCode_t)                    変換先(13488)
     D                                     STATIC INZ
     D iconvCD         S             52A   STATIC                               記述子
     D                                     INZ(*ALLX'00')
     D cdDS            DS                  BASED(pCDDS)                         記述子検査用
     D  icRV                         10I 0                                      戻り値
     D pCDDS           S               *   STATIC                               のptr
     D opened          S              1N   INZ('0') STATIC                      初回判定フラグ
     D inLen           S             10U 0                                      入力バイト長
     D outLen          S             10U 0                                      出力残バイト
     D pIn             S               *                                        入力バッファptr
     D pOut            S               *                                        出力バッファptr
     D ucs2Buf         S            512A                                        出力域
     D iRc             S             10U 0                                      戻り値
     D nChars          S             10I 0                                      変換文字数
     D j               S             10I 0                                      ループ添字
     D pUB             S               *                                        参照ptr
     D ubDS            DS                  BASED(pUB)                           バイト分解
     D  ubH                           3U 0                                      上位バイト
     D  ubL                           3U 0                                      下位バイト
     D localStr        S            256A   VARYING                              入力コピー
       // 初回のみiconv変換器を開く（CCSID 5035→UCS-2 13488）
       // iconv変換器はSTATIC変数で保持し、2回目以降の
       // 呼び出しでは再オープンしない（性能対策）。
       IF NOT opened;
         fromCode = *ALLX'00';
         fromCode.CCSID = 5035;
         fromCode.shiftAlt = 1;
         toCode = *ALLX'00';
         toCode.CCSID = 13488;
         iconvCD = QtqIconvOpen(toCode: fromCode);
         pCDDS = %ADDR(iconvCD);
         opened = '1';
       ENDIF;
       IF icRV = -1;
         RETURN 0;
       ENDIF;
       // iconvでEBCDIC→UCS-2に変換
       localStr = inStr;
       inLen = %LEN(localStr);
       IF inLen = 0;
         RETURN 0;
       ENDIF;
       outLen = 512;
       pIn = %ADDR(localStr) + 2;
       pOut = %ADDR(ucs2Buf);
       iRc = iconv(iconvCD: pIn: inLen: pOut: outLen);
       // UCS-2の各2バイトをUnicodeコードポイントに展開
       // UCS-2は2バイト固定長なので、変換後バイト数÷2が
       // 文字数となる。
       nChars = (512 - outLen) / 2;
       FOR j = 1 TO nChars;
         pUB = %ADDR(ucs2Buf) + (j - 1) * 2;
         outCPs(j) = ubH * 256 + ubL;
       ENDFOR;
       RETURN nChars;
     P                 E


      *===============================================================
      * writeStr - EBCDIC文字列をASCIIに変換してwrite()
      * PDFはASCII形式のため、EBCDIC→ASCII変換テーブル(e2aI)を
      * 使って1バイトずつ変換する。変換テーブルは静的で初回構築。
      *===============================================================
     P writeStr        B
     D writeStr        PI            10I 0                                      文字列書込
     D   fd                          10I 0 CONST                                出力先ファイルFD
     D   str                      32767A   CONST VARYING                        書込み文字列
     D rc              S             10I 0                                      戻り値
     D len             S             10U 0                                      文字列長
     D tmpBuf          S          32767A                                        変換作業域
     D pBuf            S               *                                        のptr
     D srcDS           DS                  BASED(pSrc)                          参照用
     D  srcByte                       3U 0                                      バイト値
     D pSrc            S               *                                        変換元ptr
     D dstDS           DS                  BASED(pDst)                          参照用
     D  dstByte                       3U 0                                      バイト値
     D pDst            S               *                                        変換先ptr
     D e2aI            S              3U 0 DIM(256) STATIC                      →ASCII表
     D i               S             10I 0                                      ループ添字
     D idx             S             10I 0                                      変換表添字
     D inited          S              1N   INZ('0') STATIC                      初回判定フラグ
       // 初回のみEBCDIC→ASCII変換テーブルを構築
       // PDFフォーマットはASCIIベースのため、RPGが生成する
       // EBCDIC文字列をASCIIに変換する必要がある。
       // 変換テーブルe2aIは配列添字がEBCDICコードポイント+1、
       // 値がASCII値。初回のみ構築しSTATICで保持。
       IF NOT inited;
         FOR i = 1 TO 256;
           e2aI(i) = 63;
         ENDFOR;
         e2aI(14) = 13;
         e2aI(22) = 10;
         e2aI(38) = 10;
         e2aI(11) = 10;
         e2aI(65) = 32;
         e2aI(76) = 46;
         e2aI(77) = 60;
         e2aI(78) = 40;
         e2aI(79) = 43;
         e2aI(80) = 124;
         e2aI(81) = 38;
         e2aI(91) = 33;
         e2aI(92) = 36;
         e2aI(93) = 42;
         e2aI(94) = 41;
         e2aI(95) = 59;
         e2aI(96) = 94;
         e2aI(97) = 45;
         e2aI(98) = 47;
         e2aI(108) = 44;
         e2aI(109) = 37;
         e2aI(110) = 95;
         e2aI(111) = 62;
         e2aI(112) = 63;
         e2aI(123) = 58;
         e2aI(124) = 35;
         e2aI(125) = 64;
         e2aI(126) = 39;
         e2aI(127) = 61;
         e2aI(128) = 34;
         e2aI(130) = 97;
         e2aI(131) = 98;
         e2aI(132) = 99;
         e2aI(133) = 100;
         e2aI(134) = 101;
         e2aI(135) = 102;
         e2aI(136) = 103;
         e2aI(137) = 104;
         e2aI(138) = 105;
         e2aI(140) = 123;
         e2aI(146) = 106;
         e2aI(147) = 107;
         e2aI(148) = 108;
         e2aI(149) = 109;
         e2aI(150) = 110;
         e2aI(151) = 111;
         e2aI(152) = 112;
         e2aI(153) = 113;
         e2aI(154) = 114;
         e2aI(156) = 125;
         e2aI(163) = 115;
         e2aI(164) = 116;
         e2aI(165) = 117;
         e2aI(166) = 118;
         e2aI(167) = 119;
         e2aI(168) = 120;
         e2aI(169) = 121;
         e2aI(170) = 122;
         e2aI(174) = 91;
         e2aI(177) = 126;
         e2aI(190) = 93;
         e2aI(194) = 65;
         e2aI(195) = 66;
         e2aI(196) = 67;
         e2aI(197) = 68;
         e2aI(198) = 69;
         e2aI(199) = 70;
         e2aI(200) = 71;
         e2aI(201) = 72;
         e2aI(202) = 73;
         e2aI(210) = 74;
         e2aI(211) = 75;
         e2aI(212) = 76;
         e2aI(213) = 77;
         e2aI(214) = 78;
         e2aI(215) = 79;
         e2aI(216) = 80;
         e2aI(217) = 81;
         e2aI(218) = 82;
         e2aI(225) = 92;
         e2aI(227) = 83;
         e2aI(228) = 84;
         e2aI(229) = 85;
         e2aI(230) = 86;
         e2aI(231) = 87;
         e2aI(232) = 88;
         e2aI(233) = 89;
         e2aI(234) = 90;
         e2aI(241) = 48;
         e2aI(242) = 49;
         e2aI(243) = 50;
         e2aI(244) = 51;
         e2aI(245) = 52;
         e2aI(246) = 53;
         e2aI(247) = 54;
         e2aI(248) = 55;
         e2aI(249) = 56;
         e2aI(250) = 57;
         inited = '1';
       ENDIF;
       len = %LEN(str);
       IF len > 0;
         tmpBuf = str;
         pBuf = %ADDR(tmpBuf);
         FOR i = 0 TO len - 1;
           pSrc = pBuf + i;
           idx = srcByte + 1;
           pDst = pBuf + i;
           dstByte = e2aI(idx);
         ENDFOR;
         rc = write(fd: pBuf: len);
         RETURN rc;
       ENDIF;
       RETURN 0;
     P                 E

      * writeN - バイナリデータをそのままwrite()（変換なし）
     P writeN          B
     D writeN          PI            10I 0                                      Nバイト書込
     D   fd                          10I 0 CONST                                出力先ファイルFD
     D   buffer                        *   VALUE                                書込みバッファptr
     D   length                      10U 0 CONST                                書込みバイト数
     D rc              S             10I 0                                      戻り値
       rc = write(fd: buffer: length);
       RETURN rc;
     P                 E

     P intToStr        B
     D intToStr        PI            12A   VARYING                              整数→文字列
     D   val                         10I 0 CONST                                変換元整数値
       RETURN %CHAR(val);
     P                 E

     P uintToStr       B
     D uintToStr       PI            12A   VARYING                              符号なし→文字
     D   val                         10U 0 CONST                                変換元符号なし値
       RETURN %CHAR(val);
     P                 E
