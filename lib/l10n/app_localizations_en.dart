// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'My Little Miracle\'s Diary';

  @override
  String get noDiaryTitle => 'No diaries written yet.';

  @override
  String get noDiaryDesc => 'Tap the + button below to write your first diary.';

  @override
  String get newDiary => 'New Diary';

  @override
  String get editDiary => 'Edit Diary';

  @override
  String get titleLabel => 'Title (Optional)';

  @override
  String get titleHint =>
      'If left empty, AI will automatically generate a title.';

  @override
  String get contentLabel => 'Content (Original)';

  @override
  String get contentHint => 'How was your day? Feel free to write anything.';

  @override
  String get summaryLabel => 'Summary';

  @override
  String get summaryHint => 'Summarize today in 1-3 sentences.';

  @override
  String get simpleModeLabel => 'Quick Input';

  @override
  String get manualModeLabel => 'Manual Input';

  @override
  String get analyzeButton => 'AI Analyze';

  @override
  String get analyzingLabel => 'AI is analyzing…';

  @override
  String get previewSection => 'Analysis Preview';

  @override
  String get addEventButton => 'Add Event';

  @override
  String get eventTypeLabel => 'Type';

  @override
  String get eventTypeHint => 'e.g. Feeding, Sleep, Hospital';

  @override
  String get eventDetailLabel => 'Detail';

  @override
  String get eventDetailHint => 'e.g. [7, 9, 11] AM, Pediatrician evening';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get edit => 'Edit';

  @override
  String get diaryAdded => 'A new diary has been added.';

  @override
  String get diaryUpdated => 'The diary has been updated.';

  @override
  String get diaryDeleted => 'The diary has been deleted.';

  @override
  String get deleteConfirmTitle => 'Delete Diary';

  @override
  String get deleteConfirmDesc =>
      'Are you sure you want to delete this diary? This action cannot be undone.';

  @override
  String get searchHint => 'Search past records.';

  @override
  String similarCount(int count) {
    return '$count similar diaries';
  }

  @override
  String get noSimilarDiary => 'No similar diaries found.';

  @override
  String get settings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get languageSetting => 'Language';

  @override
  String get languageSystem => 'System Default';

  @override
  String get languageKorean => '한국어(Korean)';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語(Japanese)';

  @override
  String get close => 'Close';

  @override
  String get llmModelError => 'Model file not found. AI analysis is disabled.';
}
