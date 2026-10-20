import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/models/scan_plate.dart';
import 'package:optifit/models/vn_food.dart';
import 'package:optifit/services/food_recognizer.dart';

import 'helpers/vn_food_fixture.dart';

void main() {
  group('CSV', () {
    test('handles quotes, commas, CRLF, a BOM and blank lines', () {
      final rows = parseCsv('﻿a,b,c\r\n'
          '1,"x, y","say ""hi"""\r\n'
          '\r\n'
          '2,,"multi\nline"\n');
      expect(rows, [
        {'a': '1', 'b': 'x, y', 'c': 'say "hi"'},
        {'a': '2', 'b': '', 'c': 'multi\nline'},
      ]);
    });

    test('the packaged tables parse and cover the 65 contract dishes', () {
      String read(String name) =>
          File('assets/data/vn_food/$name.csv').readAsStringSync();
      final data = parseVnFoodData(
        componentsCsv: read('components'),
        dishesCsv: read('dishes'),
        dishNamesCsv: read('dish_names'),
      );
      expect(data.dishes, hasLength(65));
      expect(data.dish('com_tam')!.nameVi, 'Cơm tấm');
      expect(data.dish('com_tam')!.parts.map((part) => part.component),
          contains('bi'));
      // A single-item dish keeps all of its nutrition in the base row.
      expect(data.dish('banh_tet')!.parts.map((part) => part.component),
          ['_base_banh_tet']);
      expect(data.addableComponents, hasLength(25));
    });

    test('rejects unknown components and negative numbers', () {
      expect(
        () => parseVnFoodData(
          componentsCsv: fixtureComponentsCsv,
          dishesCsv: 'dish,component,default_grams,default_units\n'
              'com_tam,banh_bao,100,\n',
          dishNamesCsv: fixtureDishNamesCsv,
        ),
        throwsFormatException,
      );
      expect(
        () => parseVnFoodData(
          componentsCsv: 'code,name_vi,name_en,kcal_per_100g\nx,X,X,-5\n',
          dishesCsv: 'dish,component\n',
          dishNamesCsv: 'code,name_vi,name_en\n',
        ),
        throwsFormatException,
      );
    });
  });

  group('plate', () {
    final data = fixtureVnFood();
    final comTam = data.dish('com_tam')!;

    test('without a model every usual component is ticked', () {
      final plate = ScanPlate.forDish(data, comTam, FoodRecognition.empty);
      expect(plate.items.map((item) => item.component.code),
          ['com', 'suon_nuong', 'bi', 'trung_op_la', '_base_com_tam']);
      expect(plate.items.every((item) => item.included), isTrue);
      final ribs = plate.items[1];
      expect(ribs.inUnits, isTrue);
      expect(ribs.grams, 100);
      // Bì has no nutrition yet, so the plate cannot be logged as is.
      expect(plate.missingNutrition.single.component.code, 'bi');
      expect(plate.canLog, isFalse);
      expect(
          () => plate.toEntries(
              date: DateTime(2026, 10, 17),
              meal: MealSlot.lunch,
              languageCode: 'vi'),
          throwsStateError);
    });

    test('contract thresholds decide ticks, questions and extra components',
        () {
      final plate = ScanPlate.forDish(
        data,
        comTam,
        const FoodRecognition(
          dishes: {'com_tam': 0.82, 'pho_bo': 0.18},
          components: {
            'com': 0.97,
            'suon_nuong': 0.91,
            'bi': 0.45,
            'trung_op_la': 0.12,
            'dua_leo_ca_chua': 0.7,
            'tom': 0.35,
          },
        ),
      );
      PlateItem item(String code) =>
          plate.items.firstWhere((item) => item.component.code == code);

      expect(item('suon_nuong').included, isTrue);
      expect(item('suon_nuong').confidence, 0.91);
      expect(item('bi').included, isFalse);
      expect(item('bi').uncertain, isTrue, reason: '0.3–0.6 asks the user');
      expect(item('trung_op_la').included, isFalse);
      expect(item('trung_op_la').uncertain, isFalse);
      expect(item('_base_com_tam').included, isTrue, reason: 'bases stay');
      // Outside the recipe: suggested at the ticked threshold, never ticked.
      expect(item('dua_leo_ca_chua').included, isFalse);
      expect(item('dua_leo_ca_chua').uncertain, isTrue);
      expect(plate.items.where((item) => item.component.code == 'tom'), isEmpty,
          reason: 'below the ticked threshold an extra is left out');
      expect(plate.canLog, isTrue, reason: 'unticked bì needs no data');

      // 200 g rice 260 + one 100 g chop 250 + 20 g sauce 12.
      expect(plate.calories, closeTo(522, 1e-9));
      item('dua_leo_ca_chua').included = true;
      final entries = plate.toEntries(
          date: DateTime(2026, 10, 17),
          meal: MealSlot.lunch,
          languageCode: 'vi');
      expect(entries.map((entry) => entry.name), [
        'Cơm (Cơm tấm)',
        'Sườn nướng (Cơm tấm)',
        'Nước mắm chấm (Cơm tấm)',
        'Dưa leo / cà chua (Cơm tấm)',
      ]);
      expect(entries.every((entry) => entry.source == FoodLogSource.camera),
          isTrue);
      expect(entries[1].confidence, 0.91);
      expect(entries[2].confidence, isNull);
      for (final entry in entries) {
        entry.validate();
      }
    });

    test('components of a dish the model did not learn follow the recipe', () {
      final plate = ScanPlate.forDish(
        data,
        comTam,
        const FoodRecognition(
          dishes: {'com_tam': 0.9},
          components: {'suon_nuong': 0.1, 'dua_leo_ca_chua': 0.95},
          componentDishes: {'pho_bo'},
        ),
      );
      expect(plate.items.map((item) => item.component.code),
          ['com', 'suon_nuong', 'bi', 'trung_op_la', '_base_com_tam'],
          reason: 'no suggestions from outputs that mean nothing here');
      expect(plate.items.every((item) => item.included), isTrue);
      expect(plate.items.every((item) => item.confidence == null), isTrue);
    });

    test('an added component starts at its usual portion in other dishes', () {
      final data = parseVnFoodData(
        componentsCsv: '$fixtureComponentsCsv'
            'mo_hanh,Mỡ hành,Scallion oil,583,0.5,2.5,63,,,Test\n',
        dishesCsv: '${fixtureDishesCsv}com_tam,mo_hanh,10,\n'
            'pho_bo,suon_nuong,,2\n',
        dishNamesCsv: fixtureDishNamesCsv,
      );
      // Phở does not list scallion oil; cơm tấm has 10 g of it.
      final pho = ScanPlate.forDish(
          data,
          data.dish('pho_bo')!,
          const FoodRecognition(
              dishes: {'pho_bo': 1}, components: {'mo_hanh': 0.9}));
      final oil = pho.items.singleWhere((i) => i.component.code == 'mo_hanh');
      expect(oil.grams, 10, reason: 'its usual 10 g, not 100 g');
      expect(oil.included, isFalse);
      pho.items.remove(oil);
      pho.add(data.components['mo_hanh']!);
      expect(pho.items.last.grams, 10, reason: 'added by hand: same portion');

      // A model tuned to tick at 0.3 still suggests extras only from 0.6.
      final lowTuned = ScanPlate.forDish(
          data,
          data.dish('pho_bo')!,
          const FoodRecognition(
              dishes: {'pho_bo': 1},
              components: {'mo_hanh': 0.45, 'tom': 0.7},
              thresholds: RecognitionThresholds(checked: 0.3, ask: 0.15)));
      expect(
          lowTuned.items
              .where((i) => !data
                  .dish('pho_bo')!
                  .parts
                  .any((p) => p.component == i.component.code))
              .map((i) => i.component.code),
          ['tom']);
      expect(typicalPortion(data, data.components['suon_nuong']!),
          (inUnits: true, amount: 1.5));
      expect(typicalPortion(data, data.components['tom']!),
          (inUnits: true, amount: 1.0),
          reason: 'no dish lists it: one unit');
      expect(typicalPortion(data, data.components['dua_leo_ca_chua']!),
          (inUnits: false, amount: 100.0));
    });

    test('the whole-dish portion scales every component', () {
      final plate = ScanPlate.forDish(data, comTam, FoodRecognition.empty);
      final rice = plate.items.first;
      rice.amount = 250; // the user's own change keeps its share
      plate.portion = 1.5;
      expect(rice.amount, 375);
      expect(plate.items[1].amount, 1.5, reason: 'one chop becomes 1.5');
      plate.portion = 0.5;
      expect(rice.amount, 125);
      plate.add(data.components['tom']!);
      expect(plate.items.last.amount, 0.5,
          reason: 'one shrimp at half a serving');
      plate.portion = 0;
      expect(plate.portion, 0.5, reason: 'not a portion');
      expect(plate.carbs, greaterThan(0));
    });

    test('amounts follow units, and unknown unit weights block logging', () {
      final plate = ScanPlate.forDish(data, comTam, FoodRecognition.empty);
      final egg = plate.items
          .firstWhere((item) => item.component.code == 'trung_op_la');
      egg.amount += egg.step * 2;
      expect(egg.grams, 100, reason: '2 eggs × 50 g');
      final rice = plate.items.first;
      expect(rice.inUnits, isFalse);
      expect(rice.step, 10);

      plate.items.firstWhere((item) => item.component.code == 'bi').included =
          false;
      plate.add(data.components['tom']!);
      plate.add(data.components['tom']!);
      expect(plate.items.where((item) => item.component.code == 'tom'),
          hasLength(1));
      expect(plate.canLog, isTrue);
    });
  });
}
