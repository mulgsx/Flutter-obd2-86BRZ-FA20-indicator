import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../controllers/scanresult_controller.dart';
import '../theme/app_colors.dart';
import 'dashboard_page.dart';

// ---------------------------------------------------------------------------
// FindDevicesPage / BLEデバイス選択画面
// ---------------------------------------------------------------------------

/// BLE device selection screen shown after Bluetooth adapter is confirmed on.
/// Scans for nearby ELM327 adapters; tap a result to connect and open the dashboard.
/// BLE デバイス選択画面（Bluetooth ON 確認後に表示）。
/// 近くの ELM327 アダプターをスキャンし、タップで接続・ダッシュボードへ遷移する。
class FindDevicesPage extends StatelessWidget {
  const FindDevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Registers ScanResultController to manage BLE scan lifecycle.
    // ScanResultController を登録し、BLEスキャンのライフサイクルを管理する。
    final ctrl = Get.put(ScanResultController());

    // Deferred to post-frame so the widget tree is ready before requesting permissions.
    // ウィジェットツリーの構築完了後に権限確認とスキャンを開始する。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl.requestPermissionsAndScan();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          '86BRZ FA20 OBD2 — Select Device',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          // Navigates to the dashboard without a real device (device: null = demo mode).
          // 実機なしでダッシュボードへ遷移する（device: null = デモモード）
          TextButton(
            onPressed: () => Get.to(() => const DashboardPage()),
            child: const Text(
              'DEMO',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Obx(() {
        // Permissions not yet granted and no cached results → show guidance.
        // 権限未取得かつスキャン結果なし → 権限案内を表示
        if (!ctrl.permissionGranted.value && ctrl.scanResultList.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Bluetooth・位置情報の権限が必要です。\n「許可」を選択してください。\nBluetooth and location permissions are required. \nPlease select “Allow.”',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ctrl.startScan(),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              SafeArea(
                bottom: false,
                child: _sectionHeader('Scan Results'),
              ),
              if (ctrl.scanResultList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'Device not found',
                    style: TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 13,
                    ),
                  ),
                ),
              // Spread operator: expands all scan results into the children list as _DeviceTile widgets.
              // Empty list adds nothing; non-empty list adds one tile per device.
              // スプレッド演算子: スキャン結果を _DeviceTile に変換して children へ展開する。
              // リストが空なら何も追加されず、要素があればデバイス数分のタイルが追加される。
              ...ctrl.scanResultList.map((r) => _DeviceTile(result: r)),
            ],
          ),
        );
      }),

      // Scan toggle button: red "Stop" while scanning, blue "Start" when idle.
      // スキャン切り替えボタン: スキャン中は赤の「停止」、待機中は青の「開始」
      floatingActionButton: Obx(
        () => FloatingActionButton.extended(
          backgroundColor: ctrl.isScanning.value
              ? Colors.red.shade700
              : AppColors.primaryVariant,
          onPressed: () {
            ctrl.isScanning.value ? ctrl.stopScan() : ctrl.startScan();
          },
          icon: Icon(
            ctrl.isScanning.value ? Icons.stop : Icons.search,
            color: AppColors.textPrimary,
          ),
          label: Text(
            ctrl.isScanning.value ? 'Stop scanning' : 'Start scanning',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  // Small section title above the device list (blue, wide letter-spacing).
  // デバイスリスト上部に表示するセクション見出し（青・字間広め）
  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      title,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 12,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// _DeviceTile / スキャン結果の1行ウィジェット
// ---------------------------------------------------------------------------

/// A single row in the scan result list showing device name, RSSI, and MAC address.
/// Tap to connect; tap again while connecting to cancel.
///
/// スキャン結果リストの1行。デバイス名・RSSI・MACアドレスを表示する。
/// タップで接続開始、接続中に再タップでキャンセル。
class _DeviceTile extends StatefulWidget {
  final ScanResult result;
  const _DeviceTile({required this.result});

  @override
  State<_DeviceTile> createState() => _DeviceTileState();
}

class _DeviceTileState extends State<_DeviceTile> {
  bool _connecting = false;

  // ---------------------------------------------------------------------------
  // Device Name / デバイス名の解決
  // ---------------------------------------------------------------------------

  // Resolves the display name: platformName → advName → MAC address (fallback).
  // 表示名の優先順位: platformName → advName → MACアドレス（フォールバック）
  String get _deviceName {
    final name = widget.result.device.platformName;
    if (name.isNotEmpty) return name;
    final advName = widget.result.advertisementData.advName;
    if (advName.isNotEmpty) return advName;
    return widget.result.device.remoteId.str;
  }

  // ---------------------------------------------------------------------------
  // Connection / 接続・キャンセル
  // ---------------------------------------------------------------------------

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      // try: BLE connect → navigate to dashboard on success.
      // try: BLE接続 → 成功したらダッシュボードへ遷移
      await widget.result.device.connect(timeout: const Duration(seconds: 15));
      if (!mounted) return;
      await Get.to(() => DashboardPage(device: widget.result.device));
    } catch (e) {
      // catch: connection error → show snackbar (except user-initiated cancel).
      // catch: 接続エラー → スナックバーで通知（ユーザーによるキャンセルは除外）
      if (!mounted) return;
      final msg = e.toString();
      // 'disconnected' and 'cancel' are expected when the user taps to abort — suppress those errors.
      // ユーザーがタップでキャンセルした場合は 'disconnected'/'cancel' が来るため、エラー表示しない。
      if (!msg.contains('disconnected') && !msg.contains('cancel')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      // finally: always reset spinner regardless of success or failure.
      // finally: 成功・失敗どちらでも必ずスピナーをリセットする
      if (mounted) setState(() => _connecting = false);
    }
  }

  // Called when the user taps the tile while connecting to abort the attempt.
  // 接続中にタイルをタップしたときに呼ばれ、接続試行を中断する。
  Future<void> _cancelConnect() async {
    // Reset spinner first so the UI responds immediately.
    // 先にスピナーをリセットしてUIをすぐに反応させる。
    if (mounted) setState(() => _connecting = false);
    try {
      await widget.result.device.disconnect();
    } catch (_) {}
    // Errors on disconnect during cancel are irrelevant — always suppress.
    // キャンセル中の切断エラーは無関係なため常に無視する。
  }

  // ---------------------------------------------------------------------------
  // Build / ウィジェット構築
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const Icon(Icons.bluetooth, color: AppColors.primary),
      title: Text(
        _deviceName,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'RSSI: ${widget.result.rssi} dBm  •  ${widget.result.device.remoteId.str}',
        style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
      ),
      trailing: _connecting
          // Connecting in progress → replace chevron with spinner.
          // 接続中 → 矢印アイコンをスピナーに切り替え
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : const Icon(Icons.chevron_right, color: AppColors.textDisabled),
      onTap: _connecting ? _cancelConnect : _connect,
    );
  }
}
