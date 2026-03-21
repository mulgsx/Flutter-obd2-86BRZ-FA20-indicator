import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../controllers/scanresult_controller.dart';
import 'dashboard_page.dart';

class FindDevicesPage extends StatelessWidget {
  const FindDevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ScanResultController());

    // 初回起動時に権限確認＆スキャン開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl.requestPermissionsAndScan();
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'BRZ OBD2 — デバイス選択',
          style: TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(() {
        if (!ctrl.permissionGranted.value && ctrl.scanResultList.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Bluetooth・位置情報の権限が必要です。\n「許可」を選択してください。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ctrl.startScan(),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _sectionHeader('スキャン結果'),
              if (ctrl.scanResultList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'デバイスが見つかりません',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ...ctrl.scanResultList.map((r) => _DeviceTile(result: r)),
            ],
          ),
        );
      }),
      floatingActionButton: Obx(() => FloatingActionButton.extended(
            backgroundColor: ctrl.isScanning.value
                ? Colors.red.shade700
                : const Color(0xFF1F6FEB),
            onPressed: () {
              ctrl.isScanning.value
                  ? ctrl.stopScan()
                  : ctrl.startScan();
            },
            icon: Icon(
              ctrl.isScanning.value ? Icons.stop : Icons.search,
              color: Colors.white,
            ),
            label: Text(
              ctrl.isScanning.value ? 'スキャン停止' : 'スキャン開始',
              style: const TextStyle(color: Colors.white),
            ),
          )),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF58A6FF),
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
      await widget.result.device.connect(
        timeout: const Duration(seconds: 15),
      );
      if (!mounted) return;
      await Get.to(() => DashboardPage(device: widget.result.device));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('接続失敗: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: const Color(0xFF161B22),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const Icon(Icons.bluetooth, color: Color(0xFF58A6FF)),
      title: Text(
        _deviceName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'RSSI: ${widget.result.rssi} dBm  •  ${widget.result.device.remoteId.str}',
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      trailing: _connecting
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF58A6FF),
              ),
            )
          : const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: _connecting ? null : _connect,
    );
  }
}
