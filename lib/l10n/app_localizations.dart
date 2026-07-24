import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ja'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'복덩이 일기'**
  String get appTitle;

  /// No description provided for @noDiaryTitle.
  ///
  /// In ko, this message translates to:
  /// **'작성된 일기가 없습니다.'**
  String get noDiaryTitle;

  /// No description provided for @noDiaryDesc.
  ///
  /// In ko, this message translates to:
  /// **'하단의 + 버튼을 눌러 첫 일기를 작성해 보세요.'**
  String get noDiaryDesc;

  /// No description provided for @newDiary.
  ///
  /// In ko, this message translates to:
  /// **'새 일기 작성'**
  String get newDiary;

  /// No description provided for @editDiary.
  ///
  /// In ko, this message translates to:
  /// **'일기 수정'**
  String get editDiary;

  /// No description provided for @titleLabel.
  ///
  /// In ko, this message translates to:
  /// **'제목 (선택)'**
  String get titleLabel;

  /// No description provided for @titleHint.
  ///
  /// In ko, this message translates to:
  /// **'비워두면 내용의 첫 줄로 제목을 만듭니다.'**
  String get titleHint;

  /// No description provided for @contentLabel.
  ///
  /// In ko, this message translates to:
  /// **'내용 (원문)'**
  String get contentLabel;

  /// No description provided for @contentHint.
  ///
  /// In ko, this message translates to:
  /// **'오늘 하루 어떤 일이 있었나요? 자유롭게 입력해 주세요.'**
  String get contentHint;

  /// No description provided for @summaryLabel.
  ///
  /// In ko, this message translates to:
  /// **'요약'**
  String get summaryLabel;

  /// No description provided for @summaryHint.
  ///
  /// In ko, this message translates to:
  /// **'오늘 하루를 1~3문장으로 요약해 주세요.'**
  String get summaryHint;

  /// No description provided for @simpleModeLabel.
  ///
  /// In ko, this message translates to:
  /// **'간단 입력'**
  String get simpleModeLabel;

  /// No description provided for @manualModeLabel.
  ///
  /// In ko, this message translates to:
  /// **'직접 입력'**
  String get manualModeLabel;

  /// No description provided for @analyzeButton.
  ///
  /// In ko, this message translates to:
  /// **'AI로 정리'**
  String get analyzeButton;

  /// No description provided for @analyzingLabel.
  ///
  /// In ko, this message translates to:
  /// **'AI가 기록을 정리하고 있어요…'**
  String get analyzingLabel;

  /// No description provided for @saveRecord.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get saveRecord;

  /// No description provided for @aiUnavailableDescription.
  ///
  /// In ko, this message translates to:
  /// **'현재 AI를 사용할 수 없어요. 원문 기록은 그대로 저장할 수 있어요.'**
  String get aiUnavailableDescription;

  /// No description provided for @aiAnalysisFailed.
  ///
  /// In ko, this message translates to:
  /// **'AI 정리에 실패했어요. 원문은 그대로 유지됩니다.'**
  String get aiAnalysisFailed;

  /// No description provided for @retryAiAnalysis.
  ///
  /// In ko, this message translates to:
  /// **'AI 정리 다시 시도'**
  String get retryAiAnalysis;

  /// No description provided for @aiAnalysisApplied.
  ///
  /// In ko, this message translates to:
  /// **'AI 정리 결과를 적용했어요. 입력한 원문은 그대로 보존됩니다.'**
  String get aiAnalysisApplied;

  /// No description provided for @previewSection.
  ///
  /// In ko, this message translates to:
  /// **'분석 결과 미리보기'**
  String get previewSection;

  /// No description provided for @recordAction.
  ///
  /// In ko, this message translates to:
  /// **'기록하기'**
  String get recordAction;

  /// No description provided for @recordSheetTitle.
  ///
  /// In ko, this message translates to:
  /// **'무엇을 기록할까요?'**
  String get recordSheetTitle;

  /// No description provided for @quickRecordsTitle.
  ///
  /// In ko, this message translates to:
  /// **'빠른 기록'**
  String get quickRecordsTitle;

  /// No description provided for @recentRecordsTitle.
  ///
  /// In ko, this message translates to:
  /// **'최근 사용'**
  String get recentRecordsTitle;

  /// No description provided for @allCategoriesTitle.
  ///
  /// In ko, this message translates to:
  /// **'전체 카테고리'**
  String get allCategoriesTitle;

  /// No description provided for @basicCareCategory.
  ///
  /// In ko, this message translates to:
  /// **'기본 돌봄'**
  String get basicCareCategory;

  /// No description provided for @healthMedicalCategory.
  ///
  /// In ko, this message translates to:
  /// **'건강·의료'**
  String get healthMedicalCategory;

  /// No description provided for @activityPlayCategory.
  ///
  /// In ko, this message translates to:
  /// **'활동·놀이'**
  String get activityPlayCategory;

  /// No description provided for @growthMemoryCategory.
  ///
  /// In ko, this message translates to:
  /// **'성장·추억'**
  String get growthMemoryCategory;

  /// No description provided for @feedingEvent.
  ///
  /// In ko, this message translates to:
  /// **'수유'**
  String get feedingEvent;

  /// No description provided for @mealEvent.
  ///
  /// In ko, this message translates to:
  /// **'이유식·식사'**
  String get mealEvent;

  /// No description provided for @waterSnackEvent.
  ///
  /// In ko, this message translates to:
  /// **'물·간식'**
  String get waterSnackEvent;

  /// No description provided for @waterEvent.
  ///
  /// In ko, this message translates to:
  /// **'물'**
  String get waterEvent;

  /// No description provided for @snackEvent.
  ///
  /// In ko, this message translates to:
  /// **'간식'**
  String get snackEvent;

  /// No description provided for @feedingMethodLabel.
  ///
  /// In ko, this message translates to:
  /// **'수유 방식'**
  String get feedingMethodLabel;

  /// No description provided for @breastFeedingOption.
  ///
  /// In ko, this message translates to:
  /// **'모유'**
  String get breastFeedingOption;

  /// No description provided for @bottleFeedingOption.
  ///
  /// In ko, this message translates to:
  /// **'젖병'**
  String get bottleFeedingOption;

  /// No description provided for @feedingTimeOnlyOption.
  ///
  /// In ko, this message translates to:
  /// **'시각만'**
  String get feedingTimeOnlyOption;

  /// No description provided for @breastSideLabel.
  ///
  /// In ko, this message translates to:
  /// **'수유한 쪽'**
  String get breastSideLabel;

  /// No description provided for @leftSideOption.
  ///
  /// In ko, this message translates to:
  /// **'왼쪽'**
  String get leftSideOption;

  /// No description provided for @rightSideOption.
  ///
  /// In ko, this message translates to:
  /// **'오른쪽'**
  String get rightSideOption;

  /// No description provided for @bottleContentsLabel.
  ///
  /// In ko, this message translates to:
  /// **'젖병 내용'**
  String get bottleContentsLabel;

  /// No description provided for @formulaOption.
  ///
  /// In ko, this message translates to:
  /// **'분유'**
  String get formulaOption;

  /// No description provided for @expressedMilkOption.
  ///
  /// In ko, this message translates to:
  /// **'유축 모유'**
  String get expressedMilkOption;

  /// No description provided for @otherOption.
  ///
  /// In ko, this message translates to:
  /// **'기타'**
  String get otherOption;

  /// No description provided for @amountStyleLabel.
  ///
  /// In ko, this message translates to:
  /// **'먹은 양'**
  String get amountStyleLabel;

  /// No description provided for @qualitativeAmountOption.
  ///
  /// In ko, this message translates to:
  /// **'느낌으로'**
  String get qualitativeAmountOption;

  /// No description provided for @fractionAmountOption.
  ///
  /// In ko, this message translates to:
  /// **'제공량 기준'**
  String get fractionAmountOption;

  /// No description provided for @exactAmountOption.
  ///
  /// In ko, this message translates to:
  /// **'정확한 양'**
  String get exactAmountOption;

  /// No description provided for @sipAmountOption.
  ///
  /// In ko, this message translates to:
  /// **'한 모금'**
  String get sipAmountOption;

  /// No description provided for @biteAmountOption.
  ///
  /// In ko, this message translates to:
  /// **'맛만 봄'**
  String get biteAmountOption;

  /// No description provided for @littleAmountOption.
  ///
  /// In ko, this message translates to:
  /// **'조금'**
  String get littleAmountOption;

  /// No description provided for @normalAmountOption.
  ///
  /// In ko, this message translates to:
  /// **'보통'**
  String get normalAmountOption;

  /// No description provided for @muchAmountOption.
  ///
  /// In ko, this message translates to:
  /// **'많이'**
  String get muchAmountOption;

  /// No description provided for @quarterAmountOption.
  ///
  /// In ko, this message translates to:
  /// **'¼'**
  String get quarterAmountOption;

  /// No description provided for @halfAmountOption.
  ///
  /// In ko, this message translates to:
  /// **'절반'**
  String get halfAmountOption;

  /// No description provided for @almostAllAmountOption.
  ///
  /// In ko, this message translates to:
  /// **'거의 다'**
  String get almostAllAmountOption;

  /// No description provided for @allAmountOption.
  ///
  /// In ko, this message translates to:
  /// **'전부'**
  String get allAmountOption;

  /// No description provided for @exactAmountLabel.
  ///
  /// In ko, this message translates to:
  /// **'수치'**
  String get exactAmountLabel;

  /// No description provided for @amountUnitLabel.
  ///
  /// In ko, this message translates to:
  /// **'단위'**
  String get amountUnitLabel;

  /// No description provided for @mealTypeLabel.
  ///
  /// In ko, this message translates to:
  /// **'식사 구분'**
  String get mealTypeLabel;

  /// No description provided for @breakfastOption.
  ///
  /// In ko, this message translates to:
  /// **'아침'**
  String get breakfastOption;

  /// No description provided for @lunchOption.
  ///
  /// In ko, this message translates to:
  /// **'점심'**
  String get lunchOption;

  /// No description provided for @dinnerOption.
  ///
  /// In ko, this message translates to:
  /// **'저녁'**
  String get dinnerOption;

  /// No description provided for @foodNameLabel.
  ///
  /// In ko, this message translates to:
  /// **'음식 이름 (선택)'**
  String get foodNameLabel;

  /// No description provided for @snackNameLabel.
  ///
  /// In ko, this message translates to:
  /// **'간식 이름 (선택)'**
  String get snackNameLabel;

  /// No description provided for @reactionLabel.
  ///
  /// In ko, this message translates to:
  /// **'반응 (선택)'**
  String get reactionLabel;

  /// No description provided for @ateWellOption.
  ///
  /// In ko, this message translates to:
  /// **'잘 먹음'**
  String get ateWellOption;

  /// No description provided for @averageReactionOption.
  ///
  /// In ko, this message translates to:
  /// **'보통'**
  String get averageReactionOption;

  /// No description provided for @refusedOption.
  ///
  /// In ko, this message translates to:
  /// **'거부함'**
  String get refusedOption;

  /// No description provided for @memoOptionalLabel.
  ///
  /// In ko, this message translates to:
  /// **'메모 (선택)'**
  String get memoOptionalLabel;

  /// No description provided for @cupAmountOption.
  ///
  /// In ko, this message translates to:
  /// **'컵 기준'**
  String get cupAmountOption;

  /// No description provided for @cupAmountInfoTitle.
  ///
  /// In ko, this message translates to:
  /// **'컵 단위 안내'**
  String get cupAmountInfoTitle;

  /// No description provided for @cupAmountInfoBody.
  ///
  /// In ko, this message translates to:
  /// **'아기용 컵은 제품마다 다르지만 대략 200mL 전후인 경우가 많아요. 컵 단위는 대략적인 기록이며 정확한 mL로 환산하지 않아요.'**
  String get cupAmountInfoBody;

  /// No description provided for @exactAmountRequired.
  ///
  /// In ko, this message translates to:
  /// **'0보다 큰 수치를 입력해 주세요.'**
  String get exactAmountRequired;

  /// No description provided for @sleepEvent.
  ///
  /// In ko, this message translates to:
  /// **'수면'**
  String get sleepEvent;

  /// No description provided for @diaperEvent.
  ///
  /// In ko, this message translates to:
  /// **'기저귀·배변'**
  String get diaperEvent;

  /// No description provided for @pumpingEvent.
  ///
  /// In ko, this message translates to:
  /// **'유축'**
  String get pumpingEvent;

  /// No description provided for @temperatureEvent.
  ///
  /// In ko, this message translates to:
  /// **'체온'**
  String get temperatureEvent;

  /// No description provided for @medicationEvent.
  ///
  /// In ko, this message translates to:
  /// **'투약'**
  String get medicationEvent;

  /// No description provided for @symptomEvent.
  ///
  /// In ko, this message translates to:
  /// **'증상·컨디션'**
  String get symptomEvent;

  /// No description provided for @hospitalEvent.
  ///
  /// In ko, this message translates to:
  /// **'병원·상담'**
  String get hospitalEvent;

  /// No description provided for @vaccinationEvent.
  ///
  /// In ko, this message translates to:
  /// **'예방접종'**
  String get vaccinationEvent;

  /// No description provided for @accidentInjuryEvent.
  ///
  /// In ko, this message translates to:
  /// **'사고·다침'**
  String get accidentInjuryEvent;

  /// No description provided for @tummyTimeEvent.
  ///
  /// In ko, this message translates to:
  /// **'터미타임'**
  String get tummyTimeEvent;

  /// No description provided for @bathEvent.
  ///
  /// In ko, this message translates to:
  /// **'목욕'**
  String get bathEvent;

  /// No description provided for @growthMeasurementEvent.
  ///
  /// In ko, this message translates to:
  /// **'키·몸무게 측정'**
  String get growthMeasurementEvent;

  /// No description provided for @memoEvent.
  ///
  /// In ko, this message translates to:
  /// **'메모'**
  String get memoEvent;

  /// No description provided for @eventDetailOptionalLabel.
  ///
  /// In ko, this message translates to:
  /// **'상세 (선택)'**
  String get eventDetailOptionalLabel;

  /// No description provided for @eventDetailOptionalHint.
  ///
  /// In ko, this message translates to:
  /// **'수량, 상태 또는 짧은 메모를 남겨보세요.'**
  String get eventDetailOptionalHint;

  /// No description provided for @writeDetailedRecord.
  ///
  /// In ko, this message translates to:
  /// **'긴 메모와 AI 정리'**
  String get writeDetailedRecord;

  /// No description provided for @backToRecordTypes.
  ///
  /// In ko, this message translates to:
  /// **'기록 종류로 돌아가기'**
  String get backToRecordTypes;

  /// No description provided for @savingQuickRecord.
  ///
  /// In ko, this message translates to:
  /// **'저장 중…'**
  String get savingQuickRecord;

  /// No description provided for @quickRecordSaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'기록을 저장하지 못했어요. 입력 내용은 그대로 유지됩니다.'**
  String get quickRecordSaveFailed;

  /// No description provided for @quickRecordSaved.
  ///
  /// In ko, this message translates to:
  /// **'{type} 기록을 저장했어요.'**
  String quickRecordSaved(String type);

  /// No description provided for @addEventButton.
  ///
  /// In ko, this message translates to:
  /// **'이벤트 추가'**
  String get addEventButton;

  /// No description provided for @eventTypeLabel.
  ///
  /// In ko, this message translates to:
  /// **'종류'**
  String get eventTypeLabel;

  /// No description provided for @eventTypeHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 수유, 수면, 병원'**
  String get eventTypeHint;

  /// No description provided for @eventDetailLabel.
  ///
  /// In ko, this message translates to:
  /// **'상세'**
  String get eventDetailLabel;

  /// No description provided for @eventDetailHint.
  ///
  /// In ko, this message translates to:
  /// **'예: [7, 9, 11]시, 오전 소아과'**
  String get eventDetailHint;

  /// No description provided for @recordTimeLabel.
  ///
  /// In ko, this message translates to:
  /// **'기록 시각'**
  String get recordTimeLabel;

  /// No description provided for @eventTimeUnknown.
  ///
  /// In ko, this message translates to:
  /// **'발생 시각 미상'**
  String get eventTimeUnknown;

  /// No description provided for @clearEventTime.
  ///
  /// In ko, this message translates to:
  /// **'발생 시각 지우기'**
  String get clearEventTime;

  /// No description provided for @delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get confirm;

  /// No description provided for @edit.
  ///
  /// In ko, this message translates to:
  /// **'수정'**
  String get edit;

  /// No description provided for @diaryAdded.
  ///
  /// In ko, this message translates to:
  /// **'새 일기가 추가되었습니다.'**
  String get diaryAdded;

  /// No description provided for @diaryUpdated.
  ///
  /// In ko, this message translates to:
  /// **'일기가 수정되었습니다.'**
  String get diaryUpdated;

  /// No description provided for @diaryDeleted.
  ///
  /// In ko, this message translates to:
  /// **'일기가 삭제되었습니다.'**
  String get diaryDeleted;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In ko, this message translates to:
  /// **'일기 삭제'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmDesc.
  ///
  /// In ko, this message translates to:
  /// **'이 일기를 정말 삭제하시겠습니까? 삭제 후에는 복구할 수 없습니다.'**
  String get deleteConfirmDesc;

  /// No description provided for @todayTab.
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get todayTab;

  /// No description provided for @dateTab.
  ///
  /// In ko, this message translates to:
  /// **'날짜별'**
  String get dateTab;

  /// No description provided for @todayTimelineTitle.
  ///
  /// In ko, this message translates to:
  /// **'오늘 기록'**
  String get todayTimelineTitle;

  /// No description provided for @todayStatusTitle.
  ///
  /// In ko, this message translates to:
  /// **'오늘 현황'**
  String get todayStatusTitle;

  /// No description provided for @startupLoading.
  ///
  /// In ko, this message translates to:
  /// **'앱을 준비하는 중...'**
  String get startupLoading;

  /// No description provided for @startupErrorTitle.
  ///
  /// In ko, this message translates to:
  /// **'앱 초기화 중 문제가 발생했습니다'**
  String get startupErrorTitle;

  /// No description provided for @startupRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get startupRetry;

  /// No description provided for @startupResetData.
  ///
  /// In ko, this message translates to:
  /// **'모든 데이터 초기화'**
  String get startupResetData;

  /// No description provided for @startupResetConfirmMessage.
  ///
  /// In ko, this message translates to:
  /// **'정말 모든 데이터를 삭제하고 처음부터 다시 시작하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'**
  String get startupResetConfirmMessage;

  /// No description provided for @searchTab.
  ///
  /// In ko, this message translates to:
  /// **'검색'**
  String get searchTab;

  /// No description provided for @searchTitle.
  ///
  /// In ko, this message translates to:
  /// **'기록 검색'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In ko, this message translates to:
  /// **'메모나 이벤트를 검색해 보세요.'**
  String get searchHint;

  /// No description provided for @searchAction.
  ///
  /// In ko, this message translates to:
  /// **'검색'**
  String get searchAction;

  /// No description provided for @searchIntroTitle.
  ///
  /// In ko, this message translates to:
  /// **'지난 기록을 찾아보세요'**
  String get searchIntroTitle;

  /// No description provided for @searchIntroDescription.
  ///
  /// In ko, this message translates to:
  /// **'메모 내용이나 수유, 투약 같은 이벤트 이름으로 찾을 수 있어요.'**
  String get searchIntroDescription;

  /// No description provided for @searchResultCount.
  ///
  /// In ko, this message translates to:
  /// **'검색 결과 {count}건'**
  String searchResultCount(int count);

  /// No description provided for @searchNoResults.
  ///
  /// In ko, this message translates to:
  /// **'일치하는 기록이 없어요.'**
  String get searchNoResults;

  /// No description provided for @searchNoResultsHint.
  ///
  /// In ko, this message translates to:
  /// **'검색 조건은 유지돼요. 기간을 넓히거나 조건을 하나씩 빼보세요.'**
  String get searchNoResultsHint;

  /// No description provided for @searchFailed.
  ///
  /// In ko, this message translates to:
  /// **'검색하지 못했어요. 원본 기록은 그대로 유지됩니다.'**
  String get searchFailed;

  /// No description provided for @retrySearch.
  ///
  /// In ko, this message translates to:
  /// **'다시 검색'**
  String get retrySearch;

  /// No description provided for @searchSortLabel.
  ///
  /// In ko, this message translates to:
  /// **'정렬'**
  String get searchSortLabel;

  /// No description provided for @searchSortRelevance.
  ///
  /// In ko, this message translates to:
  /// **'관련도순'**
  String get searchSortRelevance;

  /// No description provided for @searchSortNewest.
  ///
  /// In ko, this message translates to:
  /// **'최신순'**
  String get searchSortNewest;

  /// No description provided for @searchSortOldest.
  ///
  /// In ko, this message translates to:
  /// **'오래된순'**
  String get searchSortOldest;

  /// No description provided for @searchMatchExact.
  ///
  /// In ko, this message translates to:
  /// **'정확한 문구 일치'**
  String get searchMatchExact;

  /// No description provided for @searchMatchActivityType.
  ///
  /// In ko, this message translates to:
  /// **'이벤트 종류 일치'**
  String get searchMatchActivityType;

  /// No description provided for @searchMatchRelated.
  ///
  /// In ko, this message translates to:
  /// **'관련 표현'**
  String get searchMatchRelated;

  /// No description provided for @searchMatchTemperature.
  ///
  /// In ko, this message translates to:
  /// **'체온 조건 일치'**
  String get searchMatchTemperature;

  /// No description provided for @searchMatchAuthor.
  ///
  /// In ko, this message translates to:
  /// **'작성자 조건 일치'**
  String get searchMatchAuthor;

  /// No description provided for @searchMatchEvent.
  ///
  /// In ko, this message translates to:
  /// **'이벤트 조건 일치'**
  String get searchMatchEvent;

  /// No description provided for @searchMatchDate.
  ///
  /// In ko, this message translates to:
  /// **'날짜 조건 일치'**
  String get searchMatchDate;

  /// No description provided for @searchFilters.
  ///
  /// In ko, this message translates to:
  /// **'검색 조건'**
  String get searchFilters;

  /// No description provided for @searchClearFilters.
  ///
  /// In ko, this message translates to:
  /// **'조건 지우기'**
  String get searchClearFilters;

  /// No description provided for @searchApplyFilters.
  ///
  /// In ko, this message translates to:
  /// **'조건 적용'**
  String get searchApplyFilters;

  /// No description provided for @searchDate.
  ///
  /// In ko, this message translates to:
  /// **'날짜'**
  String get searchDate;

  /// No description provided for @searchAll.
  ///
  /// In ko, this message translates to:
  /// **'전체'**
  String get searchAll;

  /// No description provided for @searchAllDates.
  ///
  /// In ko, this message translates to:
  /// **'전체 기간'**
  String get searchAllDates;

  /// No description provided for @searchToday.
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get searchToday;

  /// No description provided for @searchLast7Days.
  ///
  /// In ko, this message translates to:
  /// **'최근 7일'**
  String get searchLast7Days;

  /// No description provided for @searchLast30Days.
  ///
  /// In ko, this message translates to:
  /// **'최근 30일'**
  String get searchLast30Days;

  /// No description provided for @searchCustomDate.
  ///
  /// In ko, this message translates to:
  /// **'직접 지정'**
  String get searchCustomDate;

  /// No description provided for @searchEventType.
  ///
  /// In ko, this message translates to:
  /// **'이벤트 종류'**
  String get searchEventType;

  /// No description provided for @searchAuthor.
  ///
  /// In ko, this message translates to:
  /// **'작성자'**
  String get searchAuthor;

  /// No description provided for @searchTemperature.
  ///
  /// In ko, this message translates to:
  /// **'최소 체온'**
  String get searchTemperature;

  /// No description provided for @searchTemperatureAtLeast.
  ///
  /// In ko, this message translates to:
  /// **'{value}°C 이상'**
  String searchTemperatureAtLeast(String value);

  /// No description provided for @searchEventTemperature.
  ///
  /// In ko, this message translates to:
  /// **'체온'**
  String get searchEventTemperature;

  /// No description provided for @searchEventMedication.
  ///
  /// In ko, this message translates to:
  /// **'투약'**
  String get searchEventMedication;

  /// No description provided for @searchEventFeeding.
  ///
  /// In ko, this message translates to:
  /// **'수유'**
  String get searchEventFeeding;

  /// No description provided for @searchEventDiaper.
  ///
  /// In ko, this message translates to:
  /// **'기저귀'**
  String get searchEventDiaper;

  /// No description provided for @searchEventSleep.
  ///
  /// In ko, this message translates to:
  /// **'수면'**
  String get searchEventSleep;

  /// No description provided for @searchEventHospital.
  ///
  /// In ko, this message translates to:
  /// **'병원·진료'**
  String get searchEventHospital;

  /// No description provided for @searchSemanticUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'의미 검색을 사용할 수 없거나 인덱싱 중이어도 문구·조건 검색은 계속 사용할 수 있어요.'**
  String get searchSemanticUnavailable;

  /// No description provided for @searchSameDayContext.
  ///
  /// In ko, this message translates to:
  /// **'같은 날의 다른 기록'**
  String get searchSameDayContext;

  /// No description provided for @searchSameDayContextHint.
  ///
  /// In ko, this message translates to:
  /// **'맥락을 위한 표시이며 원인이나 관련성을 뜻하지 않아요.'**
  String get searchSameDayContextHint;

  /// No description provided for @dailyAiSummary.
  ///
  /// In ko, this message translates to:
  /// **'AI 일간 정리'**
  String get dailyAiSummary;

  /// No description provided for @weeklyAiSummary.
  ///
  /// In ko, this message translates to:
  /// **'AI 주간 정리'**
  String get weeklyAiSummary;

  /// No description provided for @summarizeDay.
  ///
  /// In ko, this message translates to:
  /// **'이날 정리하기'**
  String get summarizeDay;

  /// No description provided for @summarizeWeek.
  ///
  /// In ko, this message translates to:
  /// **'이 주 정리하기'**
  String get summarizeWeek;

  /// No description provided for @summarizeWeekSoFar.
  ///
  /// In ko, this message translates to:
  /// **'현재까지 정리'**
  String get summarizeWeekSoFar;

  /// No description provided for @summaryGenerating.
  ///
  /// In ko, this message translates to:
  /// **'원본 기록을 바탕으로 정리하고 있어요…'**
  String get summaryGenerating;

  /// No description provided for @summaryUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'AI 정리를 사용할 수 없어요. 원본 기록과 계산된 현황은 그대로 볼 수 있어요.'**
  String get summaryUnavailable;

  /// No description provided for @summaryFailed.
  ///
  /// In ko, this message translates to:
  /// **'정리를 만들지 못했어요. 원본 기록은 변경되지 않았어요.'**
  String get summaryFailed;

  /// No description provided for @summaryNoRecords.
  ///
  /// In ko, this message translates to:
  /// **'정리할 원본 기록이 없어요.'**
  String get summaryNoRecords;

  /// No description provided for @summaryBasis.
  ///
  /// In ko, this message translates to:
  /// **'{time}까지의 원본 기록 {count}개 기준'**
  String summaryBasis(int count, String time);

  /// No description provided for @summaryNewRecords.
  ///
  /// In ko, this message translates to:
  /// **'이 정리 이후 새 기록이 있어요.'**
  String get summaryNewRecords;

  /// No description provided for @summarySourceChanged.
  ///
  /// In ko, this message translates to:
  /// **'이 정리에 사용한 원본 기록이 변경되었어요.'**
  String get summarySourceChanged;

  /// No description provided for @summaryEdited.
  ///
  /// In ko, this message translates to:
  /// **'직접 수정됨'**
  String get summaryEdited;

  /// No description provided for @summaryEvidence.
  ///
  /// In ko, this message translates to:
  /// **'근거 기록 보기'**
  String get summaryEvidence;

  /// No description provided for @summaryEvidenceTitle.
  ///
  /// In ko, this message translates to:
  /// **'정리에 사용한 원본 기록'**
  String get summaryEvidenceTitle;

  /// No description provided for @summaryEditTitle.
  ///
  /// In ko, this message translates to:
  /// **'정리 수정'**
  String get summaryEditTitle;

  /// No description provided for @summaryHide.
  ///
  /// In ko, this message translates to:
  /// **'숨기기'**
  String get summaryHide;

  /// No description provided for @summaryRestore.
  ///
  /// In ko, this message translates to:
  /// **'정리 다시 보기'**
  String get summaryRestore;

  /// No description provided for @summaryRegenerate.
  ///
  /// In ko, this message translates to:
  /// **'다시 생성'**
  String get summaryRegenerate;

  /// No description provided for @summaryPreviewTitle.
  ///
  /// In ko, this message translates to:
  /// **'새 정리 확인'**
  String get summaryPreviewTitle;

  /// No description provided for @summaryReplace.
  ///
  /// In ko, this message translates to:
  /// **'새 정리로 교체'**
  String get summaryReplace;

  /// No description provided for @weeklyAutoSummary.
  ///
  /// In ko, this message translates to:
  /// **'주간 AI 정리 자동 생성'**
  String get weeklyAutoSummary;

  /// No description provided for @weeklyAutoSummaryDescription.
  ///
  /// In ko, this message translates to:
  /// **'월요일부터 일요일까지 완료된 주를 기기 내 AI로 조용히 정리해요.'**
  String get weeklyAutoSummaryDescription;

  /// No description provided for @medicalBriefingTitle.
  ///
  /// In ko, this message translates to:
  /// **'병원 방문 브리핑'**
  String get medicalBriefingTitle;

  /// No description provided for @medicalBriefingDescription.
  ///
  /// In ko, this message translates to:
  /// **'병원 방문 전 기록한 체온, 투약, 증상, 진료, 예방접종과 사고·다침 사실을 모아 확인해요.'**
  String get medicalBriefingDescription;

  /// No description provided for @briefingSafetyNotice.
  ///
  /// In ko, this message translates to:
  /// **'기록된 사실만 보여 줍니다. 진단, 인과관계나 치료 조언을 제공하지 않아요. 중요한 내용은 원본 기록에서 다시 확인하세요.'**
  String get briefingSafetyNotice;

  /// No description provided for @briefingPeriod.
  ///
  /// In ko, this message translates to:
  /// **'브리핑 기간'**
  String get briefingPeriod;

  /// No description provided for @briefingDateRange.
  ///
  /// In ko, this message translates to:
  /// **'{from}~{to}'**
  String briefingDateRange(String from, String to);

  /// No description provided for @briefingFactCount.
  ///
  /// In ko, this message translates to:
  /// **'기록된 사실 {count}건'**
  String briefingFactCount(int count);

  /// No description provided for @briefingNoFacts.
  ///
  /// In ko, this message translates to:
  /// **'조건에 맞는 건강 기록이 없어요.'**
  String get briefingNoFacts;

  /// No description provided for @briefingNoFactsHint.
  ///
  /// In ko, this message translates to:
  /// **'기간을 유지하거나 더 넓혀 보세요. 일반 메모와 비의료 이벤트를 의료 사실로 추정하지 않아요.'**
  String get briefingNoFactsHint;

  /// No description provided for @briefingCopy.
  ///
  /// In ko, this message translates to:
  /// **'브리핑 복사'**
  String get briefingCopy;

  /// No description provided for @briefingCopied.
  ///
  /// In ko, this message translates to:
  /// **'브리핑을 복사했어요.'**
  String get briefingCopied;

  /// No description provided for @briefingShare.
  ///
  /// In ko, this message translates to:
  /// **'브리핑 공유'**
  String get briefingShare;

  /// No description provided for @briefingOpenOriginal.
  ///
  /// In ko, this message translates to:
  /// **'원본 기록 열기'**
  String get briefingOpenOriginal;

  /// No description provided for @searchMemoResult.
  ///
  /// In ko, this message translates to:
  /// **'메모'**
  String get searchMemoResult;

  /// No description provided for @searchActivityResult.
  ///
  /// In ko, this message translates to:
  /// **'이벤트'**
  String get searchActivityResult;

  /// No description provided for @searchReadOnly.
  ///
  /// In ko, this message translates to:
  /// **'읽기 전용'**
  String get searchReadOnly;

  /// No description provided for @searchResultDetail.
  ///
  /// In ko, this message translates to:
  /// **'검색 결과 상세'**
  String get searchResultDetail;

  /// No description provided for @settings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settings;

  /// No description provided for @settingsTitle.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTitle;

  /// No description provided for @settingsIntro.
  ///
  /// In ko, this message translates to:
  /// **'꼭 필요한 정보와 데이터 보관 방법만 한곳에서 관리합니다.'**
  String get settingsIntro;

  /// No description provided for @childInformation.
  ///
  /// In ko, this message translates to:
  /// **'아이 정보'**
  String get childInformation;

  /// No description provided for @childInformationDescription.
  ///
  /// In ko, this message translates to:
  /// **'아직 기록과 연결된 아이 정보를 저장할 수 없어요.'**
  String get childInformationDescription;

  /// No description provided for @authorProfile.
  ///
  /// In ko, this message translates to:
  /// **'내 이름과 색상'**
  String get authorProfile;

  /// No description provided for @authorProfileDescription.
  ///
  /// In ko, this message translates to:
  /// **'새 기록에 사용할 작성자 이름과 색상을 관리합니다.'**
  String get authorProfileDescription;

  /// No description provided for @authorSetupTitle.
  ///
  /// In ko, this message translates to:
  /// **'이 기기에서 누가 기록하나요?'**
  String get authorSetupTitle;

  /// No description provided for @authorSetupDescription.
  ///
  /// In ko, this message translates to:
  /// **'가족이 알아볼 수 있는 이름과 색상을 정해 주세요. 실명일 필요는 없으며 새 기록에 자동으로 적용됩니다.'**
  String get authorSetupDescription;

  /// No description provided for @authorNicknameLabel.
  ///
  /// In ko, this message translates to:
  /// **'작성자 이름'**
  String get authorNicknameLabel;

  /// No description provided for @authorNicknameHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 엄마, 아빠, 할머니'**
  String get authorNicknameHint;

  /// No description provided for @authorColorLabel.
  ///
  /// In ko, this message translates to:
  /// **'개인 색상'**
  String get authorColorLabel;

  /// No description provided for @authorSave.
  ///
  /// In ko, this message translates to:
  /// **'이 이름으로 시작'**
  String get authorSave;

  /// No description provided for @authorAdd.
  ///
  /// In ko, this message translates to:
  /// **'작성자 추가'**
  String get authorAdd;

  /// No description provided for @authorEdit.
  ///
  /// In ko, this message translates to:
  /// **'작성자 수정'**
  String get authorEdit;

  /// No description provided for @authorProfilesTitle.
  ///
  /// In ko, this message translates to:
  /// **'작성자 프로필'**
  String get authorProfilesTitle;

  /// No description provided for @authorCurrent.
  ///
  /// In ko, this message translates to:
  /// **'현재 작성자'**
  String get authorCurrent;

  /// No description provided for @authorUseProfile.
  ///
  /// In ko, this message translates to:
  /// **'이 작성자로 전환'**
  String get authorUseProfile;

  /// No description provided for @authorNicknameError.
  ///
  /// In ko, this message translates to:
  /// **'1~30자의 이름을 입력해 주세요.'**
  String get authorNicknameError;

  /// No description provided for @authorProfileLocalNotice.
  ///
  /// In ko, this message translates to:
  /// **'평소에는 현재 작성자가 자동으로 적용됩니다. 같은 기기를 여러 사람이 사용할 때만 전환하세요.'**
  String get authorProfileLocalNotice;

  /// No description provided for @familySharing.
  ///
  /// In ko, this message translates to:
  /// **'가족과 함께 쓰기'**
  String get familySharing;

  /// No description provided for @familySharingDescription.
  ///
  /// In ko, this message translates to:
  /// **'현재 기록은 이 기기에만 저장됩니다.'**
  String get familySharingDescription;

  /// No description provided for @dataBackupTitle.
  ///
  /// In ko, this message translates to:
  /// **'데이터 보관 및 백업'**
  String get dataBackupTitle;

  /// No description provided for @dataBackupDescription.
  ///
  /// In ko, this message translates to:
  /// **'기록을 파일로 보관하거나 안전하게 가져옵니다.'**
  String get dataBackupDescription;

  /// No description provided for @helpTitle.
  ///
  /// In ko, this message translates to:
  /// **'도움말'**
  String get helpTitle;

  /// No description provided for @helpDescription.
  ///
  /// In ko, this message translates to:
  /// **'앱의 동작 이유와 언어 설정을 확인합니다.'**
  String get helpDescription;

  /// No description provided for @notAvailableYetTitle.
  ///
  /// In ko, this message translates to:
  /// **'아직 준비 중이에요'**
  String get notAvailableYetTitle;

  /// No description provided for @notAvailableYetDescription.
  ///
  /// In ko, this message translates to:
  /// **'{feature} 기능은 필요한 데이터 구조와 안전 기준을 갖춘 뒤 제공할 예정입니다.'**
  String notAvailableYetDescription(String feature);

  /// No description provided for @storageSummaryTitle.
  ///
  /// In ko, this message translates to:
  /// **'현재 백업 범위'**
  String get storageSummaryTitle;

  /// No description provided for @backupContentsSummary.
  ///
  /// In ko, this message translates to:
  /// **'일기 {records}건 · 활동 {activities}건\n예상 파일 크기 {size}'**
  String backupContentsSummary(int records, int activities, String size);

  /// No description provided for @backupPrivacyNotice.
  ///
  /// In ko, this message translates to:
  /// **'현재 백업은 기록과 활동을 암호화되지 않은 JSON 파일로 보관합니다. 첨부파일 기능은 아직 포함되지 않습니다.'**
  String get backupPrivacyNotice;

  /// No description provided for @createBackupFile.
  ///
  /// In ko, this message translates to:
  /// **'백업 파일 만들기'**
  String get createBackupFile;

  /// No description provided for @createBackupDescription.
  ///
  /// In ko, this message translates to:
  /// **'현재 기기의 기록과 활동을 다른 곳에 보관할 수 있는 파일로 만듭니다.'**
  String get createBackupDescription;

  /// No description provided for @importBackupFile.
  ///
  /// In ko, this message translates to:
  /// **'백업 파일 가져오기'**
  String get importBackupFile;

  /// No description provided for @importBackupDescription.
  ///
  /// In ko, this message translates to:
  /// **'파일을 바로 합치지 않고 내용과 충돌 가능성을 먼저 보여드립니다.'**
  String get importBackupDescription;

  /// No description provided for @recentlyDeleted.
  ///
  /// In ko, this message translates to:
  /// **'최근 삭제한 기록'**
  String get recentlyDeleted;

  /// No description provided for @recentlyDeletedDescription.
  ///
  /// In ko, this message translates to:
  /// **'복구 가능한 삭제 기능은 아직 준비 중이에요.'**
  String get recentlyDeletedDescription;

  /// No description provided for @helpIntro.
  ///
  /// In ko, this message translates to:
  /// **'버튼 위치보다 왜 이렇게 동작하는지 먼저 설명드릴게요.'**
  String get helpIntro;

  /// No description provided for @offlineHelpQuestion.
  ///
  /// In ko, this message translates to:
  /// **'왜 인터넷이 없어도 기록할 수 있나요?'**
  String get offlineHelpQuestion;

  /// No description provided for @offlineHelpAnswer.
  ///
  /// In ko, this message translates to:
  /// **'기록은 먼저 현재 기기에 저장됩니다. 네트워크나 AI 기능에 문제가 생겨도 원문 기록은 계속 작성하고 찾을 수 있어요.'**
  String get offlineHelpAnswer;

  /// No description provided for @duplicateHelpQuestion.
  ///
  /// In ko, this message translates to:
  /// **'왜 가져온 기록을 자동으로 덮어쓰지 않나요?'**
  String get duplicateHelpQuestion;

  /// No description provided for @duplicateHelpAnswer.
  ///
  /// In ko, this message translates to:
  /// **'같은 기록이 서로 다르면 어느 쪽도 조용히 지우지 않는 편이 안전합니다. 지금은 새 기록만 추가하고 같은 ID의 기록은 건너뜁니다.'**
  String get duplicateHelpAnswer;

  /// No description provided for @languageSetting.
  ///
  /// In ko, this message translates to:
  /// **'언어 설정'**
  String get languageSetting;

  /// No description provided for @languageSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정'**
  String get languageSystem;

  /// No description provided for @languageKorean.
  ///
  /// In ko, this message translates to:
  /// **'한국어(Korean)'**
  String get languageKorean;

  /// No description provided for @languageEnglish.
  ///
  /// In ko, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageJapanese.
  ///
  /// In ko, this message translates to:
  /// **'日本語(Japanese)'**
  String get languageJapanese;

  /// No description provided for @close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get close;

  /// No description provided for @llmModelError.
  ///
  /// In ko, this message translates to:
  /// **'모델 파일을 찾을 수 없습니다. AI 분석이 비활성화됩니다.'**
  String get llmModelError;

  /// No description provided for @dataManagement.
  ///
  /// In ko, this message translates to:
  /// **'데이터 관리'**
  String get dataManagement;

  /// No description provided for @dataManagementDescription.
  ///
  /// In ko, this message translates to:
  /// **'전체 일기와 활동을 백업하거나 복원합니다.'**
  String get dataManagementDescription;

  /// No description provided for @exportDiary.
  ///
  /// In ko, this message translates to:
  /// **'일기 내보내기'**
  String get exportDiary;

  /// No description provided for @importDiary.
  ///
  /// In ko, this message translates to:
  /// **'일기 가져오기'**
  String get importDiary;

  /// No description provided for @exportWarningTitle.
  ///
  /// In ko, this message translates to:
  /// **'평문 백업 내보내기'**
  String get exportWarningTitle;

  /// No description provided for @exportWarning.
  ///
  /// In ko, this message translates to:
  /// **'일기 {count}건의 제목, 요약, 본문과 활동이 암호화되지 않은 파일에 포함됩니다.'**
  String exportWarning(int count);

  /// No description provided for @exporting.
  ///
  /// In ko, this message translates to:
  /// **'백업 파일을 만드는 중입니다…'**
  String get exporting;

  /// No description provided for @importing.
  ///
  /// In ko, this message translates to:
  /// **'일기를 가져오는 중입니다…'**
  String get importing;

  /// No description provided for @exportSuccess.
  ///
  /// In ko, this message translates to:
  /// **'{count}건을 v{version} 백업으로 내보냈습니다.\n{fileName}'**
  String exportSuccess(int count, int version, String fileName);

  /// No description provided for @importPreviewTitle.
  ///
  /// In ko, this message translates to:
  /// **'가져오기 미리보기'**
  String get importPreviewTitle;

  /// No description provided for @backupInfo.
  ///
  /// In ko, this message translates to:
  /// **'백업 v{version} · 앱 {appVersion}\n생성: {exportedAt}'**
  String backupInfo(int version, String appVersion, String exportedAt);

  /// No description provided for @importCounts.
  ///
  /// In ko, this message translates to:
  /// **'일기 {total}건 · 활동 {activities}건'**
  String importCounts(int total, int activities);

  /// No description provided for @newRecords.
  ///
  /// In ko, this message translates to:
  /// **'새 일기'**
  String get newRecords;

  /// No description provided for @duplicateRecords.
  ///
  /// In ko, this message translates to:
  /// **'중복'**
  String get duplicateRecords;

  /// No description provided for @identicalRecords.
  ///
  /// In ko, this message translates to:
  /// **'내용이 같은 기록'**
  String get identicalRecords;

  /// No description provided for @conflictingRecords.
  ///
  /// In ko, this message translates to:
  /// **'확인이 필요한 충돌'**
  String get conflictingRecords;

  /// No description provided for @importDateRange.
  ///
  /// In ko, this message translates to:
  /// **'기록 기간: {from} ~ {to}'**
  String importDateRange(String from, String to);

  /// No description provided for @safeImportNotice.
  ///
  /// In ko, this message translates to:
  /// **'가져오기 직전에 현재 기록을 자동 백업합니다. 기존 기록은 덮어쓰지 않고 새 기록만 추가합니다.'**
  String get safeImportNotice;

  /// No description provided for @newerRecords.
  ///
  /// In ko, this message translates to:
  /// **'최신 백업으로 갱신'**
  String get newerRecords;

  /// No description provided for @skippedRecords.
  ///
  /// In ko, this message translates to:
  /// **'건너뜀'**
  String get skippedRecords;

  /// No description provided for @conflictPolicy.
  ///
  /// In ko, this message translates to:
  /// **'중복 처리'**
  String get conflictPolicy;

  /// No description provided for @skipExisting.
  ///
  /// In ko, this message translates to:
  /// **'기존 일기 건너뛰기'**
  String get skipExisting;

  /// No description provided for @overwriteIfNewer.
  ///
  /// In ko, this message translates to:
  /// **'백업이 더 최신이면 덮어쓰기'**
  String get overwriteIfNewer;

  /// No description provided for @importAction.
  ///
  /// In ko, this message translates to:
  /// **'가져오기'**
  String get importAction;

  /// No description provided for @importResult.
  ///
  /// In ko, this message translates to:
  /// **'추가 {inserted}건 · 갱신 {updated}건 · 건너뜀 {skipped}건'**
  String importResult(int inserted, int updated, int skipped);

  /// No description provided for @embeddingFailed.
  ///
  /// In ko, this message translates to:
  /// **'검색 색인 {count}건은 나중에 다시 생성해야 합니다.'**
  String embeddingFailed(int count);

  /// No description provided for @transferError.
  ///
  /// In ko, this message translates to:
  /// **'백업을 처리하지 못했습니다. 파일 형식과 저장 공간을 확인해 주세요.'**
  String get transferError;

  /// No description provided for @draftSaving.
  ///
  /// In ko, this message translates to:
  /// **'임시 저장 중…'**
  String get draftSaving;

  /// No description provided for @draftSaved.
  ///
  /// In ko, this message translates to:
  /// **'임시 저장됨'**
  String get draftSaved;

  /// No description provided for @draftSaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'임시 저장하지 못했어요'**
  String get draftSaveFailed;

  /// No description provided for @draftSourceChanged.
  ///
  /// In ko, this message translates to:
  /// **'초안을 만든 뒤 원본 기록이 변경됐어요. 저장하기 전에 내용을 확인해 주세요.'**
  String get draftSourceChanged;

  /// No description provided for @discardDraft.
  ///
  /// In ko, this message translates to:
  /// **'초안 버리기'**
  String get discardDraft;

  /// No description provided for @discardDraftTitle.
  ///
  /// In ko, this message translates to:
  /// **'이 초안을 버릴까요?'**
  String get discardDraftTitle;

  /// No description provided for @discardDraftDescription.
  ///
  /// In ko, this message translates to:
  /// **'작성 중인 내용은 복구할 수 없습니다.'**
  String get discardDraftDescription;

  /// No description provided for @draftsInProgress.
  ///
  /// In ko, this message translates to:
  /// **'작성 중인 기록 {count}개'**
  String draftsInProgress(int count);

  /// No description provided for @continueWriting.
  ///
  /// In ko, this message translates to:
  /// **'이어서 작성'**
  String get continueWriting;

  /// No description provided for @startNewDraft.
  ///
  /// In ko, this message translates to:
  /// **'새로 작성'**
  String get startNewDraft;

  /// No description provided for @recordCreatedBy.
  ///
  /// In ko, this message translates to:
  /// **'작성자 {nickname}'**
  String recordCreatedBy(String nickname);

  /// No description provided for @recordSourceDetails.
  ///
  /// In ko, this message translates to:
  /// **'기록 출처'**
  String get recordSourceDetails;

  /// No description provided for @recordSourceDevice.
  ///
  /// In ko, this message translates to:
  /// **'입력 기기 {deviceId}'**
  String recordSourceDevice(String deviceId);

  /// No description provided for @duplicateReviewTitle.
  ///
  /// In ko, this message translates to:
  /// **'확인할 기록'**
  String get duplicateReviewTitle;

  /// No description provided for @duplicateReviewDescription.
  ///
  /// In ko, this message translates to:
  /// **'서로 다른 기기에서 같은 시각과 내용으로 저장된 원본을 비교합니다. 확인하기 전에는 어떤 기록도 합치거나 삭제하지 않아요.'**
  String get duplicateReviewDescription;

  /// No description provided for @duplicateReviewBanner.
  ///
  /// In ko, this message translates to:
  /// **'확인할 기록 {count}개'**
  String duplicateReviewBanner(int count);

  /// No description provided for @duplicateReviewBannerHint.
  ///
  /// In ko, this message translates to:
  /// **'비슷한 기록인지 확인해 주세요.'**
  String get duplicateReviewBannerHint;

  /// No description provided for @duplicatePendingCount.
  ///
  /// In ko, this message translates to:
  /// **'확인 필요 {count}개'**
  String duplicatePendingCount(int count);

  /// No description provided for @duplicateResolvedTitle.
  ///
  /// In ko, this message translates to:
  /// **'확인한 기록'**
  String get duplicateResolvedTitle;

  /// No description provided for @duplicateNeedsReview.
  ///
  /// In ko, this message translates to:
  /// **'비슷한 기록 2개'**
  String get duplicateNeedsReview;

  /// No description provided for @duplicateExactReason.
  ///
  /// In ko, this message translates to:
  /// **'종류, 발생 시각과 내용이 같고 입력 기기가 달라요.'**
  String get duplicateExactReason;

  /// No description provided for @duplicateUseSource.
  ///
  /// In ko, this message translates to:
  /// **'{number}번을 기준으로 한 건으로 표시'**
  String duplicateUseSource(int number);

  /// No description provided for @duplicateMarkDistinct.
  ///
  /// In ko, this message translates to:
  /// **'1번과 2번은 각각 다른 일'**
  String get duplicateMarkDistinct;

  /// No description provided for @duplicateReviewLater.
  ///
  /// In ko, this message translates to:
  /// **'나중에 확인'**
  String get duplicateReviewLater;

  /// No description provided for @duplicateSameEvent.
  ///
  /// In ko, this message translates to:
  /// **'같은 사건으로 확인됨'**
  String get duplicateSameEvent;

  /// No description provided for @duplicateDistinctEvents.
  ///
  /// In ko, this message translates to:
  /// **'각각 다른 일로 확인됨'**
  String get duplicateDistinctEvents;

  /// No description provided for @duplicateDecisionSaved.
  ///
  /// In ko, this message translates to:
  /// **'중복 판단을 저장했어요. 원본 기록은 그대로 유지됩니다.'**
  String get duplicateDecisionSaved;

  /// No description provided for @duplicateChangeDecision.
  ///
  /// In ko, this message translates to:
  /// **'중복 판단 변경'**
  String get duplicateChangeDecision;

  /// No description provided for @duplicateReviewEmpty.
  ///
  /// In ko, this message translates to:
  /// **'확인할 기록이 없어요'**
  String get duplicateReviewEmpty;

  /// No description provided for @duplicateReviewEmptyHint.
  ///
  /// In ko, this message translates to:
  /// **'새 후보가 생기면 오늘 화면에 표시됩니다.'**
  String get duplicateReviewEmptyHint;

  /// No description provided for @myRecordsTitle.
  ///
  /// In ko, this message translates to:
  /// **'나만의 기록'**
  String get myRecordsTitle;

  /// No description provided for @createCustomEvent.
  ///
  /// In ko, this message translates to:
  /// **'새 기록 만들기'**
  String get createCustomEvent;

  /// No description provided for @customEventNameLabel.
  ///
  /// In ko, this message translates to:
  /// **'기록 이름'**
  String get customEventNameLabel;

  /// No description provided for @customEventNameHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 비타민, 산책 준비'**
  String get customEventNameHint;

  /// No description provided for @customEventNameRequired.
  ///
  /// In ko, this message translates to:
  /// **'이름을 입력해 주세요.'**
  String get customEventNameRequired;

  /// No description provided for @customEventMemoOptionalLabel.
  ///
  /// In ko, this message translates to:
  /// **'메모 (선택)'**
  String get customEventMemoOptionalLabel;

  /// No description provided for @customEventMemoOptionalHint.
  ///
  /// In ko, this message translates to:
  /// **'필요한 내용만 짧게 남겨 주세요.'**
  String get customEventMemoOptionalHint;

  /// No description provided for @customEventMedicationHint.
  ///
  /// In ko, this message translates to:
  /// **'약을 기록하려는 경우에는 기본 ‘투약’에서 약 이름과 용량을 남길 수 있어요. 이 기록도 그대로 만들 수 있습니다.'**
  String get customEventMedicationHint;

  /// No description provided for @pinToQuickRecords.
  ///
  /// In ko, this message translates to:
  /// **'빠른 기록에 고정'**
  String get pinToQuickRecords;

  /// No description provided for @removeFromQuickRecords.
  ///
  /// In ko, this message translates to:
  /// **'빠른 기록에서 해제'**
  String get removeFromQuickRecords;

  /// No description provided for @renameCustomEvent.
  ///
  /// In ko, this message translates to:
  /// **'이름 변경'**
  String get renameCustomEvent;

  /// No description provided for @archiveCustomEvent.
  ///
  /// In ko, this message translates to:
  /// **'보관'**
  String get archiveCustomEvent;

  /// No description provided for @archiveCustomEventTitle.
  ///
  /// In ko, this message translates to:
  /// **'이 기록 종류를 보관할까요?'**
  String get archiveCustomEventTitle;

  /// No description provided for @archiveCustomEventDescription.
  ///
  /// In ko, this message translates to:
  /// **'‘{name}’은 나만의 기록에서 숨겨지지만 과거 기록은 그대로 유지됩니다.'**
  String archiveCustomEventDescription(String name);

  /// No description provided for @sleepStarted.
  ///
  /// In ko, this message translates to:
  /// **'수면 기록을 시작했어요.'**
  String get sleepStarted;

  /// No description provided for @sleepAlreadyActive.
  ///
  /// In ko, this message translates to:
  /// **'이미 진행 중인 수면이 있어요.'**
  String get sleepAlreadyActive;

  /// No description provided for @sleepInProgress.
  ///
  /// In ko, this message translates to:
  /// **'수면 중 · {duration}'**
  String sleepInProgress(String duration);

  /// No description provided for @sleepSince.
  ///
  /// In ko, this message translates to:
  /// **'{time}부터'**
  String sleepSince(String time);

  /// No description provided for @wakeUp.
  ///
  /// In ko, this message translates to:
  /// **'깨어났어요'**
  String get wakeUp;

  /// No description provided for @sleepEnded.
  ///
  /// In ko, this message translates to:
  /// **'수면 기록을 종료했어요.'**
  String get sleepEnded;

  /// No description provided for @undo.
  ///
  /// In ko, this message translates to:
  /// **'실행 취소'**
  String get undo;

  /// No description provided for @editStartTime.
  ///
  /// In ko, this message translates to:
  /// **'시작 시각 수정'**
  String get editStartTime;

  /// No description provided for @addSleepMarkers.
  ///
  /// In ko, this message translates to:
  /// **'상태 추가'**
  String get addSleepMarkers;

  /// No description provided for @sleepMarkersTitle.
  ///
  /// In ko, this message translates to:
  /// **'관찰한 수면 상태'**
  String get sleepMarkersTitle;

  /// No description provided for @sleepMarkersHint.
  ///
  /// In ko, this message translates to:
  /// **'여러 개를 선택할 수 있어요. 실제 수면 깊이를 측정한 값은 아닙니다.'**
  String get sleepMarkersHint;

  /// No description provided for @sleepMarkerRestful.
  ///
  /// In ko, this message translates to:
  /// **'푹 잠'**
  String get sleepMarkerRestful;

  /// No description provided for @sleepMarkerRestless.
  ///
  /// In ko, this message translates to:
  /// **'뒤척임'**
  String get sleepMarkerRestless;

  /// No description provided for @sleepMarkerWokeUp.
  ///
  /// In ko, this message translates to:
  /// **'중간에 깸'**
  String get sleepMarkerWokeUp;

  /// No description provided for @sleepMarkerFrequentWaking.
  ///
  /// In ko, this message translates to:
  /// **'자주 깸'**
  String get sleepMarkerFrequentWaking;

  /// No description provided for @sleepMarkersSaved.
  ///
  /// In ko, this message translates to:
  /// **'수면 상태를 저장했어요.'**
  String get sleepMarkersSaved;

  /// No description provided for @directSleepEntry.
  ///
  /// In ko, this message translates to:
  /// **'끝난 수면 직접 입력'**
  String get directSleepEntry;

  /// No description provided for @sleepStartTime.
  ///
  /// In ko, this message translates to:
  /// **'시작 시각'**
  String get sleepStartTime;

  /// No description provided for @sleepEndTime.
  ///
  /// In ko, this message translates to:
  /// **'종료 시각'**
  String get sleepEndTime;

  /// No description provided for @sleepKind.
  ///
  /// In ko, this message translates to:
  /// **'수면 구분'**
  String get sleepKind;

  /// No description provided for @sleepKindUnspecified.
  ///
  /// In ko, this message translates to:
  /// **'구분 안 함'**
  String get sleepKindUnspecified;

  /// No description provided for @sleepKindNap.
  ///
  /// In ko, this message translates to:
  /// **'낮잠'**
  String get sleepKindNap;

  /// No description provided for @sleepKindNight.
  ///
  /// In ko, this message translates to:
  /// **'밤잠'**
  String get sleepKindNight;

  /// No description provided for @sleepKindSuggested.
  ///
  /// In ko, this message translates to:
  /// **'시각을 기준으로 제안했어요. 필요하면 바꿀 수 있습니다.'**
  String get sleepKindSuggested;

  /// No description provided for @sleepNote.
  ///
  /// In ko, this message translates to:
  /// **'메모 (선택)'**
  String get sleepNote;

  /// No description provided for @sleepTimeInvalid.
  ///
  /// In ko, this message translates to:
  /// **'종료 시각은 시작 시각보다 늦어야 해요.'**
  String get sleepTimeInvalid;

  /// No description provided for @sleepFutureInvalid.
  ///
  /// In ko, this message translates to:
  /// **'끝난 수면은 미래 시각으로 저장할 수 없어요.'**
  String get sleepFutureInvalid;

  /// No description provided for @saveSleep.
  ///
  /// In ko, this message translates to:
  /// **'수면 기록 저장'**
  String get saveSleep;

  /// No description provided for @sleepDurationHoursMinutes.
  ///
  /// In ko, this message translates to:
  /// **'{hours}시간 {minutes}분'**
  String sleepDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @sleepDurationHours.
  ///
  /// In ko, this message translates to:
  /// **'{hours}시간'**
  String sleepDurationHours(int hours);

  /// No description provided for @sleepDurationMinutes.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분'**
  String sleepDurationMinutes(int minutes);

  /// No description provided for @sleepDurationLessThanMinute.
  ///
  /// In ko, this message translates to:
  /// **'1분 미만'**
  String get sleepDurationLessThanMinute;
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
      <String>['en', 'ja', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
