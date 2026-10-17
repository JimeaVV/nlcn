/// What a recognizer saw in one photo, following docs/MODEL_CONTRACT.md:
/// a softmax over dishes and an independent probability per component.
class FoodRecognition {
  const FoodRecognition({this.dishes = const {}, this.components = const {}});

  static const empty = FoodRecognition();

  /// Dish code → probability; the values sum to 1 when a model ran.
  final Map<String, double> dishes;

  /// Component code → probability between 0 and 1.
  final Map<String, double> components;

  bool get isEmpty => dishes.isEmpty && components.isEmpty;

  /// The most likely dishes first, at most [count] of them.
  List<MapEntry<String, double>> topDishes([int count = 3]) =>
      (dishes.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(count)
          .toList(growable: false);
}

/// Thresholds from the contract for showing components.
abstract final class RecognitionThresholds {
  /// At or above: ticked automatically.
  static const checked = 0.6;

  /// At or above (and below [checked]): shown unticked with a question.
  static const ask = 0.3;

  /// Below this for the best dish: the user picks from the top three.
  static const confidentDish = 0.5;
}

/// Turns a photo into dish and component probabilities.
abstract interface class FoodRecognizer {
  /// False until an on-device model is bundled; the screen then asks the
  /// user to choose the dish.
  bool get isAvailable;

  Future<FoodRecognition> recognize(String imagePath);
}

/// Used until the trained model ships: recognizes nothing.
class NoModelRecognizer implements FoodRecognizer {
  const NoModelRecognizer();

  @override
  bool get isAvailable => false;

  @override
  Future<FoodRecognition> recognize(String imagePath) async =>
      FoodRecognition.empty;
}
