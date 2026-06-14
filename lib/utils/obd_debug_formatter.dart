import '../models/debug_log.dart';

/// OBD パース結果から構造化 DebugLogEntry を生成する。
class OBDDebugFormatter {
  static DebugLogEntry formatOilTempParse({
    required DateTime timestamp,
    required String rawResponse,
    required List<String> parts,
    required int dataIndex,
    required int byteValue,
    required int result,
    required bool success,
    String? errorMessage,
  }) {
    final frameType = _frameType(parts);
    final byteHex =
        '0x${byteValue.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final details = {
      'frameType': frameType,
      'partsLength': parts.length,
      'dataIndex': dataIndex,
      'byteValue': '$byteHex ($byteValue)',
      'formula': 'A-40',
      'calculation': '$byteValue - 40 = $result',
    };
    final status = success ? 'OK' : 'ERROR${errorMessage != null ? ' [$errorMessage]' : ''}';
    final text = [
      '[${_ts(timestamp)}] [OIL-TEMP] [Mode21:2101]',
      '  Raw: $rawResponse',
      '  Parts(${parts.length}): ${parts.join(' ')}',
      '  Frame: $frameType',
      '  DataIdx: $dataIndex  Byte: $byteHex ($byteValue)',
      '  Formula: A-40  →  $byteValue - 40 = $result℃',
      '  Status: $status',
    ].join('\n');

    return DebugLogEntry(
      timestamp: timestamp,
      category: 'OIL-TEMP',
      pidHex: '0x2101',
      pidMode: 'Mode 21',
      rawResponse: rawResponse,
      parts: parts,
      parseDetails: details,
      result: result.toDouble(),
      resultUnit: '℃',
      success: success,
      errorMessage: errorMessage,
      formattedText: text,
    );
  }

  static DebugLogEntry formatRpmParse({
    required DateTime timestamp,
    required String rawResponse,
    required List<String> parts,
    required int dataIndex,
    required int byteA,
    required int byteB,
    required int result,
    required bool success,
    String? errorMessage,
  }) {
    final frameType = _frameType(parts);
    final hexA = '0x${byteA.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final hexB = '0x${byteB.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final details = {
      'frameType': frameType,
      'partsLength': parts.length,
      'dataIndex': dataIndex,
      'byteValue': '$hexA ($byteA)',
      'formula': '(A*256+B)/4',
      'calculation': '($byteA*256+$byteB)/4 = $result',
    };
    final status = success ? 'OK' : 'ERROR${errorMessage != null ? ' [$errorMessage]' : ''}';
    final text = [
      '[${_ts(timestamp)}] [RPM] [Mode01:010C]',
      '  Raw: $rawResponse',
      '  Parts(${parts.length}): ${parts.join(' ')}',
      '  Frame: $frameType',
      '  DataIdx: $dataIndex  A: $hexA ($byteA)  B: $hexB ($byteB)',
      '  Formula: (A*256+B)/4  →  ($byteA*256+$byteB)/4 = $result rpm',
      '  Status: $status',
    ].join('\n');

    return DebugLogEntry(
      timestamp: timestamp,
      category: 'RPM',
      pidHex: '0x010C',
      pidMode: 'Mode 01',
      rawResponse: rawResponse,
      parts: parts,
      parseDetails: details,
      result: result.toDouble(),
      resultUnit: 'rpm',
      success: success,
      errorMessage: errorMessage,
      formattedText: text,
    );
  }

  static DebugLogEntry formatWaterTempParse({
    required DateTime timestamp,
    required String rawResponse,
    required List<String> parts,
    required int dataIndex,
    required int byteValue,
    required int result,
    required bool success,
    String? errorMessage,
  }) {
    final frameType = _frameType(parts);
    final byteHex =
        '0x${byteValue.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final details = {
      'frameType': frameType,
      'partsLength': parts.length,
      'dataIndex': dataIndex,
      'byteValue': '$byteHex ($byteValue)',
      'formula': 'A-40',
      'calculation': '$byteValue - 40 = $result',
    };
    final status = success ? 'OK' : 'ERROR${errorMessage != null ? ' [$errorMessage]' : ''}';
    final text = [
      '[${_ts(timestamp)}] [WATER-TEMP] [Mode01:0105]',
      '  Raw: $rawResponse',
      '  Parts(${parts.length}): ${parts.join(' ')}',
      '  Frame: $frameType',
      '  DataIdx: $dataIndex  Byte: $byteHex ($byteValue)',
      '  Formula: A-40  →  $byteValue - 40 = $result℃',
      '  Status: $status',
    ].join('\n');

    return DebugLogEntry(
      timestamp: timestamp,
      category: 'WATER-TEMP',
      pidHex: '0x0105',
      pidMode: 'Mode 01',
      rawResponse: rawResponse,
      parts: parts,
      parseDetails: details,
      result: result.toDouble(),
      resultUnit: '℃',
      success: success,
      errorMessage: errorMessage,
      formattedText: text,
    );
  }

  static DebugLogEntry formatIntakeAirTempParse({
    required DateTime timestamp,
    required String rawResponse,
    required List<String> parts,
    required int dataIndex,
    required int byteValue,
    required int result,
    required bool success,
    String? errorMessage,
  }) {
    final frameType = _frameType(parts);
    final byteHex = '0x${byteValue.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final details = {
      'frameType': frameType,
      'partsLength': parts.length,
      'dataIndex': dataIndex,
      'byteValue': '$byteHex ($byteValue)',
      'formula': 'A-40',
      'calculation': '$byteValue - 40 = $result',
    };
    final status = success ? 'OK' : 'ERROR${errorMessage != null ? ' [$errorMessage]' : ''}';
    final text = [
      '[${_ts(timestamp)}] [IAT] [Mode01:010F]',
      '  Raw: $rawResponse',
      '  Parts(${parts.length}): ${parts.join(' ')}',
      '  Frame: $frameType',
      '  DataIdx: $dataIndex  Byte: $byteHex ($byteValue)',
      '  Formula: A-40  →  $byteValue - 40 = $result℃',
      '  Status: $status',
    ].join('\n');
    return DebugLogEntry(
      timestamp: timestamp,
      category: 'IAT',
      pidHex: '0x010F',
      pidMode: 'Mode 01',
      rawResponse: rawResponse,
      parts: parts,
      parseDetails: details,
      result: result.toDouble(),
      resultUnit: '℃',
      success: success,
      errorMessage: errorMessage,
      formattedText: text,
    );
  }

  static DebugLogEntry formatVoltageParse({
    required DateTime timestamp,
    required String rawResponse,
    required List<String> parts,
    required int dataIndex,
    required int byteA,
    required int byteB,
    required double result,
    required bool success,
    String? errorMessage,
  }) {
    final frameType = _frameType(parts);
    final hexA = '0x${byteA.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final hexB = '0x${byteB.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final details = {
      'frameType': frameType,
      'partsLength': parts.length,
      'dataIndex': dataIndex,
      'byteValue': '$hexA ($byteA)',
      'formula': '(A*256+B)/1000',
      'calculation': '($byteA*256+$byteB)/1000 = ${result.toStringAsFixed(3)}',
    };
    final status = success ? 'OK' : 'ERROR${errorMessage != null ? ' [$errorMessage]' : ''}';
    final text = [
      '[${_ts(timestamp)}] [VOLTAGE] [Mode01:0142]',
      '  Raw: $rawResponse',
      '  Parts(${parts.length}): ${parts.join(' ')}',
      '  Frame: $frameType',
      '  DataIdx: $dataIndex  A: $hexA ($byteA)  B: $hexB ($byteB)',
      '  Formula: (A*256+B)/1000  →  ($byteA*256+$byteB)/1000 = ${result.toStringAsFixed(3)}V',
      '  Status: $status',
    ].join('\n');
    return DebugLogEntry(
      timestamp: timestamp,
      category: 'VOLTAGE',
      pidHex: '0x0142',
      pidMode: 'Mode 01',
      rawResponse: rawResponse,
      parts: parts,
      parseDetails: details,
      result: result,
      resultUnit: 'V',
      success: success,
      errorMessage: errorMessage,
      formattedText: text,
    );
  }

  static DebugLogEntry formatAfrParse({
    required DateTime timestamp,
    required String rawResponse,
    required List<String> parts,
    required int dataIndex,
    required int byteA,
    required int byteB,
    required double result,
    required bool success,
    String? errorMessage,
  }) {
    final frameType = _frameType(parts);
    final hexA = '0x${byteA.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final hexB = '0x${byteB.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final details = {
      'frameType': frameType,
      'partsLength': parts.length,
      'dataIndex': dataIndex,
      'byteValue': '$hexA ($byteA)',
      'formula': '(A*256+B)/32768*14.7',
      'calculation': '($byteA*256+$byteB)/32768*14.7 = ${result.toStringAsFixed(2)}',
    };
    final status = success ? 'OK' : 'ERROR${errorMessage != null ? ' [$errorMessage]' : ''}';
    final text = [
      '[${_ts(timestamp)}] [AFR] [Mode01:0134]',
      '  Raw: $rawResponse',
      '  Parts(${parts.length}): ${parts.join(' ')}',
      '  Frame: $frameType',
      '  DataIdx: $dataIndex  A: $hexA ($byteA)  B: $hexB ($byteB)',
      '  Formula: (A*256+B)/32768*14.7  →  ${result.toStringAsFixed(2)} A/F',
      '  Status: $status',
    ].join('\n');
    return DebugLogEntry(
      timestamp: timestamp,
      category: 'AFR',
      pidHex: '0x0134',
      pidMode: 'Mode 01',
      rawResponse: rawResponse,
      parts: parts,
      parseDetails: details,
      result: result,
      resultUnit: 'A/F',
      success: success,
      errorMessage: errorMessage,
      formattedText: text,
    );
  }

  static DebugLogEntry formatThrottleParse({
    required DateTime timestamp,
    required String rawResponse,
    required List<String> parts,
    required int dataIndex,
    required int byteValue,
    required double result,
    required bool success,
    String? errorMessage,
  }) {
    final frameType = _frameType(parts);
    final byteHex = '0x${byteValue.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final details = {
      'frameType': frameType,
      'partsLength': parts.length,
      'dataIndex': dataIndex,
      'byteValue': '$byteHex ($byteValue)',
      'formula': 'A/2.55',
      'calculation': '$byteValue / 2.55 = ${result.toStringAsFixed(1)}',
    };
    final status = success ? 'OK' : 'ERROR${errorMessage != null ? ' [$errorMessage]' : ''}';
    final text = [
      '[${_ts(timestamp)}] [THROTTLE] [Mode01:0111]',
      '  Raw: $rawResponse',
      '  Parts(${parts.length}): ${parts.join(' ')}',
      '  Frame: $frameType',
      '  DataIdx: $dataIndex  Byte: $byteHex ($byteValue)',
      '  Formula: A/2.55  →  $byteValue / 2.55 = ${result.toStringAsFixed(1)}%',
      '  Status: $status',
    ].join('\n');
    return DebugLogEntry(
      timestamp: timestamp,
      category: 'THROTTLE',
      pidHex: '0x0111',
      pidMode: 'Mode 01',
      rawResponse: rawResponse,
      parts: parts,
      parseDetails: details,
      result: result,
      resultUnit: '%',
      success: success,
      errorMessage: errorMessage,
      formattedText: text,
    );
  }

  static String _frameType(List<String> parts) {
    if (parts.isEmpty) return 'Unknown';
    if (parts.length > 1 && parts[1].endsWith(':')) {
      return 'MultiFrame(${parts[0]})';
    }
    if (parts[0].length == 3 && parts[0].startsWith('7')) {
      return 'SingleFrame+Header(${parts[0]})';
    }
    return 'SingleFrame(no header)';
  }

  static String _ts(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}
