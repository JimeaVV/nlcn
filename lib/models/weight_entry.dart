class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.weight,
    required this.recordedAt,
  });

  factory WeightEntry.fromMap(Map<String, dynamic> row) {
    final id = row['id'];
    final weight = row['weight_kg'];
    final rawDate = row['recorded_date'];
    if (id is! int ||
        weight is! num ||
        !weight.isFinite ||
        weight <= 0 ||
        rawDate is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate)) {
      throw const FormatException('Invalid weight history entry.');
    }
    final date = DateTime.tryParse(rawDate);
    if (date == null ||
        date.year.toString().padLeft(4, '0') != rawDate.substring(0, 4) ||
        date.month.toString().padLeft(2, '0') != rawDate.substring(5, 7) ||
        date.day.toString().padLeft(2, '0') != rawDate.substring(8, 10)) {
      throw const FormatException('Invalid weight history date.');
    }
    return WeightEntry(id: id, weight: weight.toDouble(), recordedAt: date);
  }

  final int id;
  final double weight;
  final DateTime recordedAt;
}
