# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

Subaru BRZ ZC6 / Toyota 86 (FA20 engine) specialized OBD2 BLE monitor app built with Flutter. Connects to an ELM327 BLE adapter and displays real-time RPM, water temperature, and oil temperature on a dashboard with automotive-style gauges.

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
  └─ device selected → DashboardPage (live monitoring)
```

**Controller responsibilities:**
- `BluetoothController` — adapter state (on/off) stream
- `ScanResultController` — BLE scan lifecycle, device list
- `OBDController` — core engine: device connection, ELM327 AT init, PID polling loop, response parsing, debug log buffer

**OBD communication cycle (OBDController):**
1. Connect → negotiate MTU 256 → discover GATT services
2. Find FFF0 service (fallback: FFE0) → locate notify + write characteristics
3. Send AT initialization sequence: `ATZ → ATE0 → ATH0 → ATL0 → ATS1 → ATSP0` (300ms between each)
4. Poll PID queue cyclically: `['010C\r', '0105\r', '2101\r']` (RPM, water temp, oil temp)
5. Buffer notify stream data until `>` prompt, then resolve Completer and parse response

**Oil temp special handling:** PID `2101` requires the CAN header to be set to `7E0` (engine ECU). The polling loop sends `ATSH 7E0\r` immediately before `2101\r`, then resets with `ATSH 7DF\r` after. This header switch must NOT be in the init sequence — doing so causes Mode 01 responses to lag by one command.

**Response parsing:**
- Supports header-on (`7E8 04 41 0C A0 00`), header-off (`41 0C A0 00`), and ISO 15765 multi-frame (`01F 00: 61 01 XX ...`) formats
- RPM: `(A*256 + B) / 4`, Water temp: `A - 40`
- Oil temp: ELM327 returns a multi-frame response; byte A is at `parts[4]` when `parts[1].endsWith(':')`. Formula: `A - 40`

**GaugeWidget** uses `CustomPaint` with a 150° start / 240° sweep arc, color-coded segments per threshold zones defined in `GaugeConfig`.

## BLE Protocol Details

- **Service UUID:** FFF0 (primary), FFE0 (fallback)
- **Characteristics:** notify + write (discovered by property, not fixed UUID)
- ELM327 commands sent as UTF-8 codeUnits; responses buffered in `StringBuffer` until `>` terminator

See `SPEC_BRZ.md` for the full specification including verified real-car logs.

## UI Notes

- Landscape-only, immersive (no status bar), wake lock enabled — configured in `main.dart` at startup
- Dark theme: background `#0D1117`, surface `#161B22`, accent `#58A6FF`
- Dashboard gauge layout: water temp (left) | RPM (center, larger) | oil temp (right)
- Debug log panel: `DraggableScrollableSheet` (75–95% height), `enableDrag: false` to prevent scroll/dismiss conflict, TX=blue, RX=green, ERROR/TIMEOUT=red
