import 'dart:typed_data';

/// Rounds the exact binary value to decimal digits, using Python's ties to even.
///
/// Scaling a double first can introduce an extra rounding (for example 2.675).
/// Integer arithmetic keeps the original binary fraction exact until the final
/// decimal result is converted back to a double.
double roundLikePython(double value, {int digits = 2}) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'must be finite');
  }
  if (value == 0 || digits >= 324) return value;
  if (digits < -308) return value.isNegative ? -0.0 : 0.0;

  final bits = ByteData(8)..setFloat64(0, value, Endian.big);
  final high = bits.getUint32(0, Endian.big);
  final low = bits.getUint32(4, Endian.big);
  final exponentBits = (high >> 20) & 0x7ff;
  var significand = (BigInt.from(high & 0xfffff) << 32) | BigInt.from(low);
  if (exponentBits != 0) significand |= BigInt.one << 52;
  final exponent = exponentBits == 0 ? -1074 : exponentBits - 1023 - 52;
  var numerator = exponent >= 0 ? significand << exponent : significand;
  var denominator = exponent >= 0 ? BigInt.one : BigInt.one << -exponent;
  final decimalScale = BigInt.from(10).pow(digits.abs());
  if (digits >= 0) {
    numerator *= decimalScale;
  } else {
    denominator *= decimalScale;
  }

  var rounded = numerator ~/ denominator;
  final comparison =
      ((numerator % denominator) * BigInt.two).compareTo(denominator);
  if (comparison > 0 || (comparison == 0 && rounded.isOdd)) {
    rounded += BigInt.one;
  }
  // Parsing one exact decimal avoids overflow or a second rounding when a large
  // integer would otherwise be converted to double before dividing by 10^n.
  final sign = value.isNegative ? '-' : '';
  final result = double.parse('$sign${rounded}e${-digits}');
  if (!result.isFinite) {
    throw ArgumentError(
        'The rounded result is outside the finite double range.');
  }
  return result;
}
