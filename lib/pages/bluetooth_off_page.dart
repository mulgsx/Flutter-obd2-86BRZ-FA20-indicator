import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BluetoothOffPage extends StatelessWidget {
  const BluetoothOffPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled,
                size: 80, color: Colors.red.shade400),
            const SizedBox(height: 24),
            const Text(
              'Bluetooth is Off',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 20,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please turn on Bluetooth',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
