import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:optifit/services/api_service.dart';

void main() {
  test('ApiService returns a decoded JSON object', () async {
    final service = ApiService(
      baseUrl: 'http://example.test/',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'status': 'ok'}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    expect(await service.health(), {'status': 'ok'});
  });

  test('ApiService extracts FastAPI validation messages', () async {
    final service = ApiService(
      baseUrl: 'http://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': [
              {'msg': 'Input should be greater than zero'},
            ],
          }),
          422,
        ),
      ),
    );

    expect(
      service.health(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Input should be greater than zero',
        ),
      ),
    );
  });
}
