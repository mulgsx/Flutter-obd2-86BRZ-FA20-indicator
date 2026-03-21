# BRZ ZC6 OBD2 BLE モニター 仕様書

スバル BRZ ZC6（FA20エンジン）専用の OBD2 BLE モニターアプリ。
ELM327 BLE アダプタ経由でリアルタイムにRPM・水温・油温を取得し、自動車メーター風ゲージで表示する。

> この仕様書は実車検証済みの実装を記録したものです。AIがこの仕様書を読むだけでアプリを再現できることを目指しています。

---

## 1. 技術スタック

| 項目 | 内容 |
|------|------|
| フレームワーク | Flutter (Dart ^3.10.4) |
| 状態管理・DI・ルーティング | GetX (`get: ^4.7.2`) |
| BLE通信 | `flutter_blue_plus: ^1.35.3` |
| 権限管理 | `permission_handler: ^11.4.0` |
| スリープ防止 | `wakelock_plus: ^1.2.10` |
| 主要ターゲット | Android（iOS互換だが未検証） |
| 対象車種 | スバル BRZ ZC6 / FA20エンジン |

### pubspec.yaml（抜粋）

```yaml
environment:
  sdk: ^3.10.4

dependencies:
  flutter_blue_plus: ^1.35.3
  get: ^4.7.2
  permission_handler: ^11.4.0
  wakelock_plus: ^1.2.10
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_lints: ^6.0.0
```

---

## 2. ファイル構成

```
lib/
├── main.dart                        # エントリーポイント
├── controllers/
│   ├── bluetooth_controller.dart    # BT アダプタ状態監視
│   ├── scanresult_controller.dart   # BLE スキャン管理
│   └── obd_controller.dart          # OBD通信・PIDポーリング（コア）
├── pages/
│   ├── scan_ble_page.dart           # BT状態チェック・振り分け
│   ├── bluetooth_off_page.dart      # BT無効時の表示
│   ├── find_devices_page.dart       # BLEスキャン・デバイス選択
│   └── dashboard_page.dart          # メイン計器盤
├── models/
│   └── gauge_config.dart            # ゲージ設定データクラス
└── widgets/
    └── gauge_widget.dart            # 自動車メーター風カスタムゲージ
```

---

## 3. アプリ起動シーケンス（main.dart）

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
    Permission.locationWhenInUse,
  ].request();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await WakelockPlus.enable();
  runApp(const MyApp());
}
```

**MyApp テーマ設定:**

```dart
ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF0D1117),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF58A6FF),
    surface: Color(0xFF161B22),
  ),
  useMaterial3: true,
)
```

---

## 4. 画面遷移フロー

```
MyApp (GetMaterialApp)
  └─ ScanBlePage  ← ホーム。BTアダプタ状態を Obx で監視
       ├─ BT ON  → FindDevicesPage（BLEスキャン・選択）
       ├─ BT OFF → BluetoothOffPage（エラー表示）
       └─ その他 → CircularProgressIndicator（中央に表示）

FindDevicesPage
  └─ デバイスタップ → _connect() → DashboardPage（Get.to）
```

---

## 5. コントローラー仕様

### BluetoothController

BT アダプタの on/off を監視する。

```dart
class BluetoothController extends GetxController {
  final adapterState = BluetoothAdapterState.unknown.obs;

  @override
  void onInit() {
    super.onInit();
    FlutterBluePlus.adapterState.listen((s) => adapterState.value = s);
  }

  bool get isOn => adapterState.value == BluetoothAdapterState.on;
}
```

---

### ScanResultController

BLE スキャンのライフサイクルを管理する。

```dart
class ScanResultController extends GetxController {
  final scanResultList = <ScanResult>[].obs;
  final isScanning = false.obs;
  final hasPermission = false.obs;

  // スキャン開始（権限チェック込み、15秒タイムアウト）
  Future<void> startScan() async { ... }
  void stopScan() => FlutterBluePlus.stopScan();
}
```

---

### OBDController（コア）

デバイス接続 → ELM327初期化 → PIDポーリングの状態機械。

#### 状態

```dart
enum OBDStatus { disconnected, connecting, initializing, polling, error }

final status = OBDStatus.disconnected.obs;
final statusMessage = ''.obs;
final rpm = Rxn<int>();
final waterTemp = Rxn<int>();
final oilTemp = Rxn<int>();
final logs = <String>[].obs; // 最新50件、index 0が最新
```

#### 起動シーケンス（onInit → _start）

```
1. connect(timeout: 15s)
2. requestMtu(256)
3. discoverServices()
4. _findCharacteristics()  ← FFF0 → FFE0 → 全サービスの順で探索
5. notifyChar.setNotifyValue(true)
6. notifyChar.onValueReceived.listen(_onData)
7. _sendInitSequence()
8. _pollingLoop()
```

#### ATコマンド初期化シーケンス（各コマンド間 300ms 待機、タイムアウト 3s）

| 順序 | コマンド | 意味 |
|------|---------|------|
| 1 | `ATZ\r` | リセット |
| 2 | `ATE0\r` | エコーオフ |
| 3 | `ATH0\r` | ヘッダオフ |
| 4 | `ATL0\r` | 改行コードオフ |
| 5 | `ATS1\r` | スペースオン（バイト間にスペース） |
| 6 | `ATSP0\r` | プロトコル自動検出 |

> `ATSH 7E0` は init には含めない。油温PIDの直前にのみ一時的に設定する（理由は後述）。

#### PIDポーリングループ

```dart
final List<String> _pidQueue = [
  '010C\r', // RPM
  '0105\r', // 冷却水温
  '2101\r', // 油温（Mode 21 Subaru固有）
];
```

```dart
Future<void> _pollingLoop() async {
  while (_polling) {
    final cmd = _pidQueue[_pidIndex];
    _pidIndex = (_pidIndex + 1) % _pidQueue.length;

    String? response;
    if (cmd == '2101\r') {
      // 油温のみ: ECUアドレスを7E0に設定してから送信し、直後に戻す
      await _sendCommand('ATSH 7E0\r', timeout: Duration(milliseconds: 500));
      response = await _sendCommand(cmd, timeout: Duration(milliseconds: 3000));
      await _sendCommand('ATSH 7DF\r', timeout: Duration(milliseconds: 500));
    } else {
      response = await _sendCommand(cmd, timeout: Duration(milliseconds: 800));
    }

    if (response != null && response.isNotEmpty) {
      _parseResponse(cmd, response);
    }
  }
}
```

**ヘッダ切り替えが必要な理由:**
`ATSH 7E0` を init 全体に設定すると Mode 01 コマンド（RPM・水温）の応答が遅延してタイムアウトし、1コマンドずつ応答がずれるバグが発生する。`2101` 送信前後でのみ切り替えることで解消。

#### BLE データ受信・バッファリング

```dart
void _onData(List<int> data) {
  _buffer.write(String.fromCharCodes(data));
  final buffered = _buffer.toString();
  if (!buffered.contains('>')) return; // '>'プロンプトが来るまで蓄積

  final parts = buffered.split('>');
  final response = parts.first.trim();
  _buffer.clear();
  if (parts.length > 1) _buffer.write(parts.sublist(1).join('>'));

  if (response.isEmpty) return;
  _pendingResponse?.complete(response); // 待機中のCompleterを解決
}
```

#### コマンド送信

```dart
Future<String?> _sendCommand(String command, {Duration timeout = const Duration(seconds: 3)}) async {
  _pendingResponse = Completer<String>();
  final useWwr = _writeChar!.properties.writeWithoutResponse;
  await _writeChar!.write(command.codeUnits, withoutResponse: useWwr);
  return await _pendingResponse!.future.timeout(timeout).catchError((_) => null);
}
```

#### サービス・キャラクタリスティック探索

優先順位: FFF0 → FFE0 → 全サービスの順で探索。
- Notify プロパティを持つキャラクタリスティック → `_notifyChar`
- Write / WriteWithoutResponse プロパティ → `_writeChar`

---

## 6. OBDデータ解析仕様

### エラー判定（共通）

レスポンスに以下が含まれる場合は値を更新しない:
`NO DATA` / `ERROR` / `?` / `STOPPED`

### RPM（PID: `010C`）

```
計算式: (A * 256 + B) / 4
ヘッダなし: "41 0C A0 00" → parts[2]=A, parts[3]=B
ヘッダあり: "7E8 04 41 0C A0 00" → parts[4]=A, parts[5]=B
ヘッダ判定: parts[0]が長さ3かつ'7'始まり → ヘッダあり
```

### 冷却水温（PID: `0105`）

```
計算式: A - 40 [℃]
ヘッダなし: "41 05 7B" → parts[2]=A → 0x7B - 40 = 83℃
```

### 油温（PID: `2101` / Mode 21 Subaru固有）★BRZ ZC6専用

**送信前に必ず `ATSH 7E0\r` を送信すること。**

```
計算式: A - 40 [℃]
（TorquePro設定では "AC-40" と表記されるが、C は Celsius の意で A - 40 が正しい式）

ELM327 は ISO 15765 マルチフレーム形式で返す:
"01F 00: 61 01 [A] [B] [C] ... 01: [D] [E] ... 02: ..."

  01F    = 残りバイト数（0x1F = 31バイト）
  00:    = フレーム0の識別子
  61     = Mode 21 レスポンス (0x40 + 0x21)
  01     = PID
  [A]    = 最初のデータバイト = 油温生値

油温 = parts[4] - 40（マルチフレーム形式の場合）
```

**実車ログ例（エンジン始動後暖機中）:**
```
TX: ATSH 7E0  →  RX: OK
TX: 2101
RX: 01F 00: 61 01 66 00 47 02 01: 62 2E 56 42 67 7A 11 02: 47 00 00 09 0D 2B 55 03: 23 22 00 FF 20 0C 4A 04: E7 36 C2 72 00 00 00
  → parts[4] = "66" = 0x66 = 102 → 102 - 40 = 62℃
TX: ATSH 7DF  →  RX: OK
```

**パーサー実装:**

```dart
int _parseOilTemp(String response) {
  final parts = response.split(' ').where((s) => s.isNotEmpty).toList();
  final int idxA;
  if (parts.length > 1 && parts[1].endsWith(':')) {
    idxA = 4; // マルチフレーム "01F 00: 61 01 [A]..."
  } else if (parts[0].length == 3 && parts[0].startsWith('7')) {
    idxA = 4; // ヘッダあり "7E8 XX 61 01 [A]..."
  } else {
    idxA = 2; // ヘッダなし "61 01 [A]..."
  }
  if (parts.length <= idxA) throw FormatException('...');
  return int.parse(parts[idxA], radix: 16) - 40;
}
```

### 各PIDのタイムアウト設定

| PID | タイムアウト | 理由 |
|-----|------------|------|
| `010C` (RPM) | 800ms | 標準PID、高速応答 |
| `0105` (水温) | 800ms | 標準PID、高速応答 |
| `ATSH 7E0/7DF` | 500ms | ATコマンド、即応答 |
| `2101` (油温) | 3000ms | マルチフレーム組み立てに時間がかかる |

---

## 7. BLE通信仕様

- **Service UUID:** FFF0（プライマリ）、FFE0（フォールバック）
- **Write Characteristic:** FFF2（または `write`/`writeWithoutResponse` プロパティを持つもの）
- **Notify Characteristic:** FFF1（または `notify` プロパティを持つもの）
- **MTU:** 256バイトをリクエスト
- **コマンド形式:** UTF-8 文字列の codeUnits を write
- **応答終端:** `>` プロンプト（複数BLEパケットに分割して届く場合あり → StringBufferで蓄積）
- **応答待機:** Completer<String> パターン（_sendCommand が await で同期的に待つ）

---

## 8. 画面実装仕様

### ScanBlePage

- `BluetoothController` を `Get.put()` で初期化
- `Obx` で `adapterState` を監視
  - `on` → `FindDevicesPage()`
  - `off` → `BluetoothOffPage()`
  - その他 → `CircularProgressIndicator(color: Color(0xFF58A6FF))`

---

### BluetoothOffPage

Bluetooth が無効なことを伝えるシンプルな画面。アイコンとテキストのみ。

---

### FindDevicesPage

- `onInit` で権限チェック後スキャン開始
- `ListView.builder` でスキャン結果を表示
- 各デバイスタイル: デバイス名・RSSI・MACアドレス
- FAB: スキャン開始/停止トグル
- タップ → `_connect()` → `OBDController` を `Get.put()` → `Get.to(DashboardPage)`

---

### DashboardPage

#### 構成

```
Scaffold
  └─ Column
       ├─ _StatusBar（高さ44px）
       ├─ Expanded → _GaugeArea
       └─ _LogPanel（SizedBox.shrink / 実体なし）
```

#### _StatusBar（Color(0xFF161B22)、高さ44px）

```
[車アイコン] [デバイス名 | 接続状態]  [エラーメッセージ]  [ログアイコン] [切断ボタン]
```

- ログアイコン（`Icons.terminal`）タップ → `showModalBottomSheet` で `_LogSheet` 表示
- 切断ボタン: `obd.disconnect()` → `Get.back()`

#### _GaugeArea

```
Row（mainAxisAlignment: spaceEvenly）
  ├─ GaugeWidget(水温, 左)
  ├─ GaugeWidget(RPM, 中央・大)
  └─ GaugeWidget(油温, 右)
```

**ゲージ設定値:**

| ゲージ | label | unit | min | max | warn | danger | size | fontSize |
|--------|-------|------|-----|-----|------|--------|------|----------|
| RPM | `ENGINE RPM` | `rpm` | 0 | 8000 | 6000 | 7000 | 220 | 32 |
| 水温 | `WATER TEMP` | `°C` | 60 | 130 | 100 | 110 | 170 | 26 |
| 油温 | `OIL TEMP` | `°C` | 60 | 150 | 120 | 135 | 170 | 26 |

#### _LogSheet（デバッグログ）

- `showModalBottomSheet` / `isScrollControlled: true` / `enableDrag: false`
- `DraggableScrollableSheet(initialChildSize: 0.75, min: 0.4, max: 0.95)`
- `ListView.builder` でログ一覧（`scrollController` を渡してスクロール可能）
- ログ色分け:
  - TX → `Color(0xFF58A6FF)` （青）
  - RX → `Color(0xFF3FB950)` （緑）
  - ERROR / TIMEOUT → `Color(0xFFF85149)` （赤）
  - その他 → `Color(0xFF8B949E)` （グレー）

---

## 9. GaugeWidget 仕様

`CustomPaint` による自動車メーター風ゲージ。

### 描画仕様

| 項目 | 値 |
|------|----|
| 開始角度 | 150° |
| 掃引角度 | 240° |
| 背景トラック色 | `Color(0xFF1E272E)` |
| ストローク幅 | 14px |
| 目盛り数 | 12分割（3本に1本がメジャー） |

### カラーゾーン

- `0.0 〜 warnFrac` → `normalColor`（デフォルト: 緑 `0xFF4CAF50`）
- `warnFrac 〜 dangerFrac` → `warningColor`（デフォルト: 橙 `0xFFFF9800`）
- `dangerFrac 〜 1.0` → `dangerColor`（デフォルト: 赤 `0xFFF44336`）

### 値表示

- `value != null` → `value.toStringAsFixed(config.decimals)` + 単位
- `value == null` → `'--'`

---

## 10. テーマ・カラーパレット

| 用途 | カラーコード |
|------|------------|
| 背景 | `#0D1117` |
| サーフェス（カード・バー） | `#161B22` |
| アクセント（プライマリ） | `#58A6FF` |
| 通常色（ゲージ） | `#4CAF50` |
| 警告色（ゲージ） | `#FF9800` |
| 危険色（ゲージ） | `#F44336` |

---

## 11. Android 設定

### AndroidManifest.xml 権限

```xml
<!-- Android 12以上 -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE"/>

<!-- Android 11以下 -->
<uses-permission android:name="android.permission.BLUETOOTH"
    android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
    android:maxSdkVersion="30"/>

<!-- BLEスキャン（Android 11以下で必要） -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

---

## 12. 既知の問題・注意事項

| 項目 | 内容 |
|------|------|
| 標準油温PID非対応 | `015C` は BRZ FA20 では NO DATA。Mode 21 `2101` を使う |
| Mode 22 も非動作 | `221305`/`221203` はPIDテスターでは動くがポーリングでは取得不可 |
| ヘッダ切り替えのタイミング | `ATSH 7E0` を init に入れると Mode 01 が1コマンドずれる。`2101` 直前直後のみに設定すること |
| マルチフレームのタイムアウト | `2101` の応答は ISO 15765 マルチフレームで 3000ms 必要 |
| `1003`（診断セッション）は不要 | TorquePro も使っていない。送信するとむしろ不安定になる場合がある |
| ELM327 クローン品 | 安価なクローンでも動作確認済みだが、`ATFCSH`（フローコントロール）は非対応の場合がある |
| レスポンス分割 | BLE Notify は1パケットに収まらない場合があるため `StringBuffer` で `>` まで蓄積が必須 |

---

## 13. TorquePro 参考設定（実車検証済み）

BRZ ZC6 で油温を TorquePro で取得する場合の設定:

| 項目 | 値 |
|------|---|
| OBD2 Mode and PID | `2101` |
| Equation | `A-40`（表記は `AC-40` だが C は Celsius の意） |
| OBD Header | `7E0` |
| Min / Max | `-40` / `215` |
| Unit | `°C` |
| Diagnostic start command | （空欄） |
| Diagnostic stop command | （空欄） |
