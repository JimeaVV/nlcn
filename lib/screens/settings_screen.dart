import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../core/locale_controller.dart';
import '../l10n/l10n.dart';
import '../widgets/cyber_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.localeController,
  });

  final ThemeController themeController;
  final LocaleController localeController;

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
                        icon: option.icon,
                        title: option.name,
                        subtitle: _styleDescription(l10n, option.style),
                        selected: themeController.style == option.style,
                        onTap: () => themeController.setStyle(option.style),
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
  });

  final IconData icon;
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: CyberColors.cyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: CyberColors.cyan),
                ),
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
