import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../controllers/obd_controller.dart';
import '../models/gauge_config.dart';
import '../widgets/gauge_widget.dart';

/// OBDデータをゲージで表示するメイン画面。
/// ゲージを追加・変更する場合は [_buildGauges] を編集する。
class DashboardPage extends StatelessWidget {
  final BluetoothDevice device;

  const DashboardPage({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final obd = Get.put(OBDController(device));

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Column(
        children: [
          _StatusBar(obd: obd),
          Expanded(child: _GaugeArea(obd: obd)),
          _LogPanel(obd: obd),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ステータスバー
// ---------------------------------------------------------------------------

class _StatusBar extends StatelessWidget {
  final OBDController obd;
  const _StatusBar({required this.obd});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: Color(0xFF58A6FF), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Obx(() => Text(
                  '${obd.device.platformName.isNotEmpty ? obd.device.platformName : obd.device.remoteId.str}'
                  '  |  ${_statusLabel(obd.status.value)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                )),
          ),
          Obx(() => obd.status.value == OBDStatus.error
              ? Text(
                  obd.statusMessage.value,
                  style: TextStyle(color: Colors.red.shade400, fontSize: 11),
                )
              : const SizedBox.shrink()),
          const SizedBox(width: 12),
          _LogToggleButton(obd: obd),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              obd.disconnect();
              Get.back();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('切断', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _statusLabel(OBDStatus s) => switch (s) {
        OBDStatus.disconnected => '切断',
        OBDStatus.connecting => '接続中...',
        OBDStatus.initializing => '初期化中...',
        OBDStatus.polling => 'ポーリング中',
        OBDStatus.error => 'エラー',
      };
}

// ---------------------------------------------------------------------------
// ゲージエリア
// ---------------------------------------------------------------------------

class _GaugeArea extends StatelessWidget {
  final OBDController obd;
  const _GaugeArea({required this.obd});

  // ----------------------------------------------------------------
  // ゲージ設定。新しいゲージを追加する場合はここを編集する。
  // ----------------------------------------------------------------
  static const _rpmConfig = GaugeConfig(
    label: 'ENGINE RPM',
    unit: 'rpm',
    minValue: 0,
    maxValue: 8000,
    warningThreshold: 6000,
    dangerThreshold: 7000,
    size: 220,
    valueFontSize: 32,
  );

  static const _waterConfig = GaugeConfig(
    label: 'WATER TEMP',
    unit: '°C',
    minValue: 60,
    maxValue: 130,
    warningThreshold: 100,
    dangerThreshold: 110,
    size: 170,
    valueFontSize: 26,
  );

  static const _oilConfig = GaugeConfig(
    label: 'OIL TEMP',
    unit: '°C',
    minValue: 60,
    maxValue: 150,
    warningThreshold: 120,
    dangerThreshold: 135,
    size: 170,
    valueFontSize: 26,
  );

  @override
  Widget build(BuildContext context) {
    return Obx(() => _buildGauges(obd));
  }

  /// ゲージのレイアウトを組み立てる。
  /// 新しいゲージを追加する場合はここに [GaugeWidget] を追加する。
  Widget _buildGauges(OBDController obd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 左: 水温
        GaugeWidget(
          config: _waterConfig,
          value: obd.waterTemp.value?.toDouble(),
        ),

        // 中央: RPM（大きめ）
        GaugeWidget(
          config: _rpmConfig,
          value: obd.rpm.value?.toDouble(),
        ),

        // 右: 油温
        GaugeWidget(
          config: _oilConfig,
          value: obd.oilTemp.value?.toDouble(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// デバッグログパネル（トグル表示）
// ---------------------------------------------------------------------------

class _LogToggleButton extends StatefulWidget {
  final OBDController obd;
  const _LogToggleButton({required this.obd});

  @override
  State<_LogToggleButton> createState() => _LogToggleButtonState();
}

class _LogToggleButtonState extends State<_LogToggleButton> {
  bool _showLog = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_showLog) {
          Navigator.of(context).pop();
          setState(() => _showLog = false);
        } else {
          setState(() => _showLog = true);
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF161B22),
            enableDrag: false,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            builder: (_) => _LogSheet(obd: widget.obd),
          ).whenComplete(() {
            if (mounted) setState(() => _showLog = false);
          });
        }
      },
      child: Icon(
        Icons.terminal,
        color: _showLog ? const Color(0xFF58A6FF) : Colors.white38,
        size: 18,
      ),
    );
  }
}

class _LogPanel extends StatelessWidget {
  final OBDController obd;
  const _LogPanel({required this.obd});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _LogSheet extends StatelessWidget {
  final OBDController obd;
  const _LogSheet({required this.obd});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Text(
                  'デバッグログ',
                  style: TextStyle(
                    color: Color(0xFF58A6FF),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF30363D), height: 1),
          Expanded(
            child: Obx(() => ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  itemCount: obd.logs.length,
                  itemBuilder: (_, i) {
                    final log = obd.logs[i];
                    Color color = const Color(0xFF8B949E);
                    if (log.contains('TX:')) color = const Color(0xFF58A6FF);
                    if (log.contains('RX:')) color = const Color(0xFF3FB950);
                    if (log.contains('ERROR') || log.contains('TIMEOUT')) {
                      color = const Color(0xFFF85149);
                    }
                    return Text(
                      log,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    );
                  },
                )),
          ),
        ],
      ),
    );
  }
}
