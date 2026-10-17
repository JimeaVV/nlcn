import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../engine/nutrition_targets.dart';
import '../l10n/l10n.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import '../services/database_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/weight_trend_chart.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.database, this.onProfileChanged});

  final DatabaseService? database;
  final VoidCallback? onProfileChanged;

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _age = TextEditingController(text: '21');
  final _height = TextEditingController(text: '175');
  final _weight = TextEditingController(text: '70');
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  String _gender = 'male';
  double _activity = 1.55;
  NutritionGoal _goal = NutritionGoal.maintain;
  List<WeightEntry> _weights = const [];
  bool _loading = true;
  bool _saving = false;
  bool _hasProfile = false;

  /// Manual targets are optional; their fields only show when switched on.
  bool _customCalories = false;
  bool _customProtein = false;
  bool _showAllWeights = false;

  /// Built at paint time so a language switch also translates the message.
  String Function(AppLocalizations)? _error;
  int _refreshId = 0;

  DatabaseService get _database => widget.database ?? DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    for (final controller in [_age, _height, _weight, _calories, _protein]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> refresh() => _reload();

  Future<void> _reload({bool preserveDraft = false}) async {
    final refreshId = ++_refreshId;
    try {
      final map = await _database.getProfile();
      final weights = await _database.getWeightHistory();
      if (!mounted || refreshId != _refreshId) return;
      setState(() {
        if (map != null) {
          final profile = UserProfile.fromMap(map);
          _weight.text = _inputNumber(profile.weight);
          if (!preserveDraft) {
            _age.text = '${profile.age}';
            _height.text = _inputNumber(profile.height);
            _gender = profile.gender;
            _activity = profile.activityLevel;
            _goal = profile.goal;
            _customCalories = profile.calorieOverride != null;
            _customProtein = profile.proteinOverride != null;
            _calories.text = profile.calorieOverride == null
                ? ''
                : _inputNumber(profile.calorieOverride!);
            _protein.text = profile.proteinOverride == null
                ? ''
                : _inputNumber(profile.proteinOverride!);
          }
        }
        _hasProfile = map != null;
        _weights = weights;
        _loading = false;
        if (!preserveDraft) _error = null;
      });
    } catch (_) {
      if (mounted && refreshId == _refreshId) {
        setState(() {
          _loading = false;
          _error = (l10n) => l10n.profileLoadFailed;
        });
      }
    }
  }

  UserProfile _draft() => UserProfile(
        age: int.parse(_age.text.trim()),
        gender: _gender,
        height: double.parse(_height.text.trim()),
        weight: double.parse(_weight.text.trim()),
        activityLevel: _activity,
        goal: _goal,
        calorieOverride: !_customCalories || _calories.text.trim().isEmpty
            ? null
            : double.parse(_calories.text.trim()),
        proteinOverride: !_customProtein || _protein.text.trim().isEmpty
            ? null
            : double.parse(_protein.text.trim()),
      );

  Map<String, dynamic>? get _preview {
    try {
      return calculateNutritionTargets(_draft());
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final profile = _draft();
    try {
      profile.validate();
      calculateNutritionTargets(profile);
    } on NutritionTargetError catch (error) {
      setState(() => _error = (l10n) => l10n.targetError(error.issue));
      return;
    } on ArgumentError {
      setState(() => _error = (l10n) => l10n.targetError(null));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _database.saveUserProfile(profile);
      if (!mounted) return;
      await refresh();
      if (!mounted) return;
      widget.onProfileChanged?.call();
      _message(context.l10n.profileSaved);
    } catch (_) {
      if (mounted) {
        setState(() => _error = (l10n) => l10n.profileSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String? _validateNumber(
    String? value, {
    required String name,
    required double maximum,
    double minimum = 0,
    bool inclusiveMinimum = false,
    bool optional = false,
  }) {
    final text = value?.trim() ?? '';
    if (optional && text.isEmpty) return null;
    final l10n = context.l10n;
    final number = double.tryParse(text);
    if (number == null || !number.isFinite) return l10n.numberInvalid(name);
    if ((inclusiveMinimum ? number < minimum : number <= minimum) ||
        number > maximum) {
      return minimum == 0
          ? l10n.numberPositiveMax(name, context.formatMeasurement(maximum))
          : l10n.numberRange(name, context.formatMeasurement(minimum),
              context.formatMeasurement(maximum));
    }
    return null;
  }

  Widget _numberField({
    required String keyName,
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    bool integer = false,
  }) =>
      TextFormField(
        key: ValueKey(keyName),
        controller: controller,
        enabled: !_saving,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        // Narrow fields sit three to a row, so errors may need more lines.
        decoration: InputDecoration(labelText: label, errorMaxLines: 4),
        validator: validator,
        onChanged: (_) => setState(() => _error = null),
      );

  Future<void> _editWeight([WeightEntry? entry]) async {
    if (_saving) return;
    final today = _day(DateTime.now());
    final input = await showDialog<_WeightInput>(
      context: context,
      builder: (_) => _WeightDialog(
        initialWeight: entry?.weight ?? double.tryParse(_weight.text) ?? 70,
        initialDate: entry?.recordedAt ?? today,
        editing: entry != null,
      ),
    );
    if (input == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _database.saveWeight(weight: input.weight, recordedAt: input.date);
      if (!mounted) return;
      await _reload(preserveDraft: true);
      if (!mounted) return;
      widget.onProfileChanged?.call();
      _message(context.l10n.weightSaved(_date(input.date)));
    } catch (_) {
      if (mounted) _message(context.l10n.weightSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteWeight(WeightEntry entry) async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteWeightTitle),
        content: Text(
          '${context.formatMeasurement(entry.weight)} kg · '
          '${_date(entry.recordedAt)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _database.deleteWeightEntry(entry.id);
      if (!mounted) return;
      await _reload(preserveDraft: true);
      if (!mounted) return;
      widget.onProfileChanged?.call();
      _message(context.l10n.weightDeleted);
    } catch (_) {
      if (mounted) _message(context.l10n.weightDeleteFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Targets from the body details alone, ignoring manual overrides; used to
  /// prefill a manual field when it is switched on.
  Map<String, dynamic>? get _estimate {
    try {
      final draft = _draft();
      return calculateNutritionTargets(UserProfile(
        age: draft.age,
        gender: draft.gender,
        height: draft.height,
        weight: draft.weight,
        activityLevel: draft.activityLevel,
        goal: draft.goal,
      ));
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Switching a manual target on starts from the current estimate; switching
  /// it off returns to the estimate.
  void _setCustom({required bool calories, required bool on}) {
    final estimate = _estimate;
    setState(() {
      _error = null;
      final controller = calories ? _calories : _protein;
      if (calories) {
        _customCalories = on;
      } else {
        _customProtein = on;
      }
      if (!on) {
        controller.clear();
      } else if (estimate != null) {
        final value =
            (estimate[calories ? 'target_calories' : 'protein_target'] as num)
                .toDouble();
        controller.text = _inputNumber(value.roundToDouble());
      }
    });
  }

  void _showInfo(String title, List<String> paragraphs) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CyberColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              for (final paragraph in paragraphs) ...[
                const SizedBox(height: 12),
                Text(paragraph),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoButton(String key, VoidCallback onPressed) => IconButton(
        key: ValueKey(key),
        tooltip: context.l10n.howCalculated,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(Icons.info_outline_rounded, color: CyberColors.muted),
      );

  Widget _targetsCard(Map<String, dynamic>? targets) {
    final l10n = context.l10n;
    final number = context.formatNumber;
    return CyberCard(
      key: const ValueKey('profile-targets'),
      title: l10n.dailyTargetsTitle,
      icon: Icons.flag_outlined,
      trailing: _infoButton(
        'profile-how',
        () => _showInfo(l10n.howCalculated, [
          l10n.estimateFormula,
          if (targets != null)
            'BMR: ${number(targets['bmr'] as num)} kcal · '
                'TDEE: ${number(targets['tdee'] as num)} kcal',
          l10n.profileDisclaimer,
        ]),
      ),
      child: targets == null
          ? Text(l10n.targetsInvalidHint)
          : Row(
              children: [
                Expanded(
                  child: _TargetTile(
                    value: number(targets['target_calories'] as num),
                    unit: 'kcal',
                    label: l10n.caloriesLabel,
                    manual: _customCalories,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TargetTile(
                    value: number(targets['protein_target'] as num),
                    unit: 'g',
                    label: l10n.proteinLabel,
                    manual: _customProtein,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _weightHistory() {
    final chronological = List<WeightEntry>.of(_weights)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final l10n = context.l10n;
    final weight = context.formatMeasurement;
    // The newest five are enough at a glance; the rest are one tap away.
    final shown = _showAllWeights ? _weights : _weights.take(5).toList();
    return CyberCard(
      title: l10n.weightTracking,
      icon: Icons.monitor_weight_outlined,
      trailing: _infoButton(
        'weight-info',
        () => _showInfo(l10n.weightTracking, [l10n.weightHistoryNote]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_weights.isEmpty)
            Text(l10n.noWeights, style: TextStyle(color: CyberColors.muted))
          else ...[
            Text(
              l10n.latestWeight(weight(chronological.last.weight),
                  _date(chronological.last.recordedAt)),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (chronological.length > 1) ...[
              const SizedBox(height: 4),
              Text(
                l10n.weightChange(
                  context.formatSigned(
                      chronological.last.weight - chronological.first.weight,
                      decimals: 1),
                  _date(chronological.first.recordedAt),
                  _date(chronological.last.recordedAt),
                ),
                style: TextStyle(color: CyberColors.muted),
              ),
            ],
            const SizedBox(height: 10),
            WeightTrendChart(entries: chronological),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              key: const ValueKey('add-weight'),
              onPressed: _saving || !_hasProfile ? null : () => _editWeight(),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.logWeight),
            ),
          ),
          for (final entry in shown) ...[
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                      text: '${weight(entry.weight)} kg',
                      style: TextStyle(
                          color: CyberColors.text, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: '  ·  ${_date(entry.recordedAt)}',
                      style: TextStyle(color: CyberColors.muted),
                    ),
                  ])),
                ),
                IconButton(
                  key: ValueKey('edit-weight-${entry.id}'),
                  tooltip: l10n.editWeightTooltip(_date(entry.recordedAt)),
                  visualDensity: VisualDensity.compact,
                  onPressed: _saving ? null : () => _editWeight(entry),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  key: ValueKey('delete-weight-${entry.id}'),
                  tooltip: l10n.deleteWeightTooltip(_date(entry.recordedAt)),
                  visualDensity: VisualDensity.compact,
                  onPressed: _saving ? null : () => _deleteWeight(entry),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
              ],
            ),
          ],
          if (_weights.length > 5)
            Center(
              child: TextButton(
                key: const ValueKey('weights-show-all'),
                onPressed: () =>
                    setState(() => _showAllWeights = !_showAllWeights),
                child: Text(_showAllWeights
                    ? l10n.showFewerWeights
                    : l10n.showAllWeights('${_weights.length}')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _customTarget({
    required bool calories,
    required bool on,
  }) {
    final l10n = context.l10n;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                calories ? l10n.customCalories : l10n.customProtein,
                style: TextStyle(color: CyberColors.text),
              ),
            ),
            Switch(
              key: ValueKey(calories
                  ? 'profile-custom-calories'
                  : 'profile-custom-protein'),
              value: on,
              onChanged: _saving
                  ? null
                  : (value) => _setCustom(calories: calories, on: value),
            ),
          ],
        ),
        if (on) ...[
          calories
              ? _numberField(
                  keyName: 'profile-calories',
                  label: l10n.manualCalories,
                  controller: _calories,
                  validator: (value) => _validateNumber(value,
                      name: l10n.caloriesLabel,
                      minimum: 1000,
                      inclusiveMinimum: true,
                      maximum: 10000),
                )
              : _numberField(
                  keyName: 'profile-protein',
                  label: l10n.manualProtein,
                  controller: _protein,
                  validator: (value) => _validateNumber(value,
                      name: l10n.proteinLabel, maximum: 500),
                ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final targets = _preview;
    final l10n = context.l10n;
    String factor(double value) => context.formatNumber(value,
        decimals: value.toString().split('.').last.length);
    final segmentStyle = SegmentedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      selectedForegroundColor: CyberColors.background,
      selectedBackgroundColor: CyberColors.cyan,
    );
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _targetsCard(targets),
          const SizedBox(height: 14),
          CyberCard(
            title: l10n.personalInfo,
            icon: Icons.person_outline_rounded,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _numberField(
                          keyName: 'profile-age',
                          label: l10n.age,
                          controller: _age,
                          integer: true,
                          validator: (value) {
                            final number = int.tryParse(value?.trim() ?? '');
                            return number == null || number < 18 || number > 100
                                ? l10n.ageError
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _numberField(
                          keyName: 'profile-height',
                          label: l10n.heightShort,
                          controller: _height,
                          validator: (value) => _validateNumber(value,
                              name: l10n.heightName, maximum: 300),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _numberField(
                          keyName: 'profile-weight',
                          label: l10n.weightShort,
                          controller: _weight,
                          validator: (value) => _validateNumber(value,
                              name: l10n.weightName, maximum: 500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Labeled(
                    label: l10n.genderShort,
                    child: SegmentedButton<String>(
                      key: ValueKey('profile-gender-$_gender'),
                      style: segmentStyle,
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: 'male', label: Text(l10n.male)),
                        ButtonSegment(
                            value: 'female', label: Text(l10n.female)),
                      ],
                      selected: {_gender},
                      onSelectionChanged: _saving
                          ? null
                          : (value) => setState(() => _gender = value.single),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<double>(
                    key: ValueKey('profile-activity-$_activity'),
                    initialValue: _activity,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.activityLevel),
                    items: [
                      DropdownMenuItem(
                          value: 1.2,
                          child: Text(l10n.activitySedentary(factor(1.2)))),
                      DropdownMenuItem(
                          value: 1.375,
                          child: Text(l10n.activityLight(factor(1.375)))),
                      DropdownMenuItem(
                          value: 1.55,
                          child: Text(l10n.activityModerate(factor(1.55)))),
                      DropdownMenuItem(
                          value: 1.725,
                          child: Text(l10n.activityActive(factor(1.725)))),
                      DropdownMenuItem(
                          value: 1.9,
                          child: Text(l10n.activityVeryActive(factor(1.9)))),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _activity = value!),
                  ),
                  const SizedBox(height: 14),
                  _Labeled(
                    label: l10n.goal,
                    child: SegmentedButton<NutritionGoal>(
                      key: ValueKey('profile-goal-${_goal.name}'),
                      style: segmentStyle,
                      showSelectedIcon: false,
                      segments: [
                        for (final goal in NutritionGoal.values)
                          ButtonSegment(
                            value: goal,
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(l10n.goalLabel(goal)),
                            ),
                          ),
                      ],
                      selected: {_goal},
                      onSelectionChanged: _saving
                          ? null
                          : (value) => setState(() => _goal = value.single),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _customTarget(calories: true, on: _customCalories),
                  _customTarget(calories: false, on: _customProtein),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!(l10n),
                        style: TextStyle(color: CyberColors.danger)),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('save-profile'),
                    onPressed: _saving ? null : _saveProfile,
                    icon: const Icon(Icons.save_outlined),
                    label:
                        Text(_saving ? l10n.savingProfile : l10n.saveProfile),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _weightHistory(),
        ],
      ),
    );
  }
}

/// A big number with its unit, label and whether it is estimated or manual.
class _TargetTile extends StatelessWidget {
  const _TargetTile({
    required this.value,
    required this.unit,
    required this.label,
    required this.manual,
  });

  final String value;
  final String unit;
  final String label;
  final bool manual;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: CyberColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CyberColors.border),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(TextSpan(children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: CyberColors.cyan,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  color: CyberColors.cyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ])),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: CyberColors.text)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (manual ? CyberColors.magenta : CyberColors.muted)
                  .withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              manual ? l10n.sourceManual : l10n.sourceEstimated,
              style: TextStyle(
                color: manual ? CyberColors.magenta : CyberColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small caption above a control that has no label of its own.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label,
              style: TextStyle(
                  color: CyberColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          child,
        ],
      );
}

String _inputNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// Weigh-in dates are typed and shown as dd/mm/yyyy in both languages.
String _date(DateTime value) => formatDate(value);

DateTime? _parseDate(String value) {
  final parts = value.trim().split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null ||
      month == null ||
      year == null ||
      year < 1900 ||
      year > 9999) {
    return null;
  }
  final result = DateTime(year, month, day);
  return result.year == year && result.month == month && result.day == day
      ? result
      : null;
}

class _WeightInput {
  const _WeightInput(this.weight, this.date);
  final double weight;
  final DateTime date;
}

class _WeightDialog extends StatefulWidget {
  const _WeightDialog({
    required this.initialWeight,
    required this.initialDate,
    required this.editing,
  });

  final double initialWeight;
  final DateTime initialDate;
  final bool editing;

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weight;
  late final TextEditingController _dateText;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(text: _inputNumber(widget.initialWeight));
    _dateText = TextEditingController(text: _date(widget.initialDate));
  }

  @override
  void dispose() {
    _weight.dispose();
    _dateText.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final today = _day(DateTime.now());
    final parsed = _parseDate(_dateText.text);
    final l10n = context.l10n;
    final selected = await showDatePicker(
      context: context,
      initialDate: parsed == null || parsed.isAfter(today) ? today : parsed,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: l10n.chooseWeighInDate,
      cancelText: l10n.cancel,
      confirmText: l10n.choose,
      fieldLabelText: l10n.weighInDate,
      errorInvalidText: l10n.datePickerFuture,
      errorFormatText: l10n.datePickerInvalid,
    );
    if (selected != null && mounted) _dateText.text = _date(selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _WeightInput(
          double.parse(_weight.text.trim()), _parseDate(_dateText.text)!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.editing ? l10n.editWeight : l10n.logWeight),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('weight-log-value'),
                controller: _weight,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.weightKg),
                validator: (value) {
                  final weight = double.tryParse(value?.trim() ?? '');
                  return weight == null ||
                          !weight.isFinite ||
                          weight <= 0 ||
                          weight > 500
                      ? l10n.weightValueError
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('weight-log-date'),
                controller: _dateText,
                readOnly: widget.editing,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  labelText: l10n.weighInDateField,
                  suffixIcon: widget.editing
                      ? null
                      : IconButton(
                          tooltip: l10n.chooseWeighInDate,
                          onPressed: _chooseDate,
                          icon: const Icon(Icons.calendar_today_outlined),
                        ),
                ),
                validator: (value) {
                  final date = _parseDate(value ?? '');
                  if (date == null) {
                    return l10n.dateFormatError;
                  }
                  if (date.isAfter(_day(DateTime.now()))) {
                    return l10n.dateAfterToday;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.saveWeight)),
      ],
    );
  }
}
