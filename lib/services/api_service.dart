import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  ApiService({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8000',
            );

  final String baseUrl;

  Future<Map<String, dynamic>> recommendDiet({
    required int age,
    required String gender,
    required double weight,
    required double height,
    required double activityLevel,
  }) {
    return _post(
      '/api/recommend-diet',
      {
        'age': age,
        'gender': gender,
        'weight': weight,
        'height': height,
        'activity_level': activityLevel,
      },
    );
  }

  Future<Map<String, dynamic>> recommendWorkout({
    required String split,
    required String level,
    required int minutes,
  }) {
    return _post(
      '/api/recommend-workout',
      {
        'target_split': split,
        'target_level': level,
        'available_time_mins': minutes,
      },
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map<String, dynamic>
            ? decoded['detail']?.toString()
            : null;
        throw ApiException(detail ?? 'Server error ${response.statusCode}');
      }

      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Invalid response from server.');
      }

      return decoded;
    } on SocketException {
      throw const ApiException(
        'Cannot connect to FastAPI. Check the server address and Wi-Fi.',
      );
    } on FormatException {
      throw const ApiException('Server returned invalid JSON.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Request failed. Please try again.',
      );
    }
  }
}
