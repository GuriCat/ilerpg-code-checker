# コンパイルエラー原因と対応

ILE RPG UTF-8 PDFプロジェクトのビルドで発生したエラーの一覧。
次回セッションでの再発防止と、ライセンス復旧後のビルド検証に使用する。

---

## 1. RNF3308 — D仕様書注記の桁位置エラー

| 項目 | 内容 |
|------|------|
| メッセージ | RNF3308: 仕様タイプが有効でない |
| 重大度 | 20 |
| 影響 | 全コアモジュール＋テストプログラム（8ファイル） |

### 原因

UTF-8ソースを`TGTCCSID(5035)`でコンパイルすると、コンパイラはソースをEBCDIC 5035に変換してから桁位置を判定する。日本語文字はEBCDIC 5035ではSO(0x0E) + 2バイト + SI(0x0F)に変換される。

D仕様書の注記欄は81-100桁（20バイト）。UTF-8ソースで日本語注記の開始位置が早すぎると、EBCDIC変換後にSOバイトが80桁（キーワード領域）に入り、RNF3308が発生する。

### 誤った対処（過去に実施）

- `GENLVL(20)` で重大度20を無視してコンパイル → 根本解決にならない

### 正しい対処（実施済み）

- UTF-8ソースの注記開始位置をUTF-8文字インデックス80以降（81桁目以降）に統一
- 日本語注記は最大9文字（SO + 9×2 + SI = 20バイト）
- ASCII始まりの注記（例: `CP配列`）も同じルールを適用
- 詳細は [RPG_UTF8_COMMENT_GUIDE.md](RPG_UTF8_COMMENT_GUIDE.md) を参照

### 修正規模

約180行（全8ファイル）。修正後は全モジュール severity 00。

---

## 2. RNF1324 — DFTACTGRP(*NO) が CRTRPGMOD で無効

| 項目 | 内容 |
|------|------|
| メッセージ | RNF1324: キーワードはこのコマンドでは無効 |
| 重大度 | 20 |
| 影響 | テストプログラム3つ（FEATDEMO, MULTILANG, TTCDEMO） |

### 原因

テストプログラムのH仕様書に`DFTACTGRP(*NO) ACTGRP(*CALLER)`が記述されていた。`DFTACTGRP`は`CRTBNDRPG`専用のキーワードで、`CRTRPGMOD`では無効。

### 混入時期

ソースファイルが最初にgit管理される前（コミット`a5cf11a`）から存在。以前は`GENLVL(20)`で無視していたため表面化しなかった。

### 対処（実施済み）

3ファイルからH仕様書の`DFTACTGRP(*NO) ACTGRP(*CALLER)`行を削除。

---

## 3. CPF9E71 / CPF9E72 — 5770WDS ライセンス制限

| 項目 | 内容 |
|------|------|
| メッセージ | CPF9E71: 猶予期間が満了した |
| 重大度 | 40 |
| 影響 | CRTRPGMOD全般（全モジュール） |

### 原因

5770WDS（IBM Rational Development Studio for i）の機能5101（ILE RPG/COBOL/C++コンパイラ）のライセンスが切れている。

```
WRKLICINF の確認結果:
5770WDS  V7R6M0  5101  ILE COMPILERS: RPG, COBOL, C/C++  使用制限=0
```

### 症状

- `CRTRPGMOD`がCPF9E71（またはCPF9E72）で失敗
- STRREXPRC内・SSH経由・SBMJOB経由のいずれでも発生
- 実行環境やジョブの種類に依存しない（ライセンス自体の問題）

### 経緯

- 以前のセッション（2026-02-13）ではコンパイル成功 → 猶予期間内だった
- 2026-02-14のビルドでCPF9E71発生 → 猶予期間が満了

### 対処

```
ADDLICKEY PRDID(5770WDS) LICTRM(*ANY) FEATURE(5101) LICKEY(xxxx-xxxx-xxxx-xxxx)
```

ライセンスキー入力後、COMPILEALL.rexxを再実行してビルド検証を行うこと。

---

## 4. RNS9309 — コンパイル失敗（上位エラーの結果）

| 項目 | 内容 |
|------|------|
| メッセージ | RNS9309: コンパイルは正常に実行されなかった |
| 重大度 | 50 |

### 原因

RNS9309自体はエラーではなく、上位のエラー（RNF3308、CPF9E71等）の結果として発生する終了メッセージ。根本原因は上記1〜3のいずれか。

---

## ビルド検証手順（ライセンス復旧後）

```
-- 1. ソースPFにコピー
CPYFRMSTMF FROMSTMF('/home/GURICAT/ILE-RPG_UTF8-PDF/rexx/COMPILEALL.rexx')
           TOMBR('/QSYS.LIB/PDFLIB.LIB/QREXSRC3.FILE/COMPILEALL.MBR')
           MBROPT(*REPLACE) STMFCCSID(1208) DBFCCSID(1399)

-- 2. 実行
STRREXPRC SRCMBR(COMPILEALL) SRCFILE(PDFLIB/QREXSRC3)
```

### 期待結果

- Step 2: コアモジュール5つ（UNICODENM, TTFPARSER, TTFSUBSET, PDFTTFCMAP, PDFGEN）→ CRTRPGMOD OK
- Step 3: サービスプログラム PDFCMAPGEN → CRTSRVPGM OK
- Step 4: デモプログラム3つ（FEATDEMO, MULTILANG, TTCDEMO）→ CRTRPGMOD OK
- Step 5: プログラム作成 → CRTPGM OK
- Step 6: 実行 → CALL OK
- Step 7: PDF確認 → featdemo.pdf, multi.pdf, ttcdemo.pdf 存在

検出されたエラーは0個であること。

---

## 未検証事項

COMPILEALL.rexx内のCRTRPGMODは現在直接実行方式。ライセンス復旧後に STRREXPRC内から直接CRTRPGMODが実行可能か再確認が必要。CPF9E71がライセンス切れのみに起因するのか、STRREXPRC固有のライセンスセッション制約もあるのか、切り分けが未完了。

もしライセンス復旧後もSTRREXPRC内からCRTRPGMODが失敗する場合は、以下の代替策を検討：
1. QShellスクリプト（.sh）でsystemコマンド経由実行
2. CLプログラムでビルド処理を実装
3. REXXの実行自体をSBMJOBではなくQCMDEXCやSYSTEMコマンドから実行
