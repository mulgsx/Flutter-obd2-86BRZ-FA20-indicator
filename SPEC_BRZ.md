# BRZ（ZC6）OBD2 BLE モニターアプリ 仕様書

> flutter_ble_obd (https://github.com/lxcao/flutter_ble_obd) をベースにした**スバル BRZ ZC6専用**の再利用可能な設計仕様

---

## 1. 技術スタック

| 項目 | 採用技術 |
|------|---------|
| フレームワーク | Flutter |
| 言語 | Dart |
| Bluetooth | BLE（Bluetooth Low Energy） |
| BTパッケージ | `flutter_blue_plus`（flutter_blue の後継・現行推奨） |
| 状態管理 | **GetX** |
| 対象OS | Android（将来的にiOS対応可能） |
| 対象車種 | **スバル BRZ ZC6**（FA20E エンジン搭載） |

### pubspec.yaml 依存パッケージ

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_blue_plus: ^1.x.x     # BLE通信
  get: ^4.x.x                   # 状態管理・ルーティング
  permission_handler: ^11.x.x   # 実行時権限
```

---

## 2. BLE 通信仕様

### ELM327 BLE アダプタの通信構造

```
GATT Server（ELM327アダプタ）
  └─ Service UUID: FFF0
       ├─ Characteristic（Write用）: FFF1 または FFF2
       └─ Characteristic（Notify用）: FFF1 または FFF2
```

- **Write**: コマンドをバイト列で書き込む（`withoutResponse: true`）
- **Notify**: レスポンスを非同期で受け取る（`setNotifyValue(true)` で購読）
- **MTU**: 256 バイトをリクエストする

### 接続フロー

```
1. BLEスキャン開始（timeout: 15秒）
2. デバイスフィルタリング（デバイス名で判別）
3. connect()
4. requestMtu(256)
5. discoverServices()
6. Service UUID "FFF0" を特定
7. Characteristic を特定し Notify を有効化
8. ATコマンドで初期化
```

### データ送受信

```dart
// 送信: String → List<int>（codeUnits）に変換して write
await characteristic.write(command.codeUnits, withoutResponse: true);

// 受信: Notify で List<int> を受け取り String に変換
characteristic.onValueReceived.listen((List<int> data) {
  String response = String.fromCharCodes(data);
  // レスポンスをパース
});
```

---

## 3. ATコマンド定義

### 初期化シーケンス（接続後に順番に送信）

> **BRZ実装メモ**: `ATH0`（ヘッダオフ）+ `ATS1`（スペースオン）を採用。
> ヘッダなし・スペースあり形式（`41 05 7B`）がパースしやすく、実装も安定。

| コマンド文字列 | 意味 |
|-------------|------|
| `ATZ\r`   | デバイスリセット（全設定初期化） |
| `ATE0\r`  | エコーオフ（送信コマンドをレスポンスに含めない） |
| `ATH0\r`  | ヘッダオフ（BRZ推奨） |
| `ATL0\r`  | 改行コードオフ（CR のみ） |
| `ATS1\r`  | スペースオン（バイト間にスペースを入れる） |
| `ATSP0\r` | プロトコル自動検出 |

### OBD2 データリクエストコマンド（標準PID）

| 識別子 | コマンド文字列 | 取得データ |
|-------|-------------|---------|
| `RPM` | `010C\r`  | エンジン回転数 |
| `SPD` | `010D\r`  | 車速 |
| `TMP` | `0105\r`  | 冷却水温度 |
| `VIN` | `0902\r`  | 車台番号（VIN） |
| `GEN` | `0100\r`  | サポートPIDマップ（疎通確認用） |

### **BRZ ZC6専用：油温データリクエストコマンド（Mode 21）**

| 識別子 | コマンド文字列 | 取得データ | 備考 |
|-------|-------------|---------|------|
| `OIL_TEMP` | `2101\r` | **エンジンオイル温度** | **BRZ ZC6のみ対応。送信前に `ATSH 7E0` 必須** |

> **重要**：標準PID `015C` は **BRZ ZC6では非対応**。
> Mode 21（スバル固有）の `2101` を使用する。送信ヘッダを `7E0`（エンジンECU）に設定する必要がある。
> Mode 22（`221305` / `221203`）はPIDテスターではHAS DATAになるが、ポーリングでは取得不可。
> 参考：TorquePro カスタムPID設定 PID=`2101` / 式=`A-40` / ヘッダ=`7E0`

### コマンド定義の実装例

```dart
// lib/commands/obd_commands.dart

const String returnSymbol  = '\r';   // 0x0D
const String promptSymbol  = '>';    // 0x3E
const String spaceSymbol   = ' ';
const String colonSymbol   = ':';

// ATコマンドマップ
const Map<String, String> atCommands = {
  'ATZ':   'ATZ\r',
  'ATE0':  'ATE0\r',
  'ATH0':  'ATH0\r',        // BRZ採用
  'ATL0':  'ATL0\r',
  'ATSP0': 'ATSP0\r',
  'ATI':   'ATI\r',         // バージョン確認
};

// OBDデータコマンドマップ（標準PID）
const Map<String, String> obdCommands = {
  'RPM': '010C\r',
  'SPD': '010D\r',
  'TMP': '0105\r',
  'VIN': '0902\r',
  'GEN': '0100\r',
};

// BRZ ZC6専用：拡張PID（Mode 22）
const Map<String, String> brzExtendedCommands = {
  'OIL_TEMP': '2213 05\r',  // エンジンオイル温度（Mode 22）
};
```

---

## 4. OBDデータ解析仕様

### レスポンス形式

ELM327 は受信データを 16進数 ASCII 文字列で返す。

```
例（RPM - 標準PID）:
  送信: "010C\r"
  受信: "41 0C 1A F8\r>"

例（油温 - BRZ ZC6 Mode 22）:
  送信: "22 13 05\r"
  受信: "62 13 05 5C\r>"
```

### 解析処理

受信した `List<int>` を `String.fromCharCodes()` で文字列化し、
スペース区切りで分割して各バイトを解析する。

```dart
// lib/utils/string_util.dart
List<String> transferListInt2ListString(List<int> data, String delimiter) {
  return String.fromCharCodes(data).split(delimiter);
}

// lib/utils/ascii_util.dart
int transferHexString2DecInt(String hex) => int.parse(hex, radix: 16);
```

### 各PIDの計算式

```dart
// lib/services/obd_parse_service.dart

class ObdParseService {
  final List<int> buffer;
  ObdParseService({required this.buffer});

  // RPM: (A << 8 | B) / 4
  // 受信例: "41 0C 1A F8" → stringList[2]="1A", [3]="F8"
  // (0x1A << 8 | 0xF8) / 4 = 6904 / 4 = 1726 RPM
  int parseRpm() {
    final list = transferListInt2ListString(buffer, ' ');
    return (transferHexString2DecInt(list[2] + list[3]) ~/ 4);
  }

  // 速度: A [km/h]
  // 受信例: "41 0D 50" → stringList[2]="50" → 80 km/h
  int parseSpeed() {
    final list = transferListInt2ListString(buffer, ' ');
    return transferHexString2DecInt(list[2]);
  }

  // 冷却水温度: A - 40 [℃]
  // 受信例: "41 05 7B" → 0x7B(=123) - 40 = 83℃
  int parseTemperature() {
    final list = transferListInt2ListString(buffer, ' ');
    return transferHexString2DecInt(list[2]) - 40;
  }

  // 燃料残量: A * 100 / 255 [%]
  // 受信例: "41 2F 80" → 128 * 100 / 255 ≈ 50.2%
  double parseFuelLevel() {
    final list = transferListInt2ListString(buffer, ' ');
    return 100.0 * transferHexString2DecInt(list[2]) / 255.0;
  }

  // ===== BRZ ZC6 専用 =====
  // 油温（Mode 22）: A - 40 [℃]
  // リクエスト: "22 13 05\r"
  // レスポンス: "62 13 05 XX\r>"
  // 計算: XX(16進) - 40 = 油温（℃）
  // 例: "62 13 05 5C" → 0x5C(=92) - 40 = 52℃
  int parseOilTemperatureBRZ() {
    final list = transferListInt2ListString(buffer, ' ');
    
    // ヘッダなし形式: "62 13 05 XX"
    // インデックス[3]がデータバイト
    if (list.length >= 4) {
      return transferHexString2DecInt(list[3]) - 40;
    }
    
    // ヘッダあり形式対応: "7E8 05 62 13 05 XX"
    // インデックス[5]がデータバイト
    if (list.length >= 6) {
      return transferHexString2DecInt(list[5]) - 40;
    }
    
    throw Exception('Invalid oil temperature response');
  }

  // VIN（車台番号）: マルチフレームレスポンスを":"で分割して再構成
  // 受信例（3フレーム）:
  //   "0: 49 02 01 xx xx xx xx"
  //   "1: xx xx xx xx xx xx xx"
  //   "2: xx xx xx xx xx xx xx"
  String parseVin() {
    final frames = transferListInt2ListString(buffer, ':');
    final bytes = <int>[];
    final f1 = frames[1].trim().split(' ').sublist(4, 7);
    final f2 = frames[2].trim().split(' ').sublist(1, 8);
    final f3 = frames[3].trim().split(' ').sublist(1, 8);
    for (final b in [...f1, ...f2, ...f3]) {
      bytes.add(int.parse(b, radix: 16));
    }
    return String.fromCharCodes(bytes);
  }
}
```

---

## 5. 状態管理（GetX）

### コントローラー一覧

| ファイル | クラス名 | 責務 |
|--------|---------|------|
| `bluetooth_controller.dart` | `BlueToothController` | BT有効/無効状態の監視 |
| `scanresult_controller.dart` | `ScanResultController` | スキャン結果リストの管理 |
| `bluetooth_devices_controller.dart` | `BluetoothDevicesController` | 接続済みデバイス一覧（10秒ポーリング） |
| `bluetooth_device_state_controller.dart` | `BluetoothDeviceStateController` | 個別デバイスの接続状態・MTU・サービス |
| `bluetooth_device_service_characteristic_controller.dart` | `BluetoothDeviceCharacteristicController` | キャラクタリスティックの読み書き・Notify |

### コントローラー設計パターン

```dart
// 基本パターン
class XxxController extends GetxController {
  // 観測可能な状態（.obs）
  var someState = initialValue.obs;

  @override
  void onInit() {
    _fetchData();
    super.onInit();
  }

  void _fetchData() {
    someStream.listen((value) {
      someState.value = value;
    });
  }
}

// View 側での使用
final controller = Get.put(XxxController());
Obx(() => Text('${controller.someState.value}'));
```

### 各コントローラーの実装仕様

#### BlueToothController
```dart
class BlueToothController extends GetxController {
  var bluetoothstate = BluetoothState.off.obs;

  @override
  void onInit() {
    FlutterBluePlus.adapterState.listen((state) {
      bluetoothstate.value = state;
    });
    super.onInit();
  }
}
```

#### ScanResultController
```dart
class ScanResultController extends GetxController {
  var scanResultList = <ScanResult>[].obs;
  var isScanning = false.obs;

  void startScan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    FlutterBluePlus.scanResults.listen((results) {
      scanResultList.assignAll(results);
    });
    FlutterBluePlus.isScanning.listen((v) => isScanning.value = v);
  }

  void stopScan() => FlutterBluePlus.stopScan();
}
```

#### BluetoothDevicesController
```dart
class BluetoothDevicesController extends GetxController {
  var bluetoothDeviceList = <BluetoothDevice>[].obs;

  @override
  void onInit() {
    // 10秒ごとに接続済みデバイスを更新
    Stream.periodic(const Duration(seconds: 10))
        .asyncMap((_) => FlutterBluePlus.connectedDevices)
        .listen((devices) => bluetoothDeviceList.assignAll(devices));
    super.onInit();
  }
}
```

#### BluetoothDeviceStateController
```dart
class BluetoothDeviceStateController extends GetxController {
  final BluetoothDevice device;
  BluetoothDeviceStateController(this.device);

  var connectionState = BluetoothConnectionState.disconnected.obs;
  var isDiscoveringServices = false.obs;
  var mtu = 0.obs;
  var services = <BluetoothService>[].obs;

  @override
  void onInit() {
    device.connectionState.listen((s) => connectionState.value = s);
    device.mtu.listen((v) => mtu.value = v);
    device.services.listen((s) => services.assignAll(s));
    super.onInit();
  }

  Future<void> requestMtu() => device.requestMtu(256);
}
```

#### BluetoothDeviceCharacteristicController（**BRZ対応版**）
```dart
class BluetoothDeviceCharacteristicController extends GetxController {
  final BluetoothCharacteristic characteristic;
  BluetoothDeviceCharacteristicController(this.characteristic);

  var notifyValue = <int>[].obs;
  StringBuffer _responseBuffer = StringBuffer();  // BRZ: レスポンス蓄積用

  @override
  void onInit() {
    characteristic.setNotifyValue(true);
    
    // ✅ BRZ対応: onValueReceived を使う（BLE通知専用ストリーム）
    characteristic.onValueReceived.listen((data) {
      final s = String.fromCharCodes(data);
      
      // '>' プロンプト終端まで蓄積
      if (s.contains('>')) {
        _responseBuffer.writeln(s);
        // バッファをパース＆更新
        final response = _responseBuffer.toString();
        if (!response.trim().startsWith('>') && !response.trim().isEmpty) {
          notifyValue.assignAll(response.codeUnits);
        }
        _responseBuffer.clear();
      } else if (!s.startsWith('\r') && !s.startsWith('>')) {
        _responseBuffer.write(s);
      }
    });
    super.onInit();
  }

  Future<void> write(String command) async {
    // BRZ対応: writeWithoutResponse プロパティを確認
    final useWwr = characteristic.properties.writeWithoutResponse;
    await characteristic.write(command.codeUnits, withoutResponse: useWwr);
  }
}
```

---

## 6. 画面構成

### 画面遷移図

```
main.dart
  └─ ScanBlePage（ホーム・Bluetooth状態監視）
       ├─ Bluetooth OFF → BluetoothOffPage
       └─ Bluetooth ON  → FindDevicesPage（デバイス一覧）
                            └─ ELM327をタップ → Elm327DevicePage（OBD通信）
```

### 各画面の仕様

#### ScanBlePage
- `BlueToothController` を `Get.put()` で初期化
- `Obx` で `bluetoothstate` を監視し条件分岐
- Bluetooth ON → `FindDevicesPage`
- Bluetooth OFF → `BluetoothOffPage`

#### BluetoothOffPage
- Bluetooth 無効時のエラー表示のみ
- アイコン + 状態テキスト

#### FindDevicesPage
- `ScanResultController`・`BluetoothDevicesController` を使用
- 接続済みデバイスセクション（10秒ポーリング）
- スキャン結果セクション（Notify）
- FABでスキャン開始/停止
- デバイスフィルター: 名前で判別（例: "OBDII", "IOS-Vlink", "LE-Midnight"）
- タップ → `connect()` → `Elm327DevicePage` へ

#### Elm327DevicePage（BRZ対応版）
- `BluetoothDeviceStateController` を使用
- 接続/切断ボタン
- `discoverServices()` → Service一覧表示
- **BRZ ZC6油温取得ボタン**付き
- `Elm327CharacteristicTile` でOBD操作UI

### Elm327CharacteristicTile ウィジェット（BRZ拡張版）

```
┌─────────────────────────────────────┐
│  [ATZ] [ATSP0] [ATI]  ← ATコマンド  │
│                                     │
│  [GEN] [VIN] [SPD] [RPM] ← OBDリクエスト（標準）│
│                                     │
│  ⭐ [OIL_TEMP] ← BRZ ZC6専用油温   │
│                                     │
│  レスポンス表示エリア               │
│  ┌─────────────────────────┐        │
│  │  62 13 05 5C            │        │
│  │  → 52 °C（油温）         │        │
│  └─────────────────────────┘        │
└─────────────────────────────────────┘
```

---

## 7. ファイル構成

```
lib/
├── main.dart                    # エントリーポイント・GetMaterialApp
├── pages/
│   ├── scan_ble_page.dart       # ホーム（BT状態振り分け）
│   ├── bluetooth_off_page.dart  # BT無効画面
│   ├── find_devices_page.dart   # デバイス一覧・スキャン
│   └── elm327_device_page.dart  # OBD通信メイン画面（BRZ対応）
├── controllers/
│   ├── bluetooth_controller.dart
│   ├── scanresult_controller.dart
│   ├── bluetooth_devices_controller.dart
│   ├── bluetooth_device_state_controller.dart
│   └── bluetooth_device_service_characteristic_controller.dart
├── services/
│   └── obd_parse_service.dart   # OBDデータ解析ロジック（BRZ拡張）
├── commands/
│   └── obd_commands.dart        # ATコマンド・OBDコマンド定数（BRZ拡張）
├── widgets/
│   ├── scan_result_tile_widget.dart
│   ├── elm327_service_tile_widget.dart
│   └── elm327_characteristic_tile_widget.dart
└── utils/
    ├── string_util.dart          # List<int>⇔String変換
    └── ascii_util.dart           # 16進数文字列→10進数変換
```

---

## 8. Android 権限設定（BRZ対応）

### AndroidManifest.xml

```xml
<!-- Android 11以下 -->
<uses-permission android:name="android.permission.BLUETOOTH"
    android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"
    android:maxSdkVersion="30"/>

<!-- Android 12以上 -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>

<!-- BLEスキャンに必要（Android 11以下） -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### 実行時権限リクエスト（permission_handler）

```dart
// Android 12+
await [
  Permission.bluetoothScan,
  Permission.bluetoothConnect,
  Permission.locationWhenInUse,
].request();
```

---

## 9. main.dart の実装（BRZ対応）

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'pages/scan_ble_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'BRZ ZC6 OBD2 Monitor',  // BRZ明記
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ScanBlePage(),
    );
  }
}
```

---

## 10. OBDデータポーリング実装例（BRZ対応）

元リポジトリはボタン操作式だが、自動ポーリングに拡張する場合の実装例：

```dart
// 自動ポーリング（elm327_device_page.dart 内）
Timer? _pollingTimer;

// BRZ ZC6対応：標準PIDと拡張PIDを混合
final _pidQueue = [
  '010C\r',      // RPM（標準）
  '010D\r',      // SPD（標準）
  '0105\r',      // 冷却水温（標準）
  '2213 05\r',   // 油温（BRZ ZC6 Mode 22）⭐
  '012F\r',      // 燃料レベル（標準）
];
int _pidIndex = 0;

void startPolling(BluetoothDeviceCharacteristicController ctrl) {
  _pollingTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
    ctrl.write(_pidQueue[_pidIndex]);
    _pidIndex = (_pidIndex + 1) % _pidQueue.length;
  });
}

void stopPolling() => _pollingTimer?.cancel();
```

---

## 11. 注意事項・既知の問題点（BRZ ZC6対応）

| 項目 | 内容 |
|------|------|
| `flutter_blue` は非推奨 | 後継の `flutter_blue_plus` を使用すること |
| GetX バージョン | `get: ^4.x.x`（`^3.x.x` はDart 3非対応） |
| BLE vs Classic | **BRZ用ELM327はBluetooth Classic（従来型）** |
| **BRZ油温取得** | **標準PID 0x5C は非対応。Mode 22拡張PID `2213 05` を使用必須** |
| VINのマルチフレーム | ISO 15765-4（CAN）のみ対応。古いプロトコルでは取得不可 |
| レスポンス終端 | `>` プロンプトが終端。Notifyは複数回に分割して届く場合がある |
| MTU | 256バイトをリクエストするが、実際の値はデバイス側に依存 |
| **`onValueReceived` 必須** | **BLE Notifyの受信には `onValueReceived` を使用。`lastValueStream` は避ける** |
| `write` プロパティ確認 | 書き込み前に `properties.writeWithoutResponse` を確認し、`withoutResponse` 引数を適切に設定すること |
| サービスUUID多様性 | 安価なアダプタは FFF0 以外に FFE0 も使う。FFF0 → FFE0 → 全サービスの順で探索すること |

---

## 12. BRZ ZC6 専用仕様

### エンジン情報
- **エンジン型式**: FA20E
- **排気量**: 1,998cc
- **最高出力**: 200PS
- **OBD-II対応**: 2012年以降のモデル対応

### 油温（Engine Oil Temperature）取得仕様

| 項目 | 値 |
|-----|---|
| **PIDコマンド** | `2101\r` |
| **プロトコル** | Mode 21（スバル固有） |
| **送信ヘッダ** | `7E0`（`ATSH 7E0` で設定、送信後 `ATSH 7DF` で戻す） |
| **レスポンス形式** | ISO 15765 マルチフレーム `01F 00: 61 01 [A] [B] [C] ... 01: ... 02: ...` |
| **計算式** | `A - 40`（A = `61 01` 直後の最初のデータバイト） |
| **範囲** | -40 ～ 215℃ |
| **精度** | 1℃単位 |
| **タイムアウト** | 3000ms（マルチフレーム組み立てに時間がかかるため長めに設定） |

> **TorquePro設定との対応**
> PID=`2101` / 式=`AC-40`（AがデータバイトでCはCelsiusの意）/ ヘッダ=`7E0` / 診断開始コマンドなし

### ヘッダ切り替え手順

Mode 01（RPM・水温）と Mode 21（油温）でECUアドレスが異なるため、コマンドごとにヘッダを切り替える：

```
[通常ポーリング]
  010C\r  ← 標準ヘッダ(7DF)のまま
  0105\r  ← 標準ヘッダ(7DF)のまま

[油温取得時のみ]
  ATSH 7E0\r  ← エンジンECUへ直接指定
  2101\r      ← 油温リクエスト（タイムアウト3000ms）
  ATSH 7DF\r  ← 標準ブロードキャストに戻す
```

### レスポンス例（実車ログ）

```
リクエスト:  "2101\r"
レスポンス: "01F 00: 61 01 66 00 47 02 01: 62 2E 56 42 67 7A 11 02: 47 00 00 09 0D 2B 55 03: 23 22 00 FF 20 0C 4A 04: E7 36 C2 72 00 00 00"

パース:
  - 01F     = 残りバイト数（31バイト）
  - 00:     = フレーム番号
  - 61 01   = Mode 21 レスポンス（0x40+0x21=0x61）、PID=01
  - 66      = データバイトA = 0x66 = 102
  - 油温    = 102 - 40 = 62℃
```

### パーサー実装

```dart
int parseOilTemp(String response) {
  final parts = response.split(' ').where((s) => s.isNotEmpty).toList();

  // マルチフレーム: "01F 00: 61 01 [A] ..."  → index=4
  // ヘッダあり:    "7E8 XX 61 01 [A] ..."    → index=4
  // ヘッダなし:    "61 01 [A] ..."            → index=2
  final int idxA;
  if (parts.length > 1 && parts[1].endsWith(':')) {
    idxA = 4; // マルチフレーム
  } else if (parts[0].length == 3 && parts[0].startsWith('7')) {
    idxA = 4; // ヘッダあり
  } else {
    idxA = 2; // ヘッダなし
  }
  return int.parse(parts[idxA], radix: 16) - 40;
}
```

---

## 13. BLE 通信 実装上の注意（BRZ実車検証で判明）

### 通知ストリーム（BRZ対応）
```dart
// ❌ 旧：lastValueStream はパケットを取りこぼす
characteristic.lastValueStream.listen(...)

// ✅ 正：onValueReceived を使う（BLE通知専用ストリーム）
characteristic.onValueReceived.listen(...)
```

### 書き込みプロパティ確認（BRZ対応）
```dart
// writeWithoutResponse か write かを事前確認して適切に送信
final useWwr = characteristic.properties.writeWithoutResponse;
await characteristic.write(cmd.codeUnits, withoutResponse: useWwr);
```

### レスポンスバッファリング
ELM327 は1つのレスポンスを複数の BLE Notify パケットに分割して送信することがある。
`>` プロンプトが来るまで `StringBuffer` に蓄積してから処理すること。

### レスポンス形式（ヘッダあり・なし両対応）
```
ヘッダなし（ATH0）: "41 05 7B"
ヘッダあり（ATH1）: "7E8 04 41 05 7B"
先頭トークンが `7` で始まる3文字の場合はヘッダ+データ長として `startIdx = 2` にスキップする。

BRZ Mode 22 レスポンス（ヘッダなし）: "62 13 05 5C"
BRZ Mode 22 レスポンス（ヘッダあり）: "7E8 05 62 13 05 5C"
```

### 状態機械
```
IDLE → INIT（ATコマンド6本、各3sタイムアウト）→ POLLING（PIDをサイクル）
タイムアウト時は次のコマンドへ進む（スキップ）
```

---

## 14. 追加機能

### PIDテスター（pid_tester_page.dart）
- 接続中にダッシュボードの🔍ボタンから起動
- ポーリングを一時停止して任意のPIDを1発送信
- レスポンスをHAS DATA / NO DATA / TIMEOUT で判定
- BRZ/ZC6(FA20) など非標準車種のPID探索に使用

### デバッグログパネル（dashboard_page.dart）
- ダッシュボードの🐛ボタンでトグル
- TX/RX/RESP/タイムアウトをリアルタイム表示（最新30件）

### スリープ防止・横画面固定・フルスクリーン（main.dart）
```dart
await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
await WakelockPlus.enable();
```
必要パッケージ: `wakelock_plus: ^1.2.8`

---

## 15. 拡張候補（BRZ対応）

- [ ] 水温・油温・排気温の同時ダッシュボード表示
- [ ] DTC（エラーコード）読み取り・クリア（Mode 03 / Mode 04）
- [ ] グラフ表示（rpm/speed/oil_temp の時系列）
- [ ] データ記録・CSV出力（走行ログ）
- [ ] 警告ライン設定（油温が80℃以上でアラート等）
- [ ] VIN から車両情報を外部APIで取得
- [ ] OBDLink MX+ など他社製アダプタ対応

---

## 16. トラブルシューティング（BRZ特有）

### 症状: 油温が表示されない
**原因1**: 標準PID `0x5C` / `015C` を使用している → BRZ FA20は非対応
**解決1**: Mode 21 PID `2101\r` に変更し、送信前に `ATSH 7E0\r` を送信

**原因2**: `ATSH 7E0` をinit全体に設定している
**解決2**: Mode 01コマンドが遅延しレスポンスがずれる。`ATSH 7E0` は `2101` 送信直前のみに設定し、直後に `ATSH 7DF` で戻す

**原因3**: タイムアウトが短い
**解決3**: `2101` はマルチフレームのため応答に時間がかかる。タイムアウトを3000ms以上に設定

### 症状: ELM327に接続できない
**原因1**: Bluetooth Classic（従来型）の権限不足  
**解決1**: `AndroidManifest.xml` の権限設定を確認

**原因2**: サービスUUIID が FFF0 ではなく FFE0  
**解決2**: FFE0 も探索対象に含める

### 症状: レスポンスが途切れる / パース失敗
**原因**: `lastValueStream` でパケットロス  
**解決**: `onValueReceived` + `StringBuffer` でバッファリング

---

## 付録：完全な油温パース実装（実車検証済み）

```dart
/// BRZ ZC6 油温パース（Mode 21 / 実車ログで検証済み）
///
/// ELM327 は 2101 の応答をISO 15765マルチフレーム形式で返す:
///   "01F 00: 61 01 66 00 47 02 01: 62 2E ..."
///
/// TorquePro式 AC-40 の A = 最初のデータバイト、C = Celsius（単位）
/// → 実際の計算式は A - 40
int parseOilTemperature(String response) {
  final parts = response.trim().split(' ')
      .where((s) => s.isNotEmpty).toList();

  // マルチフレーム: "01F 00: 61 01 [A]..." → parts[1]が":"終端 → A=index4
  // ヘッダあり:    "7E8 XX 61 01 [A]..."  → parts[0]が"7"始まり3文字 → A=index4
  // ヘッダなし:    "61 01 [A]..."          → A=index2
  final int idxA;
  if (parts.length > 1 && parts[1].endsWith(':')) {
    idxA = 4;
  } else if (parts[0].length == 3 && parts[0].startsWith('7')) {
    idxA = 4;
  } else {
    idxA = 2;
  }

  if (parts.length <= idxA) {
    throw FormatException('Invalid oil temperature response: $response');
  }
  return int.parse(parts[idxA], radix: 16) - 40;
}
```
