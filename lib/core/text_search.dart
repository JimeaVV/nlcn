const _plain = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final _toPlain = {
  for (final entry in _plain.entries)
    for (final rune in entry.value.runes) rune: entry.key.codeUnitAt(0),
};

/// Lower-cases [text] and drops Vietnamese tone marks and diacritics, so
/// "pho" finds "Phở" and "uc ga" finds "Ức gà".
String foldForSearch(String text) => String.fromCharCodes(
    text.toLowerCase().runes.map((rune) => _toPlain[rune] ?? rune));

/// Whether every word of [query] appears in one of [fields], ignoring case
/// and diacritics.
bool matchesSearch(String query, Iterable<String> fields) {
  final words = foldForSearch(query).split(RegExp(r'\s+'))
    ..removeWhere((word) => word.isEmpty);
  if (words.isEmpty) return false;
  final haystack = fields.map(foldForSearch).join(' ');
  return words.every(haystack.contains);
}
