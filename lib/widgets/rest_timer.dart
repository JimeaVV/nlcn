import 'dart:async';

import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../core/haptics.dart';
import '../l10n/l10n.dart';

/// A rest countdown between sets, shown over the workout. It vibrates when
/// the rest is over; it only runs while the app is open.
class RestTimerBar extends StatefulWidget {
  const RestTimerBar({
    super.key,
    required this.exerciseName,
    required this.onClose,
    this.seconds = 90,
  });

  final String exerciseName;
  final VoidCallback onClose;

  /// 90 seconds suits most sets; the buttons move it by 15.
  final int seconds;

  @override
  State<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends State<RestTimerBar> {
  late int _total = widget.seconds;
  late int _left = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_left <= 1) {
      _timer?.cancel();
      Haptics.strong();
    }
    setState(() => _left = _left <= 1 ? 0 : _left - 1);
  }

  void _shift(int seconds) {
    setState(() {
      _left = (_left + seconds).clamp(0, 600);
      _total = _total < _left ? _left : _total;
    });
    if (_left > 0 && !(_timer?.isActive ?? false)) {
      _start();
    }
  }

  String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final done = _left == 0;
    final color = done ? CyberColors.lime : CyberColors.cyan;
    return Material(
      key: const ValueKey('rest-timer'),
      color: CyberColors.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(done ? Icons.check_circle_rounded : Icons.timer_outlined,
                    color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done
                            ? l10n.restTimerDone
                            : l10n.restTimerLabel(_clock(_left)),
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        widget.exerciseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: CyberColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('rest-less'),
                  tooltip: l10n.restTimerLess,
                  onPressed: done ? null : () => _shift(-15),
                  icon: const Icon(Icons.remove_rounded),
                ),
                IconButton(
                  key: const ValueKey('rest-more'),
                  tooltip: l10n.restTimerMore,
                  onPressed: () => _shift(15),
                  icon: const Icon(Icons.add_rounded),
                ),
                IconButton(
                  key: const ValueKey('rest-stop'),
                  tooltip: l10n.restTimerStop,
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: _total == 0 ? 0 : _left / _total,
                  color: color,
                  backgroundColor: CyberColors.surfaceAlt,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
