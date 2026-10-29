import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/screens/scan_result_screen.dart';

bool _overlap(Rect a, Rect b) {
  final both = a.intersect(b);
  return both.width > 0 && both.height > 0;
}

void main() {
  const area = Size(400, 300);

  test('a lone label sits inside the top edge of its box', () {
    final spots = placeBoxLabels(
      boxes: [const Rect.fromLTWH(50, 60, 150, 100)],
      labels: [const Size(90, 20)],
      area: area,
      order: [0],
    );
    expect(spots.single, const Rect.fromLTWH(50, 60, 90, 20));
  });

  test('labels of boxes that touch do not cover each other', () {
    // Grilled pork at the top, a cucumber box starting inside it on the
    // same line, rice just below: as on the broken-rice plate.
    final boxes = [
      const Rect.fromLTWH(70, 30, 150, 60),
      const Rect.fromLTWH(180, 25, 110, 70),
      const Rect.fromLTWH(90, 75, 160, 160),
    ];
    const labels = [Size(120, 22), Size(120, 22), Size(80, 22)];
    final spots = placeBoxLabels(
        boxes: boxes, labels: labels, area: area, order: [2, 0, 1]);
    for (var i = 0; i < spots.length; i++) {
      expect(spots[i].size, labels[i]);
      expect(area.contains(spots[i].topLeft), isTrue, reason: 'label $i');
      expect(spots[i].right <= area.width && spots[i].bottom <= area.height,
          isTrue,
          reason: 'label $i stays on the photo');
      for (var j = i + 1; j < spots.length; j++) {
        expect(_overlap(spots[i], spots[j]), isFalse, reason: '$i and $j');
      }
    }
    // The best score keeps the usual spot.
    expect(spots[2].topLeft, boxes[2].topLeft);
  });

  test('a box on the edge keeps its label on the photo', () {
    final spots = placeBoxLabels(
      boxes: [const Rect.fromLTWH(340, 0, 60, 80)],
      labels: [const Size(110, 22)],
      area: area,
      order: [0],
    );
    expect(spots.single.right, lessThanOrEqualTo(area.width));
    expect(spots.single.top, 0);
  });
}
