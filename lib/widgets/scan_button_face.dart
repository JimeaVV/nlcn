import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';

/// The round-or-leaf face of the Scan button, drawn differently for each
/// interface style. It uses the palette of [style] itself, so Settings can
/// preview every style at once.
///
/// - Cyberpunk: neon gradient with a two-colour glow.
/// - Minimal Light: one flat colour and a soft drop shadow.
/// - Forest: a leaf-like rounded square with a green gradient.
/// - Sunset: warm gradient inside a sun halo.
class ScanButtonFace extends StatelessWidget {
  const ScanButtonFace({
    super.key,
    required this.style,
    this.size = 52,
    this.ringColor,
  });

  final AppStyle style;
  final double size;

  /// Colour of the gap between the face and the bar; defaults to the
  /// style's surface.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.paletteFor(style);
    final ring = ringColor ?? p.surface;
    final ringWidth = size * 0.08;
    final icon = Icon(
      style == AppStyle.minimalLight
          ? Icons.photo_camera_outlined
          : Icons.photo_camera_rounded,
      color: Colors.white,
      size: size * 0.48,
    );

    final face = switch (style) {
      AppStyle.cyberpunk => Container(
          key: const ValueKey('scan-face-cyberpunk'),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.primary, p.secondary],
            ),
            border: Border.all(color: ring, width: ringWidth),
            boxShadow: [
              BoxShadow(
                color: p.primary.withValues(alpha: 0.55),
                blurRadius: size * 0.34,
                spreadRadius: 1,
                offset: Offset(-size * 0.06, 0),
              ),
              BoxShadow(
                color: p.secondary.withValues(alpha: 0.45),
                blurRadius: size * 0.34,
                spreadRadius: 1,
                offset: Offset(size * 0.06, 0),
              ),
            ],
          ),
          child: Center(child: icon),
        ),
      AppStyle.minimalLight => Container(
          key: const ValueKey('scan-face-minimalLight'),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.primary,
            border: Border.all(color: ring, width: ringWidth),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: size * 0.2,
                offset: Offset(0, size * 0.06),
              ),
            ],
          ),
          child: Center(child: icon),
        ),
      AppStyle.forest => Container(
          key: const ValueKey('scan-face-forest'),
          decoration: BoxDecoration(
            // Two rounder corners than the others read as a leaf.
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(size * 0.5),
              bottomRight: Radius.circular(size * 0.5),
              topRight: Radius.circular(size * 0.18),
              bottomLeft: Radius.circular(size * 0.18),
            ),
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [p.primary, p.secondary],
            ),
            border: Border.all(color: ring, width: ringWidth),
            boxShadow: [
              BoxShadow(
                color: p.primary.withValues(alpha: 0.30),
                blurRadius: size * 0.24,
                offset: Offset(0, size * 0.08),
              ),
            ],
          ),
          child: Center(child: icon),
        ),
      AppStyle.sunset => Container(
          key: const ValueKey('scan-face-sunset'),
          // The halo: a soft ring in the highlight colour around the sun.
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: p.highlight.withValues(alpha: 0.55),
                blurRadius: size * 0.4,
                spreadRadius: size * 0.06,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Sun at the top, dusk at the bottom; the white icon sits on
              // the orange middle for contrast.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.highlight, p.primary, p.secondary],
                stops: const [0.0, 0.5, 1.0],
              ),
              border: Border.all(color: ring, width: ringWidth),
            ),
            child: Center(child: icon),
          ),
        ),
    };

    return SizedBox.square(dimension: size, child: face);
  }
}

/// Wraps a tappable child so it dips slightly while pressed.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A small round (or leaf, for Forest) camera-screen button that follows
/// the interface style, used for the gallery and manual-log actions.
class StyledCameraButton extends StatelessWidget {
  const StyledCameraButton({
    super.key,
    required this.style,
    required this.icon,
    this.size = 52,
  });

  final AppStyle style;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.paletteFor(style);
    final leaf = BorderRadius.only(
      topLeft: Radius.circular(size * 0.5),
      bottomRight: Radius.circular(size * 0.5),
      topRight: Radius.circular(size * 0.16),
      bottomLeft: Radius.circular(size * 0.16),
    );
    final (fill, border, iconColor, glow) = switch (style) {
      AppStyle.cyberpunk => (
          Colors.black.withValues(alpha: 0.45),
          p.primary,
          p.primary,
          p.primary.withValues(alpha: 0.5),
        ),
      AppStyle.minimalLight => (
          Colors.white,
          Colors.white,
          p.primary,
          Colors.black.withValues(alpha: 0.2),
        ),
      AppStyle.forest => (
          p.primary.withValues(alpha: 0.3),
          p.secondary,
          Colors.white,
          null,
        ),
      AppStyle.sunset => (
          p.secondary.withValues(alpha: 0.4),
          p.highlight,
          p.highlight,
          p.primary.withValues(alpha: 0.35),
        ),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: style == AppStyle.forest ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: style == AppStyle.forest ? leaf : null,
        color: fill,
        border: Border.all(color: border, width: 1.6),
        boxShadow: glow == null
            ? null
            : [BoxShadow(color: glow, blurRadius: size * 0.3)],
      ),
      child: Icon(icon, color: iconColor, size: size * 0.46),
    );
  }
}

/// Corner brackets that frame the plate in the camera preview; colour and
/// roundness follow the interface style.
class ViewfinderFrame extends StatelessWidget {
  const ViewfinderFrame({super.key, required this.style});

  final AppStyle style;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.paletteFor(style);
    return CustomPaint(
      painter: _ViewfinderPainter(
        color: style == AppStyle.minimalLight ? Colors.white : p.primary,
        radius: style == AppStyle.forest ? 26 : 8,
        glow: style == AppStyle.cyberpunk || style == AppStyle.sunset,
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({
    required this.color,
    required this.radius,
    required this.glow,
  });

  final Color color;
  final double radius;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final arm = size.shortestSide * 0.18;
    final rect = Offset.zero & size;
    final r = radius;
    // One bracket per corner: a rounded corner with two short arms.
    final path = Path()
      ..moveTo(rect.left, rect.top + arm)
      ..lineTo(rect.left, rect.top + r)
      ..arcToPoint(Offset(rect.left + r, rect.top), radius: Radius.circular(r))
      ..lineTo(rect.left + arm, rect.top)
      ..moveTo(rect.right - arm, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + r), radius: Radius.circular(r))
      ..lineTo(rect.right, rect.top + arm)
      ..moveTo(rect.right, rect.bottom - arm)
      ..lineTo(rect.right, rect.bottom - r)
      ..arcToPoint(Offset(rect.right - r, rect.bottom),
          radius: Radius.circular(r))
      ..lineTo(rect.right - arm, rect.bottom)
      ..moveTo(rect.left + arm, rect.bottom)
      ..lineTo(rect.left + r, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - r),
          radius: Radius.circular(r))
      ..lineTo(rect.left, rect.bottom - arm);
    if (glow) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.glow != glow;
}
