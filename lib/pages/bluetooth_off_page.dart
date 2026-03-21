import 'package:flutter/material.dart';

class BluetoothOffPage extends StatelessWidget {
  const BluetoothOffPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled,
                size: 80, color: Colors.red.shade400),
            const SizedBox(height: 24),
            const Text(
              'Bluetooth がオフです',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 20,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bluetooth をオンにしてください',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
