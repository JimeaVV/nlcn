import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../core/haptics.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
import '../models/plate_detection.dart';
import '../models/scan_plate.dart';
import '../models/vn_food.dart';
import '../services/database_service.dart';
import '../services/food_detector.dart';
import '../services/food_recognizer.dart';
import '../services/photo_collector.dart';
import '../widgets/cyber_card.dart';
import '../widgets/variant_picker_sheet.dart';
import '../widgets/error_box.dart';
import '../widgets/food_picker_sheet.dart';
import '../widgets/food_log_sheet.dart';
import '../widgets/scan_sweep.dart';

/// Confirms what is on a photographed plate and logs it to today's diary.
/// Pops with `true` after logging.
class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({
    super.key,
    required this.imagePath,
    required this.data,
    required this.recognizer,
    this.detector = const NoFoodDetector(),
    this.database,
    this.collector,
  });

  final String imagePath;
  final VnFoodData data;
  final FoodRecognizer recognizer;

  /// Finds each food on the plate, when a detector is bundled.
  final FoodDetector detector;
  final DatabaseService? database;

  /// Where confirmed photos are kept; [PhotoCollector.instance] by default.
  final PhotoCollector? collector;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  FoodRecognition _recognition = FoodRecognition.empty;
  PlateDetection _detection = PlateDetection.empty;
  bool _recognizing = true;

  // The model answers in a fraction of a second, which hid the scan sweep;
  // it now plays at least one full pass over the photo.
  bool _sweepShown = true;
  Timer? _sweepTimer;
  ScanPlate? _plate;
  MealSlot _meal = mealSlotFor(DateTime.now());
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sweepTimer = Timer(ScanSweep.onePass, () {
      if (mounted) setState(() => _sweepShown = false);
    });
    _recognize();
  }

  @override
  void dispose() {
    _sweepTimer?.cancel();
    super.dispose();
  }

  Future<void> _recognize() async {
    // Both models at once; either may fail without stopping the other.
    final detecting = widget.detector.detect(widget.imagePath).then(
        (found) => found,
        onError: (Object _) => PlateDetection.empty);
    FoodRecognition result;
    try {
      result = await widget.recognizer.recognize(widget.imagePath);
    } catch (_) {
      result = FoodRecognition.empty;
    }
    final found = await detecting;
    if (!mounted) return;
    setState(() {
      _recognition = result;
      _detection = found;
      _recognizing = false;
      final top = result.topDishes(1);
      final confident = top.isNotEmpty &&
          !result.looksUnknown &&
          top.first.value >= result.thresholds.confidentDish;
      // Several foods on the plate: one row each, unless a confident dish
      // already holds them all (cơm tấm with its egg and pork).
      final dish = confident ? widget.data.dish(top.first.key) : null;
      final detected = _detectedPlate;
      _detectedCount = detected?.items.length;
      if (detected != null && (dish == null || !dishShowsAll(dish, found))) {
        _plate = detected;
        Haptics.found();
      } else if (confident) {
        // A confident guess opens directly; otherwise the user picks.
        _choose(top.first.key);
        Haptics.found();
      }
    });
  }

  /// How many foods the plate built from the detector's boxes has, when at
  /// least two; null otherwise.
  int? _detectedCount;

  /// A fresh plate from the detector's boxes.
  ScanPlate? get _detectedPlate {
    if (_detection.codes.length < 2) return null;
    final plate = ScanPlate.detected(widget.data, _detection);
    return plate.items.length < 2 ? null : plate;
  }

  void _choose(String code) {
    final dish = widget.data.dish(code);
    if (dish == null) return;
    _plate = ScanPlate.forDish(widget.data, dish, _recognition);
  }

  Future<FoodPick?> _showPicker(
          String title, List<VnDish> dishes, List<VnComponent> components) =>
      showModalBottomSheet<FoodPick>(
        context: context,
        isScrollControlled: true,
        backgroundColor: CyberColors.surface,
        builder: (context) => Padding(
          // The keyboard must not cover the search results.
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .75,
            maxChildSize: .95,
            builder: (context, controller) => FoodPickerSheet(
              title: title,
              dishes: dishes,
              components: components,
              scrollController: controller,
            ),
          ),
        ),
      );

  Future<void> _pickDish() async {
    final pick = await _showPicker(context.l10n.scanChooseDish,
        widget.data.dishes, widget.data.addableComponents);
    if (pick == null || !mounted) return;
    if (pick is NewFoodPick) return _logNewFood();
    setState(() => switch (pick) {
          DishPick(:final code) => _choose(code),
          ComponentPick(:final component) => _plate =
              ScanPlate.single(widget.data, component),
          NewFoodPick() => null,
        });
  }

  Future<void> _addComponent() async {
    final plate = _plate;
    if (plate == null) return;
    final present = {for (final item in plate.items) item.component.code};
    final options = [
      for (final component in widget.data.addableComponents)
        if (!present.contains(component.code)) component,
    ];
    final pick =
        await _showPicker(context.l10n.scanAddComponent, const [], options);
    if (pick is ComponentPick && mounted) {
      setState(() => plate.add(pick.component));
    }
  }

  PhotoCollector get _collector => widget.collector ?? PhotoCollector.instance;

  /// Keeps the photo with what the user confirmed, when collecting is on.
  /// It never stops the meal from being logged.
  Future<void> _keepPhoto(String label, String name) async {
    final top = _recognition.topDishes();
    try {
      await _collector.save(
        widget.imagePath,
        label: label,
        name: name,
        guess: top.isEmpty ? null : top.first.key,
        confidence: top.isEmpty ? null : top.first.value,
      );
    } catch (error) {
      debugPrint('Photo not kept: $error');
    }
  }

  /// A food that is in no list: typed in by hand, and its photo kept under
  /// its own name for a later model.
  Future<void> _logNewFood() async {
    final entry = await showModalBottomSheet<FoodLogEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CyberColors.surface,
      builder: (_) => FoodLogSheet(foods: const [], date: DateTime.now()),
    );
    if (entry == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await (widget.database ?? DatabaseService.instance)
          .addFoodLogEntries([entry.copyTo(entry.date, _meal)]);
      await _keepPhoto(PhotoCollector.labelForNewFood(entry.name), entry.name);
      Haptics.strong();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.diarySaveFailed)));
    }
  }

  Future<void> _save() async {
    final plate = _plate;
    if (plate == null || !plate.canLog || _saving) return;
    setState(() => _saving = true);
    try {
      await (widget.database ?? DatabaseService.instance).addFoodLogEntries(
        plate.toEntries(
          date: DateTime.now(),
          meal: _meal,
          languageCode: Localizations.localeOf(context).languageCode,
        ),
      );
      await _keepPhoto(
          plate.isSingle
              ? 'single_${plate.items.first.component.code}'
              : plate.isDetected
                  ? 'plate'
                  : plate.dish.code,
          plate.dish.nameVi);
      Haptics.strong();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.diarySaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plate = _plate;
    final language = Localizations.localeOf(context).languageCode;
    final missing = plate?.missingNutrition ?? const <PlateItem>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanResultTitle)),
      // The total and the log button stay in reach while the list scrolls.
      bottomNavigationBar: plate == null
          ? null
          : _TotalBar(
              plate: plate,
              meal: _meal,
              saving: _saving,
              onMealChanged: (meal) => setState(() => _meal = meal),
              onSave: _save,
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: CyberColors.surfaceAlt,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: CyberColors.muted, size: 48),
                      ),
                    ),
                    if (!_recognizing && _detection.foods.isNotEmpty)
                      _DetectionBoxes(detection: _detection),
                    if (_recognizing || _sweepShown) const ScanSweep(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_recognizing)
              Center(
                child: Text(l10n.scanRecognizing,
                    style: TextStyle(
                        color: CyberColors.cyan, fontWeight: FontWeight.w700)),
              )
            else ...[
              _Appear(
                child: _DishCard(
                  recognition: _recognition,
                  modelAvailable: widget.recognizer.isAvailable,
                  data: widget.data,
                  selected: plate?.dish.code,
                  chosenName: plate?.dish.name(language),
                  detectedCount: _detectedCount,
                  onChoose: (code) {
                    Haptics.tap();
                    setState(() => _choose(code));
                  },
                  onChooseDetected: () {
                    Haptics.tap();
                    setState(() => _plate = _detectedPlate);
                  },
                  onPickOther: _pickDish,
                ),
              ),
              if (plate != null) ...[
                const SizedBox(height: 14),
                _Appear(
                  delay: 1,
                  // Switching dish cross-fades the list and eases its height,
                  // instead of shifting everything below in one frame.
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, if (current != null) current],
                      ),
                      child: _ComponentsCard(
                        // Another dish starts with its suggestions folded.
                        key: ValueKey('components-${plate.dish.code}'),
                        plate: plate,
                        variants: widget.data.variants,
                        onChanged: () => setState(() {}),
                        onAdd: _addComponent,
                      ),
                    ),
                  ),
                ),
                if (plate.selected.isEmpty) ...[
                  const SizedBox(height: 12),
                  Text(l10n.scanNothingSelected,
                      style: TextStyle(color: CyberColors.muted)),
                ],
                if (missing.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ErrorBox(
                    message: l10n.scanMissingNutrition(missing
                        .map((item) => item.component.name(language))
                        .join(', ')),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Fades and slides a card in when it first appears; [delay] staggers cards.
class _Appear extends StatelessWidget {
  const _Appear({required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 260 + 90 * delay),
        curve: Curves.easeOutCubic,
        child: child,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
              offset: Offset(0, 18 * (1 - t)), child: child),
        ),
      );
}

class _DishCard extends StatelessWidget {
  const _DishCard({
    required this.recognition,
    required this.modelAvailable,
    required this.data,
    required this.selected,
    required this.chosenName,
    required this.onChoose,
    required this.onPickOther,
    this.detectedCount,
    this.onChooseDetected,
  });

  final FoodRecognition recognition;
  final bool modelAvailable;
  final VnFoodData data;
  final String? selected;

  /// The chosen dish or single component, shown when it is not a guess.
  final String? chosenName;
  final ValueChanged<String> onChoose;
  final VoidCallback onPickOther;

  /// How many foods the detector found, when several.
  final int? detectedCount;
  final VoidCallback? onChooseDetected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final top = recognition.topDishes();
    final detected = selected == ScanPlate.detectedPlateCode;

    return CyberCard(
      highlight: true,
      title: l10n.scanDishTitle,
      icon: Icons.restaurant_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!modelAvailable)
            Text(l10n.scanModelPending,
                style: TextStyle(color: CyberColors.muted))
          else if (detected)
            Text(l10n.scanDetectedHint,
                style: TextStyle(color: CyberColors.muted))
          else if (recognition.looksUnknown)
            Text(l10n.scanNotInApp, style: TextStyle(color: CyberColors.muted))
          else if (top.isEmpty)
            Text(l10n.scanNoGuess, style: TextStyle(color: CyberColors.muted))
          else if (top.first.value < recognition.thresholds.confidentDish)
            Text(l10n.scanLowConfidence,
                style: TextStyle(color: CyberColors.muted)),
          if (top.isNotEmpty || detectedCount != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (detectedCount case final count?)
                  ChoiceChip(
                    showCheckmark: false,
                    key: const ValueKey('guess-detected'),
                    avatar: Icon(Icons.center_focus_strong_rounded,
                        size: 18, color: CyberColors.cyan),
                    selected: detected,
                    label: Text(l10n.scanDetectedPlate(count)),
                    // Tapped again it keeps what the user changed.
                    onSelected: (_) => detected ? null : onChooseDetected?.call(),
                  ),
                for (final guess in top)
                  ChoiceChip(
                    // A checkmark would widen the chip and re-wrap the row.
                    showCheckmark: false,
                    key: ValueKey('guess-${guess.key}'),
                    selected: guess.key == selected,
                    label: Text(
                        '${data.dish(guess.key)?.name(language) ?? guess.key}'
                        ' · ${context.formatNumber(guess.value * 100)}%'),
                    onSelected: (_) => onChoose(guess.key),
                  ),
              ],
            ),
          ],
          if (chosenName != null &&
              !detected &&
              !top.any((guess) => guess.key == selected)) ...[
            const SizedBox(height: 10),
            Text(chosenName!, style: Theme.of(context).textTheme.titleLarge),
          ],
          if (recognition.timing case final timing?) ...[
            const SizedBox(height: 8),
            Text(
              key: const ValueKey('scan-timing'),
              l10n.scanTiming(
                  _seconds(context, timing.total),
                  _seconds(context, timing.prepare),
                  _seconds(context, timing.model)),
              style: TextStyle(color: CyberColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('scan-pick-dish'),
            onPressed: onPickOther,
            icon: const Icon(Icons.list_rounded),
            label: Text(selected == null && top.isEmpty
                ? l10n.scanChooseDish
                : l10n.scanOtherDish),
          ),
        ],
      ),
    );
  }
}

/// A box around each food the detector found, with its name. The photo is
/// shown cropped to fill its frame, so the boxes are cropped the same way.
class _DetectionBoxes extends StatelessWidget {
  const _DetectionBoxes({required this.detection});

  final PlateDetection detection;

  @override
  Widget build(BuildContext context) {
    // Short names fit small boxes: "Trứng", not "Trứng kho / trứng luộc".
    final name = context.l10n.detectorClassName;
    return Semantics(
      label: context.l10n
          .scanBoxesLabel(detection.codes.map(name).join(', ')),
      child: ExcludeSemantics(
        child: CustomPaint(
          key: const ValueKey('scan-boxes'),
          painter: _BoxesPainter(
            detection: detection,
            names: {for (final code in detection.codes) code: name(code)},
            colour: CyberColors.cyan,
            labelStyle: DefaultTextStyle.of(context).style.copyWith(
                color: CyberColors.background,
                fontSize: 12,
                fontWeight: FontWeight.w700),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

class _BoxesPainter extends CustomPainter {
  _BoxesPainter({
    required this.detection,
    required this.names,
    required this.colour,
    required this.labelStyle,
    required this.textScaler,
  });

  final PlateDetection detection;
  final Map<String, String> names;
  final Color colour;

  /// The app's font, so Vietnamese names draw on the photo.
  final TextStyle labelStyle;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (detection.width <= 0 || detection.height <= 0) return;
    // BoxFit.cover: scaled to fill, centred, the overflow cut off.
    final scale = size.width / detection.width > size.height / detection.height
        ? size.width / detection.width
        : size.height / detection.height;
    final shown = Size(detection.width * scale, detection.height * scale);
    final offset = Offset((size.width - shown.width) / 2,
        (size.height - shown.height) / 2);
    final stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final food in detection.foods) {
      final box = Rect.fromLTRB(
        offset.dx + food.box.left * shown.width,
        offset.dy + food.box.top * shown.height,
        offset.dx + food.box.right * shown.width,
        offset.dy + food.box.bottom * shown.height,
      );
      canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(8)), stroke);
      // At least 40 px wide, never wider than the photo.
      final room = math.max(40.0, math.min(box.width, size.width) - 8);
      TextPainter label(String text) => TextPainter(
            text: TextSpan(text: text, style: labelStyle),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
            maxLines: 1,
            ellipsis: '…',
          )..layout(maxWidth: room);
      // The score goes first when the box is too narrow for both.
      final name = names[food.code] ?? '';
      var text = label('$name ${(food.score * 100).round()}%');
      if (text.didExceedMaxLines) text = label(name);
      // Inside the box's top edge, so it stays on the photo.
      final at = Offset(
          box.left.clamp(0, math.max(0, size.width - text.width - 8)),
          box.top.clamp(0, math.max(0, size.height - text.height - 4)));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(at.dx, at.dy, text.width + 8, text.height + 4),
              const Radius.circular(6)),
          Paint()..color = colour);
      text.paint(canvas, at + const Offset(4, 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoxesPainter old) =>
      old.detection != detection ||
      old.colour != colour ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler;
}

/// Servings offered for the whole dish.
const _portions = [0.5, 1.0, 1.5, 2.0];

String _portionLabel(double servings) {
  final whole = servings.floor();
  final half = servings - whole >= .5 ? '½' : '';
  return '×${whole == 0 ? '' : whole}$half';
}

String _seconds(BuildContext context, Duration time) =>
    context.formatNumber(time.inMilliseconds / 1000, decimals: 2);

class _ComponentsCard extends StatefulWidget {
  const _ComponentsCard({
    super.key,
    required this.plate,
    required this.variants,
    required this.onChanged,
    required this.onAdd,
  });

  final ScanPlate plate;
  final FoodVariants variants;
  final VoidCallback onChanged;
  final VoidCallback onAdd;

  @override
  State<_ComponentsCard> createState() => _ComponentsCardState();
}

class _ComponentsCardState extends State<_ComponentsCard> {
  bool _showSuggestions = false;

  bool _canRefine(PlateItem item) {
    final match = componentVariants[item.component.code];
    return match != null && widget.variants.inGroup(match.$1).isNotEmpty;
  }

  /// Chicken, pork, beef, fish, eggs and rice by part and cooking: the item
  /// keeps its amount and takes the variant's nutrition and name.
  Future<void> _refine(PlateItem item) async {
    final (group, key) = componentVariants[item.component.code]!;
    // Opens at the earlier pick, if there was one.
    final variant = await pickFoodVariant(context,
        variants: widget.variants,
        group: group,
        initialKey: item.variantKey ?? key);
    if (variant == null || !mounted) return;
    // Each name in its own language, "bỏ da" and "skinless" alike.
    String name(String language) => variant.label(
        language, skinNamer(lookupAppLocalizations(Locale(language))));
    item.refine(variant.asComponent(item.component, name('vi'), name('en')),
        variantKey: variant.key);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final plate = widget.plate;
    final dishItems = [
      for (final item in plate.items)
        if (!item.suggested) item
    ];
    final suggestions = [
      for (final item in plate.items)
        if (item.suggested) item
    ];
    final chosen = suggestions.where((item) => item.included).length;
    Widget row(PlateItem item) => _ComponentRow(
          key: ValueKey('component-${item.component.code}'),
          item: item,
          language: language,
          onChanged: widget.onChanged,
          onRefine: _canRefine(item) ? () => _refine(item) : null,
        );
    return CyberCard(
      title: l10n.scanComponentsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.scanPortion,
              style: TextStyle(color: CyberColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final servings in _portions)
                ChoiceChip(
                  // A checkmark would widen the chip and re-wrap the row.
                  showCheckmark: false,
                  key: ValueKey('portion-$servings'),
                  label: Text(_portionLabel(servings)),
                  selected: plate.portion == servings,
                  onSelected: (_) {
                    Haptics.tap();
                    plate.portion = servings;
                    widget.onChanged();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in dishItems) row(item),
          // Components outside the recipe are folded away: the model is least
          // sure about them, and they would push the dish off the screen.
          if (suggestions.isNotEmpty) ...[
            const Divider(height: 20),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: const ValueKey('scan-suggestions'),
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    setState(() => _showSuggestions = !_showSuggestions),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.help_outline_rounded,
                          size: 18, color: CyberColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          chosen == 0
                              ? l10n.scanSuggestions(suggestions.length)
                              : l10n.scanSuggestionsChosen(
                                  suggestions.length, chosen),
                          style: TextStyle(
                              color: CyberColors.text,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _showSuggestions ? .5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more_rounded,
                            color: CyberColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _showSuggestions
                  ? Column(
                      children: [for (final item in suggestions) row(item)])
                  : const SizedBox(width: double.infinity),
            ),
          ],
          TextButton.icon(
            key: const ValueKey('scan-add-component'),
            onPressed: widget.onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.scanAddComponent),
          ),
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    super.key,
    required this.item,
    required this.language,
    required this.onChanged,
    this.onRefine,
  });

  final PlateItem item;
  final String language;
  final VoidCallback onChanged;

  /// Opens the part and cooking picker; null for foods without variants.
  final VoidCallback? onRefine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unit = item.inUnits
        ? (language == 'vi' ? item.component.unitNameVi : null) ??
            l10n.scanUnitFallback
        : 'g';
    final amount = '${context.formatMeasurement(item.amount)}\u00A0$unit';
    final detail = item.hasNutrition
        ? '$amount · ${context.formatNumber(item.calories)}\u00A0kcal'
        : '$amount · ${l10n.scanNoNutrition}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(
            value: item.included,
            onChanged: (value) {
              Haptics.tap();
              item.included = value ?? false;
              item.uncertain = false;
              onChanged();
            },
          ),
          Expanded(
            // The name opens the part and cooking picker where there is one,
            // so the row needs no extra button.
            child: Semantics(
              button: onRefine != null,
              hint: onRefine == null ? null : l10n.scanRefine,
              // Ink needs a Material inside the card.
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: ValueKey('refine-${item.component.code}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: onRefine,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(item.component.name(language),
                                  style: TextStyle(
                                      color: CyberColors.text,
                                      fontWeight: FontWeight.w700)),
                            ),
                            if (onRefine != null) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.tune_rounded,
                                  size: 16, color: CyberColors.cyan),
                            ],
                            if (item.uncertain) ...[
                              const SizedBox(width: 6),
                              _Badge(l10n.scanMaybe),
                            ],
                          ],
                        ),
                        Text(detail,
                            style: TextStyle(
                                color: CyberColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.scanDecrease,
            onPressed: item.amount - item.step <= 0
                ? null
                : () {
                    item.amount -= item.step;
                    onChanged();
                  },
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            tooltip: l10n.scanIncrease,
            onPressed: () {
              item.amount += item.step;
              onChanged();
            },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: CyberColors.warning.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                color: CyberColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
}

/// Stays at the bottom: the running total, where its calories come from,
/// the meal and the button that logs the plate. Numbers count to new values.
class _TotalBar extends StatelessWidget {
  const _TotalBar({
    required this.plate,
    required this.meal,
    required this.saving,
    required this.onMealChanged,
    required this.onSave,
  });

  final ScanPlate plate;
  final MealSlot meal;
  final bool saving;
  final ValueChanged<MealSlot> onMealChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: CyberColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: CyberColors.cyan, width: 1.2)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TweenAnimationBuilder<_Totals>(
              tween: _TotalsTween(end: _Totals.of(plate)),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, totals, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MacroSplit(totals: totals),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.scanTotal(
                                  context.formatNumber(totals.calories),
                                  context.formatNumber(totals.protein,
                                      decimals: 1)),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              l10n.scanMacroGrams(
                                  context.formatNumber(totals.protein),
                                  context.formatNumber(totals.carbs),
                                  context.formatNumber(totals.fat)),
                              style: TextStyle(
                                  color: CyberColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<MealSlot>(
                        key: const ValueKey('scan-meal'),
                        value: meal,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final slot in MealSlot.values)
                            DropdownMenuItem(
                                value: slot,
                                child: Text(l10n.mealSlotLabel(slot))),
                        ],
                        onChanged: (value) => onMealChanged(value!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const ValueKey('scan-save'),
                    onPressed: plate.canLog && !saving ? onSave : null,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: Text(l10n.scanSave),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The plate's totals, animated together.
class _Totals {
  const _Totals(this.calories, this.protein, this.carbs, this.fat);

  factory _Totals.of(ScanPlate plate) =>
      _Totals(plate.calories, plate.protein, plate.carbs, plate.fat);

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
}

class _TotalsTween extends Tween<_Totals> {
  _TotalsTween({required super.end});

  @override
  _Totals lerp(double t) {
    final from = begin ?? end!;
    double mix(double a, double b) => a + (b - a) * t;
    return _Totals(
      mix(from.calories, end!.calories),
      mix(from.protein, end!.protein),
      mix(from.carbs, end!.carbs),
      mix(from.fat, end!.fat),
    );
  }
}

/// A thin bar split by where the calories come from: protein, carbs, fat.
class _MacroSplit extends StatelessWidget {
  const _MacroSplit({required this.totals});

  final _Totals totals;

  @override
  Widget build(BuildContext context) {
    final parts = [
      (totals.protein * 4, CyberColors.cyan),
      (totals.carbs * 4, CyberColors.lime),
      (totals.fat * 9, CyberColors.magenta),
    ];
    final sum = parts.fold<double>(0, (total, part) => total + part.$1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: sum <= 0
            ? ColoredBox(color: CyberColors.surfaceAlt)
            : Row(
                children: [
                  for (final (energy, colour) in parts)
                    if (energy > 0)
                      Expanded(
                        flex: (energy / sum * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: colour),
                      ),
                ],
              ),
      ),
    );
  }
}
