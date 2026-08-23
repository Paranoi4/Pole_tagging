import 'dart:convert';

/// An error returned by the Poletagging API.
///
/// FastAPI reports failures in two different shapes, both under `detail`:
///
///   * `HTTPException` -> `{"detail": "Invalid username or password"}`
///   * 422 validation  -> `{"detail": [{"loc": [...], "msg": "..."}, ...]}`
///
/// The backend writes messages meant to be read by the user ("This account uses
/// Google sign-in. Please continue with Google."), so both shapes are flattened
/// into [message] rather than discarded in favour of a bare status code.
///
/// [toString] returns [message] alone, so the existing screens - which render
/// `e.toString()` - show the backend's wording without any change.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  /// Builds an exception from a failed response, using [fallback] only when the
  /// body carries no usable `detail` (an HTML error page, an empty body, a
  /// gateway failure).
  factory ApiException.fromResponse(
    int statusCode,
    String body, {
    required String fallback,
  }) {
    return ApiException(statusCode, _extractDetail(body) ?? fallback);
  }

  static String? _extractDetail(String body) {
    if (body.isEmpty) return null;

    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }

    if (decoded is! Map) return null;
    final detail = decoded['detail'];

    if (detail is String) {
      return detail.isEmpty ? null : detail;
    }

    if (detail is List) {
      final messages = detail
          .whereType<Map>()
          .map(_describeValidationError)
          .where((message) => message.isNotEmpty)
          .toList();
      return messages.isEmpty ? null : messages.join('\n');
    }

    return null;
  }

  /// Turns one 422 entry - `{"loc": ["body", "password"], "msg": "String should
  /// have at least 8 characters"}` - into
  /// `password: String should have at least 8 characters`.
  static String _describeValidationError(Map error) {
    final msg = error['msg'];
    if (msg is! String || msg.isEmpty) return '';

    final loc = error['loc'];
    if (loc is! List || loc.isEmpty) return msg;

    // Drop the leading "body"/"query"/"path" segment: it names the part of the
    // request, not the field the user filled in.
    final field = loc
        .skip(1)
        .map((segment) => segment.toString())
        .where((segment) => segment.isNotEmpty)
        .join('.');

    return field.isEmpty ? msg : '$field: $msg';
  }

  @override
  String toString() => message;
}
