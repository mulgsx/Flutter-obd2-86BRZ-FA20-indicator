# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Subaru BRZ ZC6 (FA20 engine) specialized OBD2 BLE monitor app built with Flutter. Connects to an ELM327 BLE adapter and displays real-time RPM, water temperature, and oil temperature on a dashboard with automotive-style gauges.

## Commands

```bash
# Run on connected device (Android primary target)
flutter run

# Build APK
flutter build apk

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Analyze code
flutter analyze

# Format code
dart format lib/
```

## Architecture

**State management:** GetX (`get: ^4.7.2`). All reactive state uses `.obs` properties; UI rebuilds via `Obx()` widgets. Navigation via `Get.to()` / `Get.back()`. Controllers registered with `Get.put()`.

**Navigation flow:**
```
main.dart → ScanBlePage (BT adapter check)
  ├─ BT ON  → FindDevicesPage (scan & pair)
  └─ BT ON + device selected → DashboardPage (live monitoring)
```

**Controller responsibilities:**
- `BluetoothController` — adapter state (on/off) stream
- `ScanResultController` — BLE scan lifecycle, device list
- `OBDController` — core engine: device connection, ELM327 AT init, PID polling loop, response parsing, debug log buffer

**OBD communication cycle (OBDController):**
1. Connect → negotiate MTU 256 → discover GATT services
2. Find FFF0 service (fallback: FFE0) → locate notify + write characteristics
3. Send AT initialization sequence: `ATZ → ATE0 → ATH0 → ATL0 → ATS1 → ATSP0` (300ms between each)
4. Poll PID queue cyclically: `['010C\r', '0105\r', '2213 05\r']` (RPM, water temp, oil temp)
5. Buffer notify stream data until `>` prompt, then resolve Completer and parse response

**Response parsing:**
- Supports header-on (`7E8 04 41 0C A0 00`) and header-off (`41 0C A0 00`) formats
- RPM: `(A*256 + B) / 4`, Temp: `A - 40`
- Oil temp PID `2213 05` is Mode 22 (BRZ-specific, currently returning NO DATA — see `OIL_TEMP_INVESTIGATION.md`)

**GaugeWidget** uses `CustomPaint` with a 150° start / 240° sweep arc, color-coded segments per threshold zones defined in `GaugeConfig`.

## BLE Protocol Details

- **Service UUID:** FFF0 (primary), FFE0 (fallback)
- **Characteristics:** FFF1 (notify/read), FFF2 (write)
- ELM327 commands sent as UTF-8 codeUnits; responses collected until `>` terminator

See `SPEC_BRZ.md` for complete AT command sequences and PID specifications.

## Known Issues

- **Oil temperature (PID `2213 05`)** returns NO DATA during automated polling despite showing data in manual PID testers. Leading hypothesis: Extended Diagnostic Session (`1003`) may be required before Mode 22. Details in `OIL_TEMP_INVESTIGATION.md`.
- Widget test (`test/widget_test.dart`) is a Flutter starter placeholder, not app-specific.

## UI Notes

- Landscape-only, immersive (no status bar), wake lock enabled — configured in `main.dart` at startup
- Dark theme: background `#0D1117`, surface `#161B22`, accent `#58A6FF`
- Dashboard gauge layout: water temp (left) | RPM (center, larger) | oil temp (right)
- Debug log panel (modal bottom sheet) color-codes TX=blue, RX=green, ERROR/TIMEOUT=red
