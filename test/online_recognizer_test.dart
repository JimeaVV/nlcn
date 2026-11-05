import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:optifit/services/online_recognizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _classes = [
  for (final line
      in File('assets/models/detector_classes.txt').readAsLinesSync())
    if (line.trim().isNotEmpty) line.trim(),
];

OnlineSpec _spec() => OnlineSpec.parse(
    File('assets/models/online_classes.json').readAsStringSync(), _classes);

/// Gemini's answer as the Interactions API wraps it.
String _response(List<Map<String, Object>> foods) => jsonEncode({
      'status': 'completed',
      'steps': [
        {'type': 'thought', 'signature': 'x'},
        {
          'type': 'model_output',
          'content': [
            {'type': 'text', 'text': jsonEncode({'foods': foods})},
          ],
        },
      ],
    });

class _Calls {
  final urls = <Uri>[];
  final headers = <Map<String, String>>[];
  final bodies = <Map<String, dynamic>>[];
}

OnlineRecognizer _recognizer(
  _Calls calls, {
  String apiKey = 'test-key',
  int status = 200,
  String? body,
  Object? error,
  Completer<void>? never,
}) =>
    OnlineRecognizer(
      apiKey: apiKey,
      spec: _spec(),
      readPhoto: (_) async => Uint8List.fromList([1, 2, 3]),
      timeout: const Duration(milliseconds: 50),
      retryDelays: const [Duration.zero, Duration.zero],
      post: (url, headers, sent) async {
        calls.urls.add(url);
        calls.headers.add(headers);
        calls.bodies.add(jsonDecode(utf8.decode(sent)) as Map<String, dynamic>);
        if (never != null) await never.future;
        if (error != null) throw error;
        return (status: status, body: body ?? _response(const []));
      },
    );

/// A recognizer whose [reply] decides each answer, by model and by how many
/// requests that model has had. A null reply never answers.
OnlineRecognizer _scripted(
  List<String> models,
  ({int status, String body})? Function(String model, int nth) reply, {
  Duration? totalWait,
}) =>
    OnlineRecognizer(
      apiKey: 'test-key',
      spec: _spec(),
      readPhoto: (_) async => Uint8List.fromList([1, 2, 3]),
      timeout: const Duration(milliseconds: 50),
      totalWait: totalWait,
      retryDelays: const [Duration.zero, Duration.zero],
      post: (url, headers, sent) async {
        final model =
            (jsonDecode(utf8.decode(sent)) as Map<String, dynamic>)['model'];
        models.add(model as String);
        final answer =
            reply(model, models.where((name) => name == model).length);
        if (answer == null) await Completer<void>().future;
        return answer!;
      },
    );

const _flash = 'gemini-3.8-flash';
const _lite = 'gemini-3.5-flash-lite';
const _busy = (status: 503, body: '{"error":{"message":"high demand"}}');

Future<OnlineRecognizer> _on(OnlineRecognizer online, OnlineModel model) async {
  await online.setEnabled(true, consent: true);
  await online.setModel(model);
  return online;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the app asks Gemini exactly what tool/eval/gemini_compare.py measured',
      () {
    // Written by `python tool/eval/gemini_compare.py --print-request ...`.
    final measured = jsonDecode(
            File('test/fixtures/gemini_request.json').readAsStringSync())
        as Map<String, dynamic>;
    final spec = _spec();
    expect(spec.model, measured['model']);
    expect(spec.prompt, measured['prompt']);
    expect(spec.schema, measured['schema']);
  });

  test('nothing is sent without a key, or before the user agreed', () async {
    final calls = _Calls();
    final noKey = _recognizer(calls, apiKey: '');
    await noKey.load();
    await noKey.setEnabled(true, consent: true);
    expect(noKey.available, isFalse);
    expect(noKey.enabled, isFalse);

    SharedPreferences.setMockInitialValues({});
    final online = _recognizer(calls);
    await online.load();
    await online.setEnabled(true);
    expect(online.enabled, isFalse, reason: 'not agreed yet');
    await expectLater(online.recognize('plate.jpg'),
        throwsA(isA<OnlineScanException>()));
    expect(calls.urls, isEmpty);

    await online.setEnabled(true, consent: true);
    expect(online.enabled, isTrue);
    final again = _recognizer(calls);
    await again.load();
    expect(again.enabled, isTrue, reason: 'the choice is remembered');
    await again.setEnabled(false);
    expect(again.enabled, isFalse);
  });

  test('a scan sends the shrunk photo and reads the foods named', () async {
    final calls = _Calls();
    final online = _recognizer(calls,
        body: _response([
          {'class': 'com', 'name': 'white rice', 'grams': 150},
          {'class': 'ga', 'name': 'chicken breast', 'grams': 120},
          {'class': 'com', 'name': 'more rice', 'grams': 50},
          {'class': 'other', 'name': 'mashed potatoes', 'grams': 80},
          {'class': 'pizza', 'name': 'pizza slice', 'grams': 90},
        ]));
    await online.setEnabled(true, consent: true);
    final scan = await online.recognize('plate.jpg');

    expect(scan.codes, ['com', 'ga']);
    expect(scan.otherNames, ['mashed potatoes', 'pizza slice']);
    expect(calls.urls.single.path, '/v1beta/interactions');
    expect(calls.headers.single['x-goog-api-key'], 'test-key');
    final sent = calls.bodies.single;
    expect(sent['model'], 'gemini-3.5-flash-lite');
    expect(sent['store'], isFalse);
    final input = sent['input'] as List;
    expect(input.first['text'], _spec().prompt);
    expect(input.last['data'], base64Encode([1, 2, 3]));
  });

  test('Flash-Lite, the measured model, is used until the user picks Flash',
      () async {
    expect(OnlineModel.values.first.id, _spec().model);
    final calls = _Calls();
    final online = _recognizer(calls);
    await online.load();
    await online.setEnabled(true, consent: true);
    expect(online.model, OnlineModel.flashLite);
    await online.recognize('plate.jpg');
    expect(calls.bodies.last['model'], 'gemini-3.5-flash-lite');
    expect(calls.bodies.last['generation_config'], {'seed': 0});

    await online.setModel(OnlineModel.flash);
    await online.recognize('plate.jpg');
    expect(calls.bodies.last['model'], 'gemini-3.8-flash');
    expect(calls.bodies.last['generation_config'],
        {'seed': 0, 'thinking_level': 'low'});

    final again = OnlineRecognizer(apiKey: 'test-key');
    await again.load();
    expect(again.model, OnlineModel.flash, reason: 'the choice is remembered');
    expect(again.timeout, const Duration(seconds: 20),
        reason: 'Flash thinks first, so it gets longer');
    await again.setModel(OnlineModel.flashLite);
    expect(again.timeout, onlineTimeout);
  });

  test('a missing network, a slow answer, the quota and errors are told apart',
      () async {
    Future<OnlineFailure> failure(OnlineRecognizer online) async {
      await online.setEnabled(true, consent: true);
      try {
        await online.recognize('plate.jpg');
      } on OnlineScanException catch (error) {
        return error.kind;
      }
      fail('no error');
    }

    expect(
        await failure(_recognizer(_Calls(),
            error: const SocketException('no route to host'))),
        OnlineFailure.offline);
    expect(await failure(_recognizer(_Calls(), never: Completer())),
        OnlineFailure.timeout);
    expect(
        await failure(_recognizer(_Calls(),
            status: 429, body: '{"error":{"message":"20 requests per day"}}')),
        OnlineFailure.quota);
    expect(await failure(_recognizer(_Calls(), status: 503)),
        OnlineFailure.busy);
    expect(await failure(_recognizer(_Calls(), status: 400)),
        OnlineFailure.failed);
    expect(await failure(_recognizer(_Calls(), body: '{"steps": []}')),
        OnlineFailure.failed);
  });

  test('503 then an answer: the model that was picked answers', () async {
    final models = <String>[];
    final online = await _on(
        _scripted(
            models,
            (_, nth) => nth == 1
                ? _busy
                : (status: 200, body: _response(const []))),
        OnlineModel.flash);

    final scan = await online.recognize('plate.jpg');
    expect(models, [_flash, _flash]);
    expect(scan.model, OnlineModel.flash);
    expect(scan.fellBack, isFalse);
  });

  test('503 on every try: Flash-Lite answers and is the one named', () async {
    final models = <String>[];
    final bodies = <Map<String, dynamic>>[];
    final online = await _on(
        OnlineRecognizer(
          apiKey: 'test-key',
          spec: _spec(),
          readPhoto: (_) async => Uint8List.fromList([1, 2, 3]),
          retryDelays: const [Duration.zero, Duration.zero],
          post: (url, headers, sent) async {
            final body = jsonDecode(utf8.decode(sent)) as Map<String, dynamic>;
            bodies.add(body);
            models.add(body['model'] as String);
            return body['model'] == _flash
                ? _busy
                : (status: 200, body: _response(const []));
          },
        ),
        OnlineModel.flash);

    final scan = await online.recognize('plate.jpg');
    expect(models, [_flash, _flash, _flash, _lite]);
    expect(scan.model, OnlineModel.flashLite);
    expect(scan.asked, OnlineModel.flash);
    expect(scan.fellBack, isTrue);
    expect(bodies.last['generation_config'], {'seed': 0},
        reason: 'Flash-Lite does not take the thinking level Flash was sent');
    expect(online.model, OnlineModel.flash,
        reason: 'one overloaded scan does not change the user\'s choice');
  });

  test('no answer in time counts as overload too', () async {
    final models = <String>[];
    final online = await _on(
        _scripted(models,
            (model, _) => model == _flash ? null : (status: 200, body: _response(const []))),
        OnlineModel.flash);

    final scan = await online.recognize('plate.jpg');
    expect(models, [_flash, _flash, _flash, _lite]);
    expect(scan.fellBack, isTrue);
  });

  test('429 is not retried and does not move to another model', () async {
    final models = <String>[];
    final online = await _on(
        _scripted(models, (_, __) => (status: 429, body: '{"error":{}}')),
        OnlineModel.flash);

    await expectLater(
        online.recognize('plate.jpg'),
        throwsA(isA<OnlineScanException>()
            .having((error) => error.kind, 'kind', OnlineFailure.quota)));
    expect(models, [_flash]);
  });

  test('a 400 and a missing network are not retried', () async {
    final models = <String>[];
    final online = await _on(
        _scripted(models, (_, __) => (status: 400, body: '{"error":{}}')),
        OnlineModel.flash);
    await expectLater(
        online.recognize('plate.jpg'),
        throwsA(isA<OnlineScanException>()
            .having((error) => error.kind, 'kind', OnlineFailure.failed)));
    expect(models, [_flash]);

    final calls = _Calls();
    final offline = _recognizer(calls, error: const SocketException('none'));
    await offline.setEnabled(true, consent: true);
    await expectLater(offline.recognize('plate.jpg'),
        throwsA(isA<OnlineScanException>()));
    expect(calls.urls, hasLength(1));
  });

  test('Flash-Lite overloaded as well: the user is told it is overload',
      () async {
    final models = <String>[];
    final online = await _on(_scripted(models, (_, __) => _busy), OnlineModel.flash);

    await expectLater(
        online.recognize('plate.jpg'),
        throwsA(isA<OnlineScanException>()
            .having((error) => error.kind, 'kind', OnlineFailure.busy)));
    expect(models, [_flash, _flash, _flash, _lite, _lite, _lite]);
  });

  test('with too little time left no more tries start', () async {
    final models = <String>[];
    final online = await _on(
        _scripted(
            models,
            (model, _) =>
                model == _flash ? _busy : (status: 200, body: _response(const [])),
            totalWait: onlineMinAttempt),
        OnlineModel.flash);

    final scan = await online.recognize('plate.jpg');
    expect(models, [_flash, _lite], reason: 'straight to the fallback');
    expect(scan.fellBack, isTrue);
  });

  test('the whole wait is bounded and leaves Flash-Lite its time', () {
    expect(OnlineModel.flash.totalWait, const Duration(seconds: 30));
    expect(OnlineModel.flashLite.totalWait, const Duration(seconds: 20));
    expect(
        OnlineModel.flash.totalWait - OnlineModel.flashLite.timeout >=
            OnlineModel.flash.timeout,
        isTrue,
        reason: 'one full Flash try fits before the fallback');
  });

  test('once cancelled nothing more is sent', () async {
    final models = <String>[];
    var cancelled = false;
    final online = await _on(
        _scripted(models, (_, __) {
          cancelled = true;
          return _busy;
        }),
        OnlineModel.flash);

    await expectLater(online.recognize('plate.jpg', cancelled: () => cancelled),
        throwsA(isA<OnlineScanException>()));
    expect(models, [_flash]);
  });

  test('the photo sent is upright, at most 1024 px, without EXIF', () {
    final photo = img.Image(width: 2000, height: 1500);
    photo.exif.imageIfd.make = 'TestCam';
    photo.exif.gpsIfd.setGpsLocation(latitude: 10.77, longitude: 106.70);
    final original = img.encodeJpg(photo);
    expect(img.decodeJpg(original)!.exif.isEmpty, isFalse);

    final sent = img.decodeJpg(prepareOnlinePhoto(original))!;
    expect(sent.width, 1024);
    expect(sent.height, 768);
    expect(sent.exif.isEmpty, isTrue);
  });
}
