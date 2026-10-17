import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/core/number_input.dart';
import 'package:optifit/core/text_search.dart';

void main() {
  group('parseDecimal', () {
    test('accepts a decimal comma as well as a dot', () {
      expect(parseDecimal('70,5'), 70.5);
      expect(parseDecimal(' 70.5 '), 70.5);
      expect(parseDecimal('80'), 80);
    });

    test('rejects text that is not a finite number', () {
      expect(parseDecimal(''), isNull);
      expect(parseDecimal(null), isNull);
      expect(parseDecimal('abc'), isNull);
      expect(parseDecimal('1,2,3'), isNull);
      expect(parseDecimal('Infinity'), isNull);
    });
  });

  group('search', () {
    test('folds case and Vietnamese diacritics', () {
      expect(foldForSearch('Phở Bò'), 'pho bo');
      expect(foldForSearch('ĐẬU HŨ'), 'dau hu');
      expect(foldForSearch('Ức gà'), 'uc ga');
    });

    test('matches every word in any field, in any order', () {
      expect(matchesSearch('pho', ['Phở bò']), isTrue);
      expect(matchesSearch('trứng', ['Trung op la']), isTrue);
      expect(matchesSearch('ga uc', ['Ức gà']), isTrue);
      expect(matchesSearch('rice', ['Cơm', 'Cơm Cooked rice']), isTrue);
      expect(matchesSearch('pho ga', ['Phở bò']), isFalse);
      expect(matchesSearch('   ', ['Phở bò']), isFalse);
    });
  });
}
