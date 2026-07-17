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
  /// **'비워두면 AI가 자동으로 제목을 생성합니다.'**
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
  /// **'AI 분석'**
  String get analyzeButton;

  /// No description provided for @analyzingLabel.
  ///
  /// In ko, this message translates to:
  /// **'AI가 분석 중입니다…'**
  String get analyzingLabel;

  /// No description provided for @previewSection.
  ///
  /// In ko, this message translates to:
  /// **'분석 결과 미리보기'**
  String get previewSection;

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

  /// No description provided for @searchHint.
  ///
  /// In ko, this message translates to:
  /// **'지난 기록을 찾아봅니다.'**
  String get searchHint;

  /// No description provided for @similarCount.
  ///
  /// In ko, this message translates to:
  /// **'유사한 일기 {count}건'**
  String similarCount(int count);

  /// No description provided for @noSimilarDiary.
  ///
  /// In ko, this message translates to:
  /// **'유사한 일기가 없습니다.'**
  String get noSimilarDiary;

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
