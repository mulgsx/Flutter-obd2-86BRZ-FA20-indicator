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
    final btCtrl = Get.put(BluetoothController());

    return Obx(() {
      final state = btCtrl.adapterState.value;

      if (state == BluetoothAdapterState.on) {
        return const FindDevicesPage();
      } else if (state == BluetoothAdapterState.off) {
        return const BluetoothOffPage();
      } else {
        // Transitional states: unknown / turningOn / turningOff / 遷移状態
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }
    });
  }
}
