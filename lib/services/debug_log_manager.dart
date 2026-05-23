import 'dart:convert';
import 'package:get/get.dart';
import '../models/debug_log.dart';

/// OBD パースログを蓄積し、各形式でエクスポートする。
/// OBDController のフィールドとして保持する（GetxService 不要）。
class DebugLogManager {
  static const int maxLogs = 500;

  final debugLogs = <DebugLogEntry>[].obs;

  void addLog(DebugLogEntry entry) {
    debugLogs.insert(0, entry);
    if (debugLogs.length > maxLogs) {
      debugLogs.removeRange(maxLogs, debugLogs.length);
    }
  }

  void clearLogs() => debugLogs.clear();

  List<DebugLogEntry> getByCategory(String category) =>
      debugLogs.where((l) => l.category == category).toList();

  String exportAsPlainText() {
    if (debugLogs.isEmpty) return '（ログなし）';
    final buf = StringBuffer()
      ..writeln('=== BRZ OBD2 Debug Log Export ===')
      ..writeln('Exported: ${DateTime.now().toIso8601String()}')
      ..writeln('Total Entries: ${debugLogs.length}')
      ..writeln('');
    for (final log in debugLogs) {
      buf.writeln(log.toPlainText());
    }
    return buf.toString();
  }

  String exportAsCSV() {
    if (debugLogs.isEmpty) return '';
    final buf = StringBuffer()
      ..writeln('Timestamp,Category,PID,Mode,RawResponse,'
          'FrameType,DataIndex,ByteValue,Formula,Result,Unit,Status,Error');
    for (final log in debugLogs.reversed) {
      buf.writeln(log.toCSV());
    }
    return buf.toString();
  }

  String exportAsJSON() {
    if (debugLogs.isEmpty) return '[]';
    return const JsonEncoder.withIndent('  ')
        .convert(debugLogs.reversed.map((l) => l.toJson()).toList());
  }
}
