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
        calorieOverride: _calories.text.trim().isEmpty
            ? null
            : double.parse(_calories.text.trim()),
        proteinOverride: _protein.text.trim().isEmpty
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
    String? hint,
  }) =>
      TextFormField(
        key: ValueKey(keyName),
        controller: controller,
        enabled: !_saving,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        decoration: InputDecoration(labelText: label, hintText: hint),
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

  Widget _targetSummary(Map<String, dynamic>? targets) {
    final l10n = context.l10n;
    if (targets == null) return Text(l10n.targetsInvalidHint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.caloriesPerDayValue(context.formatMeasurement(
              (targets['target_calories'] as num).toDouble())),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(_calories.text.trim().isEmpty
            ? l10n.estimatedCalories
            : l10n.manualCaloriesSource),
        const SizedBox(height: 8),
        Text(
          l10n.proteinPerDayValue(context.formatMeasurement(
              (targets['protein_target'] as num).toDouble())),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(_protein.text.trim().isEmpty
            ? l10n.estimatedProtein
            : l10n.manualProteinSource),
        const SizedBox(height: 8),
        Text(
          'BMR: ${context.formatNumber(targets['bmr'] as num)} kcal · '
          'TDEE: ${context.formatNumber(targets['tdee'] as num)} kcal',
        ),
      ],
    );
  }

  Widget _weightHistory() {
    final chronological = List<WeightEntry>.of(_weights)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final l10n = context.l10n;
    final weight = context.formatMeasurement;
    return CyberCard(
      title: l10n.weightTracking,
      icon: Icons.monitor_weight_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_weights.isEmpty)
            Text(l10n.noWeights)
          else ...[
            Text(
              l10n.latestWeight(weight(chronological.last.weight),
                  _date(chronological.last.recordedAt)),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (chronological.length > 1) ...[
              const SizedBox(height: 6),
              Text(
                l10n.weightChange(
                  context.formatSigned(
                      chronological.last.weight - chronological.first.weight,
                      decimals: 1),
                  _date(chronological.first.recordedAt),
                  _date(chronological.last.recordedAt),
                ),
              ),
            ],
            const SizedBox(height: 10),
            WeightTrendChart(entries: chronological),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('add-weight'),
              onPressed: _saving || !_hasProfile ? null : () => _editWeight(),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.logWeight),
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.weightHistoryNote),
          for (final entry in _weights) ...[
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${weight(entry.weight)} kg\n${_date(entry.recordedAt)}',
                  ),
                ),
                IconButton(
                  key: ValueKey('edit-weight-${entry.id}'),
                  tooltip: l10n.editWeightTooltip(_date(entry.recordedAt)),
                  onPressed: _saving ? null : () => _editWeight(entry),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: ValueKey('delete-weight-${entry.id}'),
                  tooltip: l10n.deleteWeightTooltip(_date(entry.recordedAt)),
                  onPressed: _saving ? null : () => _deleteWeight(entry),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final targets = _preview;
    final l10n = context.l10n;
    String factor(double value) => context.formatNumber(value,
        decimals: value.toString().split('.').last.length);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Text(l10n.profileTitle,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(l10n.profileDisclaimer),
          const SizedBox(height: 16),
          CyberCard(
            title: l10n.personalInfo,
            icon: Icons.person_outline_rounded,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _numberField(
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('profile-gender-$_gender'),
                    initialValue: _gender,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.genderFormula),
                    items: [
                      DropdownMenuItem(value: 'male', child: Text(l10n.male)),
                      DropdownMenuItem(
                          value: 'female', child: Text(l10n.female)),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _gender = value!),
                  ),
                  const SizedBox(height: 12),
                  _numberField(
                    keyName: 'profile-height',
                    label: l10n.heightCm,
                    controller: _height,
                    validator: (value) => _validateNumber(value,
                        name: l10n.heightName, maximum: 300),
                  ),
                  const SizedBox(height: 12),
                  _numberField(
                    keyName: 'profile-weight',
                    label: l10n.currentBodyWeight,
                    controller: _weight,
                    validator: (value) => _validateNumber(value,
                        name: l10n.weightName, maximum: 500),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<NutritionGoal>(
                    key: ValueKey('profile-goal-${_goal.name}'),
                    initialValue: _goal,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.goal),
                    items: NutritionGoal.values
                        .map((goal) => DropdownMenuItem(
                            value: goal, child: Text(l10n.goalLabel(goal))))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _goal = value!),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.estimateFormula),
                  const SizedBox(height: 16),
                  _numberField(
                    keyName: 'profile-calories',
                    label: l10n.manualCalories,
                    hint: l10n.manualHint,
                    controller: _calories,
                    validator: (value) => _validateNumber(value,
                        name: l10n.caloriesLabel,
                        minimum: 1000,
                        inclusiveMinimum: true,
                        maximum: 10000,
                        optional: true),
                  ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _calories.clear();
                              _error = null;
                            }),
                    child: Text(l10n.useEstimatedCalories),
                  ),
                  _numberField(
                    keyName: 'profile-protein',
                    label: l10n.manualProtein,
                    hint: l10n.manualHint,
                    controller: _protein,
                    validator: (value) => _validateNumber(value,
                        name: l10n.proteinLabel, maximum: 500, optional: true),
                  ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _protein.clear();
                              _error = null;
                            }),
                    child: Text(l10n.useEstimatedProtein),
                  ),
                  const SizedBox(height: 10),
                  _targetSummary(targets),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!(l10n),
                        style: TextStyle(color: CyberColors.danger)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('save-profile'),
                      onPressed: _saving ? null : _saveProfile,
                      icon: const Icon(Icons.save_outlined),
                      label:
                          Text(_saving ? l10n.savingProfile : l10n.saveProfile),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _weightHistory(),
        ],
      ),
    );
  }
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
