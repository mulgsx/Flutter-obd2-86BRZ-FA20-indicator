import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

class BluetoothController extends GetxController {
  var adapterState = BluetoothAdapterState.unknown.obs;

  @override
  void onInit() {
    FlutterBluePlus.adapterState.listen((state) {
      adapterState.value = state;
    });
    super.onInit();
  }

  bool get isOn => adapterState.value == BluetoothAdapterState.on;
}
