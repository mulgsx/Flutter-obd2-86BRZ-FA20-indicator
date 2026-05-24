import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../controllers/scanresult_controller.dart';
import '../theme/app_colors.dart';
import 'dashboard_page.dart';

/// BLE device selection screen shown after Bluetooth adapter is confirmed on.
/// Scans for nearby ELM327 adapters; tap a result to connect and open the dashboard.
/// BLE デバイス選択画面（Bluetooth ON 確認後に表示）。
/// 近くの ELM327 アダプターをスキャンし、タップで接続・ダッシュボードへ遷移する。
class FindDevicesPage extends StatelessWidget {
  const FindDevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ScanResultController());

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
              _sectionHeader('Scan Results'),
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

class _DeviceTile extends StatefulWidget {
  final ScanResult result;
  const _DeviceTile({required this.result});

  @override
  State<_DeviceTile> createState() => _DeviceTileState();
}

class _DeviceTileState extends State<_DeviceTile> {
  bool _connecting = false;

  String get _deviceName {
    final name = widget.result.device.platformName;
    if (name.isNotEmpty) return name;
    final advName = widget.result.advertisementData.advName;
    if (advName.isNotEmpty) return advName;
    return widget.result.device.remoteId.str;
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      await widget.result.device.connect(timeout: const Duration(seconds: 15));
      if (!mounted) return;
      await Get.to(() => DashboardPage(device: widget.result.device));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (!msg.contains('disconnected') && !msg.contains('cancel')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _cancelConnect() async {
    if (mounted) setState(() => _connecting = false);
    try {
      await widget.result.device.disconnect();
    } catch (_) {}
  }

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
          // Loading Icon
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
