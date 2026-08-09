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
  String get waterEvent => 'Water';

  @override
  String get snackEvent => 'Snack';

  @override
  String get feedingMethodLabel => 'Feeding method';

  @override
  String get breastFeedingOption => 'Breast';

  @override
  String get bottleFeedingOption => 'Bottle';

  @override
  String get feedingTimeOnlyOption => 'Time only';

  @override
  String get breastSideLabel => 'Breast side';

  @override
  String get leftSideOption => 'Left';

  @override
  String get rightSideOption => 'Right';

  @override
  String get bothSidesOption => 'Both';

  @override
  String get pumpingSideLabel => 'Pumping side';

  @override
  String get pumpingAmountLabel => 'Pumping amount (optional)';

  @override
  String get pumpingAmountHint => 'Enter mL';

  @override
  String get savePumping => 'Save Pumping Record';

  @override
  String get saveBathRecord => 'Save Bath Record';

  @override
  String get bathOneTouchHint =>
      'One-touch bath record · Save instantly with current time without detailed status or duration timers.';

  @override
  String get bathFormTitle => 'Bath Record';

  @override
  String get bottleContentsLabel => 'Bottle contents';

  @override
  String get formulaOption => 'Formula';

  @override
  String get expressedMilkOption => 'Expressed milk';

  @override
  String get expressedMilkFeedingOption => 'Expressed milk feeding';

  @override
  String get feedingChooseType => 'Choose feeding type';

  @override
  String get otherOption => 'Other';

  @override
  String get amountStyleLabel => 'Amount eaten';

  @override
  String get qualitativeAmountOption => 'By impression';

  @override
  String get fractionAmountOption => 'Of amount served';

  @override
  String get exactAmountOption => 'Exact amount';

  @override
  String get sipAmountOption => 'A sip';

  @override
  String get biteAmountOption => 'Just tasted';

  @override
  String get littleAmountOption => 'A little';

  @override
  String get normalAmountOption => 'Average';

  @override
  String get muchAmountOption => 'A lot';

  @override
  String get quarterAmountOption => '¼';

  @override
  String get halfAmountOption => 'Half';

  @override
  String get almostAllAmountOption => 'Almost all';

  @override
  String get allAmountOption => 'All';

  @override
  String get exactAmountLabel => 'Amount';

  @override
  String get amountUnitLabel => 'Unit';

  @override
  String get mealTypeLabel => 'Meal';

  @override
  String get breakfastOption => 'Breakfast';

  @override
  String get lunchOption => 'Lunch';

  @override
  String get dinnerOption => 'Dinner';

  @override
  String get foodNameLabel => 'Food (optional)';

  @override
  String get snackNameLabel => 'Snack (optional)';

  @override
  String get reactionLabel => 'Reaction (optional)';

  @override
  String get ateWellOption => 'Ate well';

  @override
  String get averageReactionOption => 'Average';

  @override
  String get refusedOption => 'Refused';

  @override
  String get memoOptionalLabel => 'Note (optional)';

  @override
  String get cupAmountOption => 'By cup';

  @override
  String get cupAmountInfoTitle => 'About cup amounts';

  @override
  String get cupAmountInfoBody =>
      'Baby cups vary by product, but many are around 200 mL. Cup amounts are approximate and are not converted to exact mL.';

  @override
  String get exactAmountRequired => 'Enter an amount greater than zero.';

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
  String get doctorNotesLabel => 'Doctor\'s notes (optional)';

  @override
  String get doctorNotesHint =>
      'Add notes about diagnosis, prescription, or home care.';

  @override
  String get prescriptionBagButton => 'Prescription Bag Photo';

  @override
  String get attachFileButton => 'Attach File';

  @override
  String get hospitalVisitTime => 'Visit Time';

  @override
  String get attachmentPrescriptionBag => 'Prescription Bag';

  @override
  String get attachmentGeneral => 'Attachment';

  @override
  String get vaccinationEvent => 'Vaccination';

  @override
  String get vaccinationTime => 'Vaccination Time';

  @override
  String get vaccinationNotesLabel => 'Vaccination Notes (Optional)';

  @override
  String get vaccinationNotesHint =>
      'Note vaccine name, clinic, or other details.';

  @override
  String get vaccinationBookButton => 'Vaccination Record Photo';

  @override
  String get attachmentVaccinationRecord => 'Vaccination Record';

  @override
  String get checkKdcaVaccinationHistory => 'Check Vaccination History on KDCA';

  @override
  String get kdcaVaccinationNotice =>
      'Does not automatically sync with national databases; stores entered facts and photos locally.';

  @override
  String get accidentInjuryEvent => 'Accident · injury';

  @override
  String get accidentCategoryLabel => 'Accident Category';

  @override
  String get accidentCategoryTraumatic => 'Traumatic (Wound/Injury)';

  @override
  String get accidentCategoryNonTraumatic =>
      'Non-Traumatic (Ingestion/Choking)';

  @override
  String get accidentInjuryTypeLabel => 'Detail Type';

  @override
  String get injuryTypeBumpBruise => 'Bump / Bruise';

  @override
  String get injuryTypeScratchWound => 'Cut / Scratch';

  @override
  String get injuryTypeFallTrip => 'Fall / Trip';

  @override
  String get injuryTypeBurn => 'Burn';

  @override
  String get injuryTypeBiteSting => 'Bite / Sting';

  @override
  String get injuryTypeOtherTrauma => 'Other Trauma';

  @override
  String get injuryTypeForeignIngestion => 'Foreign Object Ingestion';

  @override
  String get injuryTypeChokingAspiration => 'Choking / Aspiration';

  @override
  String get injuryTypeEyeEarForeignObject => 'Eye / Ear Foreign Object';

  @override
  String get injuryTypePoisoningChemical => 'Poisoning / Chemical';

  @override
  String get injuryTypeHeatColdInjury => 'Heat Stroke / Hypothermia';

  @override
  String get injuryTypeOtherNonTrauma => 'Other Non-Trauma';

  @override
  String get accidentTime => 'Accident Time';

  @override
  String get accidentNotesLabel => 'Situation & Action Note (Optional)';

  @override
  String get accidentNotesHint =>
      'Record accident context, observations, or first aid actions.';

  @override
  String get accidentPhotoAttachmentButton => 'Attach Injury/Situation Photo';

  @override
  String get accidentGuidanceAttentionTitle => 'Attention Required Accident';

  @override
  String get accidentGuidanceFirstAidInfo =>
      'For falls, burns, foreign body ingestion, choking, or poisoning, closely monitor the child and visit an emergency department or doctor if needed.';

  @override
  String get careProcedureEvent => 'Care procedure';

  @override
  String get careProcedureTime => 'Procedure time';

  @override
  String get careProcedureScopeHelp =>
      'Record only non-medication care already performed at home. If it involves ointment, eye drops, inhaled medicine, or another medication, record it as medication.';

  @override
  String get careProcedureTypeLabel => 'Procedure type';

  @override
  String get procedureTypeNasalCare => 'Nasal rinse · suction';

  @override
  String get procedureTypeWoundCare => 'Wound cleaning · dressing';

  @override
  String get procedureTypeHotColdPack => 'Cold · warm pack';

  @override
  String get procedureTypeRespiratoryCare => 'Respiratory care';

  @override
  String get procedureTypeOther => 'Other';

  @override
  String get careProcedureBodyAreaLabel => 'Body area (optional)';

  @override
  String get careProcedureBodyAreaHint => 'For example, left knee';

  @override
  String get careProcedureNoteLabel => 'Note (optional)';

  @override
  String get careProcedureOtherNoteLabel => 'What did you do?';

  @override
  String get careProcedureNoteHint =>
      'Briefly describe the care that was performed.';

  @override
  String get careProcedureTypeRequired => 'Select a procedure type.';

  @override
  String get careProcedureOtherRequired =>
      'Describe what was done for the other procedure.';

  @override
  String get careProcedurePhotoButton => 'Attach photo';

  @override
  String get tummyTimeEvent => 'Tummy time';

  @override
  String get tummyTimeFormTitle => 'Tummy Time';

  @override
  String get tummyTimeDurationLabel => 'Duration (optional)';

  @override
  String get tummyTimeDurationHint => 'Enter minutes (e.g. 5)';

  @override
  String tummyTimeDurationDisplay(int minutes) {
    return '$minutes min';
  }

  @override
  String get tummyTimeDurationInvalidError =>
      'Enter a number between 1 and 999.';

  @override
  String get tummyTimeInfantRecommendation =>
      'Tummy time helps strengthen neck, shoulder, and back muscles. Short sessions of 3–5 minutes, 2–3 times a day are recommended for young infants.';

  @override
  String get tummyTimeInfantRecommendationSource =>
      'Based on general early-childhood guidance. Consult your pediatrician for your child\'s situation.';

  @override
  String get saveTummyTimeRecord => 'Save Tummy Time';

  @override
  String get growthMeasurementFormTitle => 'Growth measurement';

  @override
  String get growthMeasurementHeightLabel => 'Height (optional)';

  @override
  String get growthMeasurementHeightHint => 'Enter cm (e.g. 55.0)';

  @override
  String get growthMeasurementWeightLabel => 'Weight (optional)';

  @override
  String get growthMeasurementWeightHint => 'Enter kg (e.g. 6.50)';

  @override
  String get growthMeasurementHeadLabel => 'Head circumference (optional)';

  @override
  String get growthMeasurementHeadHint => 'Enter cm (e.g. 38.0)';

  @override
  String get growthMeasurementAtLeastOneError =>
      'Enter at least one of height, weight, or head circumference.';

  @override
  String growthMeasurementHeightDisplay(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString cm';
  }

  @override
  String growthMeasurementWeightDisplay(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 2,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString kg';
  }

  @override
  String growthMeasurementHeadDisplay(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString cm';
  }

  @override
  String get saveGrowthMeasurementRecord => 'Save growth measurement';

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
  String get dailyAiSummary => 'AI daily recap';

  @override
  String get weeklyAiSummary => 'AI weekly recap';

  @override
  String get summarizeDay => 'Recap this day';

  @override
  String get summarizeWeek => 'Recap this week';

  @override
  String get summarizeWeekSoFar => 'Recap the week so far';

  @override
  String get summaryGenerating => 'Creating a recap from the original records…';

  @override
  String get summaryUnavailable =>
      'AI recap is unavailable. Your original records and calculated counts remain available.';

  @override
  String get summaryFailed =>
      'The recap could not be created. Your original records are unchanged.';

  @override
  String get summaryNoRecords => 'There are no original records to recap.';

  @override
  String summaryBasis(int count, String time) {
    return 'Based on $count original records through $time';
  }

  @override
  String get summaryNewRecords => 'There are new records since this recap.';

  @override
  String get summarySourceChanged =>
      'An original record used by this recap has changed.';

  @override
  String get summaryEdited => 'Edited manually';

  @override
  String get summaryEvidence => 'View source records';

  @override
  String get summaryEvidenceTitle => 'Original records used';

  @override
  String get summaryEditTitle => 'Edit recap';

  @override
  String get summaryHide => 'Hide';

  @override
  String get summaryRestore => 'Show recap';

  @override
  String get summaryRegenerate => 'Create again';

  @override
  String get summaryPreviewTitle => 'Review the new recap';

  @override
  String get summaryReplace => 'Replace recap';

  @override
  String get weeklyAutoSummary => 'Automatic weekly AI recap';

  @override
  String get weeklyAutoSummaryDescription =>
      'Quietly prepare a recap after a Monday–Sunday week ends, using the on-device AI model.';

  @override
  String get medicalBriefingTitle => 'Visit briefing';

  @override
  String get medicalBriefingDescription =>
      'Review recorded temperatures, medications, symptoms, visits, vaccinations, and injuries before a medical visit.';

  @override
  String get briefingSafetyNotice =>
      'This shows recorded facts only. It does not provide a diagnosis, causal conclusion, or treatment advice. Verify important details in the original records.';

  @override
  String get briefingPeriod => 'Briefing period';

  @override
  String briefingDateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String briefingFactCount(int count) {
    return '$count recorded facts';
  }

  @override
  String get briefingNoFacts => 'No matching health records.';

  @override
  String get briefingNoFactsHint =>
      'Keep this period or choose a wider range. General notes and non-health events are not inferred as medical facts.';

  @override
  String get briefingCopy => 'Copy briefing';

  @override
  String get briefingCopied => 'The briefing was copied.';

  @override
  String get briefingShare => 'Share briefing';

  @override
  String get briefingOpenOriginal => 'Open original record';

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
  String get familySharingIntro =>
      'When caregivers use MLMD together, everyone can see each other\'s records and care tasks automatically.';

  @override
  String get familySharingNotConnectedTitle =>
      'You are currently using MLMD on your own';

  @override
  String get familySharingNotConnectedDescription =>
      'Records on this device stay available while a secure account and invitation flow is being connected.';

  @override
  String get familySharingLocalFirstTitle =>
      'Keep recording without the internet';

  @override
  String get familySharingLocalFirstDescription =>
      'Every change is saved on this device first, so pending changes are not lost when the connection is unavailable.';

  @override
  String get familySharingTextOnlyTitle =>
      'Original photos stay on this device';

  @override
  String get familySharingTextOnlyDescription =>
      'Family sharing includes text records and attachment type and count, but not the photo or file itself.';

  @override
  String familySharingPending(int count) {
    return '$count changes waiting to reach your family';
  }

  @override
  String familySharingConflicts(int count) {
    return '$count conflicts need review';
  }

  @override
  String get familySharingNeverReceived =>
      'No family records have been received yet';

  @override
  String familySharingLastReceived(String date, String time) {
    return 'Last family records received: $date $time';
  }

  @override
  String get familySharingOfflineNotice =>
      'Changes will be applied automatically when you are online.';

  @override
  String get homeServerConnectTitle => 'Connect a home server';

  @override
  String get homeServerConnectDescription =>
      'Enter the address of the home server on your local network and the setup token shown in its console.';

  @override
  String get homeServerUrlLabel => 'Home server address';

  @override
  String get homeServerInvalidUrl =>
      'Enter a home server address beginning with http or https.';

  @override
  String get homeServerBootstrapTokenLabel => 'Setup token';

  @override
  String get homeServerFamilyNameLabel => 'Family space name';

  @override
  String get homeServerDeviceNameLabel => 'Name of this device';

  @override
  String get homeServerRequiredField => 'This field is required.';

  @override
  String get homeServerConnectAction => 'Connect a new home server';

  @override
  String get homeServerJoinTitle => 'Join a family space';

  @override
  String get homeServerJoinDescription =>
      'Name this device, then scan the QR code shown on a device that is already connected.';

  @override
  String get homeServerCameraError =>
      'The camera is unavailable. Check the camera permission.';

  @override
  String get homeServerQrSecurityNotice =>
      'This QR contains the encryption key for your family records. Do not capture or share it.';

  @override
  String homeServerJoinConfirm(String host) {
    return 'Join this family space on the $host server?';
  }

  @override
  String get homeServerJoinAction => 'Join with QR';

  @override
  String get homeServerInvalidQr =>
      'This is not a valid invitation QR from this app.';

  @override
  String get homeServerInviteTitle => 'Invite a device';

  @override
  String get homeServerInviteDescription =>
      'Scan this QR directly on the device you want to add. The invitation expires in 10 minutes.';

  @override
  String get homeServerInviteQrSemantics =>
      'Family space device invitation QR code';

  @override
  String get homeServerInviteExpired =>
      'This invitation has expired. Create a new one on a connected device.';

  @override
  String get homeServerDeviceNameRequired =>
      'Name this device before scanning the QR.';

  @override
  String get homeServerUnavailable =>
      'The home server is unavailable. Check that you are on the same network and try again.';

  @override
  String get homeServerPairingFailed =>
      'The home server connection could not be completed. Check the address and invitation status.';

  @override
  String get homeServerCreateInviteAction => 'Invite a new device';

  @override
  String get homeServerManageDevicesAction => 'Manage connected devices';

  @override
  String get homeServerDevicesTitle => 'Connected devices';

  @override
  String get homeServerDevicesRefresh => 'Refresh';

  @override
  String get homeServerDevicesOwnerOnly =>
      'Only a family space owner can view and revoke devices.';

  @override
  String get homeServerDevicesLoadFailed =>
      'The device list could not be loaded. Check the home server connection.';

  @override
  String get homeServerDeviceRevokeAction => 'Revoke device';

  @override
  String get homeServerDeviceRoleOwner => 'Owner';

  @override
  String get homeServerDeviceRoleMember => 'Family member';

  @override
  String get homeServerDeviceRevoked => 'Revoked';

  @override
  String get homeServerDeviceCurrent => 'This device';

  @override
  String get homeServerDeviceNeverSeen => 'Has not synchronized yet';

  @override
  String homeServerDeviceLastSeen(String date, String time) {
    return 'Last connected: $date $time';
  }

  @override
  String get homeServerDeviceRevokeTitle => 'Revoke this device?';

  @override
  String homeServerDeviceRevokeConfirm(String name) {
    return '$name will no longer send or receive new family records. Records and the family key already received by that device cannot be erased remotely.';
  }

  @override
  String get homeServerDeviceRevokedSuccess => 'The device was revoked.';

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
      'Backups are unencrypted. Keep files with attachments in a private, safe location.';

  @override
  String get createBackupFile => 'Create backup file';

  @override
  String get createBackupDescription =>
      'Choose how much attachment data to preserve. Original attachments are the safest default for recovery.';

  @override
  String get backupModeOriginal => 'Records and original attachments';

  @override
  String get backupModeOriginalDescription =>
      'Best for recovery. Uses the most storage.';

  @override
  String get backupModeReduced => 'Records and smaller attachments';

  @override
  String get backupModeReducedDescription =>
      'Uses optimized images when available. Protected documents keep original quality.';

  @override
  String get backupModeRecordsOnly => 'Records only';

  @override
  String get backupModeRecordsOnlyDescription =>
      'Smallest file. Photos and files cannot be restored from it.';

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
  String get photoSyncHelpQuestion =>
      'Why don\'t photos appear on another device?';

  @override
  String get photoSyncHelpAnswer =>
      'Family sharing focuses on text records first, so photos stay on the device where they were attached. Include original attachments in a backup file to keep an independent copy.';

  @override
  String get missingDataHelpQuestion =>
      'Why doesn\'t a sparse day mean “less than usual”?';

  @override
  String get missingDataHelpAnswer =>
      'A missing record may mean it was not entered, not that less happened. MLMD avoids judging incomplete days as real decreases.';

  @override
  String get quietNotificationHelpQuestion =>
      'Why are task reminders quiet by default?';

  @override
  String get quietNotificationHelpAnswer =>
      'Care reminders should help without unexpectedly waking a child or family. You can choose an audible alert when creating a task that needs one.';

  @override
  String get aiSummaryHelpQuestion => 'What does an AI summary use?';

  @override
  String get aiSummaryHelpAnswer =>
      'It uses the records selected for that period and remains a derived summary, not a medical judgment. Your original records stay available.';

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
  String exportBackupPreview(
    int records,
    int attachments,
    String size,
    int missing,
  ) {
    return '$records diaries · $attachments attachments\nEstimated file size $size\nUnavailable attachments: $missing\nThis backup is not encrypted.';
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
  String get attachmentsToImport => 'Attachments on this device';

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

  @override
  String get duplicateReviewTitle => 'Records to review';

  @override
  String get duplicateReviewDescription =>
      'Compare originals saved at the same time with the same content on different devices. Nothing is merged or deleted before you decide.';

  @override
  String duplicateReviewBanner(int count) {
    return '$count records to review';
  }

  @override
  String get duplicateReviewBannerHint =>
      'Check whether these are the same event.';

  @override
  String duplicatePendingCount(int count) {
    return '$count awaiting review';
  }

  @override
  String get duplicateResolvedTitle => 'Reviewed records';

  @override
  String get duplicateNeedsReview => 'Two similar records';

  @override
  String get duplicateExactReason =>
      'The type, time, and content match, but the input devices differ.';

  @override
  String duplicateUseSource(int number) {
    return 'Show as one event using #$number';
  }

  @override
  String get duplicateMarkDistinct => '#1 and #2 are separate events';

  @override
  String get duplicateReviewLater => 'Review later';

  @override
  String get duplicateSameEvent => 'Confirmed as the same event';

  @override
  String get duplicateDistinctEvents => 'Confirmed as separate events';

  @override
  String get duplicateDecisionSaved =>
      'Decision saved. The original records remain unchanged.';

  @override
  String get duplicateChangeDecision => 'Change duplicate decision';

  @override
  String get duplicateReviewEmpty => 'No records to review';

  @override
  String get duplicateReviewEmptyHint => 'New candidates will appear on Today.';

  @override
  String get myRecordsTitle => 'My records';

  @override
  String get createCustomEvent => 'Create a record';

  @override
  String get customEventNameLabel => 'Record name';

  @override
  String get customEventNameHint => 'For example, vitamins or walk prep';

  @override
  String get customEventNameRequired => 'Enter a name.';

  @override
  String get customEventMemoOptionalLabel => 'Memo (optional)';

  @override
  String get customEventMemoOptionalHint =>
      'Add only the details you want to remember.';

  @override
  String get customEventMedicationHint =>
      'For medicine, the built-in Medication record can store its name and dose. You can still create this record.';

  @override
  String get pinToQuickRecords => 'Pin to quick records';

  @override
  String get removeFromQuickRecords => 'Remove from quick records';

  @override
  String get renameCustomEvent => 'Rename';

  @override
  String get archiveCustomEvent => 'Archive';

  @override
  String get archiveCustomEventTitle => 'Archive this record type?';

  @override
  String archiveCustomEventDescription(String name) {
    return '“$name” will be hidden from My records. Past records will remain unchanged.';
  }

  @override
  String get sleepStarted => 'Sleep tracking started.';

  @override
  String get sleepAlreadyActive => 'A sleep session is already in progress.';

  @override
  String sleepInProgress(String duration) {
    return 'Sleeping · $duration';
  }

  @override
  String sleepSince(String time) {
    return 'Since $time';
  }

  @override
  String get wakeUp => 'Woke up';

  @override
  String get sleepEnded => 'Sleep tracking ended.';

  @override
  String get undo => 'Undo';

  @override
  String get editStartTime => 'Edit start time';

  @override
  String get sleepDateYesterday => 'Yesterday';

  @override
  String get sleepDateOther => 'Other date';

  @override
  String sleepAdjustEarlier(int minutes) {
    return 'Move $minutes minutes earlier';
  }

  @override
  String sleepAdjustLater(int minutes) {
    return 'Move $minutes minutes later';
  }

  @override
  String get addSleepMarkers => 'Add observations';

  @override
  String get sleepMarkersTitle => 'Observed sleep';

  @override
  String get sleepMarkersHint =>
      'Select any that apply. These are observations, not measured sleep depth.';

  @override
  String get sleepMarkerRestful => 'Slept well';

  @override
  String get sleepMarkerRestless => 'Restless';

  @override
  String get sleepMarkerWokeUp => 'Woke during sleep';

  @override
  String get sleepMarkerFrequentWaking => 'Woke often';

  @override
  String get sleepMarkersSaved => 'Sleep observations saved.';

  @override
  String get directSleepEntry => 'Enter completed sleep';

  @override
  String get sleepStartTime => 'Start time';

  @override
  String get sleepEndTime => 'End time';

  @override
  String get sleepKind => 'Sleep type';

  @override
  String get sleepKindUnspecified => 'Not specified';

  @override
  String get sleepKindNap => 'Nap';

  @override
  String get sleepKindNight => 'Night sleep';

  @override
  String get sleepKindSuggested =>
      'Suggested from the time. You can change it.';

  @override
  String get sleepNote => 'Note (optional)';

  @override
  String get sleepTimeInvalid => 'The end time must be after the start time.';

  @override
  String get sleepFutureInvalid => 'Completed sleep cannot end in the future.';

  @override
  String get saveSleep => 'Save sleep';

  @override
  String sleepDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String sleepDurationHours(int hours) {
    return '${hours}h';
  }

  @override
  String sleepDurationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String get sleepDurationLessThanMinute => 'Less than 1m';

  @override
  String get eliminationUrineAction => 'Wet diaper';

  @override
  String get eliminationStoolAction => 'Bowel movement';

  @override
  String get eliminationBothAction => 'Wet diaper and bowel movement';

  @override
  String get eliminationUrinePreset => 'Diaper · urine';

  @override
  String get eliminationStoolPreset => 'Diaper · stool';

  @override
  String get eliminationBothPreset => 'Diaper · urine + stool';

  @override
  String get eliminationUrineDetail => 'Urine';

  @override
  String get eliminationStoolDetail => 'Stool';

  @override
  String get eliminationBothDetail => 'Urine + stool';

  @override
  String get eliminationKindTitle => 'What was recorded';

  @override
  String get eliminationSavedHint =>
      'Saved at the current time. You can add only the details you need or correct the type now.';

  @override
  String get eliminationOptionalDetailsTitle => 'Optional details';

  @override
  String get eliminationAmountTitle => 'Amount';

  @override
  String get eliminationAmountLittle => 'A little';

  @override
  String get eliminationAmountNormal => 'Medium';

  @override
  String get eliminationAmountMuch => 'A lot';

  @override
  String get stoolConsistencyTitle => 'Consistency';

  @override
  String get stoolConsistencyLoose => 'Loose';

  @override
  String get stoolConsistencyNormal => 'Normal';

  @override
  String get stoolConsistencyHard => 'Hard';

  @override
  String get stoolColorTitle => 'Color';

  @override
  String get stoolColorYellow => 'Yellow';

  @override
  String get stoolColorBrown => 'Brown';

  @override
  String get stoolColorGreen => 'Green';

  @override
  String get stoolColorBlack => 'Black';

  @override
  String get stoolColorOther => 'Other';

  @override
  String get eliminationObservationHint =>
      'The app stores observations only and does not infer an illness or cause.';

  @override
  String get saveEliminationChanges => 'Save changes';

  @override
  String get eliminationChangesSaved => 'Diaper and bowel details saved.';

  @override
  String get temperatureValueLabel => 'Temperature';

  @override
  String get temperatureValueRequired => 'Enter a numeric temperature.';

  @override
  String get temperatureSiteLabel => 'Measurement site (optional)';

  @override
  String get temperatureSiteAxillary => 'Armpit';

  @override
  String get temperatureSiteEar => 'Ear';

  @override
  String get temperatureSiteForehead => 'Forehead';

  @override
  String get temperatureSiteRectal => 'Rectal';

  @override
  String get temperatureSiteOther => 'Other';

  @override
  String get temperatureNoteLabel => 'Note (optional)';

  @override
  String get medicalAttentionRequired => 'Needs attention';

  @override
  String get relatedOfficialGuidance => 'Related official guidance';

  @override
  String officialGuidanceMatchReason(String reason) {
    return 'Matched condition · $reason';
  }

  @override
  String get openInSystemBrowser => 'Open in system browser';

  @override
  String get officialGuidanceOpenFailed =>
      'Could not open the official guidance. This record remains open.';

  @override
  String get officialGuidanceDisclaimer =>
      'This external resource was reviewed and registered by the developer. The app does not make a diagnosis or treatment decision.';

  @override
  String get ingredientCheckRequired => 'Ingredient check required';

  @override
  String get medicationTypeTitle => 'Medication type';

  @override
  String get medicationCategoryAntipyretic => 'Antipyretic';

  @override
  String get medicationCategoryCoughCold => 'Cough & Cold';

  @override
  String get medicationCategoryAntibiotic => 'Antibiotic';

  @override
  String get medicationCategoryOintment => 'Ointment / Cream';

  @override
  String get medicationCategoryEyeEarNose => 'Eye / Ear / Nose Drops';

  @override
  String get medicationCategoryOther => 'Other';

  @override
  String get antipyreticIngredientTitle => 'Active ingredient';

  @override
  String get ingredientAcetaminophen => 'Acetaminophen';

  @override
  String get ingredientIbuprofen => 'Ibuprofen';

  @override
  String get ingredientOther => 'Other';

  @override
  String get ingredientUnknown => 'Unknown';

  @override
  String get medicationRouteTitle => 'Administration route';

  @override
  String get medicationRouteOral => 'Oral';

  @override
  String get medicationRouteSuppository => 'Suppository';

  @override
  String get medicationRouteTopical => 'Topical';

  @override
  String get medicationRouteInhaled => 'Inhaled';

  @override
  String get medicationRouteOther => 'Other';

  @override
  String get medicationAmountLabel => 'Dose and unit (optional)';

  @override
  String get medicationSiteLabel => 'Application site (optional)';

  @override
  String get antipyreticDupSameIngredientPrompt =>
      'Please check if this is a duplicate entry of the same medication.';

  @override
  String get antipyreticDupDiffIngredientPrompt =>
      'There is another antipyretic record with a different active ingredient nearby.';

  @override
  String get antipyreticDupUnknownIngredientPrompt =>
      'Please check the ingredient to compare with previous records.';

  @override
  String get antipyreticDupSameEventAction => 'Same medication record';

  @override
  String get antipyreticDupDistinctEventAction => 'Given separately';

  @override
  String get antipyreticDupDeferAction => 'Not sure right now';

  @override
  String get antipyreticDuplicateReviewTitle =>
      'Check Duplicate or Alternating Antipyretics';

  @override
  String get sttNoticeTitle => 'Check Before Voice Input';

  @override
  String get sttNoticeBody =>
      'What you say may include your child\'s health or medication details.\n\nDepending on your device speech recognition service, audio might be sent to an external server. This app cannot guarantee where processing occurs.\n\nPlease check your speech recognition service settings and privacy policy. Use voice input only if you accept external server transmission or confirm local processing.\n\nIf unsure, please type with the keyboard.';

  @override
  String get sttNoticeAcceptAction => 'Understood and Use';

  @override
  String get sttNoticeKeyboardAction => 'Type with Keyboard';

  @override
  String get sttListeningStatus => 'Listening to voice...';

  @override
  String get sttStopAction => 'Stop voice input';

  @override
  String get sttMicButtonTooltip => 'Voice note input';

  @override
  String get sttNotSupportedTooltip =>
      'Voice input is not supported in the current environment';

  @override
  String get pastNoticesTitle => 'Previously Viewed Notices';

  @override
  String get pastNoticeSttTitle => 'Android Voice Input & Privacy Notice';

  @override
  String pastNoticeStatusAccepted(String date) {
    return 'Confirmed · $date';
  }

  @override
  String get pastNoticeStatusNotAccepted => 'Not confirmed';

  @override
  String get recheckNoticeAction => 'View Notice Again';

  @override
  String get trackingPreferencesTitle => 'Tracking style';

  @override
  String get trackingPreferencesDescription =>
      'Choose detailed, daily, notable-only, or hidden for each item';

  @override
  String get trackingPreferencesIntro =>
      'Choose how each item should be tracked as your child grows. Records from different tracking styles are not compared directly.';

  @override
  String trackingModeFor(String eventName) {
    return 'Tracking style for $eventName';
  }

  @override
  String get trackingModeDetailed => 'Record every detail';

  @override
  String get trackingModeDailyCheckIn => 'One daily check-in';

  @override
  String get trackingModeNotableOnly => 'Only when notable';

  @override
  String get trackingModeHidden => 'Hide from quick records';

  @override
  String get trackingModeDetailedDescription =>
      'Keep individual records and compare only sufficiently complete days.';

  @override
  String get trackingModeDailyCheckInDescription =>
      'Record usual, less, or more with an optional note once a day.';

  @override
  String get trackingModeNotableOnlyDescription =>
      'A day without a record is not treated as normal or zero.';

  @override
  String get trackingModeHiddenDescription =>
      'Hide only from quick entry and keep all past records.';

  @override
  String dailyTrackingCheckInTitle(String eventName) {
    return 'Today\'s $eventName check-in';
  }

  @override
  String get trackingRelativeLess => 'Less';

  @override
  String get trackingRelativeUsual => 'About usual';

  @override
  String get trackingRelativeMore => 'More';

  @override
  String get trackingOptionalMemo => 'Note (optional)';

  @override
  String get syncConflictsTitle => 'Review sync conflicts';

  @override
  String get syncConflictsReviewAction => 'Review conflicts';

  @override
  String get syncConflictUnresolved => 'Needs a decision';

  @override
  String get syncConflictResolved => 'Resolved';

  @override
  String get syncConflictLocalVersion => 'This device';

  @override
  String get syncConflictIncomingVersion => 'Other device';

  @override
  String get syncConflictKeepLocal => 'Keep this device';

  @override
  String get syncConflictUseIncoming => 'Use other device';

  @override
  String get syncConflictResolutionWarning =>
      'Your choice will be saved as a new change and shared with connected devices.';

  @override
  String get syncConflictResolvedKeepLocal => 'Kept this device';

  @override
  String get syncConflictResolvedUseIncoming => 'Used other device';

  @override
  String get syncConflictEmpty => 'There are no sync conflicts to review.';

  @override
  String get syncConflictResolveFailed =>
      'This conflict could not be resolved. Refresh and try again.';

  @override
  String get syncConflictConfirmTitle => 'Resolve this conflict?';

  @override
  String get syncConflictConfirmAction => 'Resolve';

  @override
  String get syncConflictHistoryTitle => 'Resolution history';

  @override
  String syncConflictRevision(int revision) {
    return 'Revision $revision';
  }

  @override
  String get syncConflictMedicationTitle => 'Medication record conflict';

  @override
  String get syncConflictMedicationWarning =>
      'The medication name, dose, or administration time differs. Confirm what was actually administered with your family before choosing a version.';

  @override
  String syncConflictMedicationNoticeTitle(int count) {
    return '$count medication records need review';
  }

  @override
  String syncConflictMedicationComparison(
    String localValue,
    String incomingValue,
  ) {
    return 'This device: $localValue\nOther device: $incomingValue';
  }

  @override
  String get syncConflictMedicationReviewAction => 'Compare medication details';

  @override
  String get syncConflictMedicationName => 'Medication';

  @override
  String get syncConflictMedicationDose => 'Dose';

  @override
  String get syncConflictMedicationTime => 'Administered at';

  @override
  String get syncConflictMedicationAuthor => 'Author ID';

  @override
  String get syncConflictMedicationDevice => 'Device ID';

  @override
  String get syncConflictMedicationModifiedAt => 'Modified at';

  @override
  String get syncConflictValueUnknown => 'Not available';

  @override
  String get syncResolutionNoticeTitle =>
      'Concurrent changes were reconciled automatically';

  @override
  String get syncResolutionNoticeDescription =>
      'Two devices resolved the conflict at the same time. The final result was selected by server order; no further choice is needed.';

  @override
  String get syncResolutionNoticeMedicationTitle =>
      'Concurrent medication resolution';

  @override
  String get syncResolutionNoticeMedicationWarning =>
      'Two devices selected different medication details at the same time. Confirm the final applied value directly with your family.';

  @override
  String get syncResolutionNoticeFirstVersion => 'First resolution';

  @override
  String get syncResolutionNoticeSecondVersion => 'Second resolution';

  @override
  String syncResolutionNoticeWinner(String value) {
    return 'Final result: $value';
  }

  @override
  String get syncResolutionNoticeAcknowledge => 'Got it';

  @override
  String syncResolutionNoticeAcknowledgedMembers(int count) {
    return 'Acknowledged by $count member(s)';
  }

  @override
  String get growthChartTitle => 'Growth';

  @override
  String get growthChartPersonalTrendDescription =>
      'See your child\'s original measurements over time. Missing periods are not estimated.';

  @override
  String get growthChartHeight => 'Height';

  @override
  String get growthChartWeight => 'Weight';

  @override
  String get growthChartHead => 'Head';

  @override
  String get growthChartEmpty => 'No measurements for this chart yet.';

  @override
  String growthChartPointCount(int count) {
    return '$count original measurements';
  }

  @override
  String get growthChartShowReference => 'Show growth reference';

  @override
  String get growthChartProfileRequired =>
      'Exact birth date and sex are required for percentiles.';

  @override
  String get growthChartReferenceUnavailable =>
      'Only the personal trend is shown for now. Percentiles stay hidden until a child profile and versioned official reference data are available.';

  @override
  String get growthChartPercentileExplanation =>
      'A percentile describes a position in a reference distribution for children of the same age and sex. Higher or lower does not by itself mean better or worse.';

  @override
  String get quickLaunchEditTitle => 'Edit Quick Launch';

  @override
  String get quickLaunchEditDescription =>
      'Set frequent records, including reusable details.';

  @override
  String get quickLaunchAll => 'All';

  @override
  String get quickLaunchMore => 'More';

  @override
  String get quickLaunchAdd => 'Add';

  @override
  String get quickLaunchChooseEvent => 'Choose a record';

  @override
  String get quickLaunchChooseSlot => 'Choose a slot to change';

  @override
  String get quickLaunchDisplayLabel => 'Display name';

  @override
  String get quickLaunchSaveSlot => 'Save to this slot';

  @override
  String get quickLaunchClearSlot => 'Clear slot';

  @override
  String get quickLaunchMoveLeft => 'Move left';

  @override
  String get quickLaunchMoveRight => 'Move right';

  @override
  String quickLaunchInstantSemantic(String label) {
    return '$label, tap to record immediately';
  }

  @override
  String quickLaunchFormSemantic(String label) {
    return '$label, tap to open details';
  }

  @override
  String quickLaunchCategorySemantic(String label) {
    return '$label, tap to open choices';
  }

  @override
  String quickLaunchSaved(String label) {
    return 'Recorded $label.';
  }

  @override
  String get quickLaunchPresetAmount => 'Preset amount';

  @override
  String quickLaunchRecommendationTitle(String childName, String stage) {
    return 'Update $childName\'s Quick Launch for $stage?';
  }

  @override
  String get quickLaunchRecommendationDescription =>
      'Compare the current and suggested slots, then change only what you want. This is not guidance about care timing or tracking methods.';

  @override
  String get quickLaunchViewChanges => 'Review changes';

  @override
  String get quickLaunchLater => 'Later';

  @override
  String get quickLaunchSkipStage => 'Skip this stage';

  @override
  String get quickLaunchApplyAll => 'Apply all';

  @override
  String get quickLaunchApplySelected => 'Apply selected';

  @override
  String get quickLaunchCurrent => 'Current';

  @override
  String get quickLaunchSuggested => 'Suggested';

  @override
  String get quickLaunchKeep => 'Keep';

  @override
  String get quickLaunchRecommendationApplied =>
      'Applied the suggested Quick Launch.';

  @override
  String get quickLaunchRecommendationUndone =>
      'Restored the previous Quick Launch.';

  @override
  String get growthStageNewborn => 'newborn stage';

  @override
  String get growthStageMonth3 => '3 months';

  @override
  String get growthStageMonth6 => '6 months';

  @override
  String get growthStageYear1 => 'first birthday';

  @override
  String get childProfilesTitle => 'Children';

  @override
  String get childProfilesDescription =>
      'Manage each child\'s name, birth date, and Quick Launch separately.';

  @override
  String get addChildProfile => 'Add child';

  @override
  String get editChildProfile => 'Edit child';

  @override
  String get childNameLabel => 'Child\'s name';

  @override
  String get childBirthDateLabel => 'Birth date (optional)';

  @override
  String get childBirthDateUnknown => 'No birth date';

  @override
  String get selectChildProfile => 'Record for this child';

  @override
  String get selectedChildProfile => 'Currently recording';

  @override
  String get deleteChildProfile => 'Delete child';

  @override
  String get lastChildCannotDelete => 'The last child cannot be deleted.';
}
