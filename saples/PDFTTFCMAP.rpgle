      *===============================================================
      * PDFTTFCMAP - PDF CMap/ToUnicode/フォント記述子生成モジュール
      * Version: 3.0.0  Date: 2026-02-12
      *
      * PDFのフォント関連オブジェクトを生成する:
      *   - ToUnicode CMap: グリフID→Unicode逆変換（検索・コピー用）
      *   - CIDFontType2: CIDベースのTrueTypeフォント定義
      *   - FontDescriptor: フォントメトリクス・埋め込みフォント参照
      *   - Type0: CIDFont+ToUnicodeを束ねるトップレベルフォント
      *
      * また、UTF-8コードポイント取得と16進変換ユーティリティを提供。
      *===============================================================
     H NOMAIN
      /COPY QSYSINC/QRPGLESRC,SYSTYPES
      /COPY QSYSINC/QRPGLESRC,SYSSTAT
      /COPY QSYSINC/QRPGLESRC,FCNTL
      /COPY QSYSINC/QRPGLESRC,UNISTD

      *-------------------------------------------------------------
      * 公開プロシージャ宣言
      *-------------------------------------------------------------
      * generateToUnicode - ToUnicode CMapストリームを生成
      *   グリフID→Unicodeコードポイントの逆変換マップ
      *   PDF内でテキスト検索・コピーを可能にする
     D generateToUnicode...                                                     ToUnicode生成
     D                 PR          4096A   VARYING
     D                                     EXTPROC(*CL:'generateToUnicode')
     D   glyphIds                      *   CONST                                グリフID配列ptr
     D   codepoints                    *   CONST                                CP配列ポインタ
     D   numChars                    10I 0 CONST                                文字数

      * generateCIDFont - CIDFontType2オブジェクトを生成
      *   /W配列（グリフ幅情報）を含む
     D generateCIDFont...                                                       CIDFont生成
     D                 PR          2048A   VARYING
     D                                     EXTPROC(*CL:'generateCIDFont')
     D   fontName                    64A   CONST VARYING                        フォント名
     D   fontData                      *   CONST                                フォントデータptr
     D   glyphIds                      *   CONST                                グリフID配列ptr
     D   numGlyphs                   10I 0 CONST                                グリフ数
     D   cidFontObjNum...                                                        CIDFont obj番号
     D                               10I 0 CONST
     D   descriptorNum...                                                        記述子obj番号
     D                               10I 0 CONST

      * generateFontDesc - FontDescriptorオブジェクトを生成
      *   Ascent/Descent/CapHeight/Flags/FontFile2参照を含む
     D generateFontDesc...                                                      FontDesc生成
     D                 PR          1024A   VARYING
     D                                     EXTPROC(*CL:'generateFontDesc')
     D   fontName                    64A   CONST VARYING                        フォント名
     D   fontData                      *   CONST                                フォントデータptr
     D   objNum                      10I 0 CONST                                obj番号
     D   fontFileNum                 10I 0 CONST                                FontFile obj番号

      * generateType0 - Type0フォントオブジェクトを生成
      *   CIDFontとToUnicodeを束ねるトップレベル定義
     D generateType0...                                                         Type0生成
     D                 PR          1024A   VARYING EXTPROC(*CL:'generateType0')
     D   fontName                    64A   CONST VARYING                        フォント名
     D   objNum                      10I 0 CONST                                obj番号
     D   cidFontNum                  10I 0 CONST                                CIDFont obj番号
     D   toUnicodeNum                10I 0 CONST                                ToUnicode obj番号

      *-------------------------------------------------------------
      * ユーティリティプロシージャ
      *-------------------------------------------------------------
      * getCodepoint - UTF-8文字列の指定位置からコードポイントを取得
      *   posは呼び出し後に次の文字位置に更新される
     D getCodepoint    PR            10U 0 EXTPROC(*CL:'getCodepoint')          CP取得
     D   utf8Str                    256A   CONST VARYING                        UTF-8入力文字列
     D   pos                         10I 0                                      走査位置

      * toHex4 - 数値を4桁16進文字列に変換（例: 65→"0041"）
     D toHex4          PR             4A   EXTPROC(*CL:'toHex4')                4桁16進変換
     D   val                         10U 0 CONST                                変換元数値

      * toHex2 - 数値を2桁16進文字列に変換（例: 255→"FF"）
     D toHex2          PR             2A   EXTPROC(*CL:'toHex2')                2桁16進変換
     D   val                         10U 0 CONST                                変換元数値

      *-------------------------------------------------------------
      * 外部プロシージャ宣言 - TTFPARSERモジュール
      *-------------------------------------------------------------
     D getUnitsPerEm   PR            10I 0 EXTPROC(*CL:'getUnitsPerEm')         Em単位取得
     D   fontData                      *   CONST                                フォントデータptr
     D getAscent       PR            10I 0 EXTPROC(*CL:'getAscent')             上端取得
     D   fontData                      *   CONST                                フォントデータptr
     D getDescent      PR            10I 0 EXTPROC(*CL:'getDescent')            下端取得
     D   fontData                      *   CONST                                フォントデータptr
     D getCapHeight    PR            10I 0 EXTPROC(*CL:'getCapHeight')          大文字高取得
     D   fontData                      *   CONST                                フォントデータptr
     D getGlyphWidth   PR            10I 0 EXTPROC(*CL:'getGlyphWidth')         グリフ幅取得
     D   fontData                      *   CONST                                フォントデータptr
     D   glyphId                     10I 0 CONST                                対象グリフID

      *===============================================================
      * generateToUnicode - ToUnicode CMapストリーム生成
      * グリフID→Unicodeコードポイントの逆変換マップを
      * PostScript CMap形式で生成する。
      * beginbfchar セクションに各グリフのマッピングを出力。
      * BMP外文字（U+10000以上）はUTF-16サロゲートペアで出力。
      *===============================================================
     P generateToUnicode...
     P                 B                   EXPORT
     D generateToUnicode...                                                     ToUnicode生成
     D                 PI          4096A    VARYING
     D   glyphIds                      *   CONST                                グリフID配列ptr
     D   codepoints                    *   CONST                                CP配列ポインタ
     D   numChars                    10I 0 CONST                                文字数
     D result          S           4096A   VARYING                              CMap出力結果
     D gArr            S             10I 0 DIM(65536)                           グリフID配列
     D                                     BASED(glyphIds)
     D cpArr           S             10U 0 DIM(65536)                           Unicode配列
     D                                     BASED(codepoints)
     D i               S             10I 0                                      ループ索引
     D hex4            S              4A                                        16進4桁作業用
       // PostScript CMap形式のヘッダーを構築
       // PDFはToUnicode CMapでグリフ→Unicode逆変換を定義し
       // テキスト検索・コピー&ペーストを可能にする
       // codespacerange <0000>-<FFFF>: 2バイトCID空間全域を宣言
       result = '/CIDInit /ProcSet findresource begin' +
               x'0A' +
               '12 dict begin' + x'0A' +
               'begincmap' + x'0A' +
               '/CIDSystemInfo <<' + x'0A' +
               '  /Registry (Adobe)' + x'0A' +
               '  /Ordering (UCS)' + x'0A' +
               '  /Supplement 0' + x'0A' +
               '>> def' + x'0A' +
               '/CMapName /Adobe-Identity-UCS def' + x'0A' +
               '/CMapType 2 def' + x'0A' +
               '1 begincodespacerange' + x'0A' +
               '<0000> <FFFF>' + x'0A' +
               'endcodespacerange' + x'0A';

       // beginbfchar: CID(サブセット内グリフ索引)→Unicode対応表
       // 各行 <CID> <Unicode> でグリフとコードポイントを1対1マッピング
       IF numChars > 0;
         result = result + %CHAR(numChars) + ' beginbfchar' + x'0A';
         FOR i = 1 TO numChars;
           IF cpArr(i) <= 65535;
             // BMP内(U+0000-FFFF): 4桁16進で直接出力
             // 例: <0003> <0041> → グリフ3がU+0041('A')に対応
             result = result + '<' + toHex4(gArr(i)) + '> <' + toHex4(cpArr(i))
               + '>' + x'0A';
           ELSE;
             // BMP外(U+10000-10FFFF): UTF-16サロゲートペアで出力
             // PDFのToUnicode CMapはUTF-16BEを要求するため
             // 補助面文字は上位・下位サロゲートの2ワードで表現:
             //   上位(high) = 0xD800 + ((cp-0x10000) >> 10)
             //   下位(low)  = 0xDC00 + ((cp-0x10000) & 0x3FF)
             // 55232 = 0xD800-0x10000/1024の前計算値
             // 56320 = 0xDC00
             result = result + '<' + toHex4(gArr(i)) + '> <'
               + toHex4(55232 + %DIV(cpArr(i)-65536:1024))
               + toHex4(56320 + %REM(cpArr(i)-65536:1024))
               + '>' + x'0A';
           ENDIF;
         ENDFOR;
         result = result + 'endbfchar' + x'0A';
       ENDIF;

       // CMapフッター
       result = result + 'endcmap' + x'0A' +
               'CMapName currentdict /CMap defineresource pop' + x'0A' +
               'end' + x'0A' +
               'end' + x'0A';
       RETURN result;
     P                 E

      *===============================================================
      * generateCIDFont - CIDFontType2オブジェクト生成
      * /W配列: 各グリフIDの幅をFUnit→ポイント(1000単位)で出力
      *===============================================================
     P generateCIDFont...
     P                 B                   EXPORT
     D generateCIDFont...                                                       CIDFont生成
     D                 PI          2048A    VARYING
     D   fontName                    64A   CONST VARYING                        フォント名
     D   fontData                      *   CONST                                フォントデータptr
     D   glyphIds                      *   CONST                                グリフID配列ptr
     D   numGlyphs                   10I 0 CONST                                グリフ数
     D   cidFontObjNum...                                                        CIDFont obj番号
     D                               10I 0 CONST
     D   descriptorNum...                                                        記述子obj番号
     D                               10I 0 CONST
     D result          S           2048A   VARYING                              CID辞書出力
     D gArr            S             10I 0 DIM(65536)                           グリフID配列
     D                                     BASED(glyphIds)
     D upm             S             10I 0                                      UnitsPerEm値
     D w               S             10I 0                                      グリフ原寸幅
     D wScaled         S             10I 0                                      1000単位幅
     D i               S             10I 0                                      ループ索引
       // フォントのunitsPerEmを取得（幅のスケーリングに必要）
       // unitsPerEm: フォント設計座標系の1emあたりの単位数
       // (例: 2048単位/em が一般的)
       upm = getUnitsPerEm(fontData);
       // CIDFontType2辞書: CIDベースのTrueTypeフォント定義
       // CIDSystemInfo Identity: グリフIDをそのままCIDとして使用
       result = %CHAR(cidFontObjNum) + ' 0 obj' + x'0A'
         + '<<' + x'0A'
         + '/Type /Font' + x'0A'
         + '/Subtype /CIDFontType2' + x'0A'
         + '/BaseFont /' + %TRIMR(fontName) + x'0A'
         + '/CIDSystemInfo <<' + x'0A'
         + '  /Registry (Adobe)' + x'0A'
         + '  /Ordering (Identity)' + x'0A'
         + '  /Supplement 0' + x'0A'
         + '>> def' + x'0A'
         + '/FontDescriptor ' + %CHAR(descriptorNum) + ' 0 R' + x'0A';

       // /W配列: CID→前進幅(1/1000 em単位)のマッピング
       // PDFはグリフ幅を1000分率で要求するため:
       //   幅 = glyphWidth * 1000 / unitsPerEm
       // 形式: CID [width] (個別指定形式)
       result = result + '/W [' + x'0A';
       FOR i = 1 TO numGlyphs;
         w = getGlyphWidth(fontData: gArr(i));
         wScaled = w * 1000 / upm;
         result = result + %CHAR(gArr(i)) + ' [' + %CHAR(wScaled) + ']' + x'0A';
       ENDFOR;
       result = result + ']' + x'0A';

       result = result + '>>' + x'0A' +
               'endobj' + x'0A';
       RETURN result;
     P                 E

      *===============================================================
      * generateFontDesc - FontDescriptorオブジェクト生成
      * Ascent/Descent/CapHeight等のメトリクスとFontFile2参照を出力
      *===============================================================
     P generateFontDesc...
     P                 B                   EXPORT
     D generateFontDesc...                                                      FontDesc生成
     D                 PI          1024A    VARYING
     D   fontName                    64A   CONST VARYING                        フォント名
     D   fontData                      *   CONST                                フォントデータptr
     D   objNum                      10I 0 CONST                                obj番号
     D   fontFileNum                 10I 0 CONST                                FontFile obj番号
     D result          S           1024A   VARYING                              記述子出力
     D upm             S             10I 0                                      UnitsPerEm値
     D asc             S             10I 0                                      Ascent値
     D dsc             S             10I 0                                      Descent値
     D cap             S             10I 0                                      CapHeight値
       // フォントメトリクスをFUnit→1000分率にスケーリング
       upm = getUnitsPerEm(fontData);
       asc = getAscent(fontData)*1000/upm;
       dsc = getDescent(fontData)*1000/upm;
       cap = getCapHeight(fontData)*1000/upm;
       // FontDescriptor辞書を構築
       // Flags=4(非セリフ), StemV=80(固定値)
       // FontFile2でサブセットTTFを参照
       result = %CHAR(objNum) + ' 0 obj' + x'0A'
         + '<<' + x'0A'
         + '/Type /FontDescriptor' + x'0A'
         + '/FontName /' + %TRIMR(fontName) + x'0A'
         + '/Flags 4' + x'0A'
         + '/FontBBox [0 ' + %CHAR(dsc) + ' 1000 ' + %CHAR(asc) + ']' + x'0A'
         + '/ItalicAngle 0' + x'0A'
         + '/Ascent ' + %CHAR(asc) + x'0A'
         + '/Descent ' + %CHAR(dsc) + x'0A'
         + '/CapHeight ' + %CHAR(cap) + x'0A'
         + '/StemV 80' + x'0A'
         + '/FontFile2 ' + %CHAR(fontFileNum) + ' 0 R' + x'0A'
         + '>>' + x'0A'
         + 'endobj' + x'0A';
       RETURN result;
     P                 E

      *===============================================================
      * generateType0 - Type0フォントオブジェクト生成
      * /Encoding Identity-H, /DescendantFonts, /ToUnicode参照
      *===============================================================
     P generateType0...
     P                 B                   EXPORT
     D generateType0...                                                         Type0生成
     D                 PI          1024A    VARYING
     D   fontName                    64A   CONST VARYING                        フォント名
     D   objNum                      10I 0 CONST                                obj番号
     D   cidFontNum                  10I 0 CONST                                CIDFont obj番号
     D   toUnicodeNum                10I 0 CONST                                ToUnicode obj番号
     D result          S           1024A   VARYING                              Type0出力
       // Type0フォント: CIDFontとToUnicodeを束ねるトップレベル定義
       // Encoding=Identity-H: グリフIDをそのままCIDとして使用
       result = %CHAR(objNum) + ' 0 obj' + x'0A'
         + '<<' + x'0A'
         + '/Type /Font' + x'0A'
         + '/Subtype /Type0' + x'0A'
         + '/BaseFont /' + %TRIMR(fontName) + x'0A'
         + '/Encoding /Identity-H' + x'0A'
         + '/DescendantFonts [' + %CHAR(cidFontNum) + ' 0 R]' + x'0A'
         + '/ToUnicode ' + %CHAR(toUnicodeNum) + ' 0 R' + x'0A'
         + '>>' + x'0A'
         + 'endobj' + x'0A';
       RETURN result;
     P                 E

      *===============================================================
      * getCodepoint - UTF-8バイト列からUnicodeコードポイントを取得
      * 1〜4バイトのUTF-8シーケンスを解析し、posを次の文字に進める。
      * ASCII(1バイト)/2バイト/3バイト(CJK)/4バイト(絵文字)対応
      *===============================================================
     P getCodepoint    B                   EXPORT
     D getCodepoint    PI            10U 0                                      CP取得
     D   utf8Str                    256A   CONST VARYING                        UTF-8入力文字列
     D   pos                         10I 0                                      走査位置
     D byteDS          DS                                                       バイト変換DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    数値変換先
     D b1              S              3U 0                                      第1バイト値
     D b2              S              3U 0                                      第2バイト値
     D b3              S              3U 0                                      第3バイト値
     D b4              S              3U 0                                      第4バイト値
     D cp              S             10U 0                                      コードポイント
     D len             S             10I 0                                      文字列長
       len = %LEN(utf8Str);
       IF pos > len;
         RETURN 0;
       ENDIF;
       // 先頭バイトを読み取り（OVERLAY技法でバイト→数値変換）
       // byteCharに文字を代入→OVERLAYでbyteValに数値が反映
       byteVal = 0;
       byteChar = %SUBST(utf8Str:pos:1);
       b1 = byteVal;
       // UTF-8可変長エンコーディング:
       //   1バイト: 0xxxxxxx         (U+0000-007F, ASCII)
       //   2バイト: 110xxxxx 10xxxxxx (U+0080-07FF)
       //   3バイト: 1110xxxx 10xxxxxx 10xxxxxx (U+0800-FFFF)
       //   4バイト: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx (U+10000-10FFFF)
       // 先頭バイトの上位ビットパターンでバイト数を判定
       //
       // 1バイト: ASCII (0x00-0x7F) - そのまま返す
       IF b1 < 128;
         pos = pos + 1;
         RETURN b1;
       ENDIF;
       // 2バイト: ラテン拡張・キリル等 (U+0080-07FF)
       // 先頭110xxxxxから下位5ビット、続くバイトから6ビット抽出
       // BITAND(b1:31)=下位5bit, BITAND(b2:63)=x'3F'で6bit抽出
       IF b1 >= 192 AND b1 < 224;
         byteVal = 0;
         byteChar = %SUBST(utf8Str:pos+1:1);
         b2 = byteVal;
         pos = pos + 2;
         cp = %BITAND(b1: 31) * 64 + %BITAND(b2: 63);
         RETURN cp;
       ENDIF;
       // 3バイト: CJK漢字・ひらがな等BMP範囲 (U+0800-FFFF)
       // 先頭1110xxxxから4ビット + 続く2バイトから各6ビット抽出
       // BITAND(b1:15)*4096 = 上位4bit<<12
       IF b1 >= 224 AND b1 < 240;
         byteVal = 0;
         byteChar = %SUBST(utf8Str:pos+1:1);
         b2 = byteVal;
         byteVal = 0;
         byteChar = %SUBST(utf8Str:pos+2:1);
         b3 = byteVal;
         pos = pos + 3;
         cp = %BITAND(b1: 15) * 4096 + %BITAND(b2: 63) * 64 + %BITAND(b3: 63);
         RETURN cp;
       ENDIF;
       // 4バイト: 絵文字・補助面 (U+10000-10FFFF)
       // 先頭11110xxxから3ビット + 続く3バイトから各6ビット抽出
       // BITAND(b1:7)*262144 = 上位3bit<<18
       // 各継続バイトはBITAND(bn:63)=x'3F'で下位6ビットを抽出
       IF b1 >= 240;
         byteVal = 0;
         byteChar = %SUBST(utf8Str:pos+1:1);
         b2 = byteVal;
         byteVal = 0;
         byteChar = %SUBST(utf8Str:pos+2:1);
         b3 = byteVal;
         byteVal = 0;
         byteChar = %SUBST(utf8Str:pos+3:1);
         b4 = byteVal;
         pos = pos + 4;
         cp = %BITAND(b1: 7) * 262144 + %BITAND(b2: 63) * 4096 +
              %BITAND(b3: 63) * 64 + %BITAND(b4: 63);
         RETURN cp;
       ENDIF;
       // 不正なバイト: スキップ
       pos = pos + 1;
       RETURN 0;
     P                 E

      * toHex4 - 16ビット値を4桁16進文字列に変換
      * 例: 65 → "0041", 26085 → "65E5"
     P toHex4          B                   EXPORT
     D toHex4          PI             4A                                        4桁16進変換
     D   val                         10U 0 CONST                                変換元数値
     D hexChars        S             16A   INZ('0123456789ABCDEF')              16進数文字テーブル
     D result          S              4A                                        4桁16進結果
       // 整数→固定幅4桁16進文字列変換 (PDF CIDマッピング用)
       // 上位ニブルから順に16進文字を取得:
       //   桁1: val/4096       (上位4ビット = ニブル0)
       //   桁2: (val/256)%16   (ニブル1)
       //   桁3: (val/16)%16    (ニブル2)
       //   桁4: val%16         (下位4ビット = ニブル3)
       %SUBST(result:1:1) = %SUBST(hexChars: %DIV(val:4096)+1: 1);
       %SUBST(result:2:1) = %SUBST(hexChars:%REM(%DIV(val:256):16)+1:1);
       %SUBST(result:3:1) = %SUBST(hexChars:%REM(%DIV(val:16):16)+1:1);
       %SUBST(result:4:1) = %SUBST(hexChars: %REM(val:16)+1: 1);
       RETURN result;
     P                 E

      * toHex2 - 8ビット値を2桁16進文字列に変換
      * 例: 255 → "FF", 10 → "0A"
     P toHex2          B                   EXPORT
     D toHex2          PI             2A                                        2桁16進変換
     D   val                         10U 0 CONST                                変換元数値
     D hexChars        S             16A   INZ('0123456789ABCDEF')              16進数文字テーブル
     D result          S              2A                                        2桁16進結果
       // 整数→固定幅2桁16進文字列変換
       //   桁1: val/16  (上位ニブル)
       //   桁2: val%16  (下位ニブル)
       %SUBST(result:1:1) = %SUBST(hexChars: %DIV(val:16)+1: 1);
       %SUBST(result:2:1) = %SUBST(hexChars: %REM(val:16)+1: 1);
       RETURN result;
     P                 E
