/// Parses a number typed by the user. Vietnamese writes decimals with a
/// comma ("70,5"), which is also how the app displays them, so both a comma
/// and a dot are accepted. Returns null for anything else.
double? parseDecimal(String? text) {
  final value = double.tryParse((text ?? '').trim().replaceAll(',', '.'));
  return value != null && value.isFinite ? value : null;
}
