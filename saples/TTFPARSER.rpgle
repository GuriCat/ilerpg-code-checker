      *===============================================================
      * TTFPARSER - TrueType/OpenType/TTC フォント解析モジュール
      * Version: 3.0.0  Date: 2026-02-12
      *
      * TTF/OTF/TTCフォントファイルを解析し、以下の情報を取得する:
      *   - テーブルディレクトリ（tag, offset, length）
      *   - head: unitsPerEm, indexToLocFormat
      *   - maxp: glyphCount
      *   - hhea: numHMetrics
      *   - OS/2: ascent, descent, capHeight
      *   - cmap: Unicodeコードポイント→グリフID変換
      *   - COLR/CPAL: 色絵文字レイヤー情報
      *
      * TTC形式はfontIndex引数で個別フォントを選択可能。
      *===============================================================
     H NOMAIN
      /COPY QSYSINC/QRPGLESRC,SYSTYPES
      /COPY QSYSINC/QRPGLESRC,SYSSTAT
      /COPY QSYSINC/QRPGLESRC,FCNTL
      /COPY QSYSINC/QRPGLESRC,UNISTD

      *-------------------------------------------------------------
      * 内部プロシージャ宣言 - バイナリ読み取りユーティリティ
      *-------------------------------------------------------------
      * readU16BE/readU32BE: FDからビッグエンディアン整数を読む
     D readU16BE       PR             5U 0                                      BE16bit読取
     D   fd                          10I 0 CONST                                ファイル記述子
     D readU32BE       PR            10U 0                                      BE32bit読取
     D   fd                          10I 0 CONST                                ファイル記述子
      * readN: FDからNバイト読み取り
     D readN           PR            10I 0                                      Nバイト読取
     D   fd                          10I 0 CONST                                ファイル記述子
     D   buffer                        *   VALUE                                書込みバッファ
     D   length                      10U 0 CONST                                バイト長
      * readU16Buf/readI16Buf/readU32Buf: メモリ上のBE値を読む
     D readU16Buf      PR             5U 0                                      メモリBE16読取
     D   ptr                           *   CONST                                メモリ読取ptr
     D readI16Buf      PR             5I 0                                      メモリBE16符号
     D   ptr                           *   CONST                                メモリ読取ptr
     D readU32Buf      PR            10U 0                                      メモリBE32読取
     D   ptr                           *   CONST                                メモリ読取ptr
      *-------------------------------------------------------------
      * 内部プロシージャ宣言 - テーブルローダー
      *-------------------------------------------------------------
      * loadTableData: テーブルデータをメモリに読み込み
     D loadTableData   PR              *                                        テーブル読込
     D   fd                          10I 0 CONST                                ファイル記述子
     D   tblOffset                   10U 0 CONST                                テーブル開始位置
     D   tblLength                   10U 0 CONST                                テーブルバイト長
      * loadHeadTable: headテーブル解析（unitsPerEm等）
     D loadHeadTable   PR                                                       head解析
     D   fontData                      *   CONST                                フォントデータ
      * loadMaxpTable: maxpテーブル解析（グリフ数）
     D loadMaxpTable   PR                                                       maxp解析
     D   fontData                      *   CONST                                フォントデータ
      * loadHheaTable: hheaテーブル解析（hmtx数）
     D loadHheaTable   PR                                                       hhea解析
     D   fontData                      *   CONST                                フォントデータ
      * loadOs2Table: OS/2テーブル解析（ascent/descent/capHeight）
     D loadOs2Table    PR                                                       OS/2解析
     D   fontData                      *   CONST                                フォントデータ
      * loadCmapIndex: cmapテーブル解析（Unicode→GID変換表構築）
     D loadCmapIndex   PR                                                       cmap解析
     D   fontData                      *   CONST                                フォントデータ

      *-------------------------------------------------------------
      * 公開プロシージャ宣言
      *-------------------------------------------------------------
      * parseTTF: フォントファイルを開いて解析、FontData_tを返す
     D parseTTF        PR              *   EXTPROC(*CL:'parseTTF')              TTF解析
     D   fontPath                   256A   CONST VARYING                        フォントIFSパス
     D   fontIndex                   10I 0 VALUE OPTIONS(*NOPASS)               内フォント番号
      * getTable: 指定タグのテーブルデータを取得（遅延ロード）
     D getTable        PR              *   EXTPROC(*CL:'getTable')              テーブル取得
     D   fontData                      *   CONST                                フォントデータptr
     D   tag                          4A   CONST                                テーブルタグ4B
      * getGlyphCount: フォント内の総グリフ数を返す
     D getGlyphCount   PR            10I 0 EXTPROC(*CL:'getGlyphCount')         グリフ数取得
     D   fontData                      *   CONST                                フォントデータptr
      * getGlyphWidth: 指定グリフIDの水平幅（FUnit）を返す
     D getGlyphWidth   PR            10I 0 EXTPROC(*CL:'getGlyphWidth')         グリフ幅取得
     D   fontData                      *   CONST                                フォントデータptr
     D   glyphId                     10I 0 CONST                                対象グリフID
      * getUnitsPerEm: フォントの設計単位を返す
     D getUnitsPerEm   PR            10I 0 EXTPROC(*CL:'getUnitsPerEm')         Em単位取得
     D   fontData                      *   CONST                                フォントデータptr
      * getAscent/getDescent/getCapHeight: フォントメトリクス
     D getAscent       PR            10I 0 EXTPROC(*CL:'getAscent')             上端取得
     D   fontData                      *   CONST                                フォントデータptr
     D getDescent      PR            10I 0 EXTPROC(*CL:'getDescent')            下端取得
     D   fontData                      *   CONST                                フォントデータptr
     D getCapHeight    PR            10I 0 EXTPROC(*CL:'getCapHeight')          大文字高取得
     D   fontData                      *   CONST                                フォントデータptr
      * getGlyphIdForCP: Unicodeコードポイント→グリフID変換
      *   cmapのFormat 4/12を使用して変換する
     D getGlyphIdForCP...                                                       CP→グリフID
     D                 PR            10I 0 EXTPROC(*CL:'getGlyphIdForCP')
     D   fontData                      *   CONST                                フォントデータptr
     D   codepoint                   10U 0 CONST                                値
      * closeTTF: フォントデータとFDを解放する
     D closeTTF        PR                  EXTPROC(*CL:'closeTTF')              TTFクローズ
     D   fontData                      *                                        フォントデータptr
      * getTableOff/getTableLen: テーブルのオフセット・長さ取得
     D getTableOff     PR            10U 0 EXTPROC(*CL:'getTableOff')           テーブル位置取得
     D   fontData                      *   CONST                                フォントデータptr
     D   tag                          4A   CONST                                テーブルタグ4B
     D getTableLen     PR            10U 0 EXTPROC(*CL:'getTableLen')           テーブル長取得
     D   fontData                      *   CONST                                フォントデータptr
     D   tag                          4A   CONST                                テーブルタグ4B
      * getFontFd: フォントファイルのFDを返す
     D getFontFd       PR            10I 0 EXTPROC(*CL:'getFontFd')             フォントFD取得
     D   fontData                      *   CONST                                フォントデータptr

      *-------------------------------------------------------------
      * COLR/CPAL - 色絵文字テーブル参照
      *-------------------------------------------------------------
      * hasCOLR: COLR v0テーブルの有無（1=あり、0=なし）
     D hasCOLR         PR            10I 0 EXTPROC(*CL:'hasCOLR')               COLR有無判定
     D   fontData                      *   CONST                                フォントデータptr
      * getCOLRLayers: グリフのカラーレイヤーを取得
      *   各レイヤーのグリフIDとCPALカラー値を返す
     D getCOLRLayers   PR            10I 0 EXTPROC(*CL:                         COLRレイヤ取得
     D                                     'getCOLRLayers')
     D   fontData                      *   CONST                                フォントデータptr
     D   glyphId                     10I 0 CONST                                対象グリフID
     D   outLayGids                    *   CONST                                レイヤーGID出力
     D   outLayClrs                    *   CONST                                レイヤー色出力
     D   maxLayers                   10I 0 CONST                                最大レイヤー数

      *-------------------------------------------------------------
      * FontData_t - フォント情報構造体
      *   parseTTFが動的確保して返す。フォントのメタデータと
      *   テーブルディレクトリを保持する。
      *-------------------------------------------------------------
     D FontData_t      DS                  QUALIFIED TEMPLATE                   フォント情報構造体
     D   signature                   10U 0                                      フォント署名
     D   numTables                   10I 0                                      テーブル数
     D   searchRange                 10I 0                                      検索範囲
     D   entrySelector...                                                       エントリ選択子
     D                               10I 0
     D   rangeShift                  10I 0                                      範囲シフト
     D   tables                        *                                        テーブル配列ptr
     D   fileDescriptor...                                                      ファイル記述子
     D                               10I 0
     D   unitsPerEm                  10I 0                                      Em単位数
     D   glyphCount                  10I 0                                      総グリフ数
     D   ascent                      10I 0                                      上端(FUnit)
     D   descent                     10I 0                                      下端(FUnit)
     D   capHeight                   10I 0                                      大文字高さ
     D   numHMetrics                 10I 0                                      水平メトリクス数
     D   indexToLocFmt...                                                       loca形式(0/1)
     D                               10I 0
     D   cmapData                      *                                        cmapデータptr
     D   cmapLength                  10U 0                                      cmapバイト長

      * TableRecord_t - テーブルレコード（テーブルディレクトリの1エントリ）
     D TableRecord_t   DS                  QUALIFIED TEMPLATE                   テーブルレコード
     D   tag                          4A                                        テーブルタグ4B
     D   checksum                    10U 0                                      チェックサム
     D   offset                      10U 0                                      テーブル位置
     D   length                      10U 0                                      バイト長
     D   data                          *                                        テーブルデータptr

      * フォント署名定数
     D SIG_TRUETYPE    C                   CONST(65536)                         TrueType署名
     D SIG_OTTO        C                   CONST(1330926671)                    OpenType署名
     D SIG_TRUE        C                   CONST(1953658213)                    Apple TTF署名
     D SIG_TTCF        C                   CONST(1953784678)                    TTC署名

      *===============================================================
      * parseTTF - フォントファイル解析
      * TTF/OTF/TTCファイルを開き、テーブルディレクトリを読み込む。
      * TTC形式の場合はfontIndexで指定されたフォントを選択。
      * head/maxp/hhea/OS2/cmapテーブルを自動ロードする。
      * 戻り値: FontData_tポインタ（失敗時*NULL）
      *===============================================================
     P parseTTF        B                   EXPORT
     D parseTTF        PI              *                                        TTF解析
     D   fontPath                   256A   CONST VARYING                        フォントIFSパス
     D   fontIndex                   10I 0 VALUE OPTIONS(*NOPASS)               内フォント番号
     D fontData        DS                  LIKEDS(FontData_t)                   フォント情報DS
     D                                     BASED(pFontData)
     D pFontData       S               *                                        構造体ポインタ
     D fd              S             10I 0                                      ファイル記述子
     D sig             S             10U 0                                      フォント署名
     D numTbl          S             10I 0                                      テーブル数
     D i               S             10I 0                                      ループ索引
     D pTR             S               *                                        テーブルRecPtr
     D tr              DS                  LIKEDS(TableRecord_t)                テーブル1件
     D                                     BASED(pTR)
     D pathNull        S            257A                                        終端パス
     D ttcVer          S             10U 0                                      バージョン
     D ttcNum          S             10U 0                                      内フォント数
     D idxVal          S             10I 0                                      選択フォント番号
     D sfntOff         S             10U 0                                      開始位置
     D oflag           S             10I 0                                      フラグ
     D omode           S             10U 0                                      モード
       // フォントファイルを読み取り専用で開く（oflag=1=O_RDONLY）
       // 書き込み不要のため読取専用にし、FDはcloseTTFまで保持する
       // FDを維持する理由: テーブルの遅延ロード時にlseek+readで使う
       oflag = 1;
       fd = open(%TRIMR(fontPath): oflag);
       IF fd < 0;
         RETURN *NULL;
       ENDIF;

       // TTC形式の場合に使うフォントインデックス（省略時は0番目）
       // TTCは複数フォントを1ファイルに収容する形式で、
       // 日本語フォント（NotoSansCJK等）でよく使われる
       idxVal = 0;
       IF %PARMS >= 2;
         idxVal = fontIndex;
       ENDIF;

       // ファイル先頭4バイトの署名(magic number)でフォント形式を判定
       // 0x00010000=TrueType, 'OTTO'=CFF/OpenType, 'true'=Apple TTF
       // 'ttcf'=TTC(複数フォント収容)→個別sfntへの間接参照が必要
       sig = readU32BE(fd);
       sfntOff = 0;

       // TTC（TrueType Collection）: 複数フォントを1ファイルに収容
       // ヘッダ構造: 'ttcf' + version(4) + numFonts(4) + offsets[]
       // offsets[]は各フォントのsfntヘッダの絶対位置を格納
       IF sig = SIG_TTCF;
         // TTCバージョンを読む（1.0/2.0、処理上の差異なし）
         ttcVer = readU32BE(fd);
         // 収容フォント数を取得して範囲チェックに使用
         ttcNum = readU32BE(fd);
         // 指定インデックスがフォント数を超えていたらエラー
         IF idxVal >= ttcNum;
           callp close(fd);
           RETURN *NULL;
         ENDIF;
         // offsetsはヘッダ(12B)直後に並ぶ。idx>0ならシークが必要
         // idx=0なら現在位置がちょうどoffsets[0]を指している
         IF idxVal > 0;
           callp lseek(fd: 12+idxVal*4: 0);
         ENDIF;
         // 選択フォントのsfnt開始位置を読み、そこへ移動
         // 以降は通常のTTF/OTFと同じsfntヘッダ構造になる
         sfntOff = readU32BE(fd);
         callp lseek(fd: sfntOff: 0);
         // 個別フォントの署名を再度読み取って形式を確認
         sig = readU32BE(fd);
       ENDIF;

       // 署名がTTF/OTF/TRUEのいずれでもなければ非対応形式
       // WOFFやWOFF2は未対応（Web専用、IBM iでは不要）
       IF sig <> SIG_TRUETYPE AND sig <> SIG_OTTO AND sig <> SIG_TRUE;
         callp close(fd);
         RETURN *NULL;
       ENDIF;

       // FontData_t構造体を動的確保し、基本情報を初期化
       // cmapDataは後でloadCmapIndexで別途確保される
       pFontData = %ALLOC(%SIZE(FontData_t));
       fontData.fileDescriptor = fd;
       fontData.signature = sig;
       fontData.cmapData = *NULL;
       fontData.cmapLength = 0;

       // sfntヘッダ: 署名の直後にテーブル数と二分探索パラメータが続く
       // searchRange/entrySelector/rangeShiftはバイナリ検索用だが
       // 本実装では線形走査するため参考値として保持のみ
       numTbl = readU16BE(fd);
       fontData.numTables = numTbl;
       fontData.searchRange = readU16BE(fd);
       fontData.entrySelector = readU16BE(fd);
       fontData.rangeShift = readU16BE(fd);

       // テーブルディレクトリ: numTables個のTableRecord_tを格納する配列
       fontData.tables = %ALLOC(numTbl * %SIZE(TableRecord_t));

       // 各テーブルレコードは: tag(4B) checksum(4B) offset(4B) length(4B)
       // tagは'head','cmap','glyf'等のASCII 4文字識別子
       // offset/lengthでファイル内のテーブル本体位置を特定できる
       // data=*NULLで初期化し、実際のロードはgetTable初回呼出時に行う
       FOR i = 1 TO numTbl;
         pTR = fontData.tables + (i-1) * %SIZE(TableRecord_t);
         readN(fd: %ADDR(tr.tag): 4);
         tr.checksum = readU32BE(fd);
         tr.offset = readU32BE(fd);
         tr.length = readU32BE(fd);
         tr.data = *NULL;
       ENDFOR;

       // 必須テーブルを即座にロード（PDF生成に必須のメトリクス情報）
       // head: unitsPerEm（座標系）、indexToLocFormat（グリフ位置形式）
       loadHeadTable(pFontData);
       // maxp: glyphCount（サブセット時のグリフID範囲に使用）
       loadMaxpTable(pFontData);
       // hhea: numHMetrics（hmtxテーブルの構造判定に必要）
       loadHheaTable(pFontData);
       // OS/2: capHeight（PDF FontDescriptorのCapHeight値）
       loadOs2Table(pFontData);
       // cmap: Unicode→GID変換表（テキスト描画の根幹機能）
       loadCmapIndex(pFontData);

       RETURN pFontData;
     P                 E

      *===============================================================
      * getTable - テーブルデータ取得（遅延ロード方式）
      * 初回アクセス時にファイルからメモリに読み込み、以降はキャッシュ
      *===============================================================
     P getTable        B                   EXPORT
     D getTable        PI              *                                        テーブル取得
     D   fontData                      *   CONST                                フォントデータptr
     D   tag                          4A   CONST                                テーブルタグ4B
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
     D i               S             10I 0                                      ループ索引
     D pTR             S               *                                        テーブルRecPtr
     D tr              DS                  LIKEDS(TableRecord_t)                走査中テーブル
     D                                     BASED(pTR)
       // テーブルディレクトリを走査して指定タグを検索
       FOR i = 1 TO font.numTables;
         pTR = font.tables + (i-1) * %SIZE(TableRecord_t);
         IF tr.tag = tag;
           // 初回アクセス時のみファイルから読み込む（遅延ロード）
           IF tr.data = *NULL;
             tr.data = loadTableData(font.fileDescriptor: tr.offset: tr.length);
           ENDIF;
           // 2回目以降はキャッシュ済みポインタを返す
           RETURN tr.data;
         ENDIF;
       ENDFOR;
       // 該当テーブルが存在しない
       RETURN *NULL;
     P                 E

     P getTableOff     B                   EXPORT
     D getTableOff     PI            10U 0                                      テーブル位置取得
     D   fontData                      *   CONST                                フォントデータptr
     D   tag                          4A   CONST                                テーブルタグ4B
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
     D i               S             10I 0                                      ループ索引
     D pTR             S               *                                        テーブルRecPtr
     D tr              DS                  LIKEDS(TableRecord_t)                走査中テーブル
     D                                     BASED(pTR)
       // テーブルディレクトリから指定タグのファイル内オフセットを返す
       FOR i = 1 TO font.numTables;
         pTR = font.tables + (i-1) * %SIZE(TableRecord_t);
         IF tr.tag = tag;
           RETURN tr.offset;
         ENDIF;
       ENDFOR;
       RETURN 0;
     P                 E

     P getTableLen     B                   EXPORT
     D getTableLen     PI            10U 0                                      テーブル長取得
     D   fontData                      *   CONST                                フォントデータptr
     D   tag                          4A   CONST                                テーブルタグ4B
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
     D i               S             10I 0                                      ループ索引
     D pTR             S               *                                        テーブルRecPtr
     D tr              DS                  LIKEDS(TableRecord_t)                走査中テーブル
     D                                     BASED(pTR)
       // テーブルディレクトリから指定タグのデータ長を返す
       FOR i = 1 TO font.numTables;
         pTR = font.tables + (i-1) * %SIZE(TableRecord_t);
         IF tr.tag = tag;
           RETURN tr.length;
         ENDIF;
       ENDFOR;
       RETURN 0;
     P                 E

     P getFontFd       B                   EXPORT
     D getFontFd       PI            10I 0                                      フォントFD取得
     D   fontData                      *   CONST                                フォントデータptr
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
       RETURN font.fileDescriptor;
     P                 E

     P getGlyphCount   B                   EXPORT
     D getGlyphCount   PI            10I 0                                      グリフ数取得
     D   fontData                      *   CONST                                フォントデータptr
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
       RETURN font.glyphCount;
     P                 E

     P getUnitsPerEm   B                   EXPORT
     D getUnitsPerEm   PI            10I 0                                      Em単位取得
     D   fontData                      *   CONST                                フォントデータptr
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
       RETURN font.unitsPerEm;
     P                 E

     P getAscent       B                   EXPORT
     D getAscent       PI            10I 0                                      上端取得
     D   fontData                      *   CONST                                フォントデータptr
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
       RETURN font.ascent;
     P                 E

     P getDescent      B                   EXPORT
     D getDescent      PI            10I 0                                      下端取得
     D   fontData                      *   CONST                                フォントデータptr
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
       RETURN font.descent;
     P                 E

     P getCapHeight    B                   EXPORT
     D getCapHeight    PI            10I 0                                      大文字高取得
     D   fontData                      *   CONST                                フォントデータptr
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
       RETURN font.capHeight;
     P                 E

      * getGlyphWidth - hmtxテーブルからグリフ幅（FUnit）を取得
     P getGlyphWidth   B                   EXPORT
     D getGlyphWidth   PI            10I 0                                      グリフ幅取得
     D   fontData                      *   CONST                                フォントデータptr
     D   glyphId                     10I 0 CONST                                対象グリフID
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
     D hmtxPtr         S               *                                        テーブルPtr
     D off             S             10I 0                                      メトリクス位置
       // hmtxテーブル: 各グリフの水平メトリクス（幅+左サイドベアリング）
       // PDF生成時にテキスト幅計算とTJオペレータの配置に必要
       hmtxPtr = getTable(fontData: x'686D7478'); // 'hmtx'水平メトリクス
       IF hmtxPtr = *NULL;
         RETURN 0;
       ENDIF;
       // hmtxテーブルの構造:
       //   longHorMetric[numHMetrics] - 各4B: advanceWidth(2B)+lsb(2B)
       //   leftSideBearing[glyphCount-numHMetrics] - 各2B
       // numHMetrics未満のGIDは個別の幅を持つ（プロポーショナル部分）
       // numHMetrics以降のGIDは全て同じ幅を共有する（等幅部分）
       // CJKフォントでは漢字が等幅部分になることが多い
       IF glyphId < font.numHMetrics;
         off = glyphId * 4;
       ELSE;
         // 等幅部分: 最後のlongHorMetricの幅を使う
         off = (font.numHMetrics - 1) * 4;
       ENDIF;
       // longHorMetricレコードの先頭2バイトがadvanceWidth（FUnit単位）
       // PDF側でunitsPerEmで除算してポイント単位に変換する
       RETURN readU16Buf(hmtxPtr + off);
     P                 E

      *===============================================================
      * getGlyphIdForCP - Unicodeコードポイント→グリフID変換
      * cmapテーブルのFormat 4（BMP）またはFormat 12（全Unicode）を
      * 使用してグリフIDを検索する。見つからない場合は0を返す。
      *===============================================================
     P getGlyphIdForCP...
     P                 B                   EXPORT
     D getGlyphIdForCP...                                                       CP→グリフID
     D                 PI            10I 0
     D   fontData                      *   CONST                                フォントデータptr
     D   codepoint                   10U 0 CONST                                値
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
     D cPtr            S               *                                        データPtr
     D fmt             S              5U 0                                      フォーマット
     D segCnt          S             10I 0                                      セグメント数
     D ePtr            S               *                                        配列Ptr
     D sPtr            S               *                                        配列Ptr
     D dPtr            S               *                                        配列Ptr
     D rPtr            S               *                                        配列Ptr
     D i               S             10I 0                                      ループ索引
     D eCode           S              5U 0                                      セグメント終了値
     D sCode           S              5U 0                                      セグメント開始値
     D iDelta          S              5I 0                                      差分値
     D iROff           S              5U 0                                      間接参照Offset
     D gId             S             10I 0                                      算出グリフID
     D gidx            S              5U 0                                      間接参照GID
     D off             S             10I 0                                      バイトOffset
     D nGrp            S             10U 0                                      グループ数
     D sCC             S             10U 0                                      グループ開始CP
     D eCC             S             10U 0                                      グループ終了CP
     D sGId            S             10U 0                                      グループ開始GID
       // cmapデータが未ロードなら変換不可（GID=0は.notdef）
       IF font.cmapData = *NULL;
         RETURN 0;
       ENDIF;
       cPtr = font.cmapData;
       // cmapサブテーブルの先頭2バイトがフォーマット番号
       // Format 4=BMP(16bit), Format 12=全Unicode(32bit)
       fmt = readU16Buf(cPtr);

       // === Format 4: BMP範囲（U+0000〜U+FFFF）のセグメントマッピング ===
       // 連続するコードポイント範囲を「セグメント」として管理する。
       // 各セグメントは startCode〜endCode の範囲を持ち、
       // その範囲内のコードポイントをグリフIDに変換するための
       // idDelta と idRangeOffset の2つの方法を提供する。
       IF fmt = 4;
         // segCountX2（オフセット6）は実際のセグメント数の2倍の値
         segCnt = readU16Buf(cPtr + 6) / 2;
         // Format 4は4つの並列配列で構成される:
         //   endCode[segCnt]     - 各セグメントの終了コードポイント
         //   reservedPad(2byte)  - endCode直後のパディング
         //   startCode[segCnt]   - 各セグメントの開始コードポイント
         //   idDelta[segCnt]     - GID算出用の加算値（符号付き）
         //   idRangeOffset[segCnt] - 間接参照用オフセット
         // ヘッダ14バイト後にendCode配列が始まる
         ePtr = cPtr + 14;
         sPtr = ePtr + segCnt * 2 + 2;
         dPtr = sPtr + segCnt * 2;
         rPtr = dPtr + segCnt * 2;
         // endCodeは昇順ソート済みのため、最初にcodepoint<=eCodeとなる
         // セグメントを見つけたら、startCodeとも比較して範囲内か判定
         FOR i = 0 TO segCnt - 1;
           eCode = readU16Buf(ePtr + i*2);
           IF codepoint <= eCode;
             sCode = readU16Buf(sPtr + i*2);
             IF codepoint >= sCode;
               iDelta = readI16Buf(dPtr+i*2);
               iROff = readU16Buf(rPtr+i*2);
               IF iROff = 0;
                 // 方法1: idRangeOffset=0の場合
                 // GID = (codepoint + idDelta) mod 65536
                 // 連続範囲のグリフが連続GIDに対応する場合に使う
                 gId=%REM(codepoint+iDelta:65536);
               ELSE;
                 // 方法2: idRangeOffset>0の場合
                 // idRangeOffset配列自体の位置からの相対オフセットで
                 // glyphIdArray内の値を間接参照する。これにより
                 // 不連続なGIDマッピングが可能になる
                 off = iROff + (codepoint-sCode) * 2;
                 gidx = readU16Buf(rPtr + i*2 + off);
                 IF gidx = 0;
                   RETURN 0;
                 ENDIF;
                 // 間接参照で得たGIDにもidDeltaを加算する
                 gId=%REM(gidx+iDelta:65536);
               ENDIF;
               RETURN gId;
             ENDIF;
           ENDIF;
         ENDFOR;
         // 全セグメントを走査して該当なし → .notdef(GID=0)
         RETURN 0;
       ENDIF;

       // === Format 12: 全Unicode範囲のセグメントマッピング（32ビット） ===
       // BMP外の文字（絵文字U+1F600〜、CJK拡張B U+20000〜等）には
       // Format 4では対応できないため、32ビット版のFormat 12が必要。
       // 構造はシンプル: SequentialMapGroup の配列で、各グループは
       // startCharCode(4B), endCharCode(4B), startGlyphID(4B) の12バイト
       IF fmt = 12;
         // グループ数はオフセット12の位置（固定ヘッダ後）
         nGrp = readU32Buf(cPtr + 12);
         // グループデータはオフセット16から開始、各12バイト
         FOR i = 0 TO nGrp - 1;
           off = 16 + i * 12;
           sCC = readU32Buf(cPtr + off);
           eCC = readU32Buf(cPtr + off + 4);
           sGId = readU32Buf(cPtr + off + 8);
           // GID = startGlyphID + (codepoint - startCharCode)
           // グループ内はコードポイントとGIDが1対1で連続対応
           IF codepoint >= sCC AND codepoint <= eCC;
             RETURN sGId+(codepoint-sCC);
           ENDIF;
         ENDFOR;
         RETURN 0;
       ENDIF;
       // Format 4/12以外は未対応（Format 0,2,6等は現在不使用）
       RETURN 0;
     P                 E

      * hasCOLR - COLR v0テーブルの有無を判定（1=あり、0=なし）
     P hasCOLR         B                   EXPORT
     D hasCOLR         PI            10I 0                                      COLR存在フラグ
     D   fontData                      *   CONST                                フォントデータptr
     D colrPtr         S               *                                        テーブルPtr
       // COLRテーブル（タグ'COLR'）の存在を確認
       colrPtr = getTable(fontData: x'434F4C52');
       IF colrPtr <> *NULL;
         RETURN 1;
       ENDIF;
       RETURN 0;
     P                 E

      *===============================================================
      * getCOLRLayers - COLR v0のカラーレイヤーを取得
      * COLRテーブルのBaseGlyphRecordからレイヤー情報を検索し、
      * CPALテーブルからRGBA色を取得して返す。
      * 戻り値: レイヤー数（0=COLR非対応 or 該当なし）
      *===============================================================
     P getCOLRLayers   B                   EXPORT
     D getCOLRLayers   PI            10I 0                                      COLRレイヤ取得
     D   fontData                      *   CONST                                フォントデータptr
     D   glyphId                     10I 0 CONST                                対象グリフID
     D   outLayGids                    *   CONST                                レイヤーGID出力
     D   outLayClrs                    *   CONST                                レイヤー色出力
     D   maxLayers                   10I 0 CONST                                最大レイヤー数
     D colrPtr         S               *                                        テーブルPtr
     D cpalPtr         S               *                                        テーブルPtr
     D numBGR          S              5U 0                                      数
     D bgrOff          S             10U 0                                      配列Offset
     D layOff          S             10U 0                                       LayerRec Offset
     D numLayR         S              5U 0                                      数
     D i               S             10I 0                                      ループ索引
     D bgGid           S              5U 0                                      のグリフID
     D bgFirst         S              5U 0                                      先頭Layer索引
     D bgNum           S              5U 0                                      レイヤー数
     D pBGR            S               *                                        配列Ptr
     D pLay            S               *                                        配列Ptr
     D layGid          S              5U 0                                      レイヤーGID
     D palIdx          S              5U 0                                      パレット索引
     D nPalEnt         S              5U 0                                      パレット項目数
     D clrRecOff       S             10U 0                                      色RecOffset
     D pClr            S               *                                        色データPtr
     D cBytes          S              1A   DIM(4) BASED(pClr)                   各1byte
     D byteDS          DS                                                       変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
     D cB              S             10U 0                                      成分
     D cG              S             10U 0                                      成分
     D cR              S             10U 0                                      成分
     D cA              S             10U 0                                      成分
     D outG            S             10I 0 DIM(256)                             出力GID配列
     D                                     BASED(outLayGids)
     D outC            S             10U 0 DIM(256)                             出力色配列
     D                                     BASED(outLayClrs)
     D nOut            S             10I 0                                      出力レイヤー数
       // COLR v0テーブル: 色絵文字を複数レイヤーの重ね描きで表現する
       // 各レイヤーは通常のグリフ輪郭（glyf内）＋単色で構成され、
       // 背面から前面へ順に描画することでカラー絵文字を実現する。
       // 例: 笑顔絵文字 = 黄色い丸(背面) + 目(中間) + 口(前面)
       colrPtr = getTable(fontData: x'434F4C52'); // 'COLR'色レイヤー
       IF colrPtr = *NULL;
         RETURN 0;
       ENDIF;
       // CPALテーブル: COLRが参照するカラーパレットを定義する
       // 各エントリは4バイト（BGRA順）の色値を持つ
       // パレットは複数定義可能だが、ここではパレット0を使用
       cpalPtr = getTable(fontData: x'4350414C'); // 'CPAL'色パレット
       IF cpalPtr = *NULL;
         RETURN 0;
       ENDIF;

       // COLR v0ヘッダ構造（14バイト）:
       //   version(2B)=0, numBaseGlyphRecords(2B),
       //   baseGlyphRecordsOffset(4B), layerRecordsOffset(4B),
       //   numLayerRecords(2B)
       numBGR = readU16Buf(colrPtr + 2);
       bgrOff = readU32Buf(colrPtr + 4);
       layOff = readU32Buf(colrPtr + 8);
       numLayR = readU16Buf(colrPtr + 12);
       // CPALヘッダ: パレットエントリ数とカラーレコード開始位置を取得
       // カラーレコードはBGRA各1バイトの配列
       nPalEnt = readU16Buf(cpalPtr + 2);
       clrRecOff = readU32Buf(cpalPtr + 8);

       // BaseGlyphRecord配列を線形走査して対象グリフIDを検索
       // 各レコード6バイト: glyphID(2B), firstLayerIndex(2B), numLayers(2B)
       // glyphIDは昇順ソート済みだが、数が少ないため線形走査で十分
       pBGR = colrPtr + bgrOff;
       FOR i = 0 TO numBGR - 1;
         bgGid = readU16Buf(pBGR + i * 6);
         IF bgGid = glyphId;
           // 一致: このグリフのレイヤー範囲を取得
           // firstLayerIndex: LayerRecord配列内の開始位置
           // numLayers: このグリフを構成するレイヤー数
           bgFirst = readU16Buf(pBGR + i * 6 + 2);
           bgNum = readU16Buf(pBGR + i * 6 + 4);
           pLay = colrPtr + layOff;
           // 各レイヤーを読み出す（背面→前面の順で格納されている）
           // PDF描画時もこの順序で重ね描きすることでカラー表現する
           FOR nOut = 1 TO bgNum;
             IF nOut > maxLayers;
               LEAVE;
             ENDIF;
             // LayerRecord: 4バイト = glyphID(2B) + paletteIndex(2B)
             // glyphIDはglyfテーブル内の輪郭を指し、
             // paletteIndexはCPALの色テーブル内のエントリ番号
             layGid = readU16Buf(pLay + (bgFirst+nOut-1)*4);
             palIdx = readU16Buf(pLay + (bgFirst+nOut-1)*4+2);
             outG(nOut) = layGid;
             // CPALカラーレコード: BGRA順に各1バイトで色を格納
             // palIdx * 4 でエントリの先頭位置を算出
             pClr = cpalPtr + clrRecOff + palIdx * 4;
             // バイト→数値変換（EBCDICのためオーバーレイDSを使用）
             byteVal = 0;
             byteChar = cBytes(1);
             cB = byteVal;
             byteVal = 0;
             byteChar = cBytes(2);
             cG = byteVal;
             byteVal = 0;
             byteChar = cBytes(3);
             cR = byteVal;
             byteVal = 0;
             byteChar = cBytes(4);
             cA = byteVal;
             // BGRA→RGBA形式の32ビット整数にパック: 0xRRGGBBAA
             // PDF描画時にR,G,B各成分を/255で正規化して使用する
             outC(nOut) = cR * 16777216 + cG * 65536 + cB * 256 + cA;
           ENDFOR;
           RETURN bgNum;
         ENDIF;
       ENDFOR;
       // BaseGlyphRecordに該当なし: このグリフはCOLR非対応
       // 呼出元は通常のモノクログリフとして描画する
       RETURN 0;
     P                 E

      * closeTTF - フォントデータ解放（FD閉じ、メモリ解放）
     P closeTTF        B                   EXPORT
     D closeTTF        PI                                                       TTFクローズ
     D   fontData                      *                                        フォントデータptr
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
     D i               S             10I 0                                      ループ索引
     D pTR             S               *                                        テーブルRecPtr
     D tr              DS                  LIKEDS(TableRecord_t)                走査中テーブル
     D                                     BASED(pTR)
       // NULLチェック（二重解放防止）
       IF fontData = *NULL;
         RETURN;
       ENDIF;
       // 遅延ロードでメモリ確保されたテーブルデータを順に解放
       FOR i = 1 TO font.numTables;
         pTR = font.tables + (i-1) * %SIZE(TableRecord_t);
         IF tr.data <> *NULL;
           DEALLOC tr.data;
         ENDIF;
       ENDFOR;
       // テーブルディレクトリ配列自体を解放
       IF font.tables <> *NULL;
         DEALLOC font.tables;
       ENDIF;
       // cmapサブテーブルのコピーを解放（loadCmapIndexで確保）
       IF font.cmapData <> *NULL;
         DEALLOC font.cmapData;
       ENDIF;
       // フォントファイルのファイル記述子を閉じる
       callp close(font.fileDescriptor);
       // FontData_t構造体自体を解放し、ポインタをNULLに設定
       DEALLOC fontData;
       fontData = *NULL;
     P                 E

      *-------------------------------------------------------------
      * 以下: バイナリI/Oユーティリティ（ビッグエンディアン読み取り）
      *-------------------------------------------------------------
      * readU16BE - FDから2バイトBE符号なし整数を読む
     P readU16BE       B
     D readU16BE       PI             5U 0                                      BE16bit読取
     D   fd                          10I 0 CONST                                ファイル記述子
     D buf             S              2A                                        読取バッファ
     D byteDS          DS                                                       変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
     D b1              S              3U 0                                      上位バイト値
     D b2              S              3U 0                                      下位バイト値
       // FDから2バイト読み取り
       readN(fd: %ADDR(buf): 2);
       // EBCDICバイトをオーバーレイDSで数値に変換（ビッグエンディアン順）
       byteVal = 0;
       byteChar = %SUBST(buf:1:1);
       b1 = byteVal;
       byteVal = 0;
       byteChar = %SUBST(buf:2:1);
       b2 = byteVal;
       // 上位バイト*256 + 下位バイトで16ビット値を復元
       RETURN b1 * 256 + b2;
     P                 E

     P readU32BE       B
     D readU32BE       PI            10U 0                                      BE32bit読取
     D   fd                          10I 0 CONST                                ファイル記述子
     D buf             S              4A                                        読取バッファ
     D byteDS          DS                                                       変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
     D b1              S             10U 0                                      第1バイト値
     D b2              S             10U 0                                      第2バイト値
     D b3              S             10U 0                                      第3バイト値
     D b4              S             10U 0                                      第4バイト値
       // FDから4バイト読み取り
       readN(fd: %ADDR(buf): 4);
       // 各バイトをオーバーレイDSで数値化
       byteVal = 0;
       byteChar = %SUBST(buf:1:1);
       b1 = byteVal;
       byteVal = 0;
       byteChar = %SUBST(buf:2:1);
       b2 = byteVal;
       byteVal = 0;
       byteChar = %SUBST(buf:3:1);
       b3 = byteVal;
       byteVal = 0;
       byteChar = %SUBST(buf:4:1);
       b4 = byteVal;
       // ビッグエンディアン順で32ビット値を復元
       RETURN b1*16777216+b2*65536+b3*256+b4;
     P                 E

     P readN           B
     D readN           PI            10I 0                                      Nバイト読取
     D   fd                          10I 0 CONST                                ファイル記述子
     D   buffer                        *   VALUE                                読込バッファptr
     D   length                      10U 0 CONST                                読込バイト数
     D rc              S             10I 0                                      戻り値
       // POSIX read()でFDから指定バイト数をバッファに読み込む
       rc = read(fd: buffer: length);
       RETURN rc;
     P                 E

     P readU16Buf      B
     D readU16Buf      PI             5U 0                                      メモリBE16読取
     D   ptr                           *   CONST                                メモリ読取ptr
     D bA              S              1A   DIM(2) BASED(ptr)                    バイト配列参照
     D byteDS          DS                                                       変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
     D b1              S             10U 0                                      上位バイト値
     D b2              S             10U 0                                      下位バイト値
       // メモリ上のポインタから2バイトBE符号なし整数を読む
       byteVal = 0;
       byteChar = bA(1);
       b1 = byteVal;
       byteVal = 0;
       byteChar = bA(2);
       b2 = byteVal;
       RETURN b1 * 256 + b2;
     P                 E

     P readI16Buf      B
     D readI16Buf      PI             5I 0                                      メモリBE16符号
     D   ptr                           *   CONST                                メモリ読取ptr
     D uval            S              5U 0                                      符号なし中間値
     D ival            S             10I 0                                      符号付き結果値
       // まず符号なし16ビットとして読む
       uval = readU16Buf(ptr);
       ival = uval;
       // 最上位ビットが立っていれば負数に変換（2の補数）
       IF ival >= 32768;
         ival = ival - 65536;
       ENDIF;
       RETURN ival;
     P                 E

     P readU32Buf      B
     D readU32Buf      PI            10U 0                                      メモリBE32読取
     D   ptr                           *   CONST                                メモリ読取ptr
     D bA              S              1A   DIM(4) BASED(ptr)                    バイト配列参照
     D byteDS          DS                                                       変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
     D b1              S             10U 0                                      第1バイト値
     D b2              S             10U 0                                      第2バイト値
     D b3              S             10U 0                                      第3バイト値
     D b4              S             10U 0                                      第4バイト値
       // メモリ上のポインタから4バイトBE符号なし整数を読む
       byteVal = 0;
       byteChar = bA(1);
       b1 = byteVal;
       byteVal = 0;
       byteChar = bA(2);
       b2 = byteVal;
       byteVal = 0;
       byteChar = bA(3);
       b3 = byteVal;
       byteVal = 0;
       byteChar = bA(4);
       b4 = byteVal;
       RETURN b1*16777216+b2*65536+b3*256+b4;
     P                 E

      *-------------------------------------------------------------
      * 以下: テーブルローダー
      *-------------------------------------------------------------
      * loadTableData - テーブルデータをメモリに読み込み
     P loadTableData   B
     D loadTableData   PI              *                                        テーブル読込
     D   fd                          10I 0 CONST                                ファイル記述子
     D   tblOffset                   10U 0 CONST                                テーブル開始位置
     D   tblLength                   10U 0 CONST                                テーブルバイト長
     D pData           S               *                                        確保メモリPtr
       // 異常なサイズ（0または16MB超）は読み込まない
       IF tblLength = 0 OR tblLength > 16000000;
         RETURN *NULL;
       ENDIF;
       // テーブルサイズ分のメモリを確保
       pData = %ALLOC(tblLength);
       // ファイル内のテーブル開始位置にシークして一括読み込み
       callp lseek(fd: tblOffset: 0);
       readN(fd: pData: tblLength);
       RETURN pData;
     P                 E

      * loadHeadTable - headテーブルからunitsPerEm, indexToLocFormatを取得
     P loadHeadTable   B
     D loadHeadTable   PI                                                       head解析
     D   fontData                      *   CONST                                フォントデータptr
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
     D p               S               *                                        データPtr
       // 'head'テーブルを取得
       p = getTable(fontData: x'68656164');
       IF p <> *NULL;
         // オフセット18: unitsPerEm（フォントの設計単位数）
         font.unitsPerEm = readU16Buf(p+18);
         // オフセット50: indexToLocFormat（loca形式: 0=short,1=long）
         font.indexToLocFmt=readU16Buf(p+50);
       ELSE;
         // headテーブルがない場合のデフォルト値
         font.unitsPerEm = 1000;
         font.indexToLocFmt = 0;
       ENDIF;
     P                 E

      * loadMaxpTable - maxpテーブルからグリフ数を取得
     P loadMaxpTable   B
     D loadMaxpTable   PI                                                       maxp解析
     D   fontData                      *   CONST                                フォントデータptr
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
     D p               S               *                                        データPtr
       // 'maxp'テーブルを取得
       p = getTable(fontData: x'6D617870');
       IF p <> *NULL;
         // オフセット4: numGlyphs（フォント内の総グリフ数）
         font.glyphCount = readU16Buf(p+4);
       ELSE;
         font.glyphCount = 0;
       ENDIF;
     P                 E

      * loadHheaTable - hheaテーブルからnumHMetricsを取得
     P loadHheaTable   B
     D loadHheaTable   PI                                                       hhea解析
     D   fontData                      *   CONST                                フォントデータptr
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
     D p               S               *                                        データPtr
       // 'hhea'テーブルを取得（水平レイアウトヘッダ）
       p = getTable(fontData: x'68686561');
       IF p <> *NULL;
         // オフセット4: ascender（ベースラインからの上方距離）
         font.ascent = readI16Buf(p + 4);
         // オフセット6: descender（ベースラインからの下方距離、通常は負）
         font.descent = readI16Buf(p + 6);
         // オフセット34: numberOfHMetrics（hmtxのlongHorMetricレコード数）
         font.numHMetrics=readU16Buf(p+34);
       ELSE;
         // hheaテーブルがない場合のデフォルト値
         font.ascent = 750;
         font.descent = -250;
         font.numHMetrics = 0;
       ENDIF;
     P                 E

      * loadOs2Table - OS/2テーブルからascent/descent/capHeight取得
     P loadOs2Table    B
     D loadOs2Table    PI                                                       OS/2解析
     D   fontData                      *   CONST                                フォントデータptr
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
     D p               S               *                                        データPtr
     D ver             S              5U 0                                      バージョン
       // 'OS/2'テーブルを取得（Windowsメトリクス）
       p = getTable(fontData: x'4F532F32');
       IF p <> *NULL;
         // OS/2テーブルのバージョンを確認
         ver = readU16Buf(p);
         IF ver >= 2;
           // v2以降にはsCapHeightフィールドがある（オフセット88）
           font.capHeight=readI16Buf(p+88);
         ELSE;
           // v0/v1にはcapHeightがないのでascentで代用
           font.capHeight = font.ascent;
         ENDIF;
       ELSE;
         // OS/2テーブルがない場合のデフォルト値
         font.capHeight = 700;
       ENDIF;
     P                 E

      *===============================================================
      * loadCmapIndex - cmapテーブル解析
      * Unicodeプラットフォーム（platformID=0 or 3）のサブテーブルを
      * 探し、Format 4またはFormat 12のデータをメモリにロードする。
      * Format 12（32ビット）を優先し、なければFormat 4（16ビット）
      *===============================================================
     P loadCmapIndex   B
     D loadCmapIndex   PI                                                       cmap解析
     D   fontData                      *   CONST                                フォントデータptr
     D font            DS                  LIKEDS(FontData_t)                   フォント情報参照
     D                                     BASED(fontData)
     D nSub            S              5U 0                                      サブテーブル数
     D i               S             10I 0                                      サブテーブル索引
     D pId             S              5U 0                                       platformID
     D eId             S              5U 0                                       encodingID
     D sOff            S             10U 0                                      サブテーブルOff
     D fmt             S              5U 0                                      フォーマット
     D b4Off           S             10U 0                                      候補Offset
     D b12Off          S             10U 0                                      候補Offset
     D cOff            S             10U 0                                      選択サブTblOff
     D cLen            S             10U 0                                      サブTblデータ長
     D tOff            S             10U 0                                      テーブルOff
     D tLen            S             10U 0                                      テーブル長
     D pR              S               *                                        テーブルRecPtr
     D rc              DS                  LIKEDS(TableRecord_t)                走査中テーブル
     D                                     BASED(pR)
     D j               S             10I 0                                      ディレクトリ索引
       // テーブルディレクトリから'cmap'のオフセットと長さを取得
       tOff = 0;
       tLen = 0;
       FOR j = 1 TO font.numTables;
         pR = font.tables + (j-1) * %SIZE(TableRecord_t);
         IF rc.tag = x'636D6170'; // tag='cmap'
           tOff = rc.offset;
           tLen = rc.length;
           LEAVE;
         ENDIF;
       ENDFOR;
       // cmapテーブルがなければ何もしない
       IF tOff = 0;
         RETURN;
       ENDIF;

       // cmapテーブルヘッダを読む（version + numSubtables）
       callp lseek(font.fileDescriptor: tOff: 0);
       readU16BE(font.fileDescriptor);
       nSub=readU16BE(font.fileDescriptor);

       // Unicodeサブテーブルの候補を探す
       // Format 12（全Unicode対応）を優先、なければFormat 4（BMP）を使う
       b4Off = 0;
       b12Off = 0;
       FOR i = 1 TO nSub;
         // 各サブテーブルのplatformID, encodingID, offsetを読む
         pId=readU16BE(font.fileDescriptor);
         eId=readU16BE(font.fileDescriptor);
         sOff=readU32BE(font.fileDescriptor);
         // platformID=3,encodingID=10 または platformID=0,encodingID=4
         // → Format 12（フルUnicode）の候補
         IF (pId=3 AND eId=10) OR (pId=0 AND eId=4);
           b12Off = tOff + sOff;
         // platformID=3,encodingID=1 または platformID=0,encodingID=3
         // → Format 4（BMP）の候補
         ELSEIF (pId=3 AND eId=1) OR (pId=0 AND eId=3);
           IF b4Off = 0;
             b4Off = tOff + sOff;
           ENDIF;
         ENDIF;
       ENDFOR;

       // Format 12優先、なければFormat 4を選択
       IF b12Off > 0;
         cOff = b12Off;
       ELSEIF b4Off > 0;
         cOff = b4Off;
       ELSE;
         // Unicode対応のサブテーブルが見つからない
         RETURN;
       ENDIF;

       // 選択したサブテーブルのフォーマットとデータ長を読む
       callp lseek(font.fileDescriptor: cOff: 0);
       fmt=readU16BE(font.fileDescriptor);
       IF fmt = 12;
         // Format 12: 固定ヘッダの後にlength（4バイト）
         readU16BE(font.fileDescriptor);
         cLen=readU32BE(font.fileDescriptor);
       ELSEIF fmt = 4;
         // Format 4: formatの直後にlength（2バイト）
         cLen=readU16BE(font.fileDescriptor);
       ELSE;
         // 未対応フォーマット
         RETURN;
       ENDIF;

       // サブテーブル全体をメモリにコピー（getGlyphIdForCPで使用）
       font.cmapData = %ALLOC(cLen);
       font.cmapLength = cLen;
       callp lseek(font.fileDescriptor: cOff: 0);
       readN(font.fileDescriptor: font.cmapData: cLen);
     P                 E
