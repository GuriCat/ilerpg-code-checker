      *===============================================================
      * TTFSUBSET - TrueTypeフォントサブセッター
      * Version: 5.1.0  Date: 2026-02-12
      *
      * 使用グリフのみを含むサブセットTTFファイルを生成する。
      * PDF埋め込み用に最適化されたバイナリ出力。
      *
      * 特徴:
      *   - glyf/locaベースのバイナリサブセット
      *   - 大容量CJKフォント対応（ファイルI/O方式）
      *   - 複合グリフ（componentGlyph）の再帰的収集
      *   - チェックサムアキュムレーター方式
      *     （テーブル単位 + ファイル全体の二重計算）
      *   - Acrobat Reader互換のchecksumAdjustment計算
      *
      * 出力テーブル:
      *   head, hhea, maxp, OS/2, name, cmap, post,
      *   loca, glyf, hmtx
      *===============================================================
     H NOMAIN
      /COPY QSYSINC/QRPGLESRC,SYSTYPES
      /COPY QSYSINC/QRPGLESRC,SYSSTAT
      /COPY QSYSINC/QRPGLESRC,FCNTL
      /COPY QSYSINC/QRPGLESRC,UNISTD

      *-------------------------------------------------------------
      * 内部プロシージャ宣言 - バイナリ書き込みユーティリティ
      *-------------------------------------------------------------
     D writeU16BE      PR                                                       BE16bit書込
     D   fd                          10I 0 CONST                                出力先ファイルFD
     D   val                          5U 0 CONST                                BE書込み値
     D writeU32BE      PR                                                       BE32bit書込
     D   fd                          10I 0 CONST                                出力先ファイルFD
     D   val                         10U 0 CONST                                BE書込み値
     D writeN          PR            10I 0                                      Nバイト書込
     D   fd                          10I 0 CONST                                出力先ファイルFD
     D   buffer                        *   VALUE                                書込みバッファptr
     D   length                      10U 0 CONST                                書込みバイト数
      * padTo4 - 4バイト境界までゼロパディング
     D padTo4          PR                                                       4byte境界パッド
     D   fd                          10I 0 CONST                                出力先ファイルFD
     D   length                      10U 0 CONST                                元データ長

      *-------------------------------------------------------------
      * チェックサムアキュムレーター
      * テーブル単位(cs*)とファイル全体(wf*)の二重計算方式。
      * writeN/writeU16BE/writeU32BEが自動的に両方に供給する。
      *-------------------------------------------------------------
      * cs*: テーブル単位のチェックサム（テーブル毎にリセット）
     D csInit          PR                                                       テーブルCS初期化
     D csAddBytes      PR                                                       テーブルCSに加算
     D   dataPtr                       *   CONST                                入力データptr
     D   dataLen                     10U 0 CONST                                入力バイト数
     D csFlush         PR                                                       テーブルCS確定
     D csGet           PR            10U 0                                      テーブルCS取得
      * wf*: ファイル全体のチェックサム（SavePDF完了まで累積）
     D wfInit          PR                                                       全体CS初期化
     D wfAddBytes      PR                                                       全体CSに加算
     D   dataPtr                       *   CONST                                入力データptr
     D   dataLen                     10U 0 CONST                                入力バイト数
     D wfFlush         PR                                                       全体CS確定
     D wfGet           PR            10U 0                                      全体CS取得

      *-------------------------------------------------------------
      * 外部プロシージャ宣言 - TTFPARSERモジュール
      *-------------------------------------------------------------
     D parseTTF        PR              *   EXTPROC(*CL:'parseTTF')              TTF解析
     D   fontPath                   256A   CONST VARYING                        フォントIFSパス
     D   fontIndex                   10I 0 VALUE OPTIONS(*NOPASS)               TTC内フォント番号
     D getTable        PR              *   EXTPROC(*CL:'getTable')              テーブル取得
     D   fontData                      *   CONST                                フォントデータptr
     D   tag                          4A   CONST                                テーブルタグ4B
     D getTableOff     PR            10U 0 EXTPROC(*CL:'getTableOff')           テーブル位置取得
     D   fontData                      *   CONST                                フォントデータptr
     D   tag                          4A   CONST                                テーブルタグ4B
     D getTableLen     PR            10U 0 EXTPROC(*CL:'getTableLen')           テーブル長取得
     D   fontData                      *   CONST                                フォントデータptr
     D   tag                          4A   CONST                                テーブルタグ4B
     D getFontFd       PR            10I 0 EXTPROC(*CL:'getFontFd')             フォントFD取得
     D   fontData                      *   CONST                                フォントデータptr
     D getGlyphCount   PR            10I 0 EXTPROC(*CL:'getGlyphCount')         グリフ数取得
     D   fontData                      *   CONST                                フォントデータptr
     D getGlyphIdForCP...                                                       CP→グリフID
     D                 PR            10I 0 EXTPROC(*CL:'getGlyphIdForCP')
     D   fontData                      *   CONST                                フォントデータptr
     D   codepoint                   10U 0 CONST                                Unicode CP値
     D getUnitsPerEm   PR            10I 0 EXTPROC(*CL:'getUnitsPerEm')         Em単位取得
     D   fontData                      *   CONST                                フォントデータptr

      *-------------------------------------------------------------
      * 公開プロシージャ宣言
      *-------------------------------------------------------------
      * createSubset - サブセットTTFファイルを生成
      *   fontData: 元フォント  glyphIds: 使用グリフID配列
      *   outPath: 出力先IFSパス
      *   戻り値: 出力バイト数（エラー時負数）
     D createSubset    PR            10I 0 EXTPROC(*CL:'createSubset')          サブセット生成
     D   fontData                      *   CONST                                フォントデータptr
     D   glyphIds                      *   CONST                                グリフID配列ptr
     D   numGlyphs                   10I 0 CONST                                グリフ数
     D   outPath                    256A   CONST VARYING                        出力IFSパス

     D readU16Buf      PR             5U 0                                      メモリBE16読取
     D   ptr                           *   CONST                                メモリ読取ptr
     D readU32Buf      PR            10U 0                                      メモリBE32読取
     D   ptr                           *   CONST                                メモリ読取ptr
     D writeU16Buf     PR                                                       メモリBE16書込
     D   ptr                           *   CONST                                書込み先ptr
     D   val                          5U 0 CONST                                BE書込み値

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

     D TableRecord_t   DS                  QUALIFIED TEMPLATE                   テーブルレコード
     D   tag                          4A                                        テーブルタグ4B
     D   checksum                    10U 0                                      チェックサム
     D   offset                      10U 0                                      テーブル位置
     D   length                      10U 0                                      バイト長
     D   data                          *                                        テーブルデータptr

      *-------------------------------------------------------------
      * チェックサムアキュムレーター状態変数
      * csActive/csSum: テーブル単位（各テーブル書き込み前にcsInit）
      * wfActive/wfSum: ファイル全体（createSubset開始時にwfInit）
      * 4バイトバッファで端数を保持し、flushで確定する
      *-------------------------------------------------------------
     D csActive        S              1N   INZ(*OFF)                            TBL CS有効フラグ
     D csSum           S             20U 0                                      TBL CS累積値
     D csBufArr        S              1A   DIM(4)                               TBL CS端数バッファ
     D csPos           S             10I 0 INZ(0)                               TBL CS端数位置
     D wfActive        S              1N   INZ(*OFF)                            全体CS有効フラグ
     D wfSum           S             20U 0                                      全体CS累積値
     D wfBufArr        S              1A   DIM(4)                               全体端数バッファ
     D wfPos           S             10I 0 INZ(0)                               全体CS端数位置

      *===============================================================
      * createSubset - サブセットTTFファイルを生成
      *
      * 処理ステップ:
      *   1. 複合グリフの部品グリフIDを再帰的に収集
      *   2. グリフIDをソートし、GID→新GID変換表を構築
      *   3. TTFヘッダー（テーブルディレクトリ）を書き出し
      *   4. 各テーブルを書き出し（チェックサム計算付き）:
      *      head, hhea, maxp, OS/2, name, cmap, post,
      *      loca（新オフセット表）, glyf（グリフデータコピー）,
      *      hmtx（幅情報コピー）
      *   5. テーブルディレクトリのチェックサムを上書き
      *   6. checksumAdjustment = 0xB1B0AFBA - 全体チェックサム
      *===============================================================
     P createSubset    B                    EXPORT
     D createSubset    PI            10I 0                                      サブセット生成
     D   fontData                      *   CONST                                フォントデータptr
     D   glyphIds                      *   CONST                                グリフID配列ptr
     D   numGlyphs                   10I 0 CONST                                グリフ数
     D   outPath                    256A   CONST VARYING                        出力IFSパス

     D font            DS                  LIKEDS(FontData_t)                   フォント構造体参照
     D                                     BASED(fontData)
     D fd              S             10I 0                                      出力FD
     D oflag           S             10I 0                                      open()フラグ
     D omode           S             10U 0                                      open()許可モード
     D inArr           S             10I 0 DIM(65536)                           入力グリフID配列
     D                                     BASED(glyphIds)

      * Expanded glyph array (base + layer glyphs)
     D allGlyph        S             10I 0 DIM(65536)                           拡張グリフID配列
     D allCount        S             10I 0                                      拡張グリフ数
      * Old-to-new glyph ID mapping
     D gidMap          S             10I 0 DIM(65536)                           旧→新GID変換表

     D locaPtr         S               *                                        locaテーブル先頭
     D headPtr         S               *                                        headテーブル先頭
     D hheaPtr         S               *                                        hheaテーブル先頭
     D maxpPtr         S               *                                        maxpテーブル先頭
     D hmtxPtr         S               *                                        hmtxテーブル先頭
     D os2Ptr          S               *                                        OS/2テーブル先頭
     D namePtr         S               *                                        nameテーブル先頭
     D postPtr         S               *                                        postテーブル先頭

      * COLR/CPAL pointers
     D colrPtr         S               *                                        COLRテーブル先頭
     D cpalPtr         S               *                                        CPALテーブル先頭
     D colrLen         S             10U 0                                      COLRテーブル長
     D cpalLen         S             10U 0                                      CPALテーブル長
     D hasCOLR         S              1N   INZ(*OFF)                            COLR存在フラグ

      * COLR fields
     D numBaseRec      S              5U 0                                      BaseGlyph件数
     D bgRecOff        S             10U 0                                      BaseGlyph配列位置
     D layRecOff       S             10U 0                                      Layer配列位置
     D numLayRec       S              5U 0                                      LayerRecord件数
      * Subset COLR fields
     D subBGCnt        S              5U 0                                      サブセットBG数
     D subBGIdx        S             10I 0 DIM(4096)                            サブセットBG索引
     D subLayFirst     S             10I 0                                      サブセット先頭層
     D subLayLast      S             10I 0                                      サブセット末尾層

     D glyfBaseOff     S             10U 0                                      glyfベース位置
     D fontFd          S             10I 0                                      元フォントFD
     D savedPos        S             10U 0                                      seek保存位置

     D i               S             10I 0                                      ループ変数i
     D j               S             10I 0                                      ループ変数j
     D k               S             10I 0                                      ループ変数k
     D gid             S             10I 0                                      処理中グリフID
     D found           S              1N                                        検索結果フラグ
     D glyfOff         S             10U 0                                      glyfオフセット
     D glyfEnd         S             10U 0                                      glyf終了位置
     D glyfLen         S             10U 0                                      glyfデータ長
     D totalGlyf       S             10U 0                                      glyf合計サイズ
     D locaFmt         S             10I 0                                      loca形式(0/1)
     D newHmtxLen      S             10U 0                                      hmtx出力バイト数
     D numTbls         S             10I 0                                      出力テーブル数
     D tblDirOff       S             10U 0                                      テーブル目録位置
     D dataOff         S             10U 0                                      データ開始位置
     D curOff          S             10U 0                                      現在書込み位置
     D tblTag          S              4A   DIM(11)                              テーブルタグ配列
     D tblOff          S             10U 0 DIM(11)                              テーブル位置配列
     D tblLen          S             10U 0 DIM(11)                              テーブル長配列
     D tblCksum        S             10U 0 DIM(11)                              テーブルCS配列
     D t               S             10I 0                                      テーブルループ用
     D searchR         S             10I 0                                      検索範囲
     D entryS          S             10I 0                                      エントリ選択子
     D rangeS          S             10I 0                                      範囲シフト
     D pw              S             10I 0                                      2のべき乗計算用
     D locOff          S             10U 0                                      loca累積位置
     D advW            S              5U 0                                      前進幅
     D glBuf           S               *                                        グリフバッファ
     D rdLen           S             10I 0                                      read()戻り値

      * COLR write temps
     D bgGid           S              5U 0                                      COLR基底GID
     D bgFirst         S              5U 0                                      COLR先頭レイヤ
     D bgNum           S              5U 0                                      COLRレイヤ数
     D lrGid           S              5U 0                                      COLRレイヤGID
     D lrPal           S              5U 0                                      COLRパレット索引
     D newGid          S              5U 0                                      再配置後のGID
     D layIdx          S             10I 0                                      レイヤ索引
     D newLayFirst     S             10I 0                                      新先頭レイヤ索引
     D newLayCnt       S             10I 0                                      新レイヤ数
     D colrSize        S             10U 0                                      COLR出力サイズ

      * Composite glyph handling
     D cFlags          S              5U 0                                      複合グリフフラグ
     D cGid            S              5U 0                                      部品グリフID
     D cPtr            S             10I 0                                      複合解析位置
     D glArr           S              1A   DIM(65536)                           グリフバイト配列
     D                                     BASED(glBuf)
      * OS/2 fsType patch
     D os2Zero         S              1A   DIM(2)                               fsType=0用ゼロ値
     D                                     INZ(x'00')
      * Checksum step 5 vars
     D wholeSum        S             20U 0                                      全体CS合計値
     D headCkAdj       S             10U 0                                      head CS調整値
     D dirCksum        S             10U 0                                      ディレクトリCS
       // 出力ファイルをO_CREAT|O_WRONLY|O_TRUNCで開く
       oflag = 74;
       omode = 420;
       fd = open(%TRIMR(outPath): oflag: omode);
       IF fd < 0;
         RETURN -1;
       ENDIF;

       // 必要なテーブルをメモリにロード
       locaPtr = getTable(fontData: x'6C6F6361'); // 'loca'位置索引
       headPtr = getTable(fontData: x'68656164'); // 'head'ヘッダ
       hheaPtr = getTable(fontData: x'68686561'); // 'hhea'水平ヘッダ
       maxpPtr = getTable(fontData: x'6D617870'); // 'maxp'最大値
       hmtxPtr = getTable(fontData: x'686D7478'); // 'hmtx'水平幅
       os2Ptr  = getTable(fontData: x'4F532F32'); // 'OS/2'メトリクス
       namePtr = getTable(fontData: x'6E616D65'); // 'name'命名表
       postPtr = getTable(fontData: x'706F7374'); // 'post'PS名

       // COLR/CPALテーブル（色絵文字レイヤー情報）
       colrPtr = getTable(fontData: x'434F4C52'); // 'COLR'色レイヤー
       cpalPtr = getTable(fontData: x'4350414C'); // 'CPAL'色パレット
       IF colrPtr <> *NULL AND cpalPtr <> *NULL;
         hasCOLR = *ON;
         colrLen = getTableLen(fontData: x'434F4C52'); // 'COLR'
         cpalLen = getTableLen(fontData: x'4350414C'); // 'CPAL'
       ENDIF;

       // glyfテーブルのファイル内オフセットとFDを取得
       glyfBaseOff = getTableOff(fontData: x'676C7966'); // 'glyf'
       fontFd = getFontFd(fontData);

       // 必須テーブルが無ければエラー終了
       IF locaPtr = *NULL OR headPtr = *NULL OR glyfBaseOff = 0;
         callp close(fd);
         RETURN -2;
       ENDIF;

       // locaテーブルの形式（0=short/1=long）
       locaFmt = font.indexToLocFmt;

       // ========================================
       // ステップ1: ベースグリフIDをコピー
       // GID 0(.notdef)は常に先頭に含む。
       // .notdefはPDF仕様で必須の「未定義」グリフ。
       // 呼び出し元がGID 0を含めている前提。
       // 入力配列を拡張用配列allGlyphに複写。
       // ========================================
       allCount = numGlyphs;
       FOR i = 1 TO numGlyphs;
         allGlyph(i) = inArr(i);
       ENDFOR;

       // ========================================
       // ステップ2: COLRレイヤーグリフを収集
       // 色絵文字はCOLRテーブルで複数レイヤーに
       // 分解される。各レイヤーのグリフIDはcmapに
       // 直接参照されないが、glyfにデータが必要。
       // PDFコンテントストリームで個別に描画する為、
       // サブセットにレイヤーグリフも含める。
       // ========================================
       subBGCnt = 0;
       subLayFirst = 999999;
       subLayLast = 0;

       IF hasCOLR;
         // COLRヘッダーからBaseGlyph/Layer配列情報を取得
         numBaseRec = readU16Buf(colrPtr + 2);
         bgRecOff = readU32Buf(colrPtr + 4);
         layRecOff = readU32Buf(colrPtr + 8);
         numLayRec = readU16Buf(colrPtr + 12);

         // 各BaseGlyphRecordを走査し、使用中のベースグリフを検索
         FOR i = 0 TO numBaseRec - 1;
           bgGid = readU16Buf(colrPtr + bgRecOff + i * 6);
           bgFirst = readU16Buf(colrPtr + bgRecOff + i * 6 + 2);
           bgNum = readU16Buf(colrPtr + bgRecOff + i * 6 + 4);

           // 入力グリフ配列にベースGIDが含まれるか確認
           found = *OFF;
           FOR j = 1 TO numGlyphs;
             IF inArr(j) = bgGid;
               found = *ON;
               LEAVE;
             ENDIF;
           ENDFOR;

           IF found;
             // サブセット用COLRベースグリフとして記録
             subBGCnt = subBGCnt + 1;
             subBGIdx(subBGCnt) = i;
             IF bgFirst < subLayFirst;
               subLayFirst = bgFirst;
             ENDIF;
             IF bgFirst + bgNum - 1 > subLayLast;
               subLayLast = bgFirst + bgNum - 1;
             ENDIF;

             // このベースグリフのレイヤーグリフIDを収集
             // 重複チェックしながらallGlyphに追加
             FOR j = 0 TO bgNum - 1;
               lrGid = readU16Buf(colrPtr + layRecOff + (bgFirst + j) * 4);
               found = *OFF;
               FOR k = 1 TO allCount;
                 IF allGlyph(k) = lrGid;
                   found = *ON;
                   LEAVE;
                 ENDIF;
               ENDFOR;
               IF NOT found;
                 allCount = allCount + 1;
                 allGlyph(allCount) = lrGid;
               ENDIF;
             ENDFOR;
           ENDIF;
         ENDFOR;
       ENDIF;

       // ========================================
       // ステップ2b: 複合グリフの部品を再帰収集
       // glyfテーブルの複合グリフ(numContours=-1)は
       // 他のグリフを部品として参照する。
       // 部品グリフもサブセットに含めないと
       // レンダラーが描画できない。
       // allCountが増加するとDOWループが延長され
       // 間接参照の部品も再帰的に収集される。
       // ========================================
       i = 1;
       DOW i <= allCount;
         gid = allGlyph(i);
         // locaテーブルからグリフデータの開始/終了オフセット取得
         IF locaFmt = 0;
           glyfOff = readU16Buf(locaPtr + gid * 2) * 2;
           glyfEnd = readU16Buf(locaPtr+(gid+1)*2) * 2;
         ELSE;
           glyfOff = readU32Buf(locaPtr + gid * 4);
           glyfEnd = readU32Buf(locaPtr+(gid+1)*4);
         ENDIF;
         glyfLen = glyfEnd - glyfOff;
         IF glyfLen > 0;
           // グリフデータをメモリに読み込み
           glBuf = %ALLOC(glyfLen);
           savedPos = lseek(fontFd:0:1);
           callp lseek(fontFd: glyfBaseOff + glyfOff: 0);
           rdLen = read(fontFd: glBuf: glyfLen);
           callp lseek(fontFd: savedPos: 0);
           // numberOfContours=0xFFFF → 複合グリフ
           IF readU16Buf(glBuf) = 65535;
             // 複合グリフの各部品を走査
             cPtr = 11;
             DOW cPtr < glyfLen - 3;
               cFlags = readU16Buf(glBuf + cPtr - 1);
               cGid = readU16Buf(glBuf + cPtr + 1);
               // 部品グリフIDが未登録なら追加
               found = *OFF;
               FOR k = 1 TO allCount;
                 IF allGlyph(k) = cGid;
                   found = *ON;
                   LEAVE;
                 ENDIF;
               ENDFOR;
               IF NOT found;
                 allCount = allCount + 1;
                 allGlyph(allCount) = cGid;
               ENDIF;
               cPtr = cPtr + 4;
               // ARG_1_AND_2_ARE_WORDS: 引数が16bit
               IF %BITAND(cFlags:1) <> 0;
                 cPtr = cPtr + 4;
               ELSE;
                 cPtr = cPtr + 2;
               ENDIF;
               // 変換行列フラグに応じてスキップ
               IF %BITAND(cFlags:8) <> 0;
                 cPtr = cPtr + 2;
               ELSEIF %BITAND(cFlags:64)<>0;
                 cPtr = cPtr + 4;
               ELSEIF %BITAND(cFlags:128) <> 0;
                 cPtr = cPtr + 8;
               ENDIF;
               // MORE_COMPONENTS=0なら終了
               IF %BITAND(cFlags:32) = 0;
                 LEAVE;
               ENDIF;
             ENDDO;
           ENDIF;
           DEALLOC glBuf;
         ENDIF;
         i = i + 1;
       ENDDO;

       // ========================================
       // ステップ3: 旧GID→新GID変換マップ構築
       // 元フォントのGIDは疎(例: 0,15,200,8000)。
       // サブセットでは連番0..Nに再マッピングする。
       // この変換表は複合グリフの部品参照を
       // 新GIDに書き換える際に使用する。
       // ========================================
       FOR i = 1 TO 65536;
         gidMap(i) = 0;
       ENDFOR;
       FOR i = 1 TO allCount;
         gid = allGlyph(i);
         IF gid >= 0 AND gid < 65536;
           gidMap(gid + 1) = i - 1;
         ENDIF;
       ENDFOR;

       // ========================================
       // ステップ4: サブセットTTFファイル書き出し
       // 出力テーブル構成:
       //   head: フォント全体のメトリクス・CS調整欄
       //   hhea: 水平ヘッダ(numHMetrics→hmtx構造)
       //   maxp: 最大プロファイル(numGlyphs必須)
       //   hmtx: 水平メトリクス(幅+LSB/グリフ)
       //   loca: グリフ位置表(glyfへのオフセット)
       //   glyf: グリフ輪郭(TT二次ベジェ曲線)
       //   name: 命名表(最小:レコード0件)
       //   post: PostScript名(3.0=名前なし)
       //   OS/2: OS/2メトリクス(そのままコピー)
       // COLR/CPALはサブセットに含めない
       // （レイヤーはPDFコンテントストリームで描画）
       // ========================================
       numTbls = 9;

       // --- TTFヘッダー（sfVersion + テーブル数 + 検索パラメータ）---
       // ファイル全体チェックサム計算開始
       csActive = *OFF;
       wfInit();
       wfActive = *ON;
       // sfVersion=0x00010000 (TrueType)
       writeU32BE(fd: 65536);
       writeU16BE(fd: numTbls);
       // searchRange/entrySelector/rangeShift計算
       pw = 1;
       entryS = 0;
       DOW pw * 2 <= numTbls;
         pw = pw * 2;
         entryS = entryS + 1;
       ENDDO;
       searchR = pw * 16;
       rangeS = numTbls * 16 - searchR;
       writeU16BE(fd: searchR);
       writeU16BE(fd: entryS);
       writeU16BE(fd: rangeS);

       // テーブルディレクトリ仮書き（後でチェックサム上書き）
       tblDirOff = 12;
       FOR t = 1 TO numTbls;
         writeU32BE(fd: 0);
         writeU32BE(fd: 0);
         writeU32BE(fd: 0);
         writeU32BE(fd: 0);
       ENDFOR;

       // テーブルデータの書き出し開始位置
       dataOff = 12 + numTbls * 16;
       curOff = dataOff;

       // --- head: フォント全体のメトリクスとCS調整欄 ---
       // indexToLocFormat=1(long loca)に強制変更
       tblTag(1) = x'68656164'; // 'head'
       tblOff(1) = curOff;
       csInit();
       csActive = *ON;
       writeN(fd: headPtr: 50);
       // indexToLocFormatをlong(1)に変更（サブセットは常にlong loca）
       writeU16BE(fd: 1);
       writeN(fd: headPtr + 52: 2);
       csFlush();
       csActive = *OFF;
       tblCksum(1) = csGet();
       tblLen(1) = 54;
       curOff = curOff + 54;
       padTo4(fd: 54);
       curOff = curOff + %REM(4 - %REM(54:4): 4);

       // --- hhea: 水平ヘッダ ---
       // numHMetricsがhmtxの構造を決定する
       // サブセットのグリフ数に合わせて変更
       tblTag(2) = x'68686561'; // 'hhea'
       tblOff(2) = curOff;
       csInit();
       csActive = *ON;
       writeN(fd: hheaPtr: 34);
       writeU16BE(fd: allCount);
       csFlush();
       csActive = *OFF;
       tblCksum(2) = csGet();
       tblLen(2) = 36;
       curOff = curOff + 36;

       // --- maxp: 最大プロファイル ---
       // numGlyphsはフォント内のグリフ総数
       // サブセットの実グリフ数に合わせる
       tblTag(3) = x'6D617870'; // 'maxp'
       tblOff(3) = curOff;
       csInit();
       csActive = *ON;
       writeN(fd: maxpPtr: 4);
       writeU16BE(fd: allCount);
       writeN(fd: maxpPtr + 6: 26);
       csFlush();
       csActive = *OFF;
       tblCksum(3) = csGet();
       tblLen(3) = 32;
       curOff = curOff + 32;

       // --- hmtx: 水平メトリクス(前進幅+左SB) ---
       // 各グリフの前進幅とleftSideBearingを格納
       // PDF CIDFontのDW/W値の元データとなる
       tblTag(4) = x'686D7478'; // 'hmtx'
       tblOff(4) = curOff;
       newHmtxLen = allCount * 4;
       csInit();
       csActive = *ON;
       FOR i = 1 TO allCount;
         gid = allGlyph(i);
         IF gid < font.numHMetrics;
           // longHorMetricレコードをそのままコピー
           writeN(fd: hmtxPtr+gid*4: 4);
         ELSE;
           // numHMetrics以降: 最後のadvWを使い、LSBのみ個別
           advW = readU16Buf(hmtxPtr + (font.numHMetrics-1)*4);
           writeU16BE(fd: advW);
           writeU16BE(fd: readU16Buf(
             hmtxPtr + font.numHMetrics * 4
             + (gid-font.numHMetrics) * 2));
         ENDIF;
       ENDFOR;
       csFlush();
       csActive = *OFF;
       tblCksum(4) = csGet();
       tblLen(4) = newHmtxLen;
       curOff = curOff + newHmtxLen;
       padTo4(fd: newHmtxLen);
       curOff = curOff + %REM(4-%REM(newHmtxLen:4):4);

       // --- loca: グリフ位置表(long形式) ---
       // glyfテーブル内の各グリフのオフセット
       // indexToLocFormat=1なので4byte/エントリ
       // まずglyfの総サイズを事前計算し、
       // 次に各グリフの新オフセットを書き出す
       tblTag(5) = x'6C6F6361'; // 'loca'
       tblOff(5) = curOff;
       totalGlyf = 0;

       // glyfテーブル総サイズを事前計算（4バイト境界パディング込み）
       FOR i = 1 TO allCount;
         gid = allGlyph(i);
         IF locaFmt = 0;
           glyfOff = readU16Buf(locaPtr + gid * 2) * 2;
           glyfEnd = readU16Buf(locaPtr+(gid+1)*2) * 2;
         ELSE;
           glyfOff = readU32Buf(locaPtr + gid * 4);
           glyfEnd = readU32Buf(locaPtr+(gid+1)*4);
         ENDIF;
         glyfLen = glyfEnd - glyfOff;
         totalGlyf = totalGlyf + glyfLen;
         IF %REM(glyfLen: 4) <> 0;
           totalGlyf = totalGlyf + 4 - %REM(glyfLen: 4);
         ENDIF;
       ENDFOR;

       // 各グリフの新glyfオフセットを書き出し
       csInit();
       csActive = *ON;
       locOff = 0;
       FOR i = 1 TO allCount;
         writeU32BE(fd: locOff);
         gid = allGlyph(i);
         IF locaFmt = 0;
           glyfOff = readU16Buf(locaPtr+gid*2) * 2;
           glyfEnd = readU16Buf(locaPtr+(gid+1)*2) * 2;
         ELSE;
           glyfOff = readU32Buf(locaPtr+gid*4);
           glyfEnd = readU32Buf(locaPtr+(gid+1)*4);
         ENDIF;
         glyfLen = glyfEnd - glyfOff;
         locOff = locOff + glyfLen;
         IF %REM(glyfLen:4) <> 0;
           locOff=locOff+4-%REM(glyfLen:4);
         ENDIF;
       ENDFOR;
       // 最終エントリ（glyfテーブル末尾オフセット）
       writeU32BE(fd: locOff);
       csFlush();
       csActive = *OFF;
       tblCksum(5) = csGet();
       tblLen(5) = (allCount + 1) * 4;
       curOff = curOff + tblLen(5);

       // --- glyf: グリフ輪郭データ ---
       // TrueType二次ベジェ曲線によるアウトライン
       // 元フォントから各グリフのバイナリデータを読み出し、
       // 複合グリフの部品GIDは新GIDにリマップして書き出す
       tblTag(6) = x'676C7966'; // 'glyf'
       tblOff(6) = curOff;
       totalGlyf = 0;
       csInit();
       csActive = *ON;
       FOR i = 1 TO allCount;
         gid = allGlyph(i);
         IF locaFmt = 0;
           glyfOff = readU16Buf(locaPtr+gid*2) * 2;
           glyfEnd = readU16Buf(locaPtr+(gid+1)*2) * 2;
         ELSE;
           glyfOff = readU32Buf(locaPtr+gid*4);
           glyfEnd = readU32Buf(locaPtr+(gid+1)*4);
         ENDIF;
         glyfLen = glyfEnd - glyfOff;
         IF glyfLen > 0;
           // 元フォントFDからグリフデータを読み込み
           glBuf = %ALLOC(glyfLen);
           savedPos = lseek(fontFd:0:1);
           callp lseek(fontFd: glyfBaseOff + glyfOff: 0);
           rdLen = read(fontFd: glBuf: glyfLen);
           callp lseek(fontFd: savedPos: 0);
           // 複合グリフの部品GIDを新GIDにリマップ
           IF readU16Buf(glBuf) = 65535;
             cPtr = 11;
             DOW cPtr < glyfLen - 3;
               cFlags = readU16Buf(glBuf + cPtr - 1);
               cGid = readU16Buf(glBuf + cPtr + 1);
               // 旧GID→新GIDに書き換え
               IF cGid < 65536;
                 newGid = gidMap(cGid + 1);
                 writeU16Buf(glBuf + cPtr + 1: newGid);
               ENDIF;
               cPtr = cPtr + 4;
               IF %BITAND(cFlags:1)<>0;
                 cPtr = cPtr + 4;
               ELSE;
                 cPtr = cPtr + 2;
               ENDIF;
               IF %BITAND(cFlags:8)<>0;
                 cPtr = cPtr + 2;
               ELSEIF %BITAND(cFlags:64) <> 0;
                 cPtr = cPtr + 4;
               ELSEIF %BITAND(cFlags:128) <> 0;
                 cPtr = cPtr + 8;
               ENDIF;
               IF %BITAND(cFlags:32)=0;
                 LEAVE;
               ENDIF;
             ENDDO;
           ENDIF;
           // リマップ済みグリフデータを書き出し
           writeN(fd: glBuf: glyfLen);
           DEALLOC glBuf;
           padTo4(fd: glyfLen);
           totalGlyf=totalGlyf+glyfLen;
           IF %REM(glyfLen:4) <> 0;
             totalGlyf = totalGlyf + 4 - %REM(glyfLen:4);
           ENDIF;
         ENDIF;
       ENDFOR;
       csFlush();
       csActive = *OFF;
       tblCksum(6) = csGet();
       tblLen(6) = totalGlyf;
       curOff = curOff + totalGlyf;

       // --- name: 命名表(最小: レコード0件) ---
       // PDF埋め込み用なのでフォント名は不要
       tblTag(7) = x'6E616D65'; // 'name'
       tblOff(7) = curOff;
       tblLen(7) = 6;
       csInit();
       csActive = *ON;
       writeU16BE(fd: 0);
       writeU16BE(fd: 0);
       writeU16BE(fd: 6);
       csFlush();
       csActive = *OFF;
       tblCksum(7) = csGet();
       curOff = curOff + tblLen(7);
       padTo4(fd: tblLen(7));
       curOff = curOff + %REM(4-%REM(tblLen(7):4):4);

       // --- post: PostScript名(Format 3.0) ---
       // Format 3.0=グリフ名テーブルなし
       // CIDFontでは個別グリフ名は不要
       tblTag(8) = x'706F7374'; // 'post'
       tblOff(8) = curOff;
       csInit();
       csActive = *ON;
       // format=3.0(0x00030000)、残りはゼロ
       writeU32BE(fd: 196608);
       writeU32BE(fd: 0);
       writeU16BE(fd: 0);
       writeU16BE(fd: 0);
       writeU32BE(fd: 0);
       writeU32BE(fd: 0);
       writeU32BE(fd: 0);
       writeU32BE(fd: 0);
       writeU32BE(fd: 0);
       csFlush();
       csActive = *OFF;
       tblCksum(8) = csGet();
       tblLen(8) = 32;
       curOff = curOff + 32;

       // --- OS/2: OS/2メトリクス ---
       // fsType=0に変更し埋め込み制限を解除
       // 他のフィールドは元フォントからコピー
       tblTag(9) = x'4F532F32'; // 'OS/2'
       tblOff(9) = curOff;
       IF os2Ptr <> *NULL;
         tblLen(9) = 96;
         csInit();
         csActive = *ON;
         writeN(fd: os2Ptr: 8);
         // fsType=0: 埋め込み制限なし
         writeN(fd: %ADDR(os2Zero): 2);
         writeN(fd: os2Ptr + 10: 86);
         csFlush();
         csActive = *OFF;
         tblCksum(9) = csGet();
       ELSE;
         tblLen(9) = 0;
         tblCksum(9) = 0;
       ENDIF;
       curOff = curOff + tblLen(9);

       // --- COLR (disabled) ---
       IF *OFF;
         padTo4(fd: curOff);
         curOff = curOff + %REM(4-%REM(curOff:4):4);

         tblTag(10) = x'434F4C52'; // 'COLR'
         tblOff(10) = curOff;

         newLayCnt = subLayLast - subLayFirst + 1;
         writeU16BE(fd: 0);
         writeU16BE(fd: subBGCnt);
         writeU32BE(fd: 14);
         writeU32BE(fd: 14 + subBGCnt * 6);
         writeU16BE(fd: newLayCnt);

         FOR i = 1 TO subBGCnt;
           j = subBGIdx(i);
           bgGid = readU16Buf(colrPtr + bgRecOff + j * 6);
           bgFirst = readU16Buf(colrPtr + bgRecOff + j * 6 + 2);
           bgNum = readU16Buf(colrPtr + bgRecOff + j * 6 + 4);
           newGid = gidMap(bgGid + 1);
           writeU16BE(fd: newGid);
           writeU16BE(fd: bgFirst - subLayFirst);
           writeU16BE(fd: bgNum);
         ENDFOR;

         FOR i = subLayFirst TO subLayLast;
           lrGid = readU16Buf(colrPtr + layRecOff + i * 4);
           lrPal = readU16Buf(colrPtr + layRecOff + i * 4 + 2);
           newGid = gidMap(lrGid + 1);
           writeU16BE(fd: newGid);
           writeU16BE(fd: lrPal);
         ENDFOR;

         colrSize = 14 + subBGCnt * 6 + newLayCnt * 4;
         tblLen(10) = colrSize;
         curOff = curOff + colrSize;

         padTo4(fd: curOff);
         curOff = curOff + %REM(4-%REM(curOff:4):4);

         tblTag(11) = x'4350414C'; // 'CPAL'
         tblOff(11) = curOff;
         tblLen(11) = cpalLen;
         writeN(fd: cpalPtr: cpalLen);
         curOff = curOff + cpalLen;
       ENDIF;

       // ========================================
       // ステップ5: チェックサム計算と書き込み
       // TrueTypeチェックサムアルゴリズム:
       //   各テーブルのCSはBE 4byteワードの総和。
       //   headのchecksumAdj=0として全体CSを算出し、
       //   checksumAdj = 0xB1B0AFBA - 全体CS
       //   とすることでファイル全体のCSが固定値になる。
       // テーブルディレクトリを正式値で上書きし、
       // 最後にhead.checksumAdjを修正する。
       // ========================================
       // ファイル全体チェックサムの端数を確定
       wfFlush();
       wfActive = *OFF;

       // headチェックサムから元のchecksumAdjustmentを除外
       // （仕様上checksumAdj=0として計算するため）
       tblCksum(1) = %REM(tblCksum(1) + 4294967296
         - readU32Buf(headPtr + 8): 4294967296);

       // テーブルディレクトリを正式な値で上書き
       // （tag, checksum, offset, lengthの16バイト×テーブル数）
       csInit();
       csActive = *ON;
       callp lseek(fd: tblDirOff: 0);
       FOR t = 1 TO numTbls;
         writeN(fd: %ADDR(tblTag(t)): 4);
         writeU32BE(fd: tblCksum(t));
         writeU32BE(fd: tblOff(t));
         writeU32BE(fd: tblLen(t));
       ENDFOR;
       csFlush();
       csActive = *OFF;
       dirCksum = csGet();

       // ファイル全体チェックサム =
       //   wfGet（ヘッダ+ゼロディレクトリ+テーブルデータ）
       //   - 元checksumAdj + 正式ディレクトリチェックサム
       wholeSum = %REM(wfGet() + 4294967296
         - readU32Buf(headPtr + 8) + dirCksum: 4294967296);

       // checksumAdjustment = 0xB1B0AFBA - 全体チェックサム
       headCkAdj = %REM(2981146554 + 4294967296 - wholeSum: 4294967296);

       // head.checksumAdjustment (offset 8) を上書き
       callp lseek(fd: tblOff(1) + 8: 0);
       csActive = *OFF;
       writeU32BE(fd: headCkAdj);

       callp close(fd);

       RETURN 0;
     P                 E

      *-------------------------------------------------------------
      * 以下: バイナリ書き込みユーティリティ
      * 全てcs/wfアキュムレーターに自動供給する
      *-------------------------------------------------------------
      * writeU16BE - 2バイトBE符号なし整数を書き込み
      * TrueType仕様はBEバイト順。RPGにはBE変換が
      * ないため、除算でバイト分解してBE配置する。
     P writeU16BE      B
     D writeU16BE      PI                                                       BE16bit書込
     D   fd                          10I 0 CONST                                出力先ファイルFD
     D   val                          5U 0 CONST                                BE書込み値
     D buf             S              2A                                        BE 2byte出力用
     D byteDS          DS                                                       バイト変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
     D pB              S               *                                        バッファポインタ
     D bA              S              1A   DIM(2) BASED(pB)                     バイト配列ビュー
       pB = %ADDR(buf);
       // 上位バイト = val / 256
       byteVal = %DIV(val:256);
       bA(1) = byteChar;
       // 下位バイト = val mod 256
       byteVal = %REM(val:256);
       bA(2) = byteChar;
       writeN(fd: %ADDR(buf): 2);
     P                 E

      * writeU32BE - 4バイトBE符号なし整数を書き込み
     P writeU32BE      B
     D writeU32BE      PI                                                       BE32bit書込
     D   fd                          10I 0 CONST                                出力先ファイルFD
     D   val                         10U 0 CONST                                BE書込み値
     D buf             S              4A                                        BE 4byte出力用
     D byteDS          DS                                                       バイト変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
     D pB              S               *                                        バッファポインタ
     D bA              S              1A   DIM(4) BASED(pB)                     バイト配列ビュー
       pB = %ADDR(buf);
       // 4バイトを上位から順にBE配置
       byteVal = %DIV(val:16777216);
       bA(1) = byteChar;
       byteVal=%REM(%DIV(val:65536):256);
       bA(2) = byteChar;
       byteVal=%REM(%DIV(val:256):256);
       bA(3) = byteChar;
       byteVal = %REM(val:256);
       bA(4) = byteChar;
       writeN(fd: %ADDR(buf): 4);
     P                 E

      * writeN - Nバイト書き込み(二重CS自動供給)
      * csActive時: TBL CSアキュムレーターに供給
      * wfActive時: 全体CSアキュムレーターに供給
      * 両フラグが同時ONなら両方に供給する。
     P writeN          B
     D writeN          PI            10I 0                                      Nバイト書込
     D   fd                          10I 0 CONST                                出力先ファイルFD
     D   buffer                        *   VALUE                                書込みバッファptr
     D   length                      10U 0 CONST                                書込みバイト数
     D rc              S             10I 0                                      write()戻り値
       // テーブル単位チェックサムに供給
       IF csActive;
         csAddBytes(buffer: length);
       ENDIF;
       // ファイル全体チェックサムに供給
       IF wfActive;
         wfAddBytes(buffer: length);
       ENDIF;
       // FDに実際に書き込み
       rc = write(fd: buffer: length);
       RETURN rc;
     P                 E

      * padTo4 - 4バイト境界までゼロパディング
      * TTF仕様上、各テーブルは4バイト境界に揃える必要がある
     P padTo4          B
     D padTo4          PI                                                       4byte境界パッド
     D   fd                          10I 0 CONST                                出力先ファイルFD
     D   length                      10U 0 CONST                                元データ長
     D rem             S             10U 0                                      端数バイト数
     D pad             S              4A   INZ(x'00000000')                     ゼロパディング用
       rem = %REM(length: 4);
       IF rem > 0;
         // 不足バイト数分のゼロを書き出し
         writeN(fd: %ADDR(pad): 4-rem);
       ENDIF;
     P                 E

      * readU16Buf - メモリ上のBE 2バイト値を読み取り
      * OVERLAY技法でバイト→数値変換（RPGのポインタ演算制約回避）
     P readU16Buf      B
     D readU16Buf      PI             5U 0                                      メモリBE16読取
     D   ptr                           *   CONST                                メモリ読取ptr
     D bA              S              1A   DIM(2) BASED(ptr)                    BE 2byte配列
     D byteDS          DS                                                       バイト変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
     D b1              S              3U 0                                      上位バイト値
     D b2              S              3U 0                                      下位バイト値
       byteVal = 0;
       byteChar = bA(1);
       b1 = byteVal;
       byteVal = 0;
       byteChar = bA(2);
       b2 = byteVal;
       RETURN b1 * 256 + b2;
     P                 E

      *-------------------------------------------------------------
      * csInit - テーブルチェックサムアキュムレーター初期化
      *-------------------------------------------------------------
     P csInit          B
     D csInit          PI                                                       テーブルCS初期化
       csSum = 0;
       csPos = 0;
       csBufArr(1) = x'00';
       csBufArr(2) = x'00';
       csBufArr(3) = x'00';
       csBufArr(4) = x'00';
     P                 E

      * csAddBytes - バイト列をテーブルCSに供給
      * 4byteバッファ(csBufArr)にバイトを蓄積し、
      * 4byte揃った時点でBE 32bit値として加算。
      * 端数はcsFlush()でゼロ埋めして確定する。
     P csAddBytes      B
     D csAddBytes      PI                                                       テーブルCSに加算
     D   dataPtr                       *   CONST                                入力データptr
     D   dataLen                     10U 0 CONST                                入力バイト数
     D srcArr          S              1A   DIM(65535)                           入力バイト配列
     D                                     BASED(dataPtr)
     D byteDS          DS                                                       バイト変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
     D v1              S             10U 0                                      第1バイト値
     D v2              S             10U 0                                      第2バイト値
     D v3              S             10U 0                                      第3バイト値
     D v4              S             10U 0                                      第4バイト値
     D ww              S             10U 0                                      4byte合成値
     D idx             S             10U 0                                      バイト走査位置
       // 1バイトずつバッファに蓄積し4byte毎に加算
       FOR idx = 1 TO dataLen;
         csPos = csPos + 1;
         csBufArr(csPos) = srcArr(idx);
         IF csPos >= 4;
           byteVal = 0;
           byteChar = csBufArr(1);
           v1 = byteVal;
           byteVal = 0;
           byteChar = csBufArr(2);
           v2 = byteVal;
           byteVal = 0;
           byteChar = csBufArr(3);
           v3 = byteVal;
           byteVal = 0;
           byteChar = csBufArr(4);
           v4 = byteVal;
           ww = v1*16777216 + v2*65536 + v3*256 + v4;
           csSum = csSum + ww;
           csPos = 0;
         ENDIF;
       ENDFOR;
     P                 E

      * csFlush - 端数バイトをゼロパディングして確定
     P csFlush         B
     D csFlush         PI                                                       テーブルCS確定
     D byteDS          DS                                                       バイト変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
     D v1              S             10U 0                                      第1バイト値
     D v2              S             10U 0                                      第2バイト値
     D v3              S             10U 0                                      第3バイト値
     D v4              S             10U 0                                      第4バイト値
     D ww              S             10U 0                                      4byte合成値
       IF csPos > 0;
         // Pad remaining with zeros
         DOW csPos < 4;
           csPos = csPos + 1;
           csBufArr(csPos) = x'00';
         ENDDO;
         byteVal = 0;
         byteChar = csBufArr(1);
         v1 = byteVal;
         byteVal = 0;
         byteChar = csBufArr(2);
         v2 = byteVal;
         byteVal = 0;
         byteChar = csBufArr(3);
         v3 = byteVal;
         byteVal = 0;
         byteChar = csBufArr(4);
         v4 = byteVal;
         ww = v1*16777216 + v2*65536 + v3*256 + v4;
         csSum = csSum + ww;
         csPos = 0;
       ENDIF;
     P                 E

      * csGet - 32ビットチェックサム値を返す
     P csGet           B
     D csGet           PI            10U 0                                      テーブルCS取得
       RETURN %REM(csSum: 4294967296);
     P                 E

      *-------------------------------------------------------------
      * wfInit - ファイル全体チェックサムアキュムレーター初期化
      *-------------------------------------------------------------
     P wfInit          B
     D wfInit          PI                                                       全体CS初期化
       wfSum = 0;
       wfPos = 0;
       wfBufArr(1) = x'00';
       wfBufArr(2) = x'00';
       wfBufArr(3) = x'00';
       wfBufArr(4) = x'00';
     P                 E

      * wfAddBytes - バイト列をファイル全体アキュムレーターに供給
     P wfAddBytes      B
     D wfAddBytes      PI                                                       全体CSに加算
     D   dataPtr                       *   CONST                                入力データptr
     D   dataLen                     10U 0 CONST                                入力バイト数
     D srcArr          S              1A   DIM(65535)                           入力バイト配列
     D                                     BASED(dataPtr)
     D byteDS          DS                                                       バイト変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
     D v1              S             10U 0                                      第1バイト値
     D v2              S             10U 0                                      第2バイト値
     D v3              S             10U 0                                      第3バイト値
     D v4              S             10U 0                                      第4バイト値
     D ww              S             10U 0                                      4byte合成値
     D idx             S             10U 0                                      バイト走査位置
       FOR idx = 1 TO dataLen;
         wfPos = wfPos + 1;
         wfBufArr(wfPos) = srcArr(idx);
         IF wfPos >= 4;
           byteVal = 0;
           byteChar = wfBufArr(1);
           v1 = byteVal;
           byteVal = 0;
           byteChar = wfBufArr(2);
           v2 = byteVal;
           byteVal = 0;
           byteChar = wfBufArr(3);
           v3 = byteVal;
           byteVal = 0;
           byteChar = wfBufArr(4);
           v4 = byteVal;
           ww = v1*16777216 + v2*65536 + v3*256 + v4;
           wfSum = wfSum + ww;
           wfPos = 0;
         ENDIF;
       ENDFOR;
     P                 E

      * wfFlush - 端数バイトをゼロパディングして確定
     P wfFlush         B
     D wfFlush         PI                                                       全体CS確定
     D byteDS          DS                                                       バイト変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
     D v1              S             10U 0                                      第1バイト値
     D v2              S             10U 0                                      第2バイト値
     D v3              S             10U 0                                      第3バイト値
     D v4              S             10U 0                                      第4バイト値
     D ww              S             10U 0                                      4byte合成値
       IF wfPos > 0;
         DOW wfPos < 4;
           wfPos = wfPos + 1;
           wfBufArr(wfPos) = x'00';
         ENDDO;
         byteVal = 0;
         byteChar = wfBufArr(1);
         v1 = byteVal;
         byteVal = 0;
         byteChar = wfBufArr(2);
         v2 = byteVal;
         byteVal = 0;
         byteChar = wfBufArr(3);
         v3 = byteVal;
         byteVal = 0;
         byteChar = wfBufArr(4);
         v4 = byteVal;
         ww = v1*16777216 + v2*65536 + v3*256 + v4;
         wfSum = wfSum + ww;
         wfPos = 0;
       ENDIF;
     P                 E

      * wfGet - ファイル全体の32ビットチェックサム値を返す
     P wfGet           B
     D wfGet           PI            10U 0                                      全体CS取得
       RETURN %REM(wfSum: 4294967296);
     P                 E

     P readU32Buf      B
     D readU32Buf      PI            10U 0                                      メモリBE32読取
     D   ptr                           *   CONST                                メモリ読取ptr
     D bA              S              1A   DIM(4) BASED(ptr)                    BE 4byte配列
     D byteDS          DS                                                       バイト変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
     D b1              S             10U 0                                      第1バイト値
     D b2              S             10U 0                                      第2バイト値
     D b3              S             10U 0                                      第3バイト値
     D b4              S             10U 0                                      第4バイト値
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

     P writeU16Buf     B
     D writeU16Buf     PI                                                       メモリBE16書込
     D   ptr                           *   CONST                                書込み先ptr
     D   val                          5U 0 CONST                                BE書込み値
     D bA              S              1A   DIM(2) BASED(ptr)                    BE 2byte配列
     D byteDS          DS                                                       バイト変換用DS
     D  byteChar                      1A                                        1バイト文字
     D  byteVal                       3U 0 OVERLAY(byteDS:1)                    バイト数値
       byteVal = %DIV(val:256);
       bA(1) = byteChar;
       byteVal = %REM(val:256);
       bA(2) = byteChar;
     P                 E
