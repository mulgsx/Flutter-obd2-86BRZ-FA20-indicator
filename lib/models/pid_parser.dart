/// CSV-based PID definition (corresponds to Parameter.cs in ParsePID).
/// CSV ベース PID 定義（ParsePID の Parameter.cs に対応）
class PIDDefinition {
  final int pid;
  final String shortName;
  final String fullName;
  final String unit;
  final int byteLength;
  final String? formula;
  final int? minDisplay;
  final int? maxDisplay;

  const PIDDefinition({
    required this.pid,
    required this.shortName,
    required this.fullName,
    required this.unit,
    required this.byteLength,
    this.formula,
    this.minDisplay,
    this.maxDisplay,
  });

  @override
  String toString() =>
      'PIDDefinition(0x${pid.toRadixString(16).toUpperCase().padLeft(4, '0')} '
      '$shortName [$unit])';
}

/// Parses PID definitions from CSV (ported from ParseDefCsv.cs).
/// CSV から PID 定義をパースする（ParseDefCsv.cs 移植）
///
/// Expected CSV columns (tab or comma separated):
/// 期待する CSV 列（タブまたはカンマ区切り）:
///   PID, Name_Short, Name_Full, Length, Units[, Formula, MinDisplay, MaxDisplay]
class PIDCSVParser {
  static List<PIDDefinition> parseDefinitions(String csvContent) {
    final result = <PIDDefinition>[];
    for (final rawLine in csvContent.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }
      try {
        final def = _parseLine(line);
        if (def != null) result.add(def);
      } catch (_) {
        // Skip malformed lines / 不正な行はスキップ
      }
    }
    return result;
  }

  static PIDDefinition? _parseLine(String line) {
    final sep = line.contains('\t') ? '\t' : ',';
    final cols = line.split(sep);
    if (cols.length < 5) return null;

    return PIDDefinition(
      pid: _parseHexInt(cols[0].trim()),
      shortName: cols[1].trim(),
      fullName: cols[2].trim(),
      byteLength: int.parse(cols[3].trim()),
      unit: cols[4].trim(),
      formula: cols.length > 5 ? cols[5].trim() : null,
      minDisplay: cols.length > 6 ? int.tryParse(cols[6].trim()) : null,
      maxDisplay: cols.length > 7 ? int.tryParse(cols[7].trim()) : null,
    );
  }

  /// "0x0105" → 261
  static int _parseHexInt(String s) {
    const prefix = '0x';
    final idx = s.toLowerCase().indexOf(prefix);
    if (idx < 0) throw FormatException('Missing 0x prefix: $s');
    return int.parse(s.substring(idx + prefix.length), radix: 16);
  }
}

/// OBD response byte parsing utilities (ported from ParseSupportResponses.cs).
/// OBD レスポンスのバイト解析ユーティリティ（ParseSupportResponses.cs 移植）
class OBDResponseParser {
  /// Converts bytes[index..index+count-1] to an integer in big-endian order.
  /// count must be 1–8.
  /// ビッグエンディアンで bytes[index..index+count-1] を整数に変換。
  /// count は 1〜8。
  ///
  /// Example / 例: bytes=[0x40,0x79,0xC0,0x01], index=0, count=4 → 0x4079C001
  static int parseUIntBigEndian(List<int> bytes, int index, int count) {
    if (count < 1 || count > 8) {
      throw ArgumentError.value(count, 'count', '1 <= count <= 8 required');
    }
    if (index + count > bytes.length) {
      throw RangeError(
          'index=$index count=$count exceeds bytes.length=${bytes.length}');
    }
    int result = 0;
    for (int i = 0; i < count; i++) {
      result = (result << 8) | (bytes[index + i] & 0xFF);
    }
    return result;
  }

  /// Converts a space-separated hex string to a list of bytes.
  /// 空白区切りの16進数文字列をバイトリストに変換。
  ///
  /// Example / 例: "7E8 FF C0 00 03" → [0x7E8, 0xFF, 0xC0, 0x00, 0x03]
  static List<int> parseHexBytes(String response) {
    return response
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => int.parse(s, radix: 16))
        .toList();
  }
}

/// OBD support bitmap processing (ported from Support.cs).
/// OBD サポートビットマップ処理（Support.cs 移植）
class OBDSupport {
  /// Returns whether the specified PID is supported by the ECU's supportValue (32-bit).
  /// bitNr is the 1-based bit position per OBD-II standard (1=MSB, 32=LSB).
  /// ECU からの supportValue (32bit) で指定 PID がサポートされているか判定。
  /// bitNr は OBD-II 標準の 1-based ビット位置 (1=MSB, 32=LSB)。
  ///
  /// Example / 例: supportValue=0x80000000, bitNr=1 → true
  static bool isPIDSupported(int supportValue, int bitNr) {
    if (bitNr < 1 || bitNr > 32) {
      throw ArgumentError.value(bitNr, 'bitNr', '1 <= bitNr <= 32 required');
    }
    return (supportValue & (1 << (32 - bitNr))) != 0;
  }

  /// Returns all PIDs supported by supportValue, relative to startPID.
  /// supportValue でサポートされている全 PID を startPID 相対で返す。
  ///
  /// Example / 例: startPID=0x0000, supportValue=0x80000000 → [0x0001]
  static List<int> getSupportedPIDs(int supportValue, int startPID) {
    final list = <int>[];
    for (int bitNr = 1; bitNr <= 32; bitNr++) {
      if (isPIDSupported(supportValue, bitNr)) {
        list.add(startPID + bitNr);
      }
    }
    return list;
  }
}
