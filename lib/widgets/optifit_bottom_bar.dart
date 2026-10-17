import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import 'scan_button_face.dart';

class BottomBarItem {
  const BottomBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Bottom navigation with a raised Scan button in the middle:
/// `items[0] · items[1] · Scan · items[2] · items[3]`. Scan is an action, so
/// it never becomes the selected tab.
class OptiFitBottomBar extends StatelessWidget {
  const OptiFitBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.scanLabel,
    required this.onScan,
  }) : assert(items.length == 4);

  final List<BottomBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String scanLabel;
  final VoidCallback onScan;

  Widget _item(int index) => Expanded(
        child: _NavItem(
          key: ValueKey('nav-$index'),
          item: items[index],
          selected: index == selectedIndex,
          onTap: () => onSelected(index),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CyberColors.surface,
        border: Border(top: BorderSide(color: CyberColors.border)),
      ),
      child: SafeArea(
        top: false,
        // Labels may grow with the system font, but only so far that the
        // fixed-height bar still fits them.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _item(0),
                _item(1),
                Expanded(child: _ScanButton(label: scanLabel, onTap: onScan)),
                _item(2),
                _item(3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final BottomBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? CyberColors.cyan : CyberColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? CyberColors.cyan.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child:
                  Icon(selected ? item.selectedIcon : item.icon, color: color),
            ),
            const SizedBox(height: 4),
            _Label(item.label, color: color, bold: selected),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        key: const ValueKey('nav-scan'),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Raised above the bar so it reads as the main action; its look
            // follows the interface style chosen in Settings.
            Transform.translate(
              offset: const Offset(0, -12),
              child: ScanButtonFace(style: CyberColors.style),
            ),
            Transform.translate(
              offset: const Offset(0, -4),
              child: _Label(label, color: CyberColors.cyan, bold: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line that shrinks instead of wrapping, even with large system fonts.
class _Label extends StatelessWidget {
  const _Label(this.text, {required this.color, required this.bold});

  final String text;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
