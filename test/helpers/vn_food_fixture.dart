import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:optifit/models/vn_food.dart';

/// Test-only numbers (not real nutrition data) for a small cơm tấm setup.
const fixtureComponentsCsv = '''
code,name_vi,name_en,kcal_per_100g,protein_g,carb_g,fat_g,unit_name_vi,unit_grams,source
com,Cơm,Cooked rice,130,2.7,28,0.3,chén,,"Test, fixture"
suon_nuong,Sườn nướng,Grilled pork chop,250,20,5,16,miếng,100,Test
bi,Bì,Shredded pork skin,,,,,,,
trung_op_la,Trứng ốp la,Fried egg,196,13.6,0.8,15.3,quả,50,Test
dua_leo_ca_chua,Dưa leo / cà chua,Cucumber and tomato,16,0.7,3.6,0.1,,,Test
tom,Tôm,Shrimp,99,24,0.2,0.3,con,10,Test
_base_com_tam,Nước mắm chấm,Dipping fish sauce,60,1,14,0,,,Test
''';

const fixtureDishesCsv = '''
dish,component,default_grams,default_units
com_tam,com,200,
com_tam,suon_nuong,,1
com_tam,bi,30,
com_tam,trung_op_la,,1
com_tam,_base_com_tam,20,
pho_bo,com,100,
''';

const fixtureDishNamesCsv = '''
code,name_vi,name_en
com_tam,Cơm tấm,Broken rice
pho_bo,Phở bò,Beef pho
''';

VnFoodData fixtureVnFood({String variantsCsv = ''}) => parseVnFoodData(
      componentsCsv: fixtureComponentsCsv,
      dishesCsv: fixtureDishesCsv,
      dishNamesCsv: fixtureDishNamesCsv,
      variantsCsv: variantsCsv,
    );

/// Serves the fixture CSVs to VnFoodRepository.
class FixtureVnFoodBundle extends CachingAssetBundle {
  static const _files = {
    'assets/data/vn_food/components.csv': fixtureComponentsCsv,
    'assets/data/vn_food/dishes.csv': fixtureDishesCsv,
    'assets/data/vn_food/dish_names.csv': fixtureDishNamesCsv,
  };

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      _files[key] ?? (throw FlutterError('Missing test asset $key'));

  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('Binary assets are not used in this test: $key');
}
