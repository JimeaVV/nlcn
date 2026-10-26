import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../core/locale_controller.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/photo_collector.dart';
import '../engine/daily_habits.dart';
import '../services/reminder_service.dart';
import '../services/water_reminder_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/info_button.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/scan_button_face.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.localeController,
    this.database,
    this.onHistoryCleared,
    this.reminders,
    this.waterReminders,
    this.backup = const BackupService(),
    this.onDataRestored,
    this.collector,
  });

  /// Kept scan photos; [PhotoCollector.instance] by default.
  final PhotoCollector? collector;
  PhotoCollector get _photos => collector ?? PhotoCollector.instance;

  final ThemeController themeController;
  final LocaleController localeController;
  final DatabaseService? database;

  /// Called after saved meal plans, workouts and logs are deleted.
  final VoidCallback? onHistoryCleared;

  /// Meal reminders; the card is hidden without it.
  final ReminderController? reminders;

  /// Water reminders; the card is hidden without it.
  final WaterReminderController? waterReminders;
  final BackupService backup;

  /// Called after a backup replaced all data.
  final VoidCallback? onDataRestored;

  DatabaseService get _database => database ?? DatabaseService.instance;

  ({String title, String body}) Function(MealSlot) _reminderTexts(
          AppLocalizations l10n) =>
      (meal) => (
            title: l10n.reminderNotificationTitle(l10n.mealSlotLabel(meal)),
            body: l10n.reminderNotificationBody,
          );

  Future<void> _toggleReminders(BuildContext context, bool value) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final allowed = await reminders!.setEnabled(value,
        texts: _reminderTexts(l10n), channelName: l10n.reminderChannel);
    if (!allowed) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.remindersDenied)));
    }
  }

  Future<void> _pickReminderTime(BuildContext context, MealSlot meal) async {
    final l10n = context.l10n;
    final controller = reminders!;
    final time = await showTimePicker(
      context: context,
      initialTime: controller.times[meal]!,
    );
    if (time == null) return;
    await controller.setTime(meal, time,
        texts: _reminderTexts(l10n), channelName: l10n.reminderChannel);
  }

  /// Whether today's water already reaches the goal; reminders then skip
  /// the rest of today.
  Future<bool> _waterGoalReached() async {
    try {
      return await _database.getWater(DateTime.now()) >= waterTargetMl;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggleWaterReminders(BuildContext context, bool value) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final allowed = await waterReminders!.setEnabled(value,
        texts: WaterReminderTexts.of(l10n),
        goalReachedToday: await _waterGoalReached());
    if (!allowed) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.remindersDenied)));
    }
  }

  Future<void> _setWaterInterval(BuildContext context, double hours) async {
    final texts = WaterReminderTexts.of(context.l10n);
    await waterReminders!.setInterval(hours,
        texts: texts, goalReachedToday: await _waterGoalReached());
  }

  Future<void> _pickWaterTime(BuildContext context,
      {required bool start}) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final controller = waterReminders!;
    final time = await showTimePicker(
      context: context,
      initialTime: start ? controller.from : controller.to,
    );
    if (time == null) return;
    final saved = await controller.setWindow(
        start ? time : controller.from, start ? controller.to : time,
        texts: WaterReminderTexts.of(l10n),
        goalReachedToday: await _waterGoalReached());
    if (!saved) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.waterRemindersBadWindow)));
    }
  }

  Future<void> _exportPhotos(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getTemporaryDirectory();
      final zip = await _photos.exportZip(
          '${dir.path}/macrorunner_photos_${diaryDateKey(DateTime.now())}.zip');
      if (zip == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.collectEmpty)));
        return;
      }
      await SharePlus.instance.share(ShareParams(files: [XFile(zip.path)]));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.collectExportFailed)));
    }
  }

  Future<void> _deletePhotos(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.collectDeleteTitle),
        content: Text(l10n.collectDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: CyberColors.danger,
                foregroundColor: CyberColors.background),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _photos.clear();
      messenger.showSnackBar(SnackBar(content: Text(l10n.collectDeleted)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.clearAllFailed)));
    }
  }

  Future<void> _export(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await backup.export(_database);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.backupImportTitle),
        content: Text(l10n.backupImportBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.backupRestore),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final data = await backup.pick();
      if (data == null) return;
      await _database.restoreBackup(data);
      onDataRestored?.call();
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupRestored)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupInvalid)));
    }
  }

  Future<void> _clearHistory(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clearAllTitle),
        content: Text(l10n.clearAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: CyberColors.danger,
                foregroundColor: CyberColors.background),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _database.clearAllHistory();
      onHistoryCleared?.call();
      messenger.showSnackBar(SnackBar(content: Text(l10n.historyCleared)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.clearAllFailed)));
    }
  }

  /// Named after its accent colour, which the preview beside it shows.
  String _styleName(AppLocalizations l10n, AppStyle style) => switch (style) {
        AppStyle.cyberpunk => l10n.styleCyan,
        AppStyle.minimalLight => l10n.styleBlue,
        AppStyle.forest => l10n.styleGreen,
        AppStyle.sunset => l10n.styleOrange,
      };

  String _styleBackground(AppLocalizations l10n, AppStyle style) =>
      AppTheme.paletteFor(style).brightness == Brightness.dark
          ? l10n.styleDarkBackground
          : l10n.styleLightBackground;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeController,
        localeController,
        if (reminders != null) reminders!,
        if (waterReminders != null) waterReminders!,
        _photos,
      ]),
      builder: (context, _) {
        final l10n = context.l10n;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              Text(l10n.settingsTitle,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 18),
              CyberCard(
                title: l10n.languageTitle,
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AppLanguage>(
                    showSelectedIcon: false,
                    segments: [
                      for (final language in AppLanguage.values)
                        ButtonSegment(
                          value: language,
                          label: Text(language.nativeName,
                              key: ValueKey('language-${language.name}')),
                        ),
                    ],
                    selected: {localeController.language},
                    onSelectionChanged: (value) =>
                        localeController.setLanguage(value.single),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              CyberCard(
                title: l10n.interfaceStyle,
                child: Column(
                  children: [
                    for (final option in appStyleOptions)
                      _OptionTile(
                        key: ValueKey('style-${option.style.name}'),
                        icon: option.icon,
                        preview: ScanButtonFace(
                          style: option.style,
                          size: 40,
                          ringColor: Colors.transparent,
                        ),
                        title: _styleName(l10n, option.style),
                        subtitle: _styleBackground(l10n, option.style),
                        selected: themeController.style == option.style,
                        onTap: () => themeController.setStyle(option.style),
                      ),
                  ],
                ),
              ),
              if (reminders != null) ...[
                const SizedBox(height: 18),
                _remindersCard(context, l10n),
              ],
              if (waterReminders != null) ...[
                const SizedBox(height: 18),
                _waterRemindersCard(context, l10n),
              ],
              const SizedBox(height: 18),
              _collectCard(context, l10n),
              const SizedBox(height: 18),
              CyberCard(
                key: const ValueKey('backup-card'),
                title: l10n.backupTitle,
                trailing: InfoButton(
                    key: const ValueKey('backup-info'),
                    title: l10n.backupTitle,
                    paragraphs: [l10n.backupBody]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('backup-export'),
                      onPressed: () => _export(context),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(l10n.backupExport),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('backup-import'),
                      onPressed: () => _restore(context),
                      icon: const Icon(Icons.restore_rounded),
                      label: Text(l10n.backupImport),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              CyberCard(
                title: l10n.dataTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('clear-history'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CyberColors.danger,
                        side: BorderSide(color: CyberColors.danger),
                      ),
                      onPressed: () => _clearHistory(context),
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: Text(l10n.clearAllHistory),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension on SettingsScreen {
  Widget _collectCard(BuildContext context, AppLocalizations l10n) {
    final photos = _photos;
    return CyberCard(
      key: const ValueKey('collect-card'),
      title: l10n.collectTitle,
      trailing: InfoButton(
          key: const ValueKey('collect-info'),
          title: l10n.collectTitle,
          paragraphs: [l10n.collectBody]),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const ValueKey('collect-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.collectSwitch),
              value: photos.enabled,
              onChanged: photos.setEnabled,
            ),
            FutureBuilder(
              future: photos.stats(),
              builder: (context, snapshot) {
                final stats = snapshot.data;
                return Text(
                  key: const ValueKey('collect-stats'),
                  stats == null || stats.photos == 0
                      ? l10n.collectEmpty
                      : l10n.collectStats('${stats.photos}',
                          context.formatNumber(stats.bytes / 1e6, decimals: 1)),
                  style: Theme.of(context).textTheme.titleMedium,
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('collect-export'),
                  onPressed: () => _exportPhotos(context),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(l10n.collectExport),
                ),
                TextButton.icon(
                  key: const ValueKey('collect-delete'),
                  style:
                      TextButton.styleFrom(foregroundColor: CyberColors.danger),
                  onPressed: () => _deletePhotos(context),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(l10n.collectDelete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _waterRemindersCard(BuildContext context, AppLocalizations l10n) {
    final controller = waterReminders!;
    String hours(double value) => l10n.waterRemindersHours(context
        .formatNumber(value, decimals: value == value.roundToDouble() ? 0 : 1));
    return CyberCard(
      key: const ValueKey('water-reminders-card'),
      title: l10n.waterRemindersTitle,
      trailing: InfoButton(
          key: const ValueKey('water-reminders-info'),
          title: l10n.waterRemindersTitle,
          paragraphs: [
            l10n.waterRemindersBody(
                '${context.formatNumber(waterTargetMl)}\u00A0ml'),
          ]),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const ValueKey('water-reminders-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.waterRemindersSwitch),
              value: controller.enabled,
              onChanged: (value) => _toggleWaterReminders(context, value),
            ),
            Text(l10n.waterRemindersEvery,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in waterReminderIntervals)
                  ChoiceChip(
                    key: ValueKey('water-every-$option'),
                    label: Text(hours(option)),
                    selected: controller.everyHours == option,
                    onSelected: controller.enabled
                        ? (_) => _setWaterInterval(context, option)
                        : null,
                  ),
              ],
            ),
            for (final start in [true, false])
              ListTile(
                key: ValueKey(start ? 'water-from' : 'water-to'),
                contentPadding: EdgeInsets.zero,
                enabled: controller.enabled,
                leading: const Icon(Icons.schedule_rounded),
                title: Text(
                    start ? l10n.waterRemindersFrom : l10n.waterRemindersTo),
                trailing: Text(
                  (start ? controller.from : controller.to).format(context),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => _pickWaterTime(context, start: start),
              ),
          ],
        ),
      ),
    );
  }

  Widget _remindersCard(BuildContext context, AppLocalizations l10n) {
    final controller = reminders!;
    return CyberCard(
      key: const ValueKey('reminders-card'),
      title: l10n.remindersTitle,
      // The card paints its own background; the tiles need a Material for
      // their ink.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const ValueKey('reminders-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.remindersSwitch),
              value: controller.enabled,
              onChanged: (value) => _toggleReminders(context, value),
            ),
            for (final entry in controller.times.entries)
              ListTile(
                key: ValueKey('reminder-${entry.key.name}'),
                contentPadding: EdgeInsets.zero,
                enabled: controller.enabled,
                leading: const Icon(Icons.schedule_rounded),
                title: Text(l10n.mealSlotLabel(entry.key)),
                trailing: Text(
                  entry.value.format(context),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => _pickReminderTime(context, entry.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.preview,
  });

  final IconData icon;

  /// Shown instead of [icon] when given, e.g. a style's Scan button.
  final Widget? preview;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CyberColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? CyberColors.cyan : CyberColors.border,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  preview == null
                      ? Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: CyberColors.cyan.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: CyberColors.cyan),
                        )
                      : SizedBox.square(
                          dimension: 44, child: Center(child: preview)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: CyberColors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: CyberColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? CyberColors.lime : CyberColors.muted,
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
