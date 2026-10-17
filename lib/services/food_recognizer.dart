/// What a recognizer saw in one photo, following docs/MODEL_CONTRACT.md:
/// a softmax over dishes and an independent probability per component.
class FoodRecognition {
  const FoodRecognition({
    this.dishes = const {},
    this.components = const {},
    this.thresholds = RecognitionThresholds.contract,
  });

  static const empty = FoodRecognition();

  /// Dish code → probability; the values sum to 1 when a model ran.
  final Map<String, double> dishes;

  /// Component code → probability between 0 and 1.
  final Map<String, double> components;

  /// How the screen treats these probabilities; tuned per model.
  final RecognitionThresholds thresholds;

  bool get isEmpty => dishes.isEmpty && components.isEmpty;

  /// The most likely dishes first, at most [count] of them.
  List<MapEntry<String, double>> topDishes([int count = 3]) =>
      (dishes.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(count)
          .toList(growable: false);
}

/// Thresholds for showing components. The contract sets the defaults; a
/// model's MODEL_CARD.md may tune them on the validation set.
class RecognitionThresholds {
  const RecognitionThresholds({
    this.checked = 0.6,
    this.ask = 0.3,
    this.confidentDish = 0.5,
  });

  static const contract = RecognitionThresholds();

  /// At or above: ticked automatically.
  final double checked;

  /// At or above (and below [checked]): shown unticked with a question.
  final double ask;

  /// Below this for the best dish: the user picks from the top three.
  final double confidentDish;
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
