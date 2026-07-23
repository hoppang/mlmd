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
      'If left empty, the first line of the content becomes the title.';

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
  String get analyzeButton => 'Organize with AI';

  @override
  String get analyzingLabel => 'AI is organizing the record…';

  @override
  String get saveRecord => 'Save';

  @override
  String get aiUnavailableDescription =>
      'AI is currently unavailable. You can still save the original record.';

  @override
  String get aiAnalysisFailed =>
      'AI organization failed. Your original text is unchanged.';

  @override
  String get retryAiAnalysis => 'Retry AI organization';

  @override
  String get aiAnalysisApplied =>
      'AI results were applied. Your original text is still preserved.';

  @override
  String get previewSection => 'Analysis Preview';

  @override
  String get recordAction => 'Record';

  @override
  String get recordSheetTitle => 'What would you like to record?';

  @override
  String get quickRecordsTitle => 'Quick records';

  @override
  String get recentRecordsTitle => 'Recent';

  @override
  String get allCategoriesTitle => 'All categories';

  @override
  String get basicCareCategory => 'Basic care';

  @override
  String get healthMedicalCategory => 'Health · medical';

  @override
  String get activityPlayCategory => 'Activity · play';

  @override
  String get growthMemoryCategory => 'Growth · memories';

  @override
  String get feedingEvent => 'Feeding';

  @override
  String get mealEvent => 'Meal';

  @override
  String get waterSnackEvent => 'Water · snack';

  @override
  String get sleepEvent => 'Sleep';

  @override
  String get diaperEvent => 'Diaper · bowel';

  @override
  String get pumpingEvent => 'Pumping';

  @override
  String get temperatureEvent => 'Temperature';

  @override
  String get medicationEvent => 'Medication';

  @override
  String get symptomEvent => 'Symptom · condition';

  @override
  String get hospitalEvent => 'Hospital · consultation';

  @override
  String get vaccinationEvent => 'Vaccination';

  @override
  String get accidentInjuryEvent => 'Accident · injury';

  @override
  String get tummyTimeEvent => 'Tummy time';

  @override
  String get bathEvent => 'Bath';

  @override
  String get growthMeasurementEvent => 'Growth measurement';

  @override
  String get memoEvent => 'Memo';

  @override
  String get eventDetailOptionalLabel => 'Details (optional)';

  @override
  String get eventDetailOptionalHint =>
      'Add an amount, condition, or short note.';

  @override
  String get writeDetailedRecord => 'Long note and AI summary';

  @override
  String get backToRecordTypes => 'Back to record types';

  @override
  String get savingQuickRecord => 'Saving…';

  @override
  String get quickRecordSaveFailed =>
      'Could not save the record. Your input is still here.';

  @override
  String quickRecordSaved(String type) {
    return '$type saved.';
  }

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
  String get recordTimeLabel => 'Record time';

  @override
  String get eventTimeUnknown => 'Occurrence time unknown';

  @override
  String get clearEventTime => 'Clear occurrence time';

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
  String get todayTab => 'Today';

  @override
  String get dateTab => 'By Date';

  @override
  String get todayTimelineTitle => 'Today\'s Log';

  @override
  String get todayStatusTitle => 'Today\'s Status';

  @override
  String get startupLoading => 'Preparing app...';

  @override
  String get startupErrorTitle => 'A problem occurred during initialization';

  @override
  String get startupRetry => 'Retry';

  @override
  String get startupResetData => 'Reset All Data';

  @override
  String get startupResetConfirmMessage =>
      'Are you sure you want to delete all data and start over?\nThis action cannot be undone.';

  @override
  String get searchTab => 'Search';

  @override
  String get searchTitle => 'Search records';

  @override
  String get searchHint => 'Search notes or events.';

  @override
  String get searchAction => 'Search';

  @override
  String get searchIntroTitle => 'Find past records';

  @override
  String get searchIntroDescription =>
      'Search by note text or event names such as feeding and medication.';

  @override
  String searchResultCount(int count) {
    return '$count results';
  }

  @override
  String get searchNoResults => 'No matching records.';

  @override
  String get searchNoResultsHint =>
      'Your criteria are kept. Try a wider date range or remove one filter.';

  @override
  String get searchFailed =>
      'Search failed. Your original records are unchanged.';

  @override
  String get retrySearch => 'Search again';

  @override
  String get searchSortLabel => 'Sort';

  @override
  String get searchSortRelevance => 'Relevance';

  @override
  String get searchSortNewest => 'Newest';

  @override
  String get searchSortOldest => 'Oldest';

  @override
  String get searchMatchExact => 'Exact phrase match';

  @override
  String get searchMatchActivityType => 'Event type match';

  @override
  String get searchMatchRelated => 'Related expression';

  @override
  String get searchMatchTemperature => 'Temperature condition match';

  @override
  String get searchMatchAuthor => 'Author filter match';

  @override
  String get searchMatchEvent => 'Event filter match';

  @override
  String get searchMatchDate => 'Date filter match';

  @override
  String get searchFilters => 'Search filters';

  @override
  String get searchClearFilters => 'Clear filters';

  @override
  String get searchApplyFilters => 'Apply filters';

  @override
  String get searchDate => 'Date';

  @override
  String get searchAll => 'All';

  @override
  String get searchAllDates => 'All dates';

  @override
  String get searchToday => 'Today';

  @override
  String get searchLast7Days => 'Last 7 days';

  @override
  String get searchLast30Days => 'Last 30 days';

  @override
  String get searchCustomDate => 'Custom dates';

  @override
  String get searchEventType => 'Event type';

  @override
  String get searchAuthor => 'Author';

  @override
  String get searchTemperature => 'Temperature at least';

  @override
  String searchTemperatureAtLeast(String value) {
    return '$value°C or above';
  }

  @override
  String get searchEventTemperature => 'Temperature';

  @override
  String get searchEventMedication => 'Medication';

  @override
  String get searchEventFeeding => 'Feeding';

  @override
  String get searchEventDiaper => 'Diaper';

  @override
  String get searchEventSleep => 'Sleep';

  @override
  String get searchEventHospital => 'Hospital visit';

  @override
  String get searchSemanticUnavailable =>
      'Text and filter search remains available while semantic search is unavailable or indexing.';

  @override
  String get searchSameDayContext => 'Other records from the same day';

  @override
  String get searchSameDayContextHint =>
      'Shown as context only. This does not imply a cause or relationship.';

  @override
  String get searchMemoResult => 'Note';

  @override
  String get searchActivityResult => 'Event';

  @override
  String get searchReadOnly => 'Read only';

  @override
  String get searchResultDetail => 'Search result details';

  @override
  String get settings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsIntro =>
      'Manage only the essential information and ways to protect your data.';

  @override
  String get childInformation => 'Child information';

  @override
  String get childInformationDescription =>
      'Child details cannot be linked to records yet.';

  @override
  String get authorProfile => 'My name and color';

  @override
  String get authorProfileDescription =>
      'Manage the author name and color used for new records.';

  @override
  String get authorSetupTitle => 'Who records on this device?';

  @override
  String get authorSetupDescription =>
      'Choose a name and color your family will recognize. It does not need to be a real name and is applied to new records automatically.';

  @override
  String get authorNicknameLabel => 'Author name';

  @override
  String get authorNicknameHint => 'For example: Mum, Dad, Grandma';

  @override
  String get authorColorLabel => 'Personal color';

  @override
  String get authorSave => 'Start with this name';

  @override
  String get authorAdd => 'Add author';

  @override
  String get authorEdit => 'Edit author';

  @override
  String get authorProfilesTitle => 'Author profiles';

  @override
  String get authorCurrent => 'Current author';

  @override
  String get authorUseProfile => 'Switch to this author';

  @override
  String get authorNicknameError => 'Enter a name between 1 and 30 characters.';

  @override
  String get authorProfileLocalNotice =>
      'The current author is applied automatically. Switch only when several people use this device.';

  @override
  String get familySharing => 'Use with family';

  @override
  String get familySharingDescription =>
      'Records currently stay on this device.';

  @override
  String get dataBackupTitle => 'Data storage and backup';

  @override
  String get dataBackupDescription =>
      'Keep records in a file or import them safely.';

  @override
  String get helpTitle => 'Help';

  @override
  String get helpDescription =>
      'Learn why the app works this way and set its language.';

  @override
  String get notAvailableYetTitle => 'Not available yet';

  @override
  String notAvailableYetDescription(String feature) {
    return '$feature will be added after the required data model and safety rules are ready.';
  }

  @override
  String get storageSummaryTitle => 'Current backup coverage';

  @override
  String backupContentsSummary(int records, int activities, String size) {
    return '$records diaries · $activities activities\nEstimated file size $size';
  }

  @override
  String get backupPrivacyNotice =>
      'The current backup stores records and activities in an unencrypted JSON file. Attachments are not supported yet.';

  @override
  String get createBackupFile => 'Create backup file';

  @override
  String get createBackupDescription =>
      'Create a file containing this device\'s records and activities for safekeeping elsewhere.';

  @override
  String get importBackupFile => 'Import backup file';

  @override
  String get importBackupDescription =>
      'Review its contents and possible conflicts before anything is added.';

  @override
  String get recentlyDeleted => 'Recently deleted records';

  @override
  String get recentlyDeletedDescription =>
      'Recoverable deletion is not available yet.';

  @override
  String get helpIntro =>
      'This help explains why the app behaves as it does, not just where buttons are.';

  @override
  String get offlineHelpQuestion => 'Why can I record without the internet?';

  @override
  String get offlineHelpAnswer =>
      'Records are saved on this device first. You can keep writing and finding the original text even when the network or AI features are unavailable.';

  @override
  String get duplicateHelpQuestion =>
      'Why aren\'t imported records overwritten automatically?';

  @override
  String get duplicateHelpAnswer =>
      'When two versions differ, silently deleting either one is unsafe. For now, only new records are added and matching IDs are skipped.';

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

  @override
  String get dataManagement => 'Data Management';

  @override
  String get dataManagementDescription =>
      'Back up or restore all diaries and activities.';

  @override
  String get exportDiary => 'Export Diaries';

  @override
  String get importDiary => 'Import Diaries';

  @override
  String get exportWarningTitle => 'Export Plaintext Backup';

  @override
  String exportWarning(int count) {
    return 'The titles, summaries, content, and activities of $count diaries will be stored in an unencrypted file.';
  }

  @override
  String get exporting => 'Creating the backup file…';

  @override
  String get importing => 'Importing diaries…';

  @override
  String exportSuccess(int count, int version, String fileName) {
    return 'Exported $count diaries as a v$version backup.\n$fileName';
  }

  @override
  String get importPreviewTitle => 'Import Preview';

  @override
  String backupInfo(int version, String appVersion, String exportedAt) {
    return 'Backup v$version · App $appVersion\nCreated: $exportedAt';
  }

  @override
  String importCounts(int total, int activities) {
    return '$total diaries · $activities activities';
  }

  @override
  String get newRecords => 'New diaries';

  @override
  String get duplicateRecords => 'Duplicates';

  @override
  String get identicalRecords => 'Same content';

  @override
  String get conflictingRecords => 'Conflicts to review';

  @override
  String importDateRange(String from, String to) {
    return 'Record period: $from – $to';
  }

  @override
  String get safeImportNotice =>
      'Your current records are backed up automatically just before import. Existing records are not overwritten; only new records are added.';

  @override
  String get newerRecords => 'Update from newer backup';

  @override
  String get skippedRecords => 'Skipped';

  @override
  String get conflictPolicy => 'Duplicate handling';

  @override
  String get skipExisting => 'Skip existing diaries';

  @override
  String get overwriteIfNewer => 'Overwrite only when backup is newer';

  @override
  String get importAction => 'Import';

  @override
  String importResult(int inserted, int updated, int skipped) {
    return 'Added $inserted · Updated $updated · Skipped $skipped';
  }

  @override
  String embeddingFailed(int count) {
    return 'Search indexes for $count diaries must be regenerated later.';
  }

  @override
  String get transferError =>
      'The backup could not be processed. Check its format and available storage.';

  @override
  String get draftSaving => 'Saving draft…';

  @override
  String get draftSaved => 'Draft saved';

  @override
  String get draftSaveFailed => 'Draft could not be saved';

  @override
  String get draftSourceChanged =>
      'The original record changed after this draft was created. Review it before saving.';

  @override
  String get discardDraft => 'Discard draft';

  @override
  String get discardDraftTitle => 'Discard this draft?';

  @override
  String get discardDraftDescription =>
      'Your unfinished changes cannot be recovered.';

  @override
  String draftsInProgress(int count) {
    return '$count unfinished records';
  }

  @override
  String get continueWriting => 'Continue writing';

  @override
  String get startNewDraft => 'Start new';

  @override
  String recordCreatedBy(String nickname) {
    return 'Author $nickname';
  }

  @override
  String get recordSourceDetails => 'Record source';

  @override
  String recordSourceDevice(String deviceId) {
    return 'Input device $deviceId';
  }
}
