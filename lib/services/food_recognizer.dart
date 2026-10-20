/// The model's extra dish output for food the app does not know (contract
/// 1.3): it has no nutrition and is never offered as a guess.
const otherDishCode = 'khac';

/// What a recognizer saw in one photo, following docs/MODEL_CONTRACT.md:
/// a softmax over dishes and an independent probability per component.
class FoodRecognition {
  const FoodRecognition({
    this.dishes = const {},
    this.components = const {},
    this.thresholds = RecognitionThresholds.contract,
    this.componentDishes,
    this.timing,
  });

  static const empty = FoodRecognition();

  /// Dish code → probability; the values sum to 1 when a model ran.
  final Map<String, double> dishes;

  /// Component code → probability between 0 and 1.
  final Map<String, double> components;

  /// How the screen treats these probabilities; tuned per model.
  final RecognitionThresholds thresholds;

  /// Dishes whose components the model learned well (MODEL_CARD.md
  /// `component_dishes`). For any other dish the component outputs carry no
  /// meaning, so they are ignored. Null trusts them for every dish.
  final Set<String>? componentDishes;

  /// How long this photo took, when a model ran.
  final RecognitionTiming? timing;

  FoodRecognition withTiming(RecognitionTiming timing) => FoodRecognition(
        dishes: dishes,
        components: components,
        thresholds: thresholds,
        componentDishes: componentDishes,
        timing: timing,
      );

  /// Whether [components] can be used for a photo of [dish].
  bool knowsComponentsOf(String dish) =>
      componentDishes?.contains(dish) ?? true;

  bool get isEmpty => dishes.isEmpty && components.isEmpty;

  /// The most likely dishes first, at most [count] of them; the "other"
  /// output is left out.
  List<MapEntry<String, double>> topDishes([int count = 3]) =>
      (dishes.entries.where((entry) => entry.key != otherDishCode).toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(count)
          .toList(growable: false);

  /// How sure the model is that the dish is not one the app knows.
  double get otherProbability => dishes[otherDishCode] ?? 0;

  /// True when the model thinks the photo shows a dish outside the app.
  bool get looksUnknown => otherProbability >= thresholds.confidentDish;
}

/// Time spent on one photo: decoding and resizing it, then the model.
class RecognitionTiming {
  const RecognitionTiming({required this.prepare, required this.model});

  final Duration prepare;
  final Duration model;

  Duration get total => prepare + model;
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
