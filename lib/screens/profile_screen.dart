import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../engine/nutrition_targets.dart';
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
  String? _error;
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
          _error = 'Không thể tải hồ sơ. Vui lòng thử lại.';
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
    } on ArgumentError catch (error) {
      setState(() => _error = _targetError('${error.message}'));
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
      _message('Đã lưu hồ sơ và mục tiêu.');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể lưu hồ sơ. Vui lòng thử lại.');
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
    final number = double.tryParse(text);
    if (number == null || !number.isFinite) return 'Nhập $name hợp lệ.';
    if ((inclusiveMinimum ? number < minimum : number <= minimum) ||
        number > maximum) {
      return minimum == 0
          ? '$name phải lớn hơn 0 và không quá ${_number(maximum)}.'
          : '$name phải từ ${_number(minimum)} đến ${_number(maximum)}.';
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
      _message('Đã lưu cân nặng ngày ${_date(input.date)}.');
    } catch (_) {
      if (mounted) _message('Không thể lưu cân nặng. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteWeight(WeightEntry entry) async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lần ghi cân nặng?'),
        content: Text(
          '${_number(entry.weight)} kg · ${_date(entry.recordedAt)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
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
      _message('Đã xóa lần ghi cân nặng.');
    } catch (_) {
      if (mounted) _message('Không thể xóa cân nặng. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _targetSummary(Map<String, dynamic>? targets) {
    if (targets == null) {
      return const Text(
        'Nhập thông tin và mục tiêu hợp lệ để xem ước tính. '
        'Năng lượng từ protein (4 kcal/g) không vượt tổng calo.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_number((targets['target_calories'] as num).toDouble())} kcal/ngày',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(_calories.text.trim().isEmpty ? 'Calo ước tính' : 'Calo tự đặt'),
        const SizedBox(height: 8),
        Text(
          '${_number((targets['protein_target'] as num).toDouble())} g protein/ngày',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(_protein.text.trim().isEmpty
            ? 'Protein ước tính'
            : 'Protein tự đặt'),
        const SizedBox(height: 8),
        Text(
          'BMR: ${targets['bmr']} kcal · TDEE: ${targets['tdee']} kcal',
        ),
      ],
    );
  }

  Widget _weightHistory() {
    final chronological = List<WeightEntry>.of(_weights)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return CyberCard(
      title: 'Theo dõi cân nặng',
      icon: Icons.monitor_weight_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_weights.isEmpty)
            const Text('Chưa có lần ghi cân nặng. Lưu hồ sơ để bắt đầu.')
          else ...[
            Text(
              'Gần nhất: ${_number(chronological.last.weight)} kg '
              '· ${_date(chronological.last.recordedAt)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (chronological.length > 1) ...[
              const SizedBox(height: 6),
              Text(
                'Thay đổi: ${_signed(chronological.last.weight - chronological.first.weight)} kg '
                'từ ${_date(chronological.first.recordedAt)} '
                'đến ${_date(chronological.last.recordedAt)}',
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
              label: const Text('Ghi cân nặng'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mỗi ngày lưu một giá trị; ghi lại cùng ngày sẽ cập nhật giá trị đó. '
            'Biểu đồ hiển thị tối đa 90 lần ghi gần nhất.',
          ),
          for (final entry in _weights) ...[
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_number(entry.weight)} kg\n${_date(entry.recordedAt)}',
                  ),
                ),
                IconButton(
                  key: ValueKey('edit-weight-${entry.id}'),
                  tooltip: 'Sửa cân nặng ngày ${_date(entry.recordedAt)}',
                  onPressed: _saving ? null : () => _editWeight(entry),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: ValueKey('delete-weight-${entry.id}'),
                  tooltip: 'Xóa cân nặng ngày ${_date(entry.recordedAt)}',
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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Text('Hồ sơ & mục tiêu',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text(
            'Ước tính dành cho người trưởng thành từ 18 tuổi. '
            'Nhu cầu thực tế có thể khác; đây không phải chỉ định y khoa.',
          ),
          const SizedBox(height: 16),
          CyberCard(
            title: 'Thông tin cá nhân',
            icon: Icons.person_outline_rounded,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _numberField(
                    keyName: 'profile-age',
                    label: 'Tuổi',
                    controller: _age,
                    integer: true,
                    validator: (value) {
                      final number = int.tryParse(value?.trim() ?? '');
                      return number == null || number < 18 || number > 100
                          ? 'Nhập tuổi từ 18 đến 100.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('profile-gender-$_gender'),
                    initialValue: _gender,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Giới tính dùng trong công thức'),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Nam')),
                      DropdownMenuItem(value: 'female', child: Text('Nữ')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _gender = value!),
                  ),
                  const SizedBox(height: 12),
                  _numberField(
                    keyName: 'profile-height',
                    label: 'Chiều cao (cm)',
                    controller: _height,
                    validator: (value) =>
                        _validateNumber(value, name: 'Chiều cao', maximum: 300),
                  ),
                  const SizedBox(height: 12),
                  _numberField(
                    keyName: 'profile-weight',
                    label: 'Cân nặng hiện tại (kg)',
                    controller: _weight,
                    validator: (value) =>
                        _validateNumber(value, name: 'Cân nặng', maximum: 500),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<double>(
                    key: ValueKey('profile-activity-$_activity'),
                    initialValue: _activity,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Mức vận động'),
                    items: const [
                      DropdownMenuItem(
                          value: 1.2, child: Text('Ít vận động · ×1,2')),
                      DropdownMenuItem(
                          value: 1.375, child: Text('Nhẹ · ×1,375')),
                      DropdownMenuItem(value: 1.55, child: Text('Vừa · ×1,55')),
                      DropdownMenuItem(
                          value: 1.725, child: Text('Nhiều · ×1,725')),
                      DropdownMenuItem(
                          value: 1.9, child: Text('Rất nhiều · ×1,9')),
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
                    decoration: const InputDecoration(labelText: 'Mục tiêu'),
                    items: NutritionGoal.values
                        .map((goal) => DropdownMenuItem(
                            value: goal, child: Text(goal.label)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _goal = value!),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ước tính: BMR theo Mifflin–St Jeor; TDEE = BMR × mức vận động. '
                    'Calo giảm/giữ/tăng cân = 90%/100%/110% TDEE. '
                    'Protein = 1,8 g × cân nặng (kg).',
                  ),
                  const SizedBox(height: 16),
                  _numberField(
                    keyName: 'profile-calories',
                    label: 'Calo tự đặt (kcal/ngày)',
                    hint: 'Để trống để dùng ước tính',
                    controller: _calories,
                    validator: (value) => _validateNumber(value,
                        name: 'Calo',
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
                    child: const Text('Dùng calo ước tính'),
                  ),
                  _numberField(
                    keyName: 'profile-protein',
                    label: 'Protein tự đặt (g/ngày)',
                    hint: 'Để trống để dùng ước tính',
                    controller: _protein,
                    validator: (value) => _validateNumber(value,
                        name: 'Protein', maximum: 500, optional: true),
                  ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _protein.clear();
                              _error = null;
                            }),
                    child: const Text('Dùng protein ước tính'),
                  ),
                  const SizedBox(height: 10),
                  _targetSummary(targets),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: CyberColors.danger)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('save-profile'),
                      onPressed: _saving ? null : _saveProfile,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Đang lưu...' : 'Lưu hồ sơ'),
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

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

String _inputNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String _targetError(String message) {
  if (message.contains('Protein energy')) {
    return 'Năng lượng từ protein (4 kcal/g) không được vượt tổng calo. '
        'Hãy điều chỉnh mục tiêu calo hoặc protein.';
  }
  if (message.contains('Calorie target')) {
    return 'Mục tiêu calo nằm ngoài khoảng ứng dụng hỗ trợ (1.000–10.000 kcal). '
        'Kiểm tra hồ sơ hoặc tự nhập mục tiêu phù hợp.';
  }
  if (message.contains('Protein target')) {
    return 'Mục tiêu protein phải lớn hơn 0 và không quá 500 g. '
        'Kiểm tra hồ sơ hoặc tự nhập mục tiêu.';
  }
  return 'Thông tin chưa cho ước tính hợp lệ. '
      'Kiểm tra tuổi, chiều cao, cân nặng và mục tiêu.';
}

String _signed(double value) =>
    value > 0 ? '+${_number(value)}' : _number(value);

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

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
    final selected = await showDatePicker(
      context: context,
      initialDate: parsed == null || parsed.isAfter(today) ? today : parsed,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Chọn ngày cân',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      fieldLabelText: 'Ngày cân',
      errorInvalidText: 'Chọn ngày không sau hôm nay.',
      errorFormatText: 'Nhập ngày hợp lệ.',
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
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.editing ? 'Sửa cân nặng' : 'Ghi cân nặng'),
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
                  decoration: const InputDecoration(labelText: 'Cân nặng (kg)'),
                  validator: (value) {
                    final weight = double.tryParse(value?.trim() ?? '');
                    return weight == null ||
                            !weight.isFinite ||
                            weight <= 0 ||
                            weight > 500
                        ? 'Nhập cân nặng lớn hơn 0 và không quá 500 kg.'
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
                    labelText: 'Ngày cân (ngày/tháng/năm)',
                    suffixIcon: widget.editing
                        ? null
                        : IconButton(
                            tooltip: 'Chọn ngày cân',
                            onPressed: _chooseDate,
                            icon: const Icon(Icons.calendar_today_outlined),
                          ),
                  ),
                  validator: (value) {
                    final date = _parseDate(value ?? '');
                    if (date == null) {
                      return 'Nhập ngày theo dạng ngày/tháng/năm.';
                    }
                    if (date.isAfter(_day(DateTime.now()))) {
                      return 'Ngày cân không được sau hôm nay.';
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(onPressed: _submit, child: const Text('Lưu cân nặng')),
        ],
      );
}
