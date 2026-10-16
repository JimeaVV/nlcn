// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get navMeal => 'Bữa ăn';

  @override
  String get navWorkout => 'Tập luyện';

  @override
  String get navHistory => 'Lịch sử';

  @override
  String get navProfile => 'Hồ sơ';

  @override
  String get navSettings => 'Cài đặt';

  @override
  String get cancel => 'Hủy';

  @override
  String get delete => 'Xóa';

  @override
  String get ok => 'OK';

  @override
  String get retry => 'Thử lại';

  @override
  String get choose => 'Chọn';

  @override
  String get minutesUnit => 'phút';

  @override
  String get savingButton => 'ĐANG LƯU...';

  @override
  String get sourceManual => 'tự đặt';

  @override
  String get sourceEstimated => 'ước tính';

  @override
  String get mealTitle => 'THỰC ĐƠN';

  @override
  String get mealSubtitle =>
      'Tạo thực đơn từ hồ sơ và mục tiêu đã lưu trên máy.';

  @override
  String get mealProfileRequiredTitle => 'Thiết lập hồ sơ trước';

  @override
  String get mealProfileRequiredBody =>
      'Chọn mục tiêu và lưu thông tin cơ thể trong tab Hồ sơ.';

  @override
  String get mealOpenProfile => 'MỞ HỒ SƠ';

  @override
  String mealProfileSummary(String weight, String height, String age) {
    return '$weight kg • $height cm • $age tuổi';
  }

  @override
  String get caloriesPerDay => 'Calo/ngày';

  @override
  String get proteinPerDay => 'Protein/ngày';

  @override
  String targetSources(String calories, String protein) {
    return 'Calo: $calories • Protein: $protein';
  }

  @override
  String get mealEditProfile => 'Sửa hồ sơ và mục tiêu';

  @override
  String get mealGenerate => 'TẠO THỰC ĐƠN';

  @override
  String get mealSave => 'LƯU THỰC ĐƠN';

  @override
  String get mealSaved => 'Đã lưu thực đơn.';

  @override
  String get mealSaveFailed => 'Không lưu được thực đơn. Hãy thử lại.';

  @override
  String get profileLoadFailed => 'Không tải được hồ sơ đã lưu. Hãy thử lại.';

  @override
  String get mealTargetsTitle => 'Mục tiêu của thực đơn';

  @override
  String get targetLabel => 'Mục tiêu';

  @override
  String get mealComparisonTitle => 'Đối chiếu thực đơn';

  @override
  String get mealWithinTarget => 'Trong khoảng mục tiêu';

  @override
  String get mealOutsideTarget => 'Chưa đạt khoảng mục tiêu';

  @override
  String get caloriesLabel => 'Calo';

  @override
  String get proteinLabel => 'Protein';

  @override
  String comparisonDifference(String difference, String unit, String percent) {
    return 'Lệch $difference $unit ($percent%)';
  }

  @override
  String get mealToleranceNote =>
      'Mốc đối chiếu: calo ±5%, protein ±10%. Thực đơn gợi ý chưa phải lượng bạn đã ăn.';

  @override
  String get mealsTitle => 'Các bữa ăn';

  @override
  String get breakfast => 'Bữa sáng';

  @override
  String get lunch => 'Bữa trưa';

  @override
  String get dinner => 'Bữa tối';

  @override
  String get workoutTitle => 'BUỔI TẬP';

  @override
  String get workoutSubtitle =>
      'Gợi ý bài tập theo nhóm cơ, trình độ và thời gian bạn có.';

  @override
  String get trainingSetup => 'Thiết lập buổi tập';

  @override
  String get workoutSplit => 'Nhóm bài tập (split)';

  @override
  String get splitPush => 'Push · Ngực, vai, tay sau';

  @override
  String get splitPull => 'Pull · Lưng, xô, tay trước';

  @override
  String get splitLegs => 'Legs · Đùi, mông, bắp chân';

  @override
  String get splitCore => 'Core · Cơ bụng';

  @override
  String get experienceLevel => 'Trình độ';

  @override
  String get levelBeginner => 'Mới bắt đầu';

  @override
  String get levelIntermediate => 'Trung bình';

  @override
  String get levelPro => 'Nâng cao';

  @override
  String levelOption(String level, String count) {
    return '$level • tối đa $count bài';
  }

  @override
  String get availableTime => 'Thời gian có (phút)';

  @override
  String get availableTimeError => 'Nhập từ 15 đến 180 phút.';

  @override
  String get workoutGenerate => 'TẠO BUỔI TẬP';

  @override
  String get workoutSave => 'LƯU BUỔI TẬP';

  @override
  String get workoutSaved => 'Đã lưu buổi tập.';

  @override
  String get workoutSaveFailed => 'Không lưu được buổi tập.';

  @override
  String get exerciseLogSaveFailed => 'Không lưu được kết quả bài tập.';

  @override
  String get nextSessionTitle => 'Gợi ý cho buổi sau';

  @override
  String nextSessionSummary(String weight, String reps) {
    return '$weight kg • 3 hiệp • mục tiêu $reps lần';
  }

  @override
  String get overloadIncreaseWeight =>
      'Bạn đã hoàn thành 3×12 với mức gắng sức vừa phải. Buổi sau tăng thêm 2,5 kg và bắt đầu lại trong khoảng 8–12 lần.';

  @override
  String get overloadMaintainWeight =>
      'Bạn đã hoàn thành 3×12 nhưng thấy rất nặng. Giữ nguyên mức tạ thêm một buổi trước khi tăng.';

  @override
  String get overloadDecreaseWeight =>
      'Số lần chưa đạt khoảng mục tiêu. Giảm 2,5 kg và ưu tiên kỹ thuật có kiểm soát.';

  @override
  String get overloadIncreaseReps =>
      'Giữ nguyên mức tạ và cố gắng tăng số lần cho đến khi cả ba hiệp đạt 12 lần.';

  @override
  String get sessionSummary => 'Tóm tắt buổi tập';

  @override
  String get estimatedLabel => 'Ước tính';

  @override
  String get exercisesLabel => 'Số bài';

  @override
  String remainingTimeNote(String minutes) {
    return 'Còn $minutes phút cho khởi động, nghỉ giữa hiệp, giãn cơ hoặc cardio.';
  }

  @override
  String levelFallbackNote(String requested, String used) {
    return 'Dữ liệu cho trình độ $requested còn ít. Buổi tập này gồm bài ở mức: $used.';
  }

  @override
  String get exerciseSequence => 'Danh sách bài tập';

  @override
  String get noExerciseData => 'Không có dữ liệu bài tập.';

  @override
  String exerciseDetails(String muscle, String equipment, String minutes) {
    return '$muscle • $equipment • $minutes phút';
  }

  @override
  String get logResult => 'Ghi kết quả';

  @override
  String get savingResult => 'Đang lưu kết quả';

  @override
  String logExerciseTitle(String name) {
    return 'Ghi kết quả: $name';
  }

  @override
  String get progressionModel =>
      'Mô hình tăng tiến: 3 hiệp, mỗi hiệp 8–12 lần.';

  @override
  String get currentLoadKg => 'Mức tạ hiện tại (kg)';

  @override
  String get currentLoadError => 'Nhập mức tạ từ 0 đến 1000 kg.';

  @override
  String setLabel(String number) {
    return 'Hiệp $number';
  }

  @override
  String get difficulty => 'Độ khó';

  @override
  String get difficultyEasy => 'Dễ';

  @override
  String get difficultyModerate => 'Vừa sức';

  @override
  String get difficultyHard => 'Khó';

  @override
  String get difficultyFailure => 'Kiệt sức (failure)';

  @override
  String get calculate => 'Tính toán';

  @override
  String get historyTitle => 'LỊCH SỬ';

  @override
  String get historyLoadFailed => 'Không tải được lịch sử trên máy.';

  @override
  String get clearAllHistory => 'Xóa toàn bộ lịch sử';

  @override
  String get clearAllTitle => 'Xóa toàn bộ lịch sử?';

  @override
  String get clearAllBody =>
      'Toàn bộ thực đơn, buổi tập và nhật ký tăng tiến đã lưu sẽ bị xóa. Hồ sơ và lịch sử cân nặng vẫn được giữ lại.';

  @override
  String get clearAllFailed => 'Không xóa được lịch sử trên máy.';

  @override
  String get historyMealPlans => 'THỰC ĐƠN';

  @override
  String get historyWorkoutPlans => 'BUỔI TẬP';

  @override
  String get historyOverloadLogs => 'NHẬT KÝ TĂNG TIẾN';

  @override
  String get savedMealPlan => 'THỰC ĐƠN ĐÃ LƯU';

  @override
  String get savedWorkout => 'BUỔI TẬP ĐÃ LƯU';

  @override
  String get savedMealCorrupted =>
      'Thực đơn đã lưu bị thiếu hoặc hỏng dữ liệu.';

  @override
  String get savedWorkoutCorrupted =>
      'Buổi tập đã lưu bị thiếu hoặc hỏng dữ liệu.';

  @override
  String get noMealPlans => 'Chưa có thực đơn nào được lưu.';

  @override
  String get noWorkoutPlans => 'Chưa có buổi tập nào được lưu.';

  @override
  String get noExerciseLogs => 'Chưa có nhật ký bài tập.';

  @override
  String deleteRecordTitle(String record) {
    return 'Xóa $record?';
  }

  @override
  String get deleteRecordBody => 'Không thể khôi phục bản ghi sau khi xóa.';

  @override
  String get deleteRecordFailed => 'Không xóa được bản ghi đã chọn.';

  @override
  String get recordMealPlan => 'thực đơn';

  @override
  String get recordWorkoutPlan => 'buổi tập';

  @override
  String get recordExerciseLog => 'nhật ký bài tập';

  @override
  String get deleteMealPlan => 'Xóa thực đơn';

  @override
  String get deleteWorkoutPlan => 'Xóa buổi tập';

  @override
  String get deleteExerciseLog => 'Xóa nhật ký bài tập';

  @override
  String mealHistoryTitle(String calories, String protein) {
    return '$calories kcal • $protein g protein';
  }

  @override
  String workoutHistorySubtitle(String minutes, String date) {
    return '$minutes phút • $date';
  }

  @override
  String exerciseLogSubtitle(String weight, String reps, String nextWeight,
      String nextReps, String date) {
    return '$weight kg • $reps lần\nBuổi sau: $nextWeight kg • mục tiêu $nextReps lần\n$date';
  }

  @override
  String get profileTitle => 'Hồ sơ & mục tiêu';

  @override
  String get profileDisclaimer =>
      'Ước tính dành cho người trưởng thành từ 18 tuổi. Nhu cầu thực tế có thể khác; đây không phải chỉ định y khoa.';

  @override
  String get personalInfo => 'Thông tin cá nhân';

  @override
  String get age => 'Tuổi';

  @override
  String get ageError => 'Nhập tuổi từ 18 đến 100.';

  @override
  String get genderFormula => 'Giới tính dùng trong công thức';

  @override
  String get male => 'Nam';

  @override
  String get female => 'Nữ';

  @override
  String get heightCm => 'Chiều cao (cm)';

  @override
  String get heightName => 'Chiều cao';

  @override
  String get currentBodyWeight => 'Cân nặng hiện tại (kg)';

  @override
  String get weightName => 'Cân nặng';

  @override
  String get activityLevel => 'Mức vận động';

  @override
  String activitySedentary(String factor) {
    return 'Ít vận động · ×$factor';
  }

  @override
  String activityLight(String factor) {
    return 'Nhẹ · ×$factor';
  }

  @override
  String activityModerate(String factor) {
    return 'Vừa · ×$factor';
  }

  @override
  String activityActive(String factor) {
    return 'Nhiều · ×$factor';
  }

  @override
  String activityVeryActive(String factor) {
    return 'Rất nhiều · ×$factor';
  }

  @override
  String get goal => 'Mục tiêu';

  @override
  String get goalLose => 'Giảm mỡ';

  @override
  String get goalMaintain => 'Giữ cân';

  @override
  String get goalGain => 'Tăng cân';

  @override
  String get estimateFormula =>
      'Ước tính: BMR theo Mifflin–St Jeor; TDEE = BMR × mức vận động. Calo giảm/giữ/tăng cân = 90%/100%/110% TDEE. Protein = 1,8 g × cân nặng (kg).';

  @override
  String get manualCalories => 'Calo tự đặt (kcal/ngày)';

  @override
  String get manualHint => 'Để trống để dùng ước tính';

  @override
  String get useEstimatedCalories => 'Dùng calo ước tính';

  @override
  String get manualProtein => 'Protein tự đặt (g/ngày)';

  @override
  String get useEstimatedProtein => 'Dùng protein ước tính';

  @override
  String numberInvalid(String name) {
    return 'Nhập $name hợp lệ.';
  }

  @override
  String numberPositiveMax(String name, String max) {
    return '$name phải lớn hơn 0 và không quá $max.';
  }

  @override
  String numberRange(String name, String min, String max) {
    return '$name phải từ $min đến $max.';
  }

  @override
  String get targetsInvalidHint =>
      'Nhập thông tin và mục tiêu hợp lệ để xem ước tính. Năng lượng từ protein (4 kcal/g) không vượt tổng calo.';

  @override
  String caloriesPerDayValue(String value) {
    return '$value kcal/ngày';
  }

  @override
  String proteinPerDayValue(String value) {
    return '$value g protein/ngày';
  }

  @override
  String get estimatedCalories => 'Calo ước tính';

  @override
  String get manualCaloriesSource => 'Calo tự đặt';

  @override
  String get estimatedProtein => 'Protein ước tính';

  @override
  String get manualProteinSource => 'Protein tự đặt';

  @override
  String get saveProfile => 'Lưu hồ sơ';

  @override
  String get savingProfile => 'Đang lưu...';

  @override
  String get profileSaved => 'Đã lưu hồ sơ và mục tiêu.';

  @override
  String get profileSaveFailed => 'Không thể lưu hồ sơ. Vui lòng thử lại.';

  @override
  String get targetErrorProteinEnergy =>
      'Năng lượng từ protein (4 kcal/g) không được vượt tổng calo. Hãy điều chỉnh mục tiêu calo hoặc protein.';

  @override
  String get targetErrorCalorieRange =>
      'Mục tiêu calo nằm ngoài khoảng ứng dụng hỗ trợ (1.000–10.000 kcal). Kiểm tra hồ sơ hoặc tự nhập mục tiêu phù hợp.';

  @override
  String get targetErrorProteinRange =>
      'Mục tiêu protein phải lớn hơn 0 và không quá 500 g. Kiểm tra hồ sơ hoặc tự nhập mục tiêu.';

  @override
  String get targetErrorGeneric =>
      'Thông tin chưa cho ước tính hợp lệ. Kiểm tra tuổi, chiều cao, cân nặng và mục tiêu.';

  @override
  String get weightTracking => 'Theo dõi cân nặng';

  @override
  String get noWeights => 'Chưa có lần ghi cân nặng. Lưu hồ sơ để bắt đầu.';

  @override
  String latestWeight(String weight, String date) {
    return 'Gần nhất: $weight kg · $date';
  }

  @override
  String weightChange(String change, String from, String to) {
    return 'Thay đổi: $change kg từ $from đến $to';
  }

  @override
  String get logWeight => 'Ghi cân nặng';

  @override
  String get weightHistoryNote =>
      'Mỗi ngày lưu một giá trị; ghi lại cùng ngày sẽ cập nhật giá trị đó. Biểu đồ hiển thị tối đa 90 lần ghi gần nhất.';

  @override
  String editWeightTooltip(String date) {
    return 'Sửa cân nặng ngày $date';
  }

  @override
  String deleteWeightTooltip(String date) {
    return 'Xóa cân nặng ngày $date';
  }

  @override
  String weightSaved(String date) {
    return 'Đã lưu cân nặng ngày $date.';
  }

  @override
  String get weightSaveFailed => 'Không thể lưu cân nặng. Vui lòng thử lại.';

  @override
  String get deleteWeightTitle => 'Xóa lần ghi cân nặng?';

  @override
  String get weightDeleted => 'Đã xóa lần ghi cân nặng.';

  @override
  String get weightDeleteFailed => 'Không thể xóa cân nặng. Vui lòng thử lại.';

  @override
  String get editWeight => 'Sửa cân nặng';

  @override
  String get weightKg => 'Cân nặng (kg)';

  @override
  String get weightValueError => 'Nhập cân nặng lớn hơn 0 và không quá 500 kg.';

  @override
  String get weighInDateField => 'Ngày cân (ngày/tháng/năm)';

  @override
  String get weighInDate => 'Ngày cân';

  @override
  String get chooseWeighInDate => 'Chọn ngày cân';

  @override
  String get datePickerFuture => 'Chọn ngày không sau hôm nay.';

  @override
  String get datePickerInvalid => 'Nhập ngày hợp lệ.';

  @override
  String get dateFormatError => 'Nhập ngày theo dạng ngày/tháng/năm.';

  @override
  String get dateAfterToday => 'Ngày cân không được sau hôm nay.';

  @override
  String get saveWeight => 'Lưu cân nặng';

  @override
  String weightChartSemantics(String count, String firstDate,
      String firstWeight, String lastDate, String lastWeight) {
    return 'Biểu đồ $count lần ghi cân nặng. Từ $firstDate: $firstWeight kg đến $lastDate: $lastWeight kg. Các giá trị được liệt kê bên dưới.';
  }

  @override
  String get settingsTitle => 'CÀI ĐẶT';

  @override
  String get settingsSubtitle =>
      'Chọn ngôn ngữ và giao diện. Lựa chọn được lưu trên máy.';

  @override
  String get offlineModeTitle => 'Chế độ offline';

  @override
  String get offlineModeBody =>
      'Thực đơn, buổi tập và gợi ý cho buổi sau đều chạy trên máy. Hồ sơ và lịch sử được lưu cục bộ.';

  @override
  String get languageTitle => 'Ngôn ngữ';

  @override
  String get interfaceStyle => 'Giao diện';

  @override
  String get styleCyberpunkDescription =>
      'Neon xanh lơ, hồng tím trên nền xanh đen.';

  @override
  String get styleMinimalLightDescription => 'Sáng, gọn gàng và dễ đọc.';

  @override
  String get styleForestDescription =>
      'Tông xanh lá dịu mắt, mang cảm giác tự nhiên.';

  @override
  String get styleSunsetDescription => 'Điểm nhấn cam ấm và tím.';

  @override
  String get errorDataUnavailable =>
      'Không đọc được dữ liệu thực phẩm và bài tập đi kèm ứng dụng.';

  @override
  String get errorMealNotFound =>
      'Không tìm được thực đơn phù hợp với mục tiêu hiện tại. Hãy thử lại hoặc điều chỉnh mục tiêu.';

  @override
  String get errorWorkoutNotFound =>
      'Không có bài tập phù hợp với lựa chọn này. Hãy thử thời gian dài hơn hoặc nhóm bài khác.';

  @override
  String get errorInvalidInput => 'Dữ liệu nhập chưa hợp lệ. Hãy kiểm tra lại.';

  @override
  String get errorUnknown => 'Không tạo được gợi ý trên máy. Hãy thử lại.';

  @override
  String get muscleAbdominals => 'Cơ bụng';

  @override
  String get muscleAbductors => 'Cơ dạng hông';

  @override
  String get muscleAdductors => 'Cơ khép đùi';

  @override
  String get muscleBiceps => 'Tay trước';

  @override
  String get muscleCalves => 'Bắp chân';

  @override
  String get muscleChest => 'Ngực';

  @override
  String get muscleForearms => 'Cẳng tay';

  @override
  String get muscleGlutes => 'Mông';

  @override
  String get muscleHamstrings => 'Đùi sau';

  @override
  String get muscleLats => 'Cơ xô';

  @override
  String get muscleLowerBack => 'Lưng dưới';

  @override
  String get muscleMiddleBack => 'Lưng giữa';

  @override
  String get muscleQuadriceps => 'Đùi trước';

  @override
  String get muscleShoulders => 'Vai';

  @override
  String get muscleTraps => 'Cơ cầu vai';

  @override
  String get muscleTriceps => 'Tay sau';

  @override
  String get equipmentBarbell => 'Tạ đòn';

  @override
  String get equipmentBodyOnly => 'Không dụng cụ';

  @override
  String get equipmentCable => 'Máy cáp';

  @override
  String get equipmentDumbbell => 'Tạ đơn';

  @override
  String get equipmentEzCurlBar => 'Thanh EZ';

  @override
  String get equipmentKettlebells => 'Tạ ấm';

  @override
  String get equipmentMachine => 'Máy tập';

  @override
  String get equipmentOther => 'Khác';

  @override
  String get navDiary => 'Nhật ký';

  @override
  String get mealSnack => 'Bữa phụ';

  @override
  String get diaryTitle => 'NHẬT KÝ ĂN UỐNG';

  @override
  String get diarySubtitle =>
      'Ghi lại những gì bạn đã ăn và so với mục tiêu trong hồ sơ.';

  @override
  String get diaryToday => 'Hôm nay';

  @override
  String get diaryPreviousDay => 'Ngày trước';

  @override
  String get diaryNextDay => 'Ngày sau';

  @override
  String get diaryEaten => 'Đã ăn';

  @override
  String diaryCaloriesProgress(String eaten, String target) {
    return '$eaten / $target kcal';
  }

  @override
  String diaryProteinProgress(String eaten, String target) {
    return '$eaten / $target g protein';
  }

  @override
  String diaryRemaining(String value) {
    return 'Còn $value kcal so với mục tiêu';
  }

  @override
  String diaryOver(String value) {
    return 'Vượt mục tiêu $value kcal';
  }

  @override
  String get diaryNoTarget => 'Lưu hồ sơ để so với mục tiêu calo và protein.';

  @override
  String diaryMacros(String carbs, String fat) {
    return 'Carb $carbs g • Chất béo $fat g';
  }

  @override
  String get diaryEmptyMeal => 'Chưa ghi món nào.';

  @override
  String get diaryAddFood => 'THÊM MÓN';

  @override
  String get diaryAddTitle => 'Thêm món vào nhật ký';

  @override
  String get diaryMealSlot => 'Bữa';

  @override
  String get diaryFromDataset => 'Từ dữ liệu';

  @override
  String get diaryCustom => 'Tự nhập';

  @override
  String get diaryFoodSearch => 'Tìm thực phẩm';

  @override
  String get diaryFoodRequired => 'Chọn một thực phẩm trong danh sách.';

  @override
  String get diaryGrams => 'Khối lượng (g)';

  @override
  String get diaryGramsError =>
      'Nhập khối lượng lớn hơn 0 và không quá 5000 g.';

  @override
  String get diaryOptionalGrams => 'Khối lượng (g, không bắt buộc)';

  @override
  String get diaryCustomName => 'Tên món';

  @override
  String get diaryCustomNameError => 'Nhập tên món.';

  @override
  String get diaryCustomCalories => 'Calo (kcal)';

  @override
  String get diaryCustomCaloriesError => 'Nhập calo từ 0 đến 10000.';

  @override
  String get diaryCarbsLabel => 'Carb (g)';

  @override
  String get diaryFatLabel => 'Chất béo (g)';

  @override
  String get diaryMacroError => 'Từ 0 đến 1000 g.';

  @override
  String diaryPreview(String calories, String protein) {
    return 'Ước tính: $calories kcal • $protein g protein';
  }

  @override
  String get diarySave => 'Thêm vào nhật ký';

  @override
  String diaryEntryDetails(String grams, String calories, String protein) {
    return '$grams g • $calories kcal • $protein g protein';
  }

  @override
  String diaryEntryDetailsNoGrams(String calories, String protein) {
    return '$calories kcal • $protein g protein';
  }

  @override
  String get diaryAdded => 'Đã thêm vào nhật ký.';

  @override
  String get diaryDeleted => 'Đã xóa món khỏi nhật ký.';

  @override
  String get diaryUndo => 'Hoàn tác';

  @override
  String get diaryDeleteEntry => 'Xóa món';

  @override
  String get diaryLoadFailed => 'Không tải được nhật ký. Hãy thử lại.';

  @override
  String get diarySaveFailed => 'Không lưu được nhật ký. Hãy thử lại.';

  @override
  String get mealLogPlan => 'GHI VÀO NHẬT KÝ HÔM NAY';

  @override
  String get mealPlanLogged => 'Đã ghi thực đơn vào nhật ký hôm nay.';

  @override
  String get mealPlanAlreadyLogged => 'ĐÃ GHI VÀO NHẬT KÝ';
}
