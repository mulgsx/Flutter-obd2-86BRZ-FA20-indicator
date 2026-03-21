import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../controllers/bluetooth_controller.dart';
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
        // unknown / turningOn / turningOff
        return const Scaffold(
          backgroundColor: Color(0xFF0D1117),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
          ),
        );
      }
    });
  }
}
