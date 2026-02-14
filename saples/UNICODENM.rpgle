     H NOMAIN
      *=====================================================================
      * Module: UNICODENM - Unicode NFC正規化モジュール
      * Description: コードポイント配列ベースのNFC正規化
      *   - 日本語濁点/半濁点合成（ひらがな・カタカナ）
      *   - ラテン文字アクセント合成
      *   - ハングルアルゴリズム合成/分解
      *   - CCC（Canonical Combining Class）ソート
      * Version: 0.1.0
      * Created: 2026-02-11
      *=====================================================================

      *-------------------------------------------------------------
      * 定数
      *-------------------------------------------------------------
     D MAX_NFC_CP      C                   4096                                 最大CP配列要素数
     D HANGUL_SBASE    C                   44032                                音節ブロック先頭
     D HANGUL_LBASE    C                   4352                                 初声(L)先頭CP
     D HANGUL_VBASE    C                   4449                                 中声(V)先頭CP
     D HANGUL_TBASE    C                   4519                                 終声(T)先頭CP
     D HANGUL_LCOUNT   C                   19                                   初声(L)文字数
     D HANGUL_VCOUNT   C                   21                                   中声(V)文字数
     D HANGUL_TCOUNT   C                   28                                   終声(T)文字数
     D HANGUL_NCOUNT   C                   588                                  V*T組合せ数
     D HANGUL_SCOUNT   C                   11172                                音節総数

      *-------------------------------------------------------------
      * 公開プロトタイプ
      *-------------------------------------------------------------
     D normalizeNFC    PR            10I 0 EXTPROC('NORMALIZENFC')              NFC正規化
     D inCP                          10U 0 DIM(4096) CONST                      入力CP配列
     D inCount                       10I 0 CONST                                入力CP数
     D outCP                         10U 0 DIM(4096)                            出力CP配列
     D maxOut                        10I 0 CONST                                出力最大要素数

      *-------------------------------------------------------------
      * 内部プロトタイプ
      *-------------------------------------------------------------
     D getCCC          PR            10I 0                                      CCC値取得
     D cp                            10U 0 CONST                                対象CP値

     D decompCP        PR            10I 0                                      CP正規分解
     D cp                            10U 0 CONST                                分解対象CP
     D outArr                        10U 0 DIM(4)                               分解結果配列
     D maxDecomp                     10I 0 CONST                                最大分解数

     D composeCP       PR            10U 0                                      CP正規合成
     D cp1                           10U 0 CONST                                先行CP(基底)
     D cp2                           10U 0 CONST                                後続CP(結合)

     D sortCCC         PR                                                       CCCソート
     D arr                           10U 0 DIM(4096)                            CP配列(更新)
     D count                         10I 0 CONST                                配列要素数

      *=====================================================================
      * normalizeNFC - NFC正規化
      *   1. NFD分解（正規分解）
      *   2. CCCソート
      *   3. 正規合成
      *=====================================================================
     P normalizeNFC    B                   EXPORT
     D normalizeNFC    PI            10I 0                                      NFC正規化
     D inCP                          10U 0 DIM(4096) CONST                      入力CP配列
     D inCount                       10I 0 CONST                                入力CP数
     D outCP                         10U 0 DIM(4096)                            出力CP配列
     D maxOut                        10I 0 CONST                                出力最大要素数

     D decomBuf        S             10U 0 DIM(4096)                            NFD分解作業域
     D decomCnt        S             10I 0                                      分解後CP数
     D tmpArr          S             10U 0 DIM(4)                               1文字分解結果
     D tmpCnt          S             10I 0                                      分解結果数
     D i               S             10I 0                                      ループ添字
     D j               S             10I 0                                      内側ループ添字
     D starter         S             10U 0                                      合成基底CP
     D lastCCC         S             10I 0                                      前回CCC値
     D curCCC          S             10I 0                                      現在CCC値
     D composed        S             10U 0                                      合成結果CP
     D outCnt          S             10I 0                                      出力CP数

       IF inCount <= 0;
         RETURN 0;
       ENDIF;

       //Step 1: NFD分解
       decomCnt = 0;
       FOR i = 1 TO inCount;
         tmpCnt = decompCP(inCP(i):
                           tmpArr: 4);
         IF tmpCnt > 0;
           FOR j = 1 TO tmpCnt;
             IF decomCnt < MAX_NFC_CP;
               decomCnt += 1;
               decomBuf(decomCnt) = tmpArr(j);
             ENDIF;
           ENDFOR;
         ELSE;
           IF decomCnt < MAX_NFC_CP;
             decomCnt += 1;
             decomBuf(decomCnt) = inCP(i);
           ENDIF;
         ENDIF;
       ENDFOR;

       //Step 2: CCCソート
       sortCCC(decomBuf: decomCnt);

       //Step 3: 正規合成
       IF decomCnt = 0;
         RETURN 0;
       ENDIF;

       outCnt = 1;
       outCP(1) = decomBuf(1);
       starter = decomBuf(1);
       lastCCC = getCCC(decomBuf(1));
       IF lastCCC <> 0;
         lastCCC = 256;
       ENDIF;

       FOR i = 2 TO decomCnt;
         curCCC = getCCC(decomBuf(i));

         //合成可能かチェック
         composed = composeCP(starter:
                              decomBuf(i));

         IF composed > 0 AND
            (lastCCC < curCCC OR
             lastCCC = 0);
           //合成成功: starterを置換
           outCP(outCnt) = composed;
           starter = composed;
         ELSE;
           //合成不可: そのまま追加
           IF outCnt < maxOut;
             outCnt += 1;
             outCP(outCnt) = decomBuf(i);
           ENDIF;

           IF curCCC = 0;
             starter = decomBuf(i);
             lastCCC = 0;
           ELSE;
             lastCCC = curCCC;
           ENDIF;
         ENDIF;
       ENDFOR;

       RETURN outCnt;
     P                 E

      *=====================================================================
      * getCCC - Canonical Combining Class取得
      *=====================================================================
     P getCCC          B
     D getCCC          PI            10I 0                                      CCC値取得
     D cp                            10U 0 CONST                                対象CP値

       //結合ダイアクリティカルマーク (U+0300-U+036F)
       IF cp >= 768 AND cp <= 879; // 768=U+0300, 879=U+036F
         SELECT;
         WHEN cp >= 768 AND cp <= 788; // 上付き系: CCC=230
           RETURN 230;
         WHEN cp >= 790 AND cp <= 819; // 下付き系: CCC=220
           RETURN 220;
         OTHER;
           RETURN 230;
         ENDSL;
       ENDIF;

       //日本語結合濁点/半濁点
       IF cp = 12441 OR cp = 12442; // U+3099濁点/U+309A半濁点
         RETURN 8; // CCC=8(かな結合)
       ENDIF;

       RETURN 0;
     P                 E

      *=====================================================================
      * decompCP - 正規分解
      *=====================================================================
     P decompCP        B
     D decompCP        PI            10I 0                                      CP正規分解
     D cp                            10U 0 CONST                                分解対象CP
     D outArr                        10U 0 DIM(4)                               分解結果配列
     D maxDecomp                     10I 0 CONST                                最大分解数

     D sIndex          S             10I 0                                      音節内索引
     D l               S             10U 0                                      初声CP
     D v               S             10U 0                                      中声CP
     D t               S             10U 0                                      終声CP

       //ハングル音節分解
       IF cp >= HANGUL_SBASE AND
          cp < HANGUL_SBASE + HANGUL_SCOUNT;
         sIndex = cp - HANGUL_SBASE;
         l = HANGUL_LBASE +
             %DIV(sIndex: HANGUL_NCOUNT);
         v = HANGUL_VBASE +
             %DIV(%REM(sIndex: HANGUL_NCOUNT):
                  HANGUL_TCOUNT);
         t = HANGUL_TBASE +
             %REM(sIndex: HANGUL_TCOUNT);

         outArr(1) = l;
         outArr(2) = v;
         IF t <> HANGUL_TBASE;
           outArr(3) = t;
           RETURN 3;
         ENDIF;
         RETURN 2;
       ENDIF;

       //ラテン文字分解 (cp→基底文字+結合文字)
       // 65='A' 67='C' 69='E' 78='N' 79='O' 85='U'
       // 97='a' 99='c' 101='e' 110='n' 111='o' 117='u'
       // 768=U+0300(grave) 769=U+0301(acute)
       // 770=U+0302(circumflex) 771=U+0303(tilde)
       // 776=U+0308(diaeresis) 807=U+0327(cedilla)
       SELECT;
       WHEN cp = 192; // À = A + grave
         outArr(1) = 65;
           outArr(2) = 768;
         RETURN 2;
       WHEN cp = 193;
         outArr(1) = 65;
           outArr(2) = 769;
         RETURN 2;
       WHEN cp = 194;
         outArr(1) = 65;
           outArr(2) = 770;
         RETURN 2;
       WHEN cp = 195;
         outArr(1) = 65;
           outArr(2) = 771;
         RETURN 2;
       WHEN cp = 196;
         outArr(1) = 65;
           outArr(2) = 776;
         RETURN 2;
       WHEN cp = 199;
         outArr(1) = 67;
           outArr(2) = 807;
         RETURN 2;
       WHEN cp = 200;
         outArr(1) = 69;
           outArr(2) = 768;
         RETURN 2;
       WHEN cp = 201;
         outArr(1) = 69;
           outArr(2) = 769;
         RETURN 2;
       WHEN cp = 202;
         outArr(1) = 69;
           outArr(2) = 770;
         RETURN 2;
       WHEN cp = 203;
         outArr(1) = 69;
           outArr(2) = 776;
         RETURN 2;
       WHEN cp = 209;
         outArr(1) = 78;
           outArr(2) = 771;
         RETURN 2;
       WHEN cp = 214;
         outArr(1) = 79;
           outArr(2) = 776;
         RETURN 2;
       WHEN cp = 220;
         outArr(1) = 85;
           outArr(2) = 776;
         RETURN 2;
       WHEN cp = 224;
         outArr(1) = 97;
           outArr(2) = 768;
         RETURN 2;
       WHEN cp = 225;
         outArr(1) = 97;
           outArr(2) = 769;
         RETURN 2;
       WHEN cp = 226;
         outArr(1) = 97;
           outArr(2) = 770;
         RETURN 2;
       WHEN cp = 227;
         outArr(1) = 97;
           outArr(2) = 771;
         RETURN 2;
       WHEN cp = 228;
         outArr(1) = 97;
           outArr(2) = 776;
         RETURN 2;
       WHEN cp = 231;
         outArr(1) = 99;
           outArr(2) = 807;
         RETURN 2;
       WHEN cp = 232;
         outArr(1) = 101;
           outArr(2) = 768;
         RETURN 2;
       WHEN cp = 233;
         outArr(1) = 101;
           outArr(2) = 769;
         RETURN 2;
       WHEN cp = 234;
         outArr(1) = 101;
           outArr(2) = 770;
         RETURN 2;
       WHEN cp = 235;
         outArr(1) = 101;
           outArr(2) = 776;
         RETURN 2;
       WHEN cp = 241;
         outArr(1) = 110;
           outArr(2) = 771;
         RETURN 2;
       WHEN cp = 246;
         outArr(1) = 111;
           outArr(2) = 776;
         RETURN 2;
       WHEN cp = 252;
         outArr(1) = 117;
           outArr(2) = 776;
         RETURN 2;
       OTHER;
         RETURN 0;
       ENDSL;

       RETURN 0;
     P                 E

      *=====================================================================
      * composeCP - 正規合成
      *=====================================================================
     P composeCP       B
     D composeCP       PI            10U 0                                      CP正規合成
     D cp1                           10U 0 CONST                                先行CP(基底)
     D cp2                           10U 0 CONST                                後続CP(結合)

     D lIndex          S             10I 0                                      初声索引
     D vIndex          S             10I 0                                      中声索引
     D sIndex          S             10I 0                                      音節内索引
     D tIndex          S             10I 0                                      終声索引

       //ハングルLV合成
       IF cp1 >= HANGUL_LBASE AND
          cp1 < HANGUL_LBASE + HANGUL_LCOUNT;
         IF cp2 >= HANGUL_VBASE AND
            cp2 < HANGUL_VBASE + HANGUL_VCOUNT;
           lIndex = cp1 - HANGUL_LBASE;
           vIndex = cp2 - HANGUL_VBASE;
           RETURN HANGUL_SBASE +
                  (lIndex * HANGUL_VCOUNT +
                   vIndex) * HANGUL_TCOUNT;
         ENDIF;
       ENDIF;

       //ハングルLVT合成
       IF cp1 >= HANGUL_SBASE AND
          cp1 < HANGUL_SBASE + HANGUL_SCOUNT;
         sIndex = cp1 - HANGUL_SBASE;
         IF %REM(sIndex: HANGUL_TCOUNT) = 0;
           IF cp2 > HANGUL_TBASE AND
              cp2 < HANGUL_TBASE +
                     HANGUL_TCOUNT;
             tIndex = cp2 - HANGUL_TBASE;
             RETURN cp1 + tIndex;
           ENDIF;
         ENDIF;
       ENDIF;

       //ラテン文字合成 (基底+結合→合成済CP)
       SELECT;
       WHEN cp1 = 65; // 'A'+結合文字
         SELECT;
         WHEN cp2 = 768; // A+grave=À
           RETURN 192;
         WHEN cp2 = 769;
           RETURN 193;
         WHEN cp2 = 770;
           RETURN 194;
         WHEN cp2 = 771;
           RETURN 195;
         WHEN cp2 = 776;
           RETURN 196;
         ENDSL;
       WHEN cp1 = 67 AND cp2 = 807;
         RETURN 199;
       WHEN cp1 = 69;
         SELECT;
         WHEN cp2 = 768;
           RETURN 200;
         WHEN cp2 = 769;
           RETURN 201;
         WHEN cp2 = 770;
           RETURN 202;
         WHEN cp2 = 776;
           RETURN 203;
         ENDSL;
       WHEN cp1 = 78 AND cp2 = 771;
         RETURN 209;
       WHEN cp1 = 79 AND cp2 = 776;
         RETURN 214;
       WHEN cp1 = 85 AND cp2 = 776;
         RETURN 220;
       WHEN cp1 = 97;
         SELECT;
         WHEN cp2 = 768;
           RETURN 224;
         WHEN cp2 = 769;
           RETURN 225;
         WHEN cp2 = 770;
           RETURN 226;
         WHEN cp2 = 771;
           RETURN 227;
         WHEN cp2 = 776;
           RETURN 228;
         ENDSL;
       WHEN cp1 = 99 AND cp2 = 807;
         RETURN 231;
       WHEN cp1 = 101;
         SELECT;
         WHEN cp2 = 768;
           RETURN 232;
         WHEN cp2 = 769;
           RETURN 233;
         WHEN cp2 = 770;
           RETURN 234;
         WHEN cp2 = 776;
           RETURN 235;
         ENDSL;
       WHEN cp1 = 110 AND cp2 = 771;
         RETURN 241;
       WHEN cp1 = 111 AND cp2 = 776;
         RETURN 246;
       WHEN cp1 = 117 AND cp2 = 776;
         RETURN 252;
       ENDSL;

       //日本語濁点合成（ひらがな+カタカナ）
       // 12441=U+3099(結合濁点) → か→が, き→ぎ 等
       IF cp2 = 12441;
         SELECT;
         WHEN cp1 = 12363; // か(U+304B)→が(U+304C)
           RETURN 12364;
         WHEN cp1 = 12365;
           RETURN 12366;
         WHEN cp1 = 12367;
           RETURN 12368;
         WHEN cp1 = 12369;
           RETURN 12370;
         WHEN cp1 = 12371;
           RETURN 12372;
         WHEN cp1 = 12373;
           RETURN 12374;
         WHEN cp1 = 12375;
           RETURN 12376;
         WHEN cp1 = 12377;
           RETURN 12378;
         WHEN cp1 = 12379;
           RETURN 12380;
         WHEN cp1 = 12381;
           RETURN 12382;
         WHEN cp1 = 12383;
           RETURN 12384;
         WHEN cp1 = 12385;
           RETURN 12386;
         WHEN cp1 = 12388;
           RETURN 12389;
         WHEN cp1 = 12390;
           RETURN 12391;
         WHEN cp1 = 12392;
           RETURN 12393;
         WHEN cp1 = 12399;
           RETURN 12400;
         WHEN cp1 = 12402;
           RETURN 12403;
         WHEN cp1 = 12405;
           RETURN 12406;
         WHEN cp1 = 12408;
           RETURN 12409;
         WHEN cp1 = 12411;
           RETURN 12412;
         WHEN cp1 = 12459; // カ(U+30AB)→ガ(U+30AC)
           RETURN 12460;
         WHEN cp1 = 12461;
           RETURN 12462;
         WHEN cp1 = 12463;
           RETURN 12464;
         WHEN cp1 = 12465;
           RETURN 12466;
         WHEN cp1 = 12467;
           RETURN 12468;
         WHEN cp1 = 12469;
           RETURN 12470;
         WHEN cp1 = 12471;
           RETURN 12472;
         WHEN cp1 = 12473;
           RETURN 12474;
         WHEN cp1 = 12475;
           RETURN 12476;
         WHEN cp1 = 12477;
           RETURN 12478;
         WHEN cp1 = 12479;
           RETURN 12480;
         WHEN cp1 = 12481;
           RETURN 12482;
         WHEN cp1 = 12484;
           RETURN 12485;
         WHEN cp1 = 12486;
           RETURN 12487;
         WHEN cp1 = 12488;
           RETURN 12489;
         WHEN cp1 = 12495;
           RETURN 12496;
         WHEN cp1 = 12498;
           RETURN 12499;
         WHEN cp1 = 12501;
           RETURN 12502;
         WHEN cp1 = 12504;
           RETURN 12505;
         WHEN cp1 = 12507;
           RETURN 12508;
         WHEN cp1 = 12454; // ウ(U+30A6)→ヴ(U+30F4)
           RETURN 12532;
         ENDSL;
       ENDIF;

       //半濁点合成
       // 12442=U+309A(結合半濁点) → は→ぱ, ひ→ぴ 等
       IF cp2 = 12442;
         SELECT;
         WHEN cp1 = 12399; // は(U+306F)→ぱ(U+3071)
           RETURN 12401;
         WHEN cp1 = 12402;
           RETURN 12404;
         WHEN cp1 = 12405;
           RETURN 12407;
         WHEN cp1 = 12408;
           RETURN 12410;
         WHEN cp1 = 12411;
           RETURN 12413;
         WHEN cp1 = 12495; // ハ(U+30CF)→パ(U+30D1)
           RETURN 12497;
         WHEN cp1 = 12498;
           RETURN 12500;
         WHEN cp1 = 12501;
           RETURN 12503;
         WHEN cp1 = 12504;
           RETURN 12506;
         WHEN cp1 = 12507;
           RETURN 12509;
         ENDSL;
       ENDIF;

       RETURN 0;
     P                 E

      *=====================================================================
      * sortCCC - CCCによる安定ソート
      *=====================================================================
     P sortCCC         B
     D sortCCC         PI                                                       CCCソート
     D arr                           10U 0 DIM(4096)                            CP配列(更新)
     D count                         10I 0 CONST                                配列要素数

     D i               S             10I 0                                      外側ループ添字
     D j               S             10I 0                                      内側ループ添字
     D swapped         S              1N                                        交換発生フラグ
     D tmp             S             10U 0                                      交換一時変数
     D ccc1            S             10I 0                                      比較CCC値1
     D ccc2            S             10I 0                                      比較CCC値2

       IF count <= 1;
         RETURN;
       ENDIF;

       FOR i = 1 TO count - 1;
         swapped = *OFF;
         FOR j = 1 TO count - i;
           ccc1 = getCCC(arr(j));
           ccc2 = getCCC(arr(j + 1));
           IF ccc1 > ccc2 AND
              ccc1 > 0 AND ccc2 > 0;
             tmp = arr(j);
             arr(j) = arr(j + 1);
             arr(j + 1) = tmp;
             swapped = *ON;
           ENDIF;
         ENDFOR;
         IF NOT swapped;
           LEAVE;
         ENDIF;
       ENDFOR;
     P                 E
