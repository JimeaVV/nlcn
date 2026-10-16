import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/core/cyber_theme.dart';
import 'package:optifit/models/recommendation_models.dart';
import 'package:optifit/models/user_profile.dart';
import 'package:optifit/screens/meal_screen.dart';
import 'package:optifit/services/database_service.dart';
import 'package:optifit/services/recommendation_service.dart';

class _Database extends Fake implements DatabaseService {
  Map<String, dynamic>? profile;
  final saved = <DietRecommendation>[];

  @override
  Future<Map<String, dynamic>?> getProfile() async => profile;

  @override
  Future<int> saveMealPlan(DietRecommendation recommendation) async {
    saved.add(recommendation);
    return saved.length;
  }
}

class _Recommendations extends RecommendationService {
  final requests = <UserProfile>[];
  final pending = <Completer<DietRecommendation>>[];

  @override
  Future<DietRecommendation> recommendDiet({
    required int age,
    required String gender,
    required double weight,
    required double height,
    required double activityLevel,
    NutritionGoal goal = NutritionGoal.maintain,
    double? calorieOverride,
    double? proteinOverride,
    int? seed,
  }) {
    requests.add(UserProfile(
        age: age,
        gender: gender,
        weight: weight,
        height: height,
        activityLevel: activityLevel,
        goal: goal,
        calorieOverride: calorieOverride,
        proteinOverride: proteinOverride));
    final future = Completer<DietRecommendation>();
    pending.add(future);
    return future.future;
  }
}

UserProfile _profile(
        {double calories = 2200, NutritionGoal goal = NutritionGoal.gain}) =>
    UserProfile(
        age: 21,
        gender: 'male',
        height: 175,
        weight: 70,
        activityLevel: 1.55,
        goal: goal,
        calorieOverride: calories,
        proteinOverride: 140);

DietRecommendation _plan(double target) => DietRecommendation.fromJson({
      'bmr': 1694,
      'tdee': 2625,
      'target_calories': target,
      'data': {
        'protein_target': 140,
        'total_calo': target,
        'total_protein': 140,
        'total_carb': 200,
        'total_fat': 60,
        'meals': {
          'Breakfast': {
            'calo': target,
            'protein': 140,
            'carb': 200,
            'fat': 60,
            'items': [
              {'name': 'Oats', 'display_name': '100g oats'}
            ]
          }
        }
      },
    });

Future<void> _mount(
    WidgetTester tester, _Database database, _Recommendations recommendations,
    {GlobalKey<MealScreenState>? key, VoidCallback? onOpenProfile}) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppStyle.cyberpunk),
      home: Scaffold(
          body: MealScreen(
              key: key,
              database: database,
              recommendations: recommendations,
              onOpenProfile: onOpenProfile))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first use requires a saved profile rather than sample metrics',
      (tester) async {
    var opened = false;
    final recommendations = _Recommendations();
    await _mount(tester, _Database(), recommendations,
        onOpenProfile: () => opened = true);
    expect(find.text('Thiết lập hồ sơ trước'), findsOneWidget);
    await tester.tap(find.text('MỞ HỒ SƠ'));
    expect(opened, isTrue);
    expect(recommendations.requests, isEmpty);
    expect(find.text('TẠO THỰC ĐƠN'), findsNothing);
  });

  testWidgets(
      'saved goals and independent targets reach generation and history',
      (tester) async {
    final database = _Database()..profile = _profile().toMap();
    final recommendations = _Recommendations();
    await _mount(tester, database, recommendations);
    await tester.tap(find.text('TẠO THỰC ĐƠN'));
    await tester.pump();
    expect(recommendations.requests.single.goal, NutritionGoal.gain);
    expect(recommendations.requests.single.calorieOverride, 2200);
    expect(recommendations.requests.single.proteinOverride, 140);
    recommendations.pending.single.complete(_plan(2200));
    await tester.pumpAndSettle();
    final save = find.text('LƯU THỰC ĐƠN');
    await tester.scrollUntilVisible(save, 350);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(database.saved.single.targetCalories, 2200);
    expect(database.saved.single.plan.proteinTarget, 140);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a profile change invalidates a pending plan and keeps the new target',
      (tester) async {
    final database = _Database()..profile = _profile().toMap();
    final recommendations = _Recommendations();
    final key = GlobalKey<MealScreenState>();
    await _mount(tester, database, recommendations, key: key);
    await tester.tap(find.text('TẠO THỰC ĐƠN'));
    await tester.pump();
    database.profile =
        _profile(calories: 2400, goal: NutritionGoal.maintain).toMap();
    await key.currentState!.refreshProfile();
    await tester.pump();
    recommendations.pending.first.complete(_plan(2200));
    await tester.pumpAndSettle();
    expect(find.text('LƯU THỰC ĐƠN'), findsNothing);
    await tester.tap(find.text('TẠO THỰC ĐƠN'));
    await tester.pump();
    expect(recommendations.requests.last.calorieOverride, 2400);
    recommendations.pending.last.complete(_plan(2400));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('LƯU THỰC ĐƠN'), 350);
    expect(find.text('LƯU THỰC ĐƠN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
