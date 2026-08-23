/// Parses a timestamp coming from the Poletagging API.
///
/// The backend declares its columns as `Column(DateTime)` with
/// `default=datetime.utcnow` (no `timezone=True`), so it stores naive UTC and
/// serializes it without a zone designator: `2026-08-24T10:30:00`.
///
/// `DateTime.parse` reads a zone-less string as *local* time, which skews every
/// timestamp by the device's UTC offset (8 hours in the Philippines). Appending
/// `Z` when the server left it off makes the value read as the UTC it really is;
/// the result is then converted to local so existing screens that print it
/// directly show the correct wall-clock time.
DateTime? parseServerDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;

  return DateTime.tryParse(_withZone(value))?.toLocal();
}

final RegExp _explicitOffset = RegExp(r'[+-]\d{2}:?\d{2}$');

String _withZone(String value) {
  // A date with no time part ("2026-08-24") cannot carry a zone designator -
  // appending one makes it unparseable - so leave it alone.
  final hasTimePart = value.contains('T') || value.contains(' ');
  if (!hasTimePart) return value;

  final hasZone = value.endsWith('Z') ||
      value.endsWith('z') ||
      _explicitOffset.hasMatch(value);

  return hasZone ? value : '${value}Z';
}
