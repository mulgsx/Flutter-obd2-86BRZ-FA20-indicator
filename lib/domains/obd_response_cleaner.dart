class OBDResponseCleaner {
  const OBDResponseCleaner._();

  static List<String> clean(List<String> parts) {
    if (parts.isEmpty) return parts;

    if (parts.length > 1 && _isFrameLineNumber(parts[1])) {
      return parts.skip(2).where((part) => !_isFrameLineNumber(part)).toList();
    }

    if (parts.length > 2 && _isCanHeader(parts[0])) {
      return parts.sublist(2);
    }

    return parts;
  }

  static bool _isFrameLineNumber(String part) => part.trim().endsWith(':');

  static bool _isCanHeader(String part) {
    final normalized = part.trim().toUpperCase();
    return normalized.length == 3 && normalized.startsWith('7');
  }
}
