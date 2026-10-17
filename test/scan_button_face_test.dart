import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/core/cyber_theme.dart';
import 'package:optifit/core/locale_controller.dart';
import 'package:optifit/screens/settings_screen.dart';
import 'package:optifit/widgets/optifit_bottom_bar.dart';
import 'package:optifit/widgets/scan_button_face.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/localized_app.dart';

BoxDecoration _decoration(WidgetTester tester, AppStyle style) => tester
    .widget<Container>(find.byKey(ValueKey('scan-face-${style.name}')))
    .decoration as BoxDecoration;

const _items = [
  BottomBarItem(icon: Icons.today, selectedIcon: Icons.today, label: 'A'),
  BottomBarItem(icon: Icons.today, selectedIcon: Icons.today, label: 'B'),
  BottomBarItem(icon: Icons.today, selectedIcon: Icons.today, label: 'C'),
  BottomBarItem(icon: Icons.today, selectedIcon: Icons.today, label: 'D'),
];

void main() {
  tearDown(() => CyberColors.apply(AppStyle.cyberpunk));

  testWidgets('every interface style draws its own Scan button',
      (tester) async {
    await tester.pumpWidget(localizedApp(
      home: Scaffold(
        body: Row(children: [
          for (final style in AppStyle.values) ScanButtonFace(style: style),
        ]),
      ),
    ));

    final cyber = _decoration(tester, AppStyle.cyberpunk);
    expect(cyber.shape, BoxShape.circle);
    expect(cyber.gradient, isA<LinearGradient>());
    expect(cyber.boxShadow, hasLength(2), reason: 'two-colour neon glow');

    final minimal = _decoration(tester, AppStyle.minimalLight);
    expect(minimal.gradient, isNull, reason: 'flat single colour');
    expect(minimal.color, AppTheme.paletteFor(AppStyle.minimalLight).primary);

    final forest = _decoration(tester, AppStyle.forest);
    expect(forest.shape, BoxShape.rectangle);
    final leaf = forest.borderRadius! as BorderRadius;
    expect(leaf.topLeft, isNot(leaf.topRight), reason: 'leaf-like corners');

    final halo = _decoration(tester, AppStyle.sunset);
    expect(halo.boxShadow!.single.color.a, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bar follows the chosen style and dips while pressed',
      (tester) async {
    CyberColors.apply(AppStyle.forest);
    var scans = 0;
    await tester.pumpWidget(localizedApp(
      home: Scaffold(
        bottomNavigationBar: OptiFitBottomBar(
          items: _items,
          selectedIndex: 0,
          onSelected: (_) {},
          scanLabel: 'Quét',
          onScan: () => scans++,
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('scan-face-forest')), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-face-cyberpunk')), findsNothing);

    final gesture = await tester
        .startGesture(tester.getCenter(find.byKey(const ValueKey('nav-scan'))));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(scans, 1);
  });

  testWidgets('Settings previews the Scan button of each style',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(localizedApp(
      home: Scaffold(
        body: SettingsScreen(
          themeController: ThemeController(),
          localeController: LocaleController(),
        ),
      ),
    ));
    for (final style in AppStyle.values) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('style-${style.name}')),
          matching: find.byKey(ValueKey('scan-face-${style.name}')),
        ),
        findsOneWidget,
      );
    }
  });
}
