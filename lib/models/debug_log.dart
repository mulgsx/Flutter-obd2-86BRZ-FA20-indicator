/// Structured debug log entry for one OBD parse result.
/// OBD パース1回分の構造化デバッグログエントリ
class DebugLogEntry {
  final DateTime timestamp;

  /// 'OIL-TEMP' | 'RPM' | 'WATER-TEMP'
  final String category;

  final String? pidHex;
  final String? pidMode;
  final String rawResponse;
  final List<String>? parts;
  final Map<String, dynamic>? parseDetails;
  final double? result;
  final String? resultUnit;
  final bool success;
  final String? errorMessage;

  /// Pre-formatted multi-line text for the log panel display.
  /// ログパネル表示用のフォーマット済みテキスト（複数行）
  final String formattedText;

  const DebugLogEntry({
    required this.timestamp,
    required this.category,
    required this.rawResponse,
    required this.formattedText,
    this.pidHex,
    this.pidMode,
    this.parts,
    this.parseDetails,
    this.result,
    this.resultUnit,
    this.success = true,
    this.errorMessage,
  });

  String toPlainText() => formattedText;

  /// One CSV row (no header) / CSV 1行（ヘッダなし）
  String toCSV() {
    return [
      _esc(timestamp.toIso8601String()),
      _esc(category),
      _esc(pidHex ?? ''),
      _esc(pidMode ?? ''),
      _esc(rawResponse),
      _esc(parseDetails?['frameType']?.toString() ?? ''),
      _esc(parseDetails?['dataIndex']?.toString() ?? ''),
      _esc(parseDetails?['byteValue']?.toString() ?? ''),
      _esc(parseDetails?['formula']?.toString() ?? ''),
      _esc(result?.toString() ?? ''),
      _esc(resultUnit ?? ''),
      _esc(success ? 'OK' : 'ERROR'),
      _esc(errorMessage ?? ''),
    ].join(',');
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'category': category,
        'pidHex': pidHex,
        'pidMode': pidMode,
        'rawResponse': rawResponse,
        'parts': parts,
        'parseDetails': parseDetails,
        'result': result,
        'resultUnit': resultUnit,
        'success': success,
        'errorMessage': errorMessage,
      };

  static String _esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
