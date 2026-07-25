import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';

class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? CyberColors.cyan;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: resolvedColor,
                ),
              )
            : Icon(icon),
        label: Text(loading ? 'PROCESSING...' : label),
        style: FilledButton.styleFrom(
          backgroundColor: resolvedColor,
          foregroundColor: CyberColors.background,
          disabledBackgroundColor: CyberColors.surfaceAlt,
          disabledForegroundColor: resolvedColor,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
