import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'pages/scan_ble_page.dart';
import 'theme/app_colors.dart';

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

  // Request permission for Bluetooth and location services / Bluetooth・位置情報の許可をリクエスト
  await _requestPermissions();

  // Lock to landscape orientation / 横画面固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Hide the status bar and navigation bar / ステータスバー・ナビゲーションバーを非表示
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Prevent sleep / スリープ防止
  await WakelockPlus.enable();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '86BRZ FA20 OBD2 Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        useMaterial3: true,
      ),
      home: const ScanBlePage(),
    );
  }
}
