import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/widgets/scan_sweep.dart';

Widget _host({required bool reduceMotion}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Center(
          child: SizedBox(width: 300, height: 200, child: ScanSweep()),
        ),
      ),
    );

void main() {
  testWidgets('keeps sweeping while shown', (tester) async {
    await tester.pumpWidget(_host(reduceMotion: false));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isTrue,
        reason: 'the line keeps moving');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('holds still when the system reduces motion', (tester) async {
    await tester.pumpWidget(_host(reduceMotion: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
