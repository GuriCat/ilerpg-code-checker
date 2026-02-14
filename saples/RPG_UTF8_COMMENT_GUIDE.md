# ILE RPG 固定形式ソースに日本語注記を書くためのガイド

UTF-8 ストリームファイルを `TGTCCSID(5035)` でコンパイルする場合の、
D仕様書注記（columns 81-100）に日本語を記述する際のルールと注意点。

## 前提

- ソースファイル: IFS 上の UTF-8 ストリームファイル（CCSID 1208）
- コンパイル: `CRTRPGMOD ... SRCSTMF('...') TGTCCSID(5035)`
- RPG IV 固定形式（非フリーフォーマット）

## EBCDIC 5035 変換の仕組み

RPG コンパイラは UTF-8 ソースを EBCDIC CCSID 5035 に変換してから
桁位置を解釈します。CCSID 5035 では:

| 文字種 | UTF-8 バイト数 | EBCDIC 5035 バイト数 |
|--------|---------------|---------------------|
| ASCII (英数記号) | 1 | 1 |
| 日本語 1文字（単独） | 3 | 4 (SO + 2 + SI) |
| 日本語 N文字（連続） | 3N | 2N + 2 (SO + N×2 + SI) |

SO = Shift-Out (0x0E)、SI = Shift-In (0x0F)。
連続する日本語文字は SO/SI を共有します。

## D仕様書の桁構成

```
桁 1-5:   シーケンス番号（任意）
桁 6:     D（仕様書タイプ）
桁 7-21:  名前
桁 22:    外部記述(E)
桁 23:    DS タイプ
桁 24-25: 開始位置
桁 26-32: 終了位置/長さ
桁 33:    内部データ型
桁 34-37: 小数桁
桁 38-43: 予約
桁 44-80: キーワード（37桁）
桁 81-100: 注記（20桁）  ← ここに日本語を書く
```

**EBCDIC 5035 での注記領域は 20 バイト**です。

## ルール

### ルール 1: 注記の先頭文字は UTF-8 の 81 桁目以降に配置する

日本語文字（非ASCII文字）が 80 桁目（UTF-8 文字位置）にあると、
EBCDIC 変換時の SO バイトが 80 桁目（キーワード領域の最終桁）に
落ちてしまい、**RNF3308**（キーワード名が正しくない）が発生します。

```
NG: ...CONST                     入力CP配列    ← 「入」が80桁目 → SO がEBCDIC 80桁
                                  ↑ col 80

OK: ...CONST                      入力CP配列   ← 「入」が81桁目 → SO がEBCDIC 81桁
                                   ↑ col 81
```

**ASCII始まりの混合注記も同様です。**
`CIDFont obj番号` のような注記でも、先頭の `C` が 80 桁目にあると
注記全体がキーワード領域にはみ出してRNF3308になります。

### ルール 2: 日本語は最大 9 文字まで

EBCDIC 5035 の注記領域は 20 バイトです。

| 注記内容 | EBCDIC バイト数 | 判定 |
|---------|----------------|------|
| 日本語9文字 | SO(1) + 9×2 + SI(1) = 20 | OK（ちょうど上限） |
| 日本語10文字 | SO(1) + 10×2 + SI(1) = 22 | NG（2バイト超過） |
| ASCII 5文字 + 日本語6文字 | 5 + SO(1) + 6×2 + SI(1) = 19 | OK |
| ASCII 7文字 + 日本語5文字 | 7 + SO(1) + 5×2 + SI(1) = 19 | OK |

注記がキーワード領域にはみ出すと RNF3308 になります。

### ルール 3: H/P/C仕様書も同じルールが適用される

D仕様書だけでなく、すべての固定形式仕様書で注記領域のルールは同じです。

### ルール 4: DFTACTGRP は CRTRPGMOD では使用不可

`H DFTACTGRP(*NO) ACTGRP(*CALLER)` は CRTBNDRPG 専用キーワードです。
CRTRPGMOD + CRTPGM 方式では **RNF1324**（severity 20）が発生します。
モジュール方式ではこの行を削除してください。

## 検証方法

### Python スクリプトで事前チェック

```python
def check_dspec_comment(filepath):
    """D仕様書注記の桁位置とEBCDICバイト長を検証"""
    def ebcdic5035_len(text):
        length, in_dbcs = 0, False
        for ch in text:
            if ord(ch) <= 0x7F:
                if in_dbcs:
                    length += 1  # SI
                    in_dbcs = False
                length += 1
            else:
                if not in_dbcs:
                    length += 1  # SO
                    in_dbcs = True
                length += 2
        if in_dbcs:
            length += 1  # SI
        return length

    with open(filepath, 'r', encoding='utf-8') as f:
        for i, line in enumerate(f, 1):
            raw = line.rstrip()
            if len(raw) < 6 or raw[5].upper() != 'D':
                continue
            if len(raw) <= 80:
                continue
            comment = raw[80:]
            # 先頭文字位置チェック
            for ci, ch in enumerate(comment):
                if ch != ' ':
                    if ci == 0 and len(raw) > 79 and raw[79] != ' ':
                        # 注記が80桁目から始まっている
                        has_jp = any(ord(c) > 0x7F
                                     for c in raw[79:])
                        if has_jp:
                            print(f'{i}: 注記が80桁目から開始')
                    break
            # EBCDICバイト長チェック
            elen = ebcdic5035_len(comment.rstrip())
            if elen > 20:
                print(f'{i}: 注記EBCDIC長={elen} (上限20)')
```

### コンパイラでの確認

```
CRTRPGMOD MODULE(PDFLIB/name)
          SRCSTMF('/path/to/source.rpgle')
          DBGVIEW(*SOURCE) TGTCCSID(5035) REPLACE(*YES)
```

GENLVL を指定せず（デフォルト 0）、severity 00 で完了すれば注記に
問題はありません。severity 20 が出た場合は RNF3308 を確認してください。

## よくある間違い

### 1. 1桁ずれ

```
NG: ...CONST                     グリフ数       ← 80桁目に「グ」
OK: ...CONST                      グリフ数      ← 81桁目に「グ」
```

1スペース足りないだけで RNF3308 が発生します。

### 2. 日本語文字数の超過

```
NG: ...CONST                      フォントデータポインタ  ← 10文字=22バイト
OK: ...CONST                      フォントデータptr       ← 7文字+3ASCII=19バイト
```

ASCII文字を混ぜると多くの情報を入れられます。

### 3. エディタの表示幅と実際の桁位置の混同

日本語は全角（表示幅2桁）ですが、UTF-8 ソースでの桁位置は
**文字数** でカウントします。表示幅ではありません。
等幅フォントのエディタで見ると日本語が右にずれて見えますが、
重要なのはファイル内の文字インデックスです。

## 参考

- IBM i 7.5 ILE RPG Language Reference (SC09-2508)
- CCSID 5035: IBM日本語EBCDIC (カタカナ拡張+漢字)
- SO/SI: EBCDIC DBCS混在文字列のシフト制御文字
