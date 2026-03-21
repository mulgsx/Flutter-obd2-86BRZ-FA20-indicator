import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'pages/scan_ble_page.dart';

Future<void> _requestPermissions() async {
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
    Permission.locationWhenInUse,
  ].request();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bluetooth・位置情報の許可をリクエスト
  await _requestPermissions();

  // 横画面固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // ステータスバー・ナビゲーションバーを非表示（時刻表示なし）
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // スリープ防止
  await WakelockPlus.enable();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'BRZ ZC6 OBD2 Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF58A6FF),
          surface: Color(0xFF161B22),
        ),
        useMaterial3: true,
      ),
      home: const ScanBlePage(),
    );
  }
}
