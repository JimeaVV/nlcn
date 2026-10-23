import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/models/scan_plate.dart';
import 'package:optifit/models/vn_food.dart';
import 'package:optifit/services/food_recognizer.dart';
import 'package:optifit/widgets/food_log_sheet.dart';
import 'package:optifit/widgets/variant_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/localized_app.dart';

final _variants = parseFoodVariants(
    File('assets/data/vn_food/food_variants.csv').readAsStringSync());

String _skin(String skin) => switch (skin) {
      'bo_da' => 'bỏ da',
      'ca_da' => 'cả da',
      _ => '',
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the variants table has every group and its values', () {
    for (final group in variantGroups) {
      expect(_variants.inGroup(group), isNotEmpty, reason: group);
    }
    final breast = _variants.find('ga', 'uc|bo_da|luoc')!;
    expect(breast.kcal, 151);
    expect(breast.protein, 28.98);
    expect(breast.label('vi', _skin), 'Ức gà, bỏ da, luộc / hầm');
    expect(breast.label('en', _skin), 'Chicken breast, bỏ da, boiled / stewed',
        reason: 'the skin name comes from the caller, in its language');
    // Cooked rice is served one way: just its name.
    expect(_variants.find('tinh_bot', 'com_trang||chin')!.label('vi', _skin),
        'Cơm trắng');
    expect(_variants.find('trung', 'ca_qua||luoc')!.unitGrams, 50);
  });

  test('every scanned component that has variants opens on a real one', () {
    for (final MapEntry(key: code, value: (group, key))
        in componentVariants.entries) {
      expect(_variants.find(group, key), isNotNull, reason: '$code → $key');
    }
  });

  group('a plate item takes a variant', () {
    const egg = VnComponent(
        code: 'trung_op_la',
        nameVi: 'Trứng ốp la',
        nameEn: 'Fried egg',
        kcalPer100g: 192,
        proteinPer100g: 11.56,
        carbPer100g: 0.9,
        fatPer100g: 15.81,
        unitNameVi: 'quả',
        unitGrams: 55);

    test('in units when the variant has a unit weight', () {
      final item =
          PlateItem(component: egg, included: true, inUnits: true, amount: 2);
      final boiled = _variants.find('trung', 'ca_qua||luoc')!;
      item.refine(boiled.asComponent(egg, 'Trứng luộc', 'Boiled egg'));
      expect(item.inUnits, isTrue);
      expect(item.grams, 100, reason: 'two 50 g eggs');
      expect(item.calories, closeTo(155, 1e-9));
      expect(item.component.code, 'trung_op_la', reason: 'same plate slot');
    });

    test('in grams, the same weight, when it has none', () {
      const fried = VnComponent(
          code: 'ga_chien',
          nameVi: 'Gà chiên',
          nameEn: 'Fried chicken',
          kcalPer100g: 260,
          proteinPer100g: 19,
          carbPer100g: 6,
          fatPer100g: 17,
          unitNameVi: 'miếng',
          unitGrams: 165);
      final item =
          PlateItem(component: fried, included: true, inUnits: true, amount: 1);
      final breast = _variants.find('ga', 'uc|bo_da|luoc')!;
      item.refine(breast.asComponent(fried, 'Ức gà', 'Chicken breast'));
      expect(item.inUnits, isFalse);
      expect(item.amount, 165);
      expect(item.calories, closeTo(151 * 1.65, 1e-9));
    });
  });

  test('a dish that is only its base row is logged under one name', () {
    final data = parseVnFoodData(
      componentsCsv: '''
code,name_vi,name_en,kcal_per_100g,protein_g,carb_g,fat_g,unit_name_vi,unit_grams,source
_base_uc_ga,"Ức gà chín, bỏ da","Chicken breast, cooked, skinless",165,31,0,3.6,miếng,150,Test
''',
      dishesCsv: '''
dish,component,default_grams,default_units
uc_ga,_base_uc_ga,,1
''',
      dishNamesCsv: '''
code,name_vi,name_en
uc_ga,"Ức gà chín, bỏ da","Chicken breast, cooked, skinless"
''',
    );
    final plate = ScanPlate.forDish(data, data.dish('uc_ga')!,
        const FoodRecognition(dishes: {'uc_ga': 0.9}, components: {}));
    final entries = plate.toEntries(
        date: DateTime(2026, 10, 23), meal: MealSlot.lunch, languageCode: 'vi');
    expect(entries.single.name, 'Ức gà chín, bỏ da');
    expect(entries.single.calories, closeTo(165 * 1.5, 1e-9));
  });

  testWidgets('the picker only offers combinations the data has',
      (tester) async {
    FoodVariant? picked;
    await tester.pumpWidget(localizedApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async => picked = await pickFoodVariant(context,
                variants: _variants, group: 'ga', initialKey: 'uc|bo_da|luoc'),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('151 kcal • 29,0 g protein mỗi 100 g'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('variant-part-canh')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('variant-skin-ca_da')));
    await tester.pumpAndSettle();
    // Wings with skin are only raw or roasted in the data.
    ChoiceChip chip(String style) =>
        tester.widget(find.byKey(ValueKey('variant-style-$style')));
    expect(chip('chien').onSelected, isNull);
    expect(chip('nuong').onSelected, isNotNull);
    await tester.tap(find.byKey(const ValueKey('variant-style-nuong')));
    await tester.pumpAndSettle();
    expect(find.textContaining('254 kcal'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('variant-choose')));
    await tester.pumpAndSettle();
    expect(picked!.key, 'canh|ca_da|nuong');

    // The next time the group opens at that choice.
    expect((await SharedPreferences.getInstance()).getString('food_variant_ga'),
        'canh|ca_da|nuong');
  });

  testWidgets('logging by hand: pick the part and cooking, then the grams',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FoodLogEntry? entry;
    await tester.pumpWidget(localizedApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async => entry = await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => FoodLogSheet(
                foods: const [],
                date: DateTime(2026, 10, 23),
                variants: _variants,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('diary-variant-ga')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('variant-style-luoc')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('variant-choose')));
    await tester.pumpAndSettle();
    // The search field shows the pick.
    expect(find.text('Ức gà, bỏ da, luộc / hầm'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('diary-grams')), '200');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('diary-save')));
    await tester.pumpAndSettle();
    expect(entry!.name, 'Ức gà, bỏ da, luộc / hầm');
    expect(entry!.calories, closeTo(302, 1e-9));
    expect(entry!.protein, closeTo(57.96, 1e-9));
  });
}
