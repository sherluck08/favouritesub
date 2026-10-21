class FriendlyError {
  static String from(Object? error, {String? fallback}) {
    if (error == null) return fallback ?? _generic;
    final raw = error is String ? error : error.toString();
    return _humanize(raw, fallback: fallback);
  }

  static String sanitize(String message, {String? fallback}) =>
      _humanize(message, fallback: fallback);

  static const String _generic =
      'Something went wrong. Please try again in a moment.';

  static String _humanize(String raw, {String? fallback}) {
    final cleaned = _strip(raw);

    final lower = cleaned.toLowerCase();

    if (lower.contains('failed host lookup') ||
        lower.contains('no address associated') ||
        lower.contains('network is unreachable') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed') ||
        lower.contains('connection abort') ||
        lower.contains('software caused connection') ||
        lower.contains('connection terminated')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (lower.contains('timeoutexception') || lower.contains('timed out')) {
      return 'The request took too long. Please try again.';
    }
    if (lower.contains('handshakeexception') ||
        lower.contains('certificate') ||
        lower.contains('tls')) {
      return 'Secure connection failed. Please try again or update the app.';
    }
    if (lower.contains('formatexception') ||
        lower.contains('unexpected character') ||
        lower.contains('unexpected end of input')) {
      return 'We could not understand the server response. Please try again.';
    }
    if (lower.contains('500 internal') ||
        lower.contains('502 bad gateway') ||
        lower.contains('503 service') ||
        lower.contains('504 gateway')) {
      return 'Server is having issues right now. Please try again shortly.';
    }
    if (lower.contains('401') &&
        (lower.contains('unauthorized') || lower.contains('credentials'))) {
      return 'Your session has expired. Please sign in again.';
    }
    if (lower.contains('403') && lower.contains('forbidden')) {
      return "You don't have permission to perform this action.";
    }

    if (cleaned.isEmpty) return fallback ?? _generic;

    if (_looksTechnical(cleaned)) return fallback ?? _generic;

    return cleaned;
  }

  static String _strip(String raw) {
    var s = raw;
    s = s.replaceAll(RegExp(r'^Exception:\s*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'https?:\/\/\S+'), '');
    s = s.replaceAll(RegExp(r"uri=\S+", caseSensitive: false), '');
    s = s.replaceAll(RegExp(r"host\s*lookup:\s*'[^']*'"), 'network');
    s = s.replaceAll(RegExp(r'\(OS Error:[^)]*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'errno\s*=\s*-?\d+', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\b(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}\b'), '');
    s = s.replaceAll(
      RegExp(
        r'\b(?:ClientException|HttpException|SocketException|TlsException|HandshakeException|FormatException|TimeoutException|FileSystemException|TypeError|RangeError|StateError|ArgumentError)(?:\s+with\s+\w+)?:?',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    s = s.replaceAll(RegExp(r'^[\s,;:.\-]+'), '');
    s = s.replaceAll(RegExp(r'[\s,;:.\-]+$'), '');
    return s.trim();
  }

  static bool _looksTechnical(String s) {
    final t = s.toLowerCase();
    if (t.contains('stacktrace') || t.contains('stack trace')) return true;
    if (t.contains('null check operator')) return true;
    if (t.contains('package:') || t.contains('dart:')) return true;
    if (t.contains('errno') || t.contains('os error')) return true;
    if (t.contains('uri=')) return true;
    if (t.length > 240) return true;
    return false;
  }
}
