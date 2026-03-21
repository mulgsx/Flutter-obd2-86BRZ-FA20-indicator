import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanResultController extends GetxController {
  var scanResultList = <ScanResult>[].obs;
  var isScanning = false.obs;
  var permissionGranted = false.obs;

  @override
  void onInit() {
    FlutterBluePlus.isScanning.listen((v) => isScanning.value = v);
    super.onInit();
  }

  Future<void> requestPermissionsAndScan() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = statuses.values.every(
      (s) => s == PermissionStatus.granted,
    );
    permissionGranted.value = allGranted;

    if (allGranted) startScan();
  }

  void startScan() {
    scanResultList.clear();
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    FlutterBluePlus.scanResults.listen((results) {
      scanResultList.assignAll(results);
    });
  }

  void stopScan() => FlutterBluePlus.stopScan();

  @override
  void onClose() {
    stopScan();
    super.onClose();
  }
}
