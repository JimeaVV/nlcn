import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../core/locale_controller.dart';
import '../l10n/l10n.dart';
import '../services/database_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/scan_button_face.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.localeController,
    this.database,
    this.onHistoryCleared,
  });

  final ThemeController themeController;
  final LocaleController localeController;
  final DatabaseService? database;

  /// Called after saved meal plans, workouts and logs are deleted.
  final VoidCallback? onHistoryCleared;

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
      await (database ?? DatabaseService.instance).clearAllHistory();
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
      listenable: Listenable.merge([themeController, localeController]),
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
