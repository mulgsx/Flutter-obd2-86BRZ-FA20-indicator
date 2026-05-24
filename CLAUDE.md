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
  └─ device selected → DashboardPage (live monitoring)
```

**Layer structure:**
- `lib/controllers/` — GetX controllers (BT adapter state, BLE scan, OBD communication)
- `lib/pages/` — Screen widgets; pass device to `DashboardPage(device: null)` for demo mode
- `lib/domains/` — Pure logic: `OBDResponseCleaner` normalizes raw BLE hex parts before parsing
- `lib/services/` — `DebugLogManager` accumulates structured `DebugLogEntry` objects (max 500), exports to plain text / CSV / JSON
- `lib/utils/` — `OBDDebugFormatter` builds `DebugLogEntry` from parse results
- `lib/models/` — Data classes: `GaugeConfig`, `DebugLogEntry`, and `pid_parser.dart` (ported C# scaffolding, not used in main OBD flow)
- `lib/widgets/` — `GaugeWidget` (CustomPaint arc gauge)

**Controller responsibilities:**
- `BluetoothController` — adapter state (on/off) stream
- `ScanResultController` — BLE scan lifecycle, device list
- `OBDController` — core engine: device connection, ELM327 AT init, PID polling loop, response parsing, debug log buffer

**OBD communication cycle (OBDController):**
1. Connect → negotiate MTU 256 → discover GATT services
2. Find FFF0 service (fallback: FFE0) → locate notify + write characteristics by property (not fixed UUID)
3. Send AT initialization sequence: `ATZ → ATE0 → ATH0 → ATL0 → ATS1 → ATSP0` (300ms between each)
4. Poll PID queue cyclically: `['010C\r', '0105\r', '2101\r']` (RPM, water temp, oil temp)
5. Buffer notify stream data until `>` prompt, then resolve Completer and parse response

**Status machine:** `OBDStatus` enum — `disconnected → connecting → initializing → polling → error`

**Oil temp special handling:** PID `2101` requires the CAN header to be set to `7E0` (engine ECU). The polling loop sends `ATSH 7E0\r` immediately before `2101\r`, then resets with `ATSH 7DF\r` after. This header switch must NOT be in the init sequence — doing so causes Mode 01 responses to lag by one command.

## Response Parsing Pipeline

Raw BLE data → `_splitHex()` → `OBDResponseCleaner.clean()` → `_dataStartIndex()` (always returns 2) → formula

**`OBDResponseCleaner.clean()` normalization rules:**
- If `parts[1]` ends with `:` → multi-frame ISO 15765: strip frame line-number tokens (e.g. `00:`, `01:`)
- Else if `parts[0]` is a 3-char hex starting with `7` → CAN header present: strip first 2 tokens
- Otherwise → pass through unchanged

After cleaning, data bytes always start at index 2 (service byte at [0], PID echo at [1]).

**Formulas:**
- RPM (`010C`): `(parts[2]*256 + parts[3]) / 4`
- Water temp (`0105`): `parts[2] - 40`
- Oil temp (`2101`): `parts[2 + 28] - 40` (BRZ ZC6 / FA20 — oil temp is at data byte offset 28 in the Mode 21 payload)

## BLE Protocol Details

- **Service UUID:** FFF0 (primary), FFE0 (fallback)
- **Characteristics:** notify + write (discovered by property)
- ELM327 commands sent as UTF-8 codeUnits; responses buffered in `StringBuffer` until `>` terminator

## UI Notes

- Landscape-only, immersive (no status bar), wake lock enabled — configured in `main.dart` at startup
- Dark theme: background `#0D1117`, surface `#161B22`, accent `#58A6FF`
- Dashboard gauge layout: water temp (left) | RPM (center, larger) | oil temp (right)
- Gauge thresholds defined as `GaugeConfig` constants in `_GaugeArea` in `dashboard_page.dart`
- Debug log panel: tap terminal icon in status bar → `DraggableScrollableSheet` (40–95% height), `enableDrag: false` to prevent scroll/dismiss conflict; three views: リアルタイム (structured) / CSV / JSON; export copies to clipboard
