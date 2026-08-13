import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/recommendation_models.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = _normalizeBaseUrl(
          baseUrl ??
              const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'http://10.0.2.2:8000',
              ),
        ),
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  static const _timeout = Duration(seconds: 20);

  final String baseUrl;
  final http.Client _client;
  final bool _ownsClient;

  static String _normalizeBaseUrl(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<Map<String, dynamic>> health() => _get('/api/health');

  Future<DietRecommendation> recommendDiet({
    required int age,
    required String gender,
    required double weight,
    required double height,
    required double activityLevel,
  }) {
    return _post('/api/recommend-diet', {
      'age': age,
      'gender': gender,
      'weight': weight,
      'height': height,
      'activity_level': activityLevel,
    }).then((json) => _parse(json, DietRecommendation.fromJson));
  }

  Future<WorkoutRecommendation> recommendWorkout({
    required String split,
    required String level,
    required int minutes,
  }) {
    return _post('/api/recommend-workout', {
      'target_split': split,
      'target_level': level,
      'available_time_mins': minutes,
    }).then((json) => _parse(json, WorkoutRecommendation.fromJson));
  }

  Future<ProgressiveOverloadRecommendation> recommendProgressiveOverload({
    required String exerciseName,
    required double currentWeight,
    required int set1Reps,
    required int set2Reps,
    required int set3Reps,
    required String difficulty,
  }) {
    return _post('/api/progressive-overload', {
      'exercise_name': exerciseName,
      'current_weight': currentWeight,
      'set_1_reps': set1Reps,
      'set_2_reps': set2Reps,
      'set_3_reps': set3Reps,
      'difficulty': difficulty,
    }).then(
      (json) => _parse(json, ProgressiveOverloadRecommendation.fromJson),
    );
  }

  T _parse<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parser,
  ) {
    try {
      return parser(json);
    } on FormatException {
      throw const ApiException('Invalid response from server.');
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    return _send(() => _client.get(Uri.parse('$baseUrl$path')));
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _send(
      () => _client.post(
        Uri.parse('$baseUrl$path'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(_timeout);
      final decoded = _decodeBody(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _errorDetail(decoded) ?? 'Server error ${response.statusCode}.',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Invalid response from server.');
      }
      return decoded;
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } on SocketException {
      throw const ApiException(
        'Cannot connect to FastAPI. Check the server address and Wi-Fi.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Cannot connect to FastAPI. Check the server address and Wi-Fi.',
      );
    } on FormatException {
      throw const ApiException('Server returned invalid JSON.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Request failed. Please try again.');
    }
  }

  dynamic _decodeBody(String body) {
    if (body.trim().isEmpty) return null;
    return jsonDecode(body);
  }

  String? _errorDetail(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final detail = decoded['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) return '${first['msg']}';
    }
    return null;
  }
}
