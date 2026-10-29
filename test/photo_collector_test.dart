import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:optifit/services/photo_collector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory temp;
  late PhotoCollector collector;
  late String photo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('photos_test');
    collector = PhotoCollector(
        root: () async => Directory('${temp.path}/training_photos'));
    // A 1600×1200 photo, as the camera takes them.
    photo = '${temp.path}/scan.jpg';
    await File(photo)
        .writeAsBytes(img.encodeJpg(img.Image(width: 1600, height: 1200)));
  });

  tearDown(() => temp.delete(recursive: true));

  test('nothing is kept until the user turns collecting on', () async {
    await collector.load();
    expect(collector.enabled, isFalse);
    await collector.save(photo, label: 'pho_bo', name: 'Phở bò');
    expect((await collector.stats()).photos, 0);

    await collector.setEnabled(true);
    final again = PhotoCollector(root: () async => temp);
    await again.load();
    expect(again.enabled, isTrue, reason: 'the choice is remembered');
  });

  test('a kept photo is shrunk, filed by label and indexed', () async {
    await collector.setEnabled(true);
    await collector.save(photo,
        label: 'pho_bo', name: 'Phở bò', guess: 'bun_bo_hue', confidence: .41);
    await collector.save(photo, label: 'single_com', name: 'Cơm');

    final root = Directory('${temp.path}/training_photos');
    final kept = File(Directory('${root.path}/pho_bo').listSync().single.path);
    final decoded = img.decodeJpg(await kept.readAsBytes())!;
    expect(decoded.width, PhotoCollector.maxSide);
    expect(decoded.height, 480);

    final index = await File('${root.path}/index.csv').readAsLines();
    expect(index.first, startsWith('file,label,name,model_guess'));
    expect(index[1], contains(',pho_bo,"Phở bò",bun_bo_hue,0.410,'));
    expect(index, hasLength(3));
    expect((await collector.stats()).photos, 2);
  });

  test('labels are codes; a new food gets one from its name', () async {
    expect(PhotoCollector.labelForNewFood('Yến mạch'), 'new_yen_mach');
    expect(PhotoCollector.labelForNewFood('Trà sữa trân châu!'),
        'new_tra_sua_tran_chau');
    expect(PhotoCollector.labelForNewFood('!!'), 'new_food');
    await collector.setEnabled(true);
    expect(collector.save(photo, label: '../escape', name: 'x'),
        throwsArgumentError);
  });

  test('the export zip holds every photo and the index; clear removes them',
      () async {
    await collector.setEnabled(true);
    expect(await collector.exportZip('${temp.path}/empty.zip'), isNull);
    await collector.save(photo, label: 'new_yen_mach', name: 'Yến mạch');
    final zip = await collector.exportZip('${temp.path}/out.zip');
    final archive = ZipDecoder().decodeBytes(await zip!.readAsBytes());
    final names = [for (final file in archive.files) file.name];
    expect(names, contains('index.csv'));
    expect(
        names.where((name) =>
            name.startsWith('new_yen_mach/') && name.endsWith('.jpg')),
        hasLength(1));

    await collector.clear();
    expect((await collector.stats()).photos, 0);
  });
}
