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
      // Sort so devices whose name contains "OBD" appear at the top of the list.
      // "OBD" を含むデバイス名をリストの先頭に並べる。
      final sorted = [...results]..sort((a, b) {
        final aName = a.device.platformName.isNotEmpty
            ? a.device.platformName
            : a.advertisementData.advName;
        final bName = b.device.platformName.isNotEmpty
            ? b.device.platformName
            : b.advertisementData.advName;
        final aIsObd = aName.toUpperCase().contains('OBD');
        final bIsObd = bName.toUpperCase().contains('OBD');
        if (aIsObd && !bIsObd) return -1;
        if (!aIsObd && bIsObd) return 1;
        return 0;
      });
      scanResultList.assignAll(sorted);
    });
  }

  void stopScan() => FlutterBluePlus.stopScan();

  @override
  void onClose() {
    stopScan();
    super.onClose();
  }
}
