import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../controllers/bluetooth_controller.dart';
import '../theme/app_colors.dart';
import 'bluetooth_off_page.dart';
import 'find_devices_page.dart';

class ScanBlePage extends StatelessWidget {
  const ScanBlePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Registers BluetoothController and starts listening to the adapter state stream.
    // BluetoothController を登録し、アダプター状態ストリームの監視を開始する。
    final btCtrl = Get.put(BluetoothController());

    return Obx(() {
      final state = btCtrl.adapterState.value;

      // BT ON → device selection screen / BT ON → デバイス選択画面
      if (state == BluetoothAdapterState.on) return const FindDevicesPage();

      // BT OFF → prompt user to enable Bluetooth / BT OFF → Bluetooth ONを促す案内画面
      if (state == BluetoothAdapterState.off) return const BluetoothOffPage();

      // Transitional states (unknown / turningOn / turningOff) → loading indicator
      // 遷移状態（unknown / turningOn / turningOff）→ ローディング表示
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    });
  }
}
