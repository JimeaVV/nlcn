import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';

/// A neon line sweeping over a photo while it is being recognized. Drawn by
/// the fragment shader in `shaders/scan_sweep.frag`; where shaders cannot
/// load (some test hosts), a gradient band stands in. Still when the system
/// asks for reduced motion.
class ScanSweep extends StatefulWidget {
  const ScanSweep({super.key});

  @override
  State<ScanSweep> createState() => _ScanSweepState();
}

class _ScanSweepState extends State<ScanSweep>
    with SingleTickerProviderStateMixin {
  static final Future<ui.FragmentProgram?> _program =
      ui.FragmentProgram.fromAsset('shaders/scan_sweep.frag')
          .then<ui.FragmentProgram?>((program) => program,
              onError: (_) => null);

  late final AnimationController _sweep = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _program.then((program) {
      if (program != null && mounted) {
        setState(() => _shader = program.fragmentShader());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep
        ..stop()
        ..value = 0.5;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          painter: _SweepPainter(
            progress: _sweep,
            shader: _shader,
            line: CyberColors.cyan,
            trail: CyberColors.magenta,
          ),
          child: const SizedBox.expand(),
        ),
      );
}

class _SweepPainter extends CustomPainter {
  _SweepPainter({
    required this.progress,
    required this.shader,
    required this.line,
    required this.trail,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final ui.FragmentShader? shader;
  final Color line;
  final Color trail;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = this.shader;
    final rect = Offset.zero & size;
    if (shader != null) {
      var i = 0;
      void put(double value) => shader.setFloat(i++, value);
      put(size.width);
      put(size.height);
      put(progress.value);
      for (final colour in [line, trail]) {
        put(colour.r);
        put(colour.g);
        put(colour.b);
        put(colour.a);
      }
      canvas.drawRect(rect, Paint()..shader = shader);
      return;
    }
    // Fallback: a soft band at the same position as the shader's line.
    final y = (progress.value * 1.2 - 0.1) * size.height;
    final band = Rect.fromLTRB(0, y - size.height * .25, size.width, y + 2);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            trail.withValues(alpha: 0),
            trail.withValues(alpha: .25),
            line.withValues(alpha: .9),
          ],
          stops: const [0, .9, 1],
        ).createShader(band),
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) =>
      old.shader != shader || old.line != line || old.trail != trail;
}
