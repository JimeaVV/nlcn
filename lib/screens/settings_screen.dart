import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../core/locale_controller.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../services/photo_collector.dart';
import '../services/reminder_service.dart';
import '../widgets/cyber_card.dart';
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

  String _styleDescription(AppLocalizations l10n, AppStyle style) =>
      switch (style) {
        AppStyle.cyberpunk => l10n.styleCyberpunkDescription,
        AppStyle.minimalLight => l10n.styleMinimalLightDescription,
        AppStyle.forest => l10n.styleForestDescription,
        AppStyle.sunset => l10n.styleSunsetDescription,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeController,
        localeController,
        if (reminders != null) reminders!,
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
              const SizedBox(height: 6),
              Text(
                l10n.settingsSubtitle,
                style: TextStyle(color: CyberColors.muted),
              ),
              const SizedBox(height: 18),
              CyberCard(
                title: l10n.offlineModeTitle,
                icon: Icons.offline_bolt_rounded,
                child: Text(
                  l10n.offlineModeBody,
                  style: TextStyle(color: CyberColors.muted),
                ),
              ),
              const SizedBox(height: 18),
              CyberCard(
                title: l10n.languageTitle,
                icon: Icons.translate_rounded,
                child: Column(
                  children: [
                    for (final language in AppLanguage.values)
                      _OptionTile(
                        key: ValueKey('language-${language.name}'),
                        icon: Icons.language_rounded,
                        title: language.nativeName,
                        subtitle: language.name.toUpperCase(),
                        selected: localeController.language == language,
                        onTap: () => localeController.setLanguage(language),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              CyberCard(
                title: l10n.interfaceStyle,
                icon: Icons.palette_outlined,
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
                        title: option.name,
                        subtitle: _styleDescription(l10n, option.style),
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
              const SizedBox(height: 18),
              _collectCard(context, l10n),
              const SizedBox(height: 18),
              CyberCard(
                key: const ValueKey('backup-card'),
                title: l10n.backupTitle,
                icon: Icons.backup_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.backupBody,
                        style: TextStyle(color: CyberColors.muted)),
                    const SizedBox(height: 12),
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
                icon: Icons.storage_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.clearAllBody,
                        style: TextStyle(color: CyberColors.muted)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('clear-history'),
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
      icon: Icons.photo_library_outlined,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.collectBody, style: TextStyle(color: CyberColors.muted)),
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

  Widget _remindersCard(BuildContext context, AppLocalizations l10n) {
    final controller = reminders!;
    return CyberCard(
      key: const ValueKey('reminders-card'),
      title: l10n.remindersTitle,
      icon: Icons.notifications_active_outlined,
      // The card paints its own background; the tiles need a Material for
      // their ink.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.remindersBody,
                style: TextStyle(color: CyberColors.muted)),
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
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? CyberColors.lime : CyberColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
