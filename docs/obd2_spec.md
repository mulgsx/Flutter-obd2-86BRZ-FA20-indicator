# OBD2 BLE Specification — 86BRZ / FA20

Communication specification for the 86BRZ (FA20 engine) dedicated OBD2 BLE monitor app.
86BRZ（FA20エンジン）専用 OBD2 BLE モニターアプリの通信仕様書。

---

## 1. Overview

### Communication Stack / 通信スタック

```
Android BLE
    ↓ GATT write / notify
ELM327 BLE Adapter (generic OBD2 dongle / 汎用OBD2ドングル)
    ↓ CAN bus / CAN バス
86BRZ ECU (FA20 engine / FA20エンジン)
```

### Data Acquired / 取得するデータ

| Data / データ | PID | Type / 種別 |
|---|---|---|
| Engine RPM / エンジン回転数 | `010C` | OBD2 standard / 標準（Mode 01） |
| Coolant Temperature / 冷却水温 | `0105` | OBD2 standard / 標準（Mode 01） |
| Engine Oil Temperature / エンジンオイル温度 | `2101` | 86BRZ / FA20 specific / 固有（Mode 21） |

---

## 2. BLE Connection

| Item / 項目 | Value / 値 |
|---|---|
| Target service UUID | `0000FFF0-0000-1000-8000-00805F9B34FB` |
| Fallback service UUID | `0000FFE0-0000-1000-8000-00805F9B34FB` |
| Write characteristic | Characteristic with **write** property in FFF0/FFE0 service (not a fixed UUID) / `FFF0`/`FFE0` サービス内の **write プロパティ**を持つもの（UUID固定ではない） |
| Notify characteristic | Characteristic with **notify** property in same service / 同サービス内の **notify プロパティ**を持つもの（UUID固定ではない） |
| MTU | Request 256 — so long ELM327 responses fit in one packet / 256 をリクエスト（ELM327 の長いレスポンスが1パケットに収まるように） |
| Connect timeout | 15 seconds / 15 秒 |

> **Note:** Do not hardcode a specific UUID — discover characteristics by **property (write / notify)**.
> **注意:** 特定の UUID を決め打ちせず、**プロパティ（write / notify）で特性を探す**こと。
> The characteristic UUID may differ between ELM327 products.
> ELM327 の製品によって characteristic UUID が異なる場合がある。

---

## 3. ELM327 AT Initialization Sequence

Send the following AT commands in order after connecting, before starting OBD2 communication.
接続後、OBD2 通信を開始する前に以下の AT コマンドを順番に送信して ELM327 を初期化する。

### Basic Send/Receive Rules / 送受信の基本ルール

- Commands are written as **UTF-8 bytes** to the write characteristic. / コマンドは **UTF-8 バイト列**として write characteristic に書き込む。
- Each command is terminated with a carriage return `\r`. / 各コマンドはキャリッジリターン `\r` で終端する。
- Responses are received via the notify callback; one command is complete when `>` arrives. / レスポンスは notify コールバックで受信し、`>` プロンプトが来たら1コマンド完了。
- **Insert a 300ms wait between each command** (the ELM327 may not keep up otherwise). / **各コマンド間に 300ms のウェイトを挟む**（ELM327 の処理が追いつかないことがある）。

### Command List / 初期化コマンド一覧

| Order / 順序 | Command / コマンド | Meaning / 意味 |
|---|---|---|
| 1 | `ATZ\r` | Software reset / ソフトウェアリセット |
| 2 | `ATE0\r` | Echo off — do not echo sent command in response / エコーオフ（送信したコマンドをレスポンスに含めない） |
| 3 | `ATH0\r` | Hide CAN headers / CAN ヘッダ非表示 |
| 4 | `ATL0\r` | No linefeed (LF) / 改行コード（LF）なし |
| 5 | `ATS1\r` | Add spaces between bytes (required for parsing) / バイト間にスペースを入れる（パース処理に必要） |
| 6 | `ATSP0\r` | Auto protocol selection / プロトコル自動選択 |

---

## 4. PID Polling Loop

After initialization, cyclically send the following 3 PIDs to acquire data.
初期化完了後、以下の3つの PID をサイクリック（繰り返し）に送信してデータを取得する。

### Polling Order / ポーリング順序

```
1. 010C\r      → Get RPM / RPM 取得
2. 0105\r      → Get coolant temp / 水温取得
3. ATSH 7E0\r  → Fix CAN header to ECU address (pre-process for oil temp) / CAN ヘッダを ECU アドレスに固定（油温取得の前処理）
4. 2101\r      → Get oil temp / 油温取得
5. ATSH 7DF\r  → Reset CAN header to default / CAN ヘッダをデフォルトに戻す
6.             → back to 1 / 1 に戻る
```

### 86BRZ / FA20 Specific: CAN Header Switching for Oil Temp / 油温取得の CAN ヘッダ切り替え

> Oil temperature (Mode 21 PID `2101`) does not exist in standard OBD2 PIDs.
> 油温（Mode 21 PID `2101`）は汎用 OBD2 の標準 PID には存在しない。
> It is a manufacturer-specific PID of the FA20 engine ECU; the ECU must be addressed directly or no response is returned.
> 86BRZ の FA20 エンジン ECU が独自に持つ製造元固有 PID であり、ECU を直接指定しないとレスポンスが返らない。

| Command / コマンド | Timing / タイミング | Meaning / 意味 |
|---|---|---|
| `ATSH 7E0\r` | Immediately **before** sending `2101\r` / `2101\r` 送信の**直前** | Fix CAN header to FA20 engine ECU address `7E0` / CAN ヘッダを FA20 エンジン ECU アドレス `7E0` に固定 |
| `ATSH 7DF\r` | Immediately **after** receiving `2101\r` response / `2101\r` レスポンス取得の**直後** | Reset CAN header to default broadcast `7DF` / CAN ヘッダをデフォルト（ブロードキャスト `7DF`）に戻す |

> **Important:** Including this `ATSH` switch in the init sequence causes Mode 01 responses to shift by one command.
> **重要:** この `ATSH` 切り替えを初期化シーケンスに入れると、その後の Mode 01 レスポンスが1コマンドずれる不具合が出る。
> **Perform this only immediately before and after `2101\r` within the polling loop.**
> **ポーリングループ内、`2101\r` の直前直後にのみ実施すること。**

---

## 5. Response Parsing Pipeline

```
BLE notify callback (byte array) / BLE notify コールバック（バイト列）
  ↓ UTF-8 decode → append to StringBuffer / UTF-8 デコード → 文字列を StringBuffer に追記
  ↓ one response confirmed when ">" arrives / ">" が来たら1レスポンス確定
  ↓ split by whitespace/newlines → List<String> parts (hex strings) / 空白・改行で split → List<String> parts（各要素は hex 文字列）
  ↓ cleaning (Section 5-1) / クリーニング処理（Section 5-1）
  ↓ data bytes start at parts[2] → apply formula (Section 5-2) / parts[2] 以降がデータバイト → 計算式を適用（Section 5-2）
```

---

### 5-1. Response Cleaning Rules

ELM327 responses may include headers or frame numbers depending on the frame type.
ELM327 のレスポンスはフレーム形式によってヘッダの有無やフレーム番号が付くことがある。
Apply the rules below to normalize so that data bytes always start at `parts[2]`.
以下のルールでクリーニングし、データバイトの開始インデックスを常に `parts[2]` に統一する。

| Condition / 条件 | Action / 処理 |
|---|---|
| `parts[1]` ends with `:` / `parts[1]` が `:` で終わる | **ISO 15765 multi-frame:** Remove frame number tokens (`00:`, `01:`, etc.) / **マルチフレーム:** フレーム番号トークン（`00:`, `01:` 等）を除去する |
| `parts[0]` is a 3-digit hex starting with `7` (e.g. `7E8`) / `parts[0]` が `7` 始まりの3桁 hex | **CAN header present:** Remove first 2 tokens (header + frame type) / **CAN ヘッダあり:** 先頭2トークン（ヘッダ + フレームタイプ）を除去する |
| Otherwise / それ以外 | Pass through / そのまま |

**parts structure after cleaning / クリーニング後の parts 構造:**

```
parts[0] = service byte  (e.g. "41" = Mode 01 response / Mode 01 レスポンス)
parts[1] = PID echo      (e.g. "0C" = RPM)
parts[2]+ = data bytes   (データバイト)
```

#### Example — RPM with CAN header / レスポンス例（RPM、CAN ヘッダあり）

```
raw:      "7E8 04 41 0C 1A F8"
split:    ["7E8", "04", "41", "0C", "1A", "F8"]
↓ parts[0]="7E8" starts with 7 (3-digit) → remove first 2 tokens / 先頭2トークン除去
cleaned:  ["41", "0C", "1A", "F8"]
parts[2]=0x1A, parts[3]=0xF8 → RPM = (26*256 + 248) / 4 = 1726.0 rpm
```

---

### 5-2. Calculation Formulas

| PID | Data / データ | Formula / 計算式 | Unit / 単位 | Notes / 備考 |
|---|---|---|---|---|
| `010C` | Engine RPM / エンジン回転数 | `(parts[2] * 256 + parts[3]) / 4` | rpm | — |
| `0105` | Coolant temp / 冷却水温 | `parts[2] - 40` | °C | — |
| `2101` | Oil temp / エンジンオイル温度 | `parts[2 + 28] - 40` | °C | **86BRZ FA20 specific: offset byte 28 / オフセット 28 バイト目** |

> **86BRZ / FA20 Specific — Oil temp byte position / 油温バイト位置:**
> In the Mode 21 response payload (after cleaning, `parts[2]` onward), the FA20 engine ECU stores oil temperature at offset **byte 28**.
> Mode 21 のレスポンスペイロード（クリーニング後の `parts[2]` 以降）において、FA20 エンジン ECU はオフセット **28 バイト目**にエンジンオイル温度を格納している。
> This byte position may differ for other vehicle models or engines.
> 他の車種・エンジンでは位置が異なる可能性がある。

---

## 6. Connection Status Machine / 接続ステータス

```
disconnected       (切断)
    ↓ connect()
connecting         (接続中)
    ↓ GATT services discovered, MTU negotiated / サービス検出・MTU ネゴシエーション完了
initializing       (初期化中)
    ↓ AT init sequence complete / AT 初期化シーケンス完了
polling            (ポーリング中)
    ↓ error / disconnect
error              (エラー)
```

---

## 7. Error Handling / エラー処理

| Case / ケース | Action / 対処 |
|---|---|
| Connection timeout (15s) / 接続タイムアウト（15秒） | Transition to `error` state / `error` 状態へ遷移 |
| No notify for a period / notify が一定時間来ない | Retry or transition to `error` after timeout / タイムアウト後 retry または `error` 状態へ |
| Empty PID response or parse failure / PID レスポンスが空・parse 失敗 | Retain last value, log the error, advance to next PID / 前回値を保持し、ログに記録して次の PID へ進む |
| Disconnect detected / 切断検知（GATT disconnect callback） | Transition to `disconnected` state / `disconnected` 状態へ遷移 |
