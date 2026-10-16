import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// No description provided for @navMeal.
  ///
  /// In vi, this message translates to:
  /// **'Bữa ăn'**
  String get navMeal;

  /// No description provided for @navWorkout.
  ///
  /// In vi, this message translates to:
  /// **'Tập luyện'**
  String get navWorkout;

  /// No description provided for @navHistory.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử'**
  String get navHistory;

  /// No description provided for @navProfile.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get navProfile;

  /// No description provided for @navSettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get navSettings;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In vi, this message translates to:
  /// **'Xóa'**
  String get delete;

  /// No description provided for @ok.
  ///
  /// In vi, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @retry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get retry;

  /// No description provided for @choose.
  ///
  /// In vi, this message translates to:
  /// **'Chọn'**
  String get choose;

  /// No description provided for @minutesUnit.
  ///
  /// In vi, this message translates to:
  /// **'phút'**
  String get minutesUnit;

  /// No description provided for @savingButton.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG LƯU...'**
  String get savingButton;

  /// No description provided for @sourceManual.
  ///
  /// In vi, this message translates to:
  /// **'tự đặt'**
  String get sourceManual;

  /// No description provided for @sourceEstimated.
  ///
  /// In vi, this message translates to:
  /// **'ước tính'**
  String get sourceEstimated;

  /// No description provided for @mealTitle.
  ///
  /// In vi, this message translates to:
  /// **'THỰC ĐƠN'**
  String get mealTitle;

  /// No description provided for @mealSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo thực đơn từ hồ sơ và mục tiêu đã lưu trên máy.'**
  String get mealSubtitle;

  /// No description provided for @mealProfileRequiredTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập hồ sơ trước'**
  String get mealProfileRequiredTitle;

  /// No description provided for @mealProfileRequiredBody.
  ///
  /// In vi, this message translates to:
  /// **'Chọn mục tiêu và lưu thông tin cơ thể trong tab Hồ sơ.'**
  String get mealProfileRequiredBody;

  /// No description provided for @mealOpenProfile.
  ///
  /// In vi, this message translates to:
  /// **'MỞ HỒ SƠ'**
  String get mealOpenProfile;

  /// No description provided for @mealProfileSummary.
  ///
  /// In vi, this message translates to:
  /// **'{weight} kg • {height} cm • {age} tuổi'**
  String mealProfileSummary(String weight, String height, String age);

  /// No description provided for @caloriesPerDay.
  ///
  /// In vi, this message translates to:
  /// **'Calo/ngày'**
  String get caloriesPerDay;

  /// No description provided for @proteinPerDay.
  ///
  /// In vi, this message translates to:
  /// **'Protein/ngày'**
  String get proteinPerDay;

  /// No description provided for @targetSources.
  ///
  /// In vi, this message translates to:
  /// **'Calo: {calories} • Protein: {protein}'**
  String targetSources(String calories, String protein);

  /// No description provided for @mealEditProfile.
  ///
  /// In vi, this message translates to:
  /// **'Sửa hồ sơ và mục tiêu'**
  String get mealEditProfile;

  /// No description provided for @mealGenerate.
  ///
  /// In vi, this message translates to:
  /// **'TẠO THỰC ĐƠN'**
  String get mealGenerate;

  /// No description provided for @mealSave.
  ///
  /// In vi, this message translates to:
  /// **'LƯU THỰC ĐƠN'**
  String get mealSave;

  /// No description provided for @mealSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu thực đơn.'**
  String get mealSaved;

  /// No description provided for @mealSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được thực đơn. Hãy thử lại.'**
  String get mealSaveFailed;

  /// No description provided for @profileLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được hồ sơ đã lưu. Hãy thử lại.'**
  String get profileLoadFailed;

  /// No description provided for @mealTargetsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mục tiêu của thực đơn'**
  String get mealTargetsTitle;

  /// No description provided for @targetLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mục tiêu'**
  String get targetLabel;

  /// No description provided for @mealComparisonTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đối chiếu thực đơn'**
  String get mealComparisonTitle;

  /// No description provided for @mealWithinTarget.
  ///
  /// In vi, this message translates to:
  /// **'Trong khoảng mục tiêu'**
  String get mealWithinTarget;

  /// No description provided for @mealOutsideTarget.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đạt khoảng mục tiêu'**
  String get mealOutsideTarget;

  /// No description provided for @caloriesLabel.
  ///
  /// In vi, this message translates to:
  /// **'Calo'**
  String get caloriesLabel;

  /// No description provided for @proteinLabel.
  ///
  /// In vi, this message translates to:
  /// **'Protein'**
  String get proteinLabel;

  /// No description provided for @comparisonDifference.
  ///
  /// In vi, this message translates to:
  /// **'Lệch {difference} {unit} ({percent}%)'**
  String comparisonDifference(String difference, String unit, String percent);

  /// No description provided for @mealToleranceNote.
  ///
  /// In vi, this message translates to:
  /// **'Mốc đối chiếu: calo ±5%, protein ±10%. Thực đơn gợi ý chưa phải lượng bạn đã ăn.'**
  String get mealToleranceNote;

  /// No description provided for @mealsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Các bữa ăn'**
  String get mealsTitle;

  /// No description provided for @breakfast.
  ///
  /// In vi, this message translates to:
  /// **'Bữa sáng'**
  String get breakfast;

  /// No description provided for @lunch.
  ///
  /// In vi, this message translates to:
  /// **'Bữa trưa'**
  String get lunch;

  /// No description provided for @dinner.
  ///
  /// In vi, this message translates to:
  /// **'Bữa tối'**
  String get dinner;

  /// No description provided for @workoutTitle.
  ///
  /// In vi, this message translates to:
  /// **'BUỔI TẬP'**
  String get workoutTitle;

  /// No description provided for @workoutSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Gợi ý bài tập theo nhóm cơ, trình độ và thời gian bạn có.'**
  String get workoutSubtitle;

  /// No description provided for @trainingSetup.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập buổi tập'**
  String get trainingSetup;

  /// No description provided for @workoutSplit.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm bài tập (split)'**
  String get workoutSplit;

  /// No description provided for @splitPush.
  ///
  /// In vi, this message translates to:
  /// **'Push · Ngực, vai, tay sau'**
  String get splitPush;

  /// No description provided for @splitPull.
  ///
  /// In vi, this message translates to:
  /// **'Pull · Lưng, xô, tay trước'**
  String get splitPull;

  /// No description provided for @splitLegs.
  ///
  /// In vi, this message translates to:
  /// **'Legs · Đùi, mông, bắp chân'**
  String get splitLegs;

  /// No description provided for @splitCore.
  ///
  /// In vi, this message translates to:
  /// **'Core · Cơ bụng'**
  String get splitCore;

  /// No description provided for @experienceLevel.
  ///
  /// In vi, this message translates to:
  /// **'Trình độ'**
  String get experienceLevel;

  /// No description provided for @levelBeginner.
  ///
  /// In vi, this message translates to:
  /// **'Mới bắt đầu'**
  String get levelBeginner;

  /// No description provided for @levelIntermediate.
  ///
  /// In vi, this message translates to:
  /// **'Trung bình'**
  String get levelIntermediate;

  /// No description provided for @levelPro.
  ///
  /// In vi, this message translates to:
  /// **'Nâng cao'**
  String get levelPro;

  /// No description provided for @levelOption.
  ///
  /// In vi, this message translates to:
  /// **'{level} • tối đa {count} bài'**
  String levelOption(String level, String count);

  /// No description provided for @availableTime.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian có (phút)'**
  String get availableTime;

  /// No description provided for @availableTimeError.
  ///
  /// In vi, this message translates to:
  /// **'Nhập từ 15 đến 180 phút.'**
  String get availableTimeError;

  /// No description provided for @workoutGenerate.
  ///
  /// In vi, this message translates to:
  /// **'TẠO BUỔI TẬP'**
  String get workoutGenerate;

  /// No description provided for @workoutSave.
  ///
  /// In vi, this message translates to:
  /// **'LƯU BUỔI TẬP'**
  String get workoutSave;

  /// No description provided for @workoutSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu buổi tập.'**
  String get workoutSaved;

  /// No description provided for @workoutSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được buổi tập.'**
  String get workoutSaveFailed;

  /// No description provided for @exerciseLogSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được kết quả bài tập.'**
  String get exerciseLogSaveFailed;

  /// No description provided for @nextSessionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gợi ý cho buổi sau'**
  String get nextSessionTitle;

  /// No description provided for @nextSessionSummary.
  ///
  /// In vi, this message translates to:
  /// **'{weight} kg • 3 hiệp • mục tiêu {reps} lần'**
  String nextSessionSummary(String weight, String reps);

  /// No description provided for @overloadIncreaseWeight.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã hoàn thành 3×12 với mức gắng sức vừa phải. Buổi sau tăng thêm 2,5 kg và bắt đầu lại trong khoảng 8–12 lần.'**
  String get overloadIncreaseWeight;

  /// No description provided for @overloadMaintainWeight.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã hoàn thành 3×12 nhưng thấy rất nặng. Giữ nguyên mức tạ thêm một buổi trước khi tăng.'**
  String get overloadMaintainWeight;

  /// No description provided for @overloadDecreaseWeight.
  ///
  /// In vi, this message translates to:
  /// **'Số lần chưa đạt khoảng mục tiêu. Giảm 2,5 kg và ưu tiên kỹ thuật có kiểm soát.'**
  String get overloadDecreaseWeight;

  /// No description provided for @overloadIncreaseReps.
  ///
  /// In vi, this message translates to:
  /// **'Giữ nguyên mức tạ và cố gắng tăng số lần cho đến khi cả ba hiệp đạt 12 lần.'**
  String get overloadIncreaseReps;

  /// No description provided for @sessionSummary.
  ///
  /// In vi, this message translates to:
  /// **'Tóm tắt buổi tập'**
  String get sessionSummary;

  /// No description provided for @estimatedLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ước tính'**
  String get estimatedLabel;

  /// No description provided for @exercisesLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số bài'**
  String get exercisesLabel;

  /// No description provided for @remainingTimeNote.
  ///
  /// In vi, this message translates to:
  /// **'Còn {minutes} phút cho khởi động, nghỉ giữa hiệp, giãn cơ hoặc cardio.'**
  String remainingTimeNote(String minutes);

  /// No description provided for @levelFallbackNote.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu cho trình độ {requested} còn ít. Buổi tập này gồm bài ở mức: {used}.'**
  String levelFallbackNote(String requested, String used);

  /// No description provided for @exerciseSequence.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách bài tập'**
  String get exerciseSequence;

  /// No description provided for @noExerciseData.
  ///
  /// In vi, this message translates to:
  /// **'Không có dữ liệu bài tập.'**
  String get noExerciseData;

  /// No description provided for @exerciseDetails.
  ///
  /// In vi, this message translates to:
  /// **'{muscle} • {equipment} • {minutes} phút'**
  String exerciseDetails(String muscle, String equipment, String minutes);

  /// No description provided for @logResult.
  ///
  /// In vi, this message translates to:
  /// **'Ghi kết quả'**
  String get logResult;

  /// No description provided for @savingResult.
  ///
  /// In vi, this message translates to:
  /// **'Đang lưu kết quả'**
  String get savingResult;

  /// No description provided for @logExerciseTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ghi kết quả: {name}'**
  String logExerciseTitle(String name);

  /// No description provided for @progressionModel.
  ///
  /// In vi, this message translates to:
  /// **'Mô hình tăng tiến: 3 hiệp, mỗi hiệp 8–12 lần.'**
  String get progressionModel;

  /// No description provided for @currentLoadKg.
  ///
  /// In vi, this message translates to:
  /// **'Mức tạ hiện tại (kg)'**
  String get currentLoadKg;

  /// No description provided for @currentLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mức tạ từ 0 đến 1000 kg.'**
  String get currentLoadError;

  /// No description provided for @setLabel.
  ///
  /// In vi, this message translates to:
  /// **'Hiệp {number}'**
  String setLabel(String number);

  /// No description provided for @difficulty.
  ///
  /// In vi, this message translates to:
  /// **'Độ khó'**
  String get difficulty;

  /// No description provided for @difficultyEasy.
  ///
  /// In vi, this message translates to:
  /// **'Dễ'**
  String get difficultyEasy;

  /// No description provided for @difficultyModerate.
  ///
  /// In vi, this message translates to:
  /// **'Vừa sức'**
  String get difficultyModerate;

  /// No description provided for @difficultyHard.
  ///
  /// In vi, this message translates to:
  /// **'Khó'**
  String get difficultyHard;

  /// No description provided for @difficultyFailure.
  ///
  /// In vi, this message translates to:
  /// **'Kiệt sức (failure)'**
  String get difficultyFailure;

  /// No description provided for @calculate.
  ///
  /// In vi, this message translates to:
  /// **'Tính toán'**
  String get calculate;

  /// No description provided for @historyTitle.
  ///
  /// In vi, this message translates to:
  /// **'LỊCH SỬ'**
  String get historyTitle;

  /// No description provided for @historyLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được lịch sử trên máy.'**
  String get historyLoadFailed;

  /// No description provided for @clearAllHistory.
  ///
  /// In vi, this message translates to:
  /// **'Xóa toàn bộ lịch sử'**
  String get clearAllHistory;

  /// No description provided for @clearAllTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xóa toàn bộ lịch sử?'**
  String get clearAllTitle;

  /// No description provided for @clearAllBody.
  ///
  /// In vi, this message translates to:
  /// **'Toàn bộ thực đơn, buổi tập và nhật ký tăng tiến đã lưu sẽ bị xóa. Hồ sơ và lịch sử cân nặng vẫn được giữ lại.'**
  String get clearAllBody;

  /// No description provided for @clearAllFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không xóa được lịch sử trên máy.'**
  String get clearAllFailed;

  /// No description provided for @historyMealPlans.
  ///
  /// In vi, this message translates to:
  /// **'THỰC ĐƠN'**
  String get historyMealPlans;

  /// No description provided for @historyWorkoutPlans.
  ///
  /// In vi, this message translates to:
  /// **'BUỔI TẬP'**
  String get historyWorkoutPlans;

  /// No description provided for @historyOverloadLogs.
  ///
  /// In vi, this message translates to:
  /// **'NHẬT KÝ TĂNG TIẾN'**
  String get historyOverloadLogs;

  /// No description provided for @savedMealPlan.
  ///
  /// In vi, this message translates to:
  /// **'THỰC ĐƠN ĐÃ LƯU'**
  String get savedMealPlan;

  /// No description provided for @savedWorkout.
  ///
  /// In vi, this message translates to:
  /// **'BUỔI TẬP ĐÃ LƯU'**
  String get savedWorkout;

  /// No description provided for @savedMealCorrupted.
  ///
  /// In vi, this message translates to:
  /// **'Thực đơn đã lưu bị thiếu hoặc hỏng dữ liệu.'**
  String get savedMealCorrupted;

  /// No description provided for @savedWorkoutCorrupted.
  ///
  /// In vi, this message translates to:
  /// **'Buổi tập đã lưu bị thiếu hoặc hỏng dữ liệu.'**
  String get savedWorkoutCorrupted;

  /// No description provided for @noMealPlans.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có thực đơn nào được lưu.'**
  String get noMealPlans;

  /// No description provided for @noWorkoutPlans.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có buổi tập nào được lưu.'**
  String get noWorkoutPlans;

  /// No description provided for @noExerciseLogs.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có nhật ký bài tập.'**
  String get noExerciseLogs;

  /// No description provided for @deleteRecordTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xóa {record}?'**
  String deleteRecordTitle(String record);

  /// No description provided for @deleteRecordBody.
  ///
  /// In vi, this message translates to:
  /// **'Không thể khôi phục bản ghi sau khi xóa.'**
  String get deleteRecordBody;

  /// No description provided for @deleteRecordFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không xóa được bản ghi đã chọn.'**
  String get deleteRecordFailed;

  /// No description provided for @recordMealPlan.
  ///
  /// In vi, this message translates to:
  /// **'thực đơn'**
  String get recordMealPlan;

  /// No description provided for @recordWorkoutPlan.
  ///
  /// In vi, this message translates to:
  /// **'buổi tập'**
  String get recordWorkoutPlan;

  /// No description provided for @recordExerciseLog.
  ///
  /// In vi, this message translates to:
  /// **'nhật ký bài tập'**
  String get recordExerciseLog;

  /// No description provided for @deleteMealPlan.
  ///
  /// In vi, this message translates to:
  /// **'Xóa thực đơn'**
  String get deleteMealPlan;

  /// No description provided for @deleteWorkoutPlan.
  ///
  /// In vi, this message translates to:
  /// **'Xóa buổi tập'**
  String get deleteWorkoutPlan;

  /// No description provided for @deleteExerciseLog.
  ///
  /// In vi, this message translates to:
  /// **'Xóa nhật ký bài tập'**
  String get deleteExerciseLog;

  /// No description provided for @mealHistoryTitle.
  ///
  /// In vi, this message translates to:
  /// **'{calories} kcal • {protein} g protein'**
  String mealHistoryTitle(String calories, String protein);

  /// No description provided for @workoutHistorySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'{minutes} phút • {date}'**
  String workoutHistorySubtitle(String minutes, String date);

  /// No description provided for @exerciseLogSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'{weight} kg • {reps} lần\nBuổi sau: {nextWeight} kg • mục tiêu {nextReps} lần\n{date}'**
  String exerciseLogSubtitle(String weight, String reps, String nextWeight,
      String nextReps, String date);

  /// No description provided for @profileTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ & mục tiêu'**
  String get profileTitle;

  /// No description provided for @profileDisclaimer.
  ///
  /// In vi, this message translates to:
  /// **'Ước tính dành cho người trưởng thành từ 18 tuổi. Nhu cầu thực tế có thể khác; đây không phải chỉ định y khoa.'**
  String get profileDisclaimer;

  /// No description provided for @personalInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cá nhân'**
  String get personalInfo;

  /// No description provided for @age.
  ///
  /// In vi, this message translates to:
  /// **'Tuổi'**
  String get age;

  /// No description provided for @ageError.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tuổi từ 18 đến 100.'**
  String get ageError;

  /// No description provided for @genderFormula.
  ///
  /// In vi, this message translates to:
  /// **'Giới tính dùng trong công thức'**
  String get genderFormula;

  /// No description provided for @male.
  ///
  /// In vi, this message translates to:
  /// **'Nam'**
  String get male;

  /// No description provided for @female.
  ///
  /// In vi, this message translates to:
  /// **'Nữ'**
  String get female;

  /// No description provided for @heightCm.
  ///
  /// In vi, this message translates to:
  /// **'Chiều cao (cm)'**
  String get heightCm;

  /// No description provided for @heightName.
  ///
  /// In vi, this message translates to:
  /// **'Chiều cao'**
  String get heightName;

  /// No description provided for @currentBodyWeight.
  ///
  /// In vi, this message translates to:
  /// **'Cân nặng hiện tại (kg)'**
  String get currentBodyWeight;

  /// No description provided for @weightName.
  ///
  /// In vi, this message translates to:
  /// **'Cân nặng'**
  String get weightName;

  /// No description provided for @activityLevel.
  ///
  /// In vi, this message translates to:
  /// **'Mức vận động'**
  String get activityLevel;

  /// No description provided for @activitySedentary.
  ///
  /// In vi, this message translates to:
  /// **'Ít vận động · ×{factor}'**
  String activitySedentary(String factor);

  /// No description provided for @activityLight.
  ///
  /// In vi, this message translates to:
  /// **'Nhẹ · ×{factor}'**
  String activityLight(String factor);

  /// No description provided for @activityModerate.
  ///
  /// In vi, this message translates to:
  /// **'Vừa · ×{factor}'**
  String activityModerate(String factor);

  /// No description provided for @activityActive.
  ///
  /// In vi, this message translates to:
  /// **'Nhiều · ×{factor}'**
  String activityActive(String factor);

  /// No description provided for @activityVeryActive.
  ///
  /// In vi, this message translates to:
  /// **'Rất nhiều · ×{factor}'**
  String activityVeryActive(String factor);

  /// No description provided for @goal.
  ///
  /// In vi, this message translates to:
  /// **'Mục tiêu'**
  String get goal;

  /// No description provided for @goalLose.
  ///
  /// In vi, this message translates to:
  /// **'Giảm mỡ'**
  String get goalLose;

  /// No description provided for @goalMaintain.
  ///
  /// In vi, this message translates to:
  /// **'Giữ cân'**
  String get goalMaintain;

  /// No description provided for @goalGain.
  ///
  /// In vi, this message translates to:
  /// **'Tăng cân'**
  String get goalGain;

  /// No description provided for @estimateFormula.
  ///
  /// In vi, this message translates to:
  /// **'Ước tính: BMR theo Mifflin–St Jeor; TDEE = BMR × mức vận động. Calo giảm/giữ/tăng cân = 90%/100%/110% TDEE. Protein = 1,8 g × cân nặng (kg).'**
  String get estimateFormula;

  /// No description provided for @manualCalories.
  ///
  /// In vi, this message translates to:
  /// **'Calo tự đặt (kcal/ngày)'**
  String get manualCalories;

  /// No description provided for @manualHint.
  ///
  /// In vi, this message translates to:
  /// **'Để trống để dùng ước tính'**
  String get manualHint;

  /// No description provided for @useEstimatedCalories.
  ///
  /// In vi, this message translates to:
  /// **'Dùng calo ước tính'**
  String get useEstimatedCalories;

  /// No description provided for @manualProtein.
  ///
  /// In vi, this message translates to:
  /// **'Protein tự đặt (g/ngày)'**
  String get manualProtein;

  /// No description provided for @useEstimatedProtein.
  ///
  /// In vi, this message translates to:
  /// **'Dùng protein ước tính'**
  String get useEstimatedProtein;

  /// No description provided for @numberInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Nhập {name} hợp lệ.'**
  String numberInvalid(String name);

  /// No description provided for @numberPositiveMax.
  ///
  /// In vi, this message translates to:
  /// **'{name} phải lớn hơn 0 và không quá {max}.'**
  String numberPositiveMax(String name, String max);

  /// No description provided for @numberRange.
  ///
  /// In vi, this message translates to:
  /// **'{name} phải từ {min} đến {max}.'**
  String numberRange(String name, String min, String max);

  /// No description provided for @targetsInvalidHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập thông tin và mục tiêu hợp lệ để xem ước tính. Năng lượng từ protein (4 kcal/g) không vượt tổng calo.'**
  String get targetsInvalidHint;

  /// No description provided for @caloriesPerDayValue.
  ///
  /// In vi, this message translates to:
  /// **'{value} kcal/ngày'**
  String caloriesPerDayValue(String value);

  /// No description provided for @proteinPerDayValue.
  ///
  /// In vi, this message translates to:
  /// **'{value} g protein/ngày'**
  String proteinPerDayValue(String value);

  /// No description provided for @estimatedCalories.
  ///
  /// In vi, this message translates to:
  /// **'Calo ước tính'**
  String get estimatedCalories;

  /// No description provided for @manualCaloriesSource.
  ///
  /// In vi, this message translates to:
  /// **'Calo tự đặt'**
  String get manualCaloriesSource;

  /// No description provided for @estimatedProtein.
  ///
  /// In vi, this message translates to:
  /// **'Protein ước tính'**
  String get estimatedProtein;

  /// No description provided for @manualProteinSource.
  ///
  /// In vi, this message translates to:
  /// **'Protein tự đặt'**
  String get manualProteinSource;

  /// No description provided for @saveProfile.
  ///
  /// In vi, this message translates to:
  /// **'Lưu hồ sơ'**
  String get saveProfile;

  /// No description provided for @savingProfile.
  ///
  /// In vi, this message translates to:
  /// **'Đang lưu...'**
  String get savingProfile;

  /// No description provided for @profileSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu hồ sơ và mục tiêu.'**
  String get profileSaved;

  /// No description provided for @profileSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể lưu hồ sơ. Vui lòng thử lại.'**
  String get profileSaveFailed;

  /// No description provided for @targetErrorProteinEnergy.
  ///
  /// In vi, this message translates to:
  /// **'Năng lượng từ protein (4 kcal/g) không được vượt tổng calo. Hãy điều chỉnh mục tiêu calo hoặc protein.'**
  String get targetErrorProteinEnergy;

  /// No description provided for @targetErrorCalorieRange.
  ///
  /// In vi, this message translates to:
  /// **'Mục tiêu calo nằm ngoài khoảng ứng dụng hỗ trợ (1.000–10.000 kcal). Kiểm tra hồ sơ hoặc tự nhập mục tiêu phù hợp.'**
  String get targetErrorCalorieRange;

  /// No description provided for @targetErrorProteinRange.
  ///
  /// In vi, this message translates to:
  /// **'Mục tiêu protein phải lớn hơn 0 và không quá 500 g. Kiểm tra hồ sơ hoặc tự nhập mục tiêu.'**
  String get targetErrorProteinRange;

  /// No description provided for @targetErrorGeneric.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin chưa cho ước tính hợp lệ. Kiểm tra tuổi, chiều cao, cân nặng và mục tiêu.'**
  String get targetErrorGeneric;

  /// No description provided for @weightTracking.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi cân nặng'**
  String get weightTracking;

  /// No description provided for @noWeights.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có lần ghi cân nặng. Lưu hồ sơ để bắt đầu.'**
  String get noWeights;

  /// No description provided for @latestWeight.
  ///
  /// In vi, this message translates to:
  /// **'Gần nhất: {weight} kg · {date}'**
  String latestWeight(String weight, String date);

  /// No description provided for @weightChange.
  ///
  /// In vi, this message translates to:
  /// **'Thay đổi: {change} kg từ {from} đến {to}'**
  String weightChange(String change, String from, String to);

  /// No description provided for @logWeight.
  ///
  /// In vi, this message translates to:
  /// **'Ghi cân nặng'**
  String get logWeight;

  /// No description provided for @weightHistoryNote.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi ngày lưu một giá trị; ghi lại cùng ngày sẽ cập nhật giá trị đó. Biểu đồ hiển thị tối đa 90 lần ghi gần nhất.'**
  String get weightHistoryNote;

  /// No description provided for @editWeightTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Sửa cân nặng ngày {date}'**
  String editWeightTooltip(String date);

  /// No description provided for @deleteWeightTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Xóa cân nặng ngày {date}'**
  String deleteWeightTooltip(String date);

  /// No description provided for @weightSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu cân nặng ngày {date}.'**
  String weightSaved(String date);

  /// No description provided for @weightSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể lưu cân nặng. Vui lòng thử lại.'**
  String get weightSaveFailed;

  /// No description provided for @deleteWeightTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xóa lần ghi cân nặng?'**
  String get deleteWeightTitle;

  /// No description provided for @weightDeleted.
  ///
  /// In vi, this message translates to:
  /// **'Đã xóa lần ghi cân nặng.'**
  String get weightDeleted;

  /// No description provided for @weightDeleteFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể xóa cân nặng. Vui lòng thử lại.'**
  String get weightDeleteFailed;

  /// No description provided for @editWeight.
  ///
  /// In vi, this message translates to:
  /// **'Sửa cân nặng'**
  String get editWeight;

  /// No description provided for @weightKg.
  ///
  /// In vi, this message translates to:
  /// **'Cân nặng (kg)'**
  String get weightKg;

  /// No description provided for @weightValueError.
  ///
  /// In vi, this message translates to:
  /// **'Nhập cân nặng lớn hơn 0 và không quá 500 kg.'**
  String get weightValueError;

  /// No description provided for @weighInDateField.
  ///
  /// In vi, this message translates to:
  /// **'Ngày cân (ngày/tháng/năm)'**
  String get weighInDateField;

  /// No description provided for @weighInDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày cân'**
  String get weighInDate;

  /// No description provided for @chooseWeighInDate.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngày cân'**
  String get chooseWeighInDate;

  /// No description provided for @datePickerFuture.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngày không sau hôm nay.'**
  String get datePickerFuture;

  /// No description provided for @datePickerInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Nhập ngày hợp lệ.'**
  String get datePickerInvalid;

  /// No description provided for @dateFormatError.
  ///
  /// In vi, this message translates to:
  /// **'Nhập ngày theo dạng ngày/tháng/năm.'**
  String get dateFormatError;

  /// No description provided for @dateAfterToday.
  ///
  /// In vi, this message translates to:
  /// **'Ngày cân không được sau hôm nay.'**
  String get dateAfterToday;

  /// No description provided for @saveWeight.
  ///
  /// In vi, this message translates to:
  /// **'Lưu cân nặng'**
  String get saveWeight;

  /// No description provided for @weightChartSemantics.
  ///
  /// In vi, this message translates to:
  /// **'Biểu đồ {count} lần ghi cân nặng. Từ {firstDate}: {firstWeight} kg đến {lastDate}: {lastWeight} kg. Các giá trị được liệt kê bên dưới.'**
  String weightChartSemantics(String count, String firstDate,
      String firstWeight, String lastDate, String lastWeight);

  /// No description provided for @settingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'CÀI ĐẶT'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngôn ngữ và giao diện. Lựa chọn được lưu trên máy.'**
  String get settingsSubtitle;

  /// No description provided for @offlineModeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ offline'**
  String get offlineModeTitle;

  /// No description provided for @offlineModeBody.
  ///
  /// In vi, this message translates to:
  /// **'Thực đơn, buổi tập và gợi ý cho buổi sau đều chạy trên máy. Hồ sơ và lịch sử được lưu cục bộ.'**
  String get offlineModeBody;

  /// No description provided for @languageTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get languageTitle;

  /// No description provided for @interfaceStyle.
  ///
  /// In vi, this message translates to:
  /// **'Giao diện'**
  String get interfaceStyle;

  /// No description provided for @styleCyberpunkDescription.
  ///
  /// In vi, this message translates to:
  /// **'Neon xanh lơ, hồng tím trên nền xanh đen.'**
  String get styleCyberpunkDescription;

  /// No description provided for @styleMinimalLightDescription.
  ///
  /// In vi, this message translates to:
  /// **'Sáng, gọn gàng và dễ đọc.'**
  String get styleMinimalLightDescription;

  /// No description provided for @styleForestDescription.
  ///
  /// In vi, this message translates to:
  /// **'Tông xanh lá dịu mắt, mang cảm giác tự nhiên.'**
  String get styleForestDescription;

  /// No description provided for @styleSunsetDescription.
  ///
  /// In vi, this message translates to:
  /// **'Điểm nhấn cam ấm và tím.'**
  String get styleSunsetDescription;

  /// No description provided for @errorDataUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Không đọc được dữ liệu thực phẩm và bài tập đi kèm ứng dụng.'**
  String get errorDataUnavailable;

  /// No description provided for @errorMealNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm được thực đơn phù hợp với mục tiêu hiện tại. Hãy thử lại hoặc điều chỉnh mục tiêu.'**
  String get errorMealNotFound;

  /// No description provided for @errorWorkoutNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không có bài tập phù hợp với lựa chọn này. Hãy thử thời gian dài hơn hoặc nhóm bài khác.'**
  String get errorWorkoutNotFound;

  /// No description provided for @errorInvalidInput.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu nhập chưa hợp lệ. Hãy kiểm tra lại.'**
  String get errorInvalidInput;

  /// No description provided for @errorUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Không tạo được gợi ý trên máy. Hãy thử lại.'**
  String get errorUnknown;

  /// No description provided for @muscleAbdominals.
  ///
  /// In vi, this message translates to:
  /// **'Cơ bụng'**
  String get muscleAbdominals;

  /// No description provided for @muscleAbductors.
  ///
  /// In vi, this message translates to:
  /// **'Cơ dạng hông'**
  String get muscleAbductors;

  /// No description provided for @muscleAdductors.
  ///
  /// In vi, this message translates to:
  /// **'Cơ khép đùi'**
  String get muscleAdductors;

  /// No description provided for @muscleBiceps.
  ///
  /// In vi, this message translates to:
  /// **'Tay trước'**
  String get muscleBiceps;

  /// No description provided for @muscleCalves.
  ///
  /// In vi, this message translates to:
  /// **'Bắp chân'**
  String get muscleCalves;

  /// No description provided for @muscleChest.
  ///
  /// In vi, this message translates to:
  /// **'Ngực'**
  String get muscleChest;

  /// No description provided for @muscleForearms.
  ///
  /// In vi, this message translates to:
  /// **'Cẳng tay'**
  String get muscleForearms;

  /// No description provided for @muscleGlutes.
  ///
  /// In vi, this message translates to:
  /// **'Mông'**
  String get muscleGlutes;

  /// No description provided for @muscleHamstrings.
  ///
  /// In vi, this message translates to:
  /// **'Đùi sau'**
  String get muscleHamstrings;

  /// No description provided for @muscleLats.
  ///
  /// In vi, this message translates to:
  /// **'Cơ xô'**
  String get muscleLats;

  /// No description provided for @muscleLowerBack.
  ///
  /// In vi, this message translates to:
  /// **'Lưng dưới'**
  String get muscleLowerBack;

  /// No description provided for @muscleMiddleBack.
  ///
  /// In vi, this message translates to:
  /// **'Lưng giữa'**
  String get muscleMiddleBack;

  /// No description provided for @muscleQuadriceps.
  ///
  /// In vi, this message translates to:
  /// **'Đùi trước'**
  String get muscleQuadriceps;

  /// No description provided for @muscleShoulders.
  ///
  /// In vi, this message translates to:
  /// **'Vai'**
  String get muscleShoulders;

  /// No description provided for @muscleTraps.
  ///
  /// In vi, this message translates to:
  /// **'Cơ cầu vai'**
  String get muscleTraps;

  /// No description provided for @muscleTriceps.
  ///
  /// In vi, this message translates to:
  /// **'Tay sau'**
  String get muscleTriceps;

  /// No description provided for @equipmentBarbell.
  ///
  /// In vi, this message translates to:
  /// **'Tạ đòn'**
  String get equipmentBarbell;

  /// No description provided for @equipmentBodyOnly.
  ///
  /// In vi, this message translates to:
  /// **'Không dụng cụ'**
  String get equipmentBodyOnly;

  /// No description provided for @equipmentCable.
  ///
  /// In vi, this message translates to:
  /// **'Máy cáp'**
  String get equipmentCable;

  /// No description provided for @equipmentDumbbell.
  ///
  /// In vi, this message translates to:
  /// **'Tạ đơn'**
  String get equipmentDumbbell;

  /// No description provided for @equipmentEzCurlBar.
  ///
  /// In vi, this message translates to:
  /// **'Thanh EZ'**
  String get equipmentEzCurlBar;

  /// No description provided for @equipmentKettlebells.
  ///
  /// In vi, this message translates to:
  /// **'Tạ ấm'**
  String get equipmentKettlebells;

  /// No description provided for @equipmentMachine.
  ///
  /// In vi, this message translates to:
  /// **'Máy tập'**
  String get equipmentMachine;

  /// No description provided for @equipmentOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get equipmentOther;

  /// No description provided for @navDiary.
  ///
  /// In vi, this message translates to:
  /// **'Nhật ký'**
  String get navDiary;

  /// No description provided for @mealSnack.
  ///
  /// In vi, this message translates to:
  /// **'Bữa phụ'**
  String get mealSnack;

  /// No description provided for @diaryTitle.
  ///
  /// In vi, this message translates to:
  /// **'NHẬT KÝ ĂN UỐNG'**
  String get diaryTitle;

  /// No description provided for @diarySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Ghi lại những gì bạn đã ăn và so với mục tiêu trong hồ sơ.'**
  String get diarySubtitle;

  /// No description provided for @diaryToday.
  ///
  /// In vi, this message translates to:
  /// **'Hôm nay'**
  String get diaryToday;

  /// No description provided for @diaryPreviousDay.
  ///
  /// In vi, this message translates to:
  /// **'Ngày trước'**
  String get diaryPreviousDay;

  /// No description provided for @diaryNextDay.
  ///
  /// In vi, this message translates to:
  /// **'Ngày sau'**
  String get diaryNextDay;

  /// No description provided for @diaryEaten.
  ///
  /// In vi, this message translates to:
  /// **'Đã ăn'**
  String get diaryEaten;

  /// No description provided for @diaryCaloriesProgress.
  ///
  /// In vi, this message translates to:
  /// **'{eaten} / {target} kcal'**
  String diaryCaloriesProgress(String eaten, String target);

  /// No description provided for @diaryProteinProgress.
  ///
  /// In vi, this message translates to:
  /// **'{eaten} / {target} g protein'**
  String diaryProteinProgress(String eaten, String target);

  /// No description provided for @diaryRemaining.
  ///
  /// In vi, this message translates to:
  /// **'Còn {value} kcal so với mục tiêu'**
  String diaryRemaining(String value);

  /// No description provided for @diaryOver.
  ///
  /// In vi, this message translates to:
  /// **'Vượt mục tiêu {value} kcal'**
  String diaryOver(String value);

  /// No description provided for @diaryNoTarget.
  ///
  /// In vi, this message translates to:
  /// **'Lưu hồ sơ để so với mục tiêu calo và protein.'**
  String get diaryNoTarget;

  /// No description provided for @diaryMacros.
  ///
  /// In vi, this message translates to:
  /// **'Carb {carbs} g • Chất béo {fat} g'**
  String diaryMacros(String carbs, String fat);

  /// No description provided for @diaryEmptyMeal.
  ///
  /// In vi, this message translates to:
  /// **'Chưa ghi món nào.'**
  String get diaryEmptyMeal;

  /// No description provided for @diaryAddFood.
  ///
  /// In vi, this message translates to:
  /// **'THÊM MÓN'**
  String get diaryAddFood;

  /// No description provided for @diaryAddTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm món vào nhật ký'**
  String get diaryAddTitle;

  /// No description provided for @diaryMealSlot.
  ///
  /// In vi, this message translates to:
  /// **'Bữa'**
  String get diaryMealSlot;

  /// No description provided for @diaryFromDataset.
  ///
  /// In vi, this message translates to:
  /// **'Từ dữ liệu'**
  String get diaryFromDataset;

  /// No description provided for @diaryCustom.
  ///
  /// In vi, this message translates to:
  /// **'Tự nhập'**
  String get diaryCustom;

  /// No description provided for @diaryFoodSearch.
  ///
  /// In vi, this message translates to:
  /// **'Tìm thực phẩm'**
  String get diaryFoodSearch;

  /// No description provided for @diaryFoodRequired.
  ///
  /// In vi, this message translates to:
  /// **'Chọn một thực phẩm trong danh sách.'**
  String get diaryFoodRequired;

  /// No description provided for @diaryGrams.
  ///
  /// In vi, this message translates to:
  /// **'Khối lượng (g)'**
  String get diaryGrams;

  /// No description provided for @diaryGramsError.
  ///
  /// In vi, this message translates to:
  /// **'Nhập khối lượng lớn hơn 0 và không quá 5000 g.'**
  String get diaryGramsError;

  /// No description provided for @diaryOptionalGrams.
  ///
  /// In vi, this message translates to:
  /// **'Khối lượng (g, không bắt buộc)'**
  String get diaryOptionalGrams;

  /// No description provided for @diaryCustomName.
  ///
  /// In vi, this message translates to:
  /// **'Tên món'**
  String get diaryCustomName;

  /// No description provided for @diaryCustomNameError.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên món.'**
  String get diaryCustomNameError;

  /// No description provided for @diaryCustomCalories.
  ///
  /// In vi, this message translates to:
  /// **'Calo (kcal)'**
  String get diaryCustomCalories;

  /// No description provided for @diaryCustomCaloriesError.
  ///
  /// In vi, this message translates to:
  /// **'Nhập calo từ 0 đến 10000.'**
  String get diaryCustomCaloriesError;

  /// No description provided for @diaryCarbsLabel.
  ///
  /// In vi, this message translates to:
  /// **'Carb (g)'**
  String get diaryCarbsLabel;

  /// No description provided for @diaryFatLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chất béo (g)'**
  String get diaryFatLabel;

  /// No description provided for @diaryMacroError.
  ///
  /// In vi, this message translates to:
  /// **'Từ 0 đến 1000 g.'**
  String get diaryMacroError;

  /// No description provided for @diaryPreview.
  ///
  /// In vi, this message translates to:
  /// **'Ước tính: {calories} kcal • {protein} g protein'**
  String diaryPreview(String calories, String protein);

  /// No description provided for @diarySave.
  ///
  /// In vi, this message translates to:
  /// **'Thêm vào nhật ký'**
  String get diarySave;

  /// No description provided for @diaryEntryDetails.
  ///
  /// In vi, this message translates to:
  /// **'{grams} g • {calories} kcal • {protein} g protein'**
  String diaryEntryDetails(String grams, String calories, String protein);

  /// No description provided for @diaryEntryDetailsNoGrams.
  ///
  /// In vi, this message translates to:
  /// **'{calories} kcal • {protein} g protein'**
  String diaryEntryDetailsNoGrams(String calories, String protein);

  /// No description provided for @diaryAdded.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm vào nhật ký.'**
  String get diaryAdded;

  /// No description provided for @diaryDeleted.
  ///
  /// In vi, this message translates to:
  /// **'Đã xóa món khỏi nhật ký.'**
  String get diaryDeleted;

  /// No description provided for @diaryUndo.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tác'**
  String get diaryUndo;

  /// No description provided for @diaryDeleteEntry.
  ///
  /// In vi, this message translates to:
  /// **'Xóa món'**
  String get diaryDeleteEntry;

  /// No description provided for @diaryLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được nhật ký. Hãy thử lại.'**
  String get diaryLoadFailed;

  /// No description provided for @diarySaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được nhật ký. Hãy thử lại.'**
  String get diarySaveFailed;

  /// No description provided for @mealLogPlan.
  ///
  /// In vi, this message translates to:
  /// **'GHI VÀO NHẬT KÝ HÔM NAY'**
  String get mealLogPlan;

  /// No description provided for @mealPlanLogged.
  ///
  /// In vi, this message translates to:
  /// **'Đã ghi thực đơn vào nhật ký hôm nay.'**
  String get mealPlanLogged;

  /// No description provided for @mealPlanAlreadyLogged.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ GHI VÀO NHẬT KÝ'**
  String get mealPlanAlreadyLogged;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
