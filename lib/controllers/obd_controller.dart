import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

enum OBDStatus { disconnected, connecting, initializing, polling, error }

/// OBD通信のメインコントローラー。
/// 接続 → ATコマンド初期化 → PIDポーリング の状態機械を管理する。
class OBDController extends GetxController {
  final BluetoothDevice device;
  OBDController(this.device);

  // --- 観測可能な状態 ---
  final status = OBDStatus.disconnected.obs;
  final statusMessage = ''.obs;
  final rpm = Rxn<int>();
  final waterTemp = Rxn<int>();
  final oilTemp = Rxn<int>();
  final logs = <String>[].obs;

  // --- 内部状態 ---
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  Completer<String>? _pendingResponse;
  final StringBuffer _buffer = StringBuffer();
  bool _polling = false;

  /// ポーリング対象のPIDリスト（BRZ ZC6対応）。
  /// 追加・変更するにはこのリストを編集する。
  final List<String> _pidQueue = [
    '010C\r', // RPM
    '0105\r', // 冷却水温
    '2101\r', // 油温（Mode 21 Subaru固有 + ATSH 7E0）
  ];
  int _pidIndex = 0;

  @override
  void onInit() {
    super.onInit();
    _start();
  }

  @override
  void onClose() {
    _polling = false;
    device.disconnect();
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // 接続・初期化
  // ---------------------------------------------------------------------------

  Future<void> _start() async {
    try {
      status.value = OBDStatus.connecting;
      _log('デバイスに接続中...');
      await device.connect(timeout: const Duration(seconds: 15));
      await device.requestMtu(256);

      _log('サービスを探索中...');
      final services = await device.discoverServices();

      if (!_findCharacteristics(services)) {
        _setError('対応サービスが見つかりません (FFF0/FFE0)');
        return;
      }

      await _notifyChar!.setNotifyValue(true);
      _notifyChar!.onValueReceived.listen(_onData);

      status.value = OBDStatus.initializing;
      _log('ELM327を初期化中...');
      await _sendInitSequence();

      status.value = OBDStatus.polling;
      _log('ポーリング開始');
      _polling = true;
      _pollingLoop();
    } catch (e) {
      _setError('接続エラー: $e');
    }
  }

  /// FFF0 → FFE0 → 全サービスの順でキャラクタリスティックを探索する。
  bool _findCharacteristics(List<BluetoothService> services) {
    for (final targetUuid in ['fff0', 'ffe0']) {
      for (final service in services) {
        if (!service.uuid.toString().toLowerCase().contains(targetUuid)) {
          continue;
        }
        for (final char in service.characteristics) {
          if (char.properties.notify && _notifyChar == null) {
            _notifyChar = char;
          }
          if ((char.properties.write || char.properties.writeWithoutResponse) &&
              _writeChar == null) {
            _writeChar = char;
          }
        }
        if (_notifyChar != null && _writeChar != null) return true;
      }
    }
    // フォールバック: 全サービスを探索
    for (final service in services) {
      for (final char in service.characteristics) {
        if (char.properties.notify && _notifyChar == null) _notifyChar = char;
        if ((char.properties.write || char.properties.writeWithoutResponse) &&
            _writeChar == null) {
          _writeChar = char;
        }
      }
    }
    return _notifyChar != null && _writeChar != null;
  }

  // ---------------------------------------------------------------------------
  // BLEデータ受信
  // ---------------------------------------------------------------------------

  void _onData(List<int> data) {
    final s = String.fromCharCodes(data);
    _buffer.write(s);
    final buffered = _buffer.toString();

    if (!buffered.contains('>')) return;

    final parts = buffered.split('>');
    final response = parts.first.trim();
    _buffer.clear();
    // '>' の後に残ったデータがあれば次のバッファへ
    if (parts.length > 1) _buffer.write(parts.sublist(1).join('>'));

    if (response.isEmpty) return;
    _log('RX: $response');

    final pending = _pendingResponse;
    if (pending != null && !pending.isCompleted) {
      pending.complete(response);
    }
  }

  // ---------------------------------------------------------------------------
  // コマンド送信
  // ---------------------------------------------------------------------------

  Future<String?> _sendCommand(String command,
      {Duration timeout = const Duration(seconds: 3)}) async {
    if (_writeChar == null) return null;
    _log('TX: ${command.trim()}');

    _pendingResponse = Completer<String>();
    final completer = _pendingResponse!;

    final useWwr = _writeChar!.properties.writeWithoutResponse;
    await _writeChar!.write(command.codeUnits, withoutResponse: useWwr);

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _log('TIMEOUT: ${command.trim()}');
      return null;
    } catch (_) {
      return null;
    } finally {
      if (_pendingResponse == completer) _pendingResponse = null;
    }
  }

  Future<void> _sendInitSequence() async {
    final cmds = [
      'ATZ\r',
      'ATE0\r',
      'ATH0\r',
      'ATL0\r',
      'ATS1\r',
      'ATSP0\r',
    ];
    for (final cmd in cmds) {
      await _sendCommand(cmd, timeout: const Duration(seconds: 3));
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  // ---------------------------------------------------------------------------
  // PIDポーリングループ
  // ---------------------------------------------------------------------------

  Future<void> _pollingLoop() async {
    while (_polling) {
      final cmd = _pidQueue[_pidIndex];
      _pidIndex = (_pidIndex + 1) % _pidQueue.length;

      String? response;
      if (cmd == '2101\r') {
        // Mode 21はECU固有ヘッダが必要なため、このコマンドのみ一時的に変更
        await _sendCommand('ATSH 7E0\r',
            timeout: const Duration(milliseconds: 500));
        response = await _sendCommand(cmd,
            timeout: const Duration(milliseconds: 3000));
        await _sendCommand('ATSH 7DF\r',
            timeout: const Duration(milliseconds: 500)); // デフォルトに戻す
      } else {
        response =
            await _sendCommand(cmd, timeout: const Duration(milliseconds: 800));
      }

      if (response != null && response.isNotEmpty) {
        _parseResponse(cmd, response);
      }
    }
  }

  void _parseResponse(String command, String response) {
    try {
      final trimmed = response.trim().toUpperCase();
      if (trimmed.contains('NO DATA') ||
          trimmed.contains('ERROR') ||
          trimmed.contains('?') ||
          trimmed.contains('STOPPED')) {
        return;
      }

      if (command == '010C\r') {
        rpm.value = _parseRpm(trimmed);
      } else if (command == '0105\r') {
        waterTemp.value = _parseTemp(trimmed);
      } else if (command == '2101\r') {
        _log('OIL RAW: $trimmed'); // バイト位置確認用
        oilTemp.value = _parseOilTemp(trimmed);
      }
    } catch (e) {
      _log('PARSE ERR: $e ($response)');
    }
  }

  // ---------------------------------------------------------------------------
  // パーサー（BRZ ZC6対応）
  // ---------------------------------------------------------------------------

  /// RPM: (A*256 + B) / 4
  /// ATH0形式: "41 0C A0 00" → データ開始インデックス=2
  /// ヘッダあり: "7E8 04 41 0C A0 00" → インデックス=4
  int _parseRpm(String response) {
    final parts = _splitHex(response);
    final idx = _dataStartIndex(parts, '0C');
    final a = int.parse(parts[idx], radix: 16);
    final b = int.parse(parts[idx + 1], radix: 16);
    return (a * 256 + b) ~/ 4;
  }

  /// 冷却水温: A - 40 [℃]
  /// "41 05 7B" → 0x7B - 40 = 83℃
  int _parseTemp(String response) {
    final parts = _splitHex(response);
    final idx = _dataStartIndex(parts, '05');
    return int.parse(parts[idx], radix: 16) - 40;
  }

  /// BRZ ZC6 油温 Mode 21: A - 40 [℃]
  /// TorquePro式 AC-40 の C は Celsius の意（A=最初のデータバイト）
  /// マルチフレーム: "01F 00: 61 01 [A] ..." → idxA=4
  /// ヘッダあり:    "7E8 XX 61 01 [A] ..." → idxA=4
  /// ヘッダなし:    "61 01 [A] ..."         → idxA=2
  int _parseOilTemp(String response) {
    final parts = _splitHex(response);
    final int idxA;
    if (parts.length > 1 && parts[1].endsWith(':')) {
      idxA = 4; // マルチフレーム形式 "01F 00: 61 01 [A]"
    } else if (parts[0].length == 3 && parts[0].startsWith('7')) {
      idxA = 4; // ヘッダあり "7E8 XX 61 01 [A]"
    } else {
      idxA = 2; // ヘッダなし "61 01 [A]"
    }
    if (parts.length <= idxA) {
      throw FormatException('Invalid oil temp response: $response');
    }
    return int.parse(parts[idxA], radix: 16) - 40;
  }

  List<String> _splitHex(String response) =>
      response.split(' ').where((s) => s.isNotEmpty).toList();

  /// モード01レスポンスのデータ開始インデックスを返す。
  /// ヘッダあり形式 "7E8 XX 41 PID DATA..." の場合はスキップする。
  int _dataStartIndex(List<String> parts, String pid) {
    if (parts[0].length == 3 && parts[0].startsWith('7')) {
      // ヘッダあり: [7E8, len, 41, PID, DATA...]
      return 4;
    }
    // ヘッダなし: [41, PID, DATA...]
    return 2;
  }

  // ---------------------------------------------------------------------------
  // ユーティリティ
  // ---------------------------------------------------------------------------

  void _setError(String msg) {
    status.value = OBDStatus.error;
    statusMessage.value = msg;
    _log('ERROR: $msg');
  }

  void _log(String msg) {
    logs.insert(0, '[${_timestamp()}] $msg');
    if (logs.length > 50) logs.removeLast();
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  void disconnect() {
    _polling = false;
    device.disconnect();
    status.value = OBDStatus.disconnected;
    statusMessage.value = '';
  }
}
