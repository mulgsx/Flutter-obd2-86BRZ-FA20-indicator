import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../controllers/obd_controller.dart';
import '../models/gauge_config.dart';
import '../services/debug_log_manager.dart';
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

class _LogSheet extends StatefulWidget {
  final OBDController obd;
  const _LogSheet({required this.obd});

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  /// 'plain' = 構造化ログ表示 / 'csv' / 'json'
  String _format = 'plain';

  @override
  Widget build(BuildContext context) {
    final mgr = widget.obd.debugLogManager;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダ行
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
                _ExportMenuButton(mgr: mgr),
                const SizedBox(width: 4),
                _ClearButton(mgr: mgr),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon:
                      const Icon(Icons.close, color: Colors.white38, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF30363D), height: 1),
          // フォーマット選択ボタン行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _FmtBtn(
                  label: 'リアルタイム',
                  selected: _format == 'plain',
                  onTap: () => setState(() => _format = 'plain'),
                ),
                const SizedBox(width: 6),
                _FmtBtn(
                  label: 'CSV',
                  selected: _format == 'csv',
                  onTap: () => setState(() => _format = 'csv'),
                ),
                const SizedBox(width: 6),
                _FmtBtn(
                  label: 'JSON',
                  selected: _format == 'json',
                  onTap: () => setState(() => _format = 'json'),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF30363D), height: 1),
          // ログ表示エリア
          Expanded(
            child: _LogContent(
              obd: widget.obd,
              format: _format,
              scrollController: scrollController,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ログシート内部ウィジェット群
// ---------------------------------------------------------------------------

class _ExportMenuButton extends StatelessWidget {
  final DebugLogManager mgr;
  const _ExportMenuButton({required this.mgr});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.download, color: Color(0xFF58A6FF), size: 18),
      padding: EdgeInsets.zero,
      color: const Color(0xFF161B22),
      onSelected: (value) async {
        final text = switch (value) {
          'plain' => mgr.exportAsPlainText(),
          'csv' => mgr.exportAsCSV(),
          'json' => mgr.exportAsJSON(),
          _ => '',
        };
        if (text.isEmpty) return;
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('クリップボードにコピーしました'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'plain', child: Text('テキストでコピー')),
        PopupMenuItem(value: 'csv', child: Text('CSVでコピー')),
        PopupMenuItem(value: 'json', child: Text('JSONでコピー')),
      ],
    );
  }
}

class _ClearButton extends StatelessWidget {
  final DebugLogManager mgr;
  const _ClearButton({required this.mgr});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text(
            'ログをクリア',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          content: const Text(
            'すべてのデバッグログを削除します。',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                mgr.clearLogs();
                Navigator.pop(context);
              },
              child:
                  const Text('クリア', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
      icon:
          const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}

class _FmtBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FmtBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? const Color(0xFF58A6FF) : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF58A6FF) : Colors.white54,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _LogContent extends StatelessWidget {
  final OBDController obd;
  final String format;
  final ScrollController scrollController;
  const _LogContent({
    required this.obd,
    required this.format,
    required this.scrollController,
  });

  static const _mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 9,
    height: 1.5,
    color: Color(0xFF8B949E),
  );

  @override
  Widget build(BuildContext context) {
    if (format == 'plain') {
      return Obx(() {
        final logs = obd.debugLogManager.debugLogs;
        if (logs.isEmpty) {
          return const Center(
            child: Text(
              '（ログがまだ記録されていません）',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          );
        }
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: logs.length,
          itemBuilder: (_, i) {
            final entry = logs[i];
            final color = entry.success
                ? const Color(0xFF8B949E)
                : const Color(0xFFF85149);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                entry.formattedText,
                style: _mono.copyWith(color: color),
              ),
            );
          },
        );
      });
    }

    // CSV / JSON: SelectableText で表示
    return Obx(() {
      // debugLogs を参照して変更時に再ビルドさせる
      final _ = obd.debugLogManager.debugLogs.length;
      final text = format == 'csv'
          ? obd.debugLogManager.exportAsCSV()
          : obd.debugLogManager.exportAsJSON();
      if (text.isEmpty) {
        return const Center(
          child: Text(
            '（ログがまだ記録されていません）',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        );
      }
      return SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SelectableText(text, style: _mono),
      );
    });
  }
}
