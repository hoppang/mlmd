// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '복덩이 일기';

  @override
  String get noDiaryTitle => '작성된 일기가 없습니다.';

  @override
  String get noDiaryDesc => '하단의 + 버튼을 눌러 첫 일기를 작성해 보세요.';

  @override
  String get newDiary => '새 일기 작성';

  @override
  String get editDiary => '일기 수정';

  @override
  String get titleLabel => '제목 (선택)';

  @override
  String get titleHint => '비워두면 내용의 첫 줄로 제목을 만듭니다.';

  @override
  String get contentLabel => '내용 (원문)';

  @override
  String get contentHint => '오늘 하루 어떤 일이 있었나요? 자유롭게 입력해 주세요.';

  @override
  String get summaryLabel => '요약';

  @override
  String get summaryHint => '오늘 하루를 1~3문장으로 요약해 주세요.';

  @override
  String get simpleModeLabel => '간단 입력';

  @override
  String get manualModeLabel => '직접 입력';

  @override
  String get analyzeButton => 'AI로 정리';

  @override
  String get analyzingLabel => 'AI가 기록을 정리하고 있어요…';

  @override
  String get saveRecord => '저장';

  @override
  String get aiUnavailableDescription =>
      '현재 AI를 사용할 수 없어요. 원문 기록은 그대로 저장할 수 있어요.';

  @override
  String get aiAnalysisFailed => 'AI 정리에 실패했어요. 원문은 그대로 유지됩니다.';

  @override
  String get retryAiAnalysis => 'AI 정리 다시 시도';

  @override
  String get aiAnalysisApplied => 'AI 정리 결과를 적용했어요. 입력한 원문은 그대로 보존됩니다.';

  @override
  String get previewSection => '분석 결과 미리보기';

  @override
  String get recordAction => '기록하기';

  @override
  String get recordSheetTitle => '무엇을 기록할까요?';

  @override
  String get quickRecordsTitle => '빠른 기록';

  @override
  String get recentRecordsTitle => '최근 사용';

  @override
  String get allCategoriesTitle => '전체 카테고리';

  @override
  String get basicCareCategory => '기본 돌봄';

  @override
  String get healthMedicalCategory => '건강·의료';

  @override
  String get activityPlayCategory => '활동·놀이';

  @override
  String get growthMemoryCategory => '성장·추억';

  @override
  String get feedingEvent => '수유';

  @override
  String get mealEvent => '이유식·식사';

  @override
  String get waterSnackEvent => '물·간식';

  @override
  String get waterEvent => '물';

  @override
  String get snackEvent => '간식';

  @override
  String get feedingMethodLabel => '수유 방식';

  @override
  String get breastFeedingOption => '모유';

  @override
  String get bottleFeedingOption => '젖병';

  @override
  String get feedingTimeOnlyOption => '시각만';

  @override
  String get breastSideLabel => '수유한 쪽';

  @override
  String get leftSideOption => '왼쪽';

  @override
  String get rightSideOption => '오른쪽';

  @override
  String get bothSidesOption => '양쪽';

  @override
  String get pumpingSideLabel => '유축 부위';

  @override
  String get pumpingAmountLabel => '유축량 (선택)';

  @override
  String get pumpingAmountHint => 'mL 수치 입력';

  @override
  String get savePumping => '유축 기록 저장';

  @override
  String get saveBathRecord => '목욕 기록 저장';

  @override
  String get bathOneTouchHint => '원터치 목욕 기록 · 세부 상태와 소요 시간 없이 현재 시각으로 저장합니다.';

  @override
  String get bathFormTitle => '목욕 기록';

  @override
  String get bottleContentsLabel => '젖병 내용';

  @override
  String get formulaOption => '분유';

  @override
  String get expressedMilkOption => '유축 모유';

  @override
  String get expressedMilkFeedingOption => '유축수유';

  @override
  String get feedingChooseType => '수유 종류 선택';

  @override
  String get otherOption => '기타';

  @override
  String get amountStyleLabel => '먹은 양';

  @override
  String get qualitativeAmountOption => '느낌으로';

  @override
  String get fractionAmountOption => '제공량 기준';

  @override
  String get exactAmountOption => '정확한 양';

  @override
  String get sipAmountOption => '한 모금';

  @override
  String get biteAmountOption => '맛만 봄';

  @override
  String get littleAmountOption => '조금';

  @override
  String get normalAmountOption => '보통';

  @override
  String get muchAmountOption => '많이';

  @override
  String get quarterAmountOption => '¼';

  @override
  String get halfAmountOption => '절반';

  @override
  String get almostAllAmountOption => '거의 다';

  @override
  String get allAmountOption => '전부';

  @override
  String get exactAmountLabel => '수치';

  @override
  String get amountUnitLabel => '단위';

  @override
  String get mealTypeLabel => '식사 구분';

  @override
  String get breakfastOption => '아침';

  @override
  String get lunchOption => '점심';

  @override
  String get dinnerOption => '저녁';

  @override
  String get foodNameLabel => '음식 이름 (선택)';

  @override
  String get snackNameLabel => '간식 이름 (선택)';

  @override
  String get reactionLabel => '반응 (선택)';

  @override
  String get ateWellOption => '잘 먹음';

  @override
  String get averageReactionOption => '보통';

  @override
  String get refusedOption => '거부함';

  @override
  String get memoOptionalLabel => '메모 (선택)';

  @override
  String get cupAmountOption => '컵 기준';

  @override
  String get cupAmountInfoTitle => '컵 단위 안내';

  @override
  String get cupAmountInfoBody =>
      '아기용 컵은 제품마다 다르지만 대략 200mL 전후인 경우가 많아요. 컵 단위는 대략적인 기록이며 정확한 mL로 환산하지 않아요.';

  @override
  String get exactAmountRequired => '0보다 큰 수치를 입력해 주세요.';

  @override
  String get sleepEvent => '수면';

  @override
  String get diaperEvent => '기저귀·배변';

  @override
  String get pumpingEvent => '유축';

  @override
  String get temperatureEvent => '체온';

  @override
  String get medicationEvent => '투약';

  @override
  String get symptomEvent => '증상·컨디션';

  @override
  String get hospitalEvent => '병원·상담';

  @override
  String get doctorNotesLabel => '의사에게 들은 내용 (선택)';

  @override
  String get doctorNotesHint => '진단명, 처방 또는 집에서 주의할 내용을 메모로 남기세요.';

  @override
  String get prescriptionBagButton => '약봉투 촬영';

  @override
  String get attachFileButton => '파일 첨부';

  @override
  String get hospitalVisitTime => '방문 시각';

  @override
  String get attachmentPrescriptionBag => '약봉투';

  @override
  String get attachmentGeneral => '첨부파일';

  @override
  String get vaccinationEvent => '예방접종';

  @override
  String get vaccinationTime => '접종 시각';

  @override
  String get vaccinationNotesLabel => '접종 메모 (선택)';

  @override
  String get vaccinationNotesHint => '백신 종류, 접종 기관 또는 참고할 사항을 남기세요.';

  @override
  String get vaccinationBookButton => '예방접종 수첩 촬영';

  @override
  String get attachmentVaccinationRecord => '예방접종 수첩';

  @override
  String get checkKdcaVaccinationHistory => '질병관리청에서 접종 내역 확인';

  @override
  String get kdcaVaccinationNotice =>
      '국가 예방접종 체계와 자동으로 동기화되지 않으며, 기록된 접종 사실과 첨부된 수첩 사진만 보존됩니다.';

  @override
  String get accidentInjuryEvent => '사고·다침';

  @override
  String get accidentCategoryLabel => '사고 유형';

  @override
  String get accidentCategoryTraumatic => '외상 (다침/상처)';

  @override
  String get accidentCategoryNonTraumatic => '비외상 (삼킴/이물/사레)';

  @override
  String get accidentInjuryTypeLabel => '세부 유형';

  @override
  String get injuryTypeBumpBruise => '콕 찍힘·멍';

  @override
  String get injuryTypeScratchWound => '긁힘·상처';

  @override
  String get injuryTypeFallTrip => '넘어짐·낙상';

  @override
  String get injuryTypeBurn => '화상';

  @override
  String get injuryTypeBiteSting => '물림';

  @override
  String get injuryTypeOtherTrauma => '기타 외상';

  @override
  String get injuryTypeForeignIngestion => '이물질 삼킴';

  @override
  String get injuryTypeChokingAspiration => '사레·기도 이물';

  @override
  String get injuryTypeEyeEarForeignObject => '눈·귀 이물';

  @override
  String get injuryTypePoisoningChemical => '중독·약물';

  @override
  String get injuryTypeHeatColdInjury => '열사병·저체온';

  @override
  String get injuryTypeOtherNonTrauma => '기타 비외상';

  @override
  String get accidentTime => '사고 발생 시각';

  @override
  String get accidentNotesLabel => '사고 상황 및 조치 메모 (선택)';

  @override
  String get accidentNotesHint => '사고 경위나 관찰 상태, 응급 조치 내용을 기록하세요.';

  @override
  String get accidentPhotoAttachmentButton => '상처/현장 사진 첨부';

  @override
  String get accidentGuidanceAttentionTitle => '주의 필요 사고';

  @override
  String get accidentGuidanceFirstAidInfo =>
      '낙상, 화상, 이물질 삼킴, 기도 이물, 중독의 경우 아이의 상태를 면밀히 관찰하고 필요시 즉시 응급실이나 전문 의료기관을 방문하세요.';

  @override
  String get careProcedureEvent => '처치·관리';

  @override
  String get careProcedureTime => '시행 시각';

  @override
  String get careProcedureScopeHelp =>
      '집에서 이미 시행한 비투약 처치만 기록하세요. 연고·안약·흡입약처럼 약물이 들어가면 투약으로 기록합니다.';

  @override
  String get careProcedureTypeLabel => '처치 종류';

  @override
  String get procedureTypeNasalCare => '코 세척·흡인';

  @override
  String get procedureTypeWoundCare => '상처 세척·드레싱';

  @override
  String get procedureTypeHotColdPack => '냉·온찜질';

  @override
  String get procedureTypeRespiratoryCare => '호흡기 관리';

  @override
  String get procedureTypeOther => '기타';

  @override
  String get careProcedureBodyAreaLabel => '부위 (선택)';

  @override
  String get careProcedureBodyAreaHint => '예: 왼쪽 무릎';

  @override
  String get careProcedureNoteLabel => '메모 (선택)';

  @override
  String get careProcedureOtherNoteLabel => '무엇을 했나요?';

  @override
  String get careProcedureNoteHint => '시행한 처치에 필요한 설명을 짧게 남기세요.';

  @override
  String get careProcedureTypeRequired => '처치 종류를 선택해 주세요.';

  @override
  String get careProcedureOtherRequired => '기타 처치로 무엇을 했는지 입력해 주세요.';

  @override
  String get careProcedurePhotoButton => '사진 첨부';

  @override
  String get tummyTimeEvent => '터미타임';

  @override
  String get tummyTimeFormTitle => '터미타임 기록';

  @override
  String get tummyTimeDurationLabel => '시간 (선택)';

  @override
  String get tummyTimeDurationHint => '분 단위 입력 (예: 5)';

  @override
  String tummyTimeDurationDisplay(int minutes) {
    return '$minutes분';
  }

  @override
  String get tummyTimeDurationInvalidError => '1~999 사이의 숫자를 입력해 주세요.';

  @override
  String get tummyTimeInfantRecommendation =>
      '터미타임은 목·어깨·등 근육을 키우는 데 도움이 됩니다. 어린 영아는 하루에 2~3회, 한 번에 3~5분 정도의 짧은 시간이 권장됩니다.';

  @override
  String get tummyTimeInfantRecommendationSource =>
      '일반적인 영유아 발달 지침을 참고한 안내입니다. 아이의 상태에 맞는 구체적인 지도는 담당 소아과 의사에게 확인하세요.';

  @override
  String get saveTummyTimeRecord => '터미타임 기록 저장';

  @override
  String get growthMeasurementFormTitle => '성장 측정';

  @override
  String get growthMeasurementHeightLabel => '키 (선택)';

  @override
  String get growthMeasurementHeightHint => 'cm 단위 입력 (예: 55.0)';

  @override
  String get growthMeasurementWeightLabel => '몸무게 (선택)';

  @override
  String get growthMeasurementWeightHint => 'kg 단위 입력 (예: 6.50)';

  @override
  String get growthMeasurementHeadLabel => '머리둘레 (선택)';

  @override
  String get growthMeasurementHeadHint => 'cm 단위 입력 (예: 38.0)';

  @override
  String get growthMeasurementAtLeastOneError =>
      '키, 몸무게, 머리둘레 중 하나 이상 입력해 주세요.';

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
  String get saveGrowthMeasurementRecord => '성장 측정 저장';

  @override
  String get bathEvent => '목욕';

  @override
  String get growthMeasurementEvent => '키·몸무게 측정';

  @override
  String get memoEvent => '메모';

  @override
  String get eventDetailOptionalLabel => '상세 (선택)';

  @override
  String get eventDetailOptionalHint => '수량, 상태 또는 짧은 메모를 남겨보세요.';

  @override
  String get writeDetailedRecord => '긴 메모와 AI 정리';

  @override
  String get backToRecordTypes => '기록 종류로 돌아가기';

  @override
  String get savingQuickRecord => '저장 중…';

  @override
  String get quickRecordSaveFailed => '기록을 저장하지 못했어요. 입력 내용은 그대로 유지됩니다.';

  @override
  String quickRecordSaved(String type) {
    return '$type 기록을 저장했어요.';
  }

  @override
  String get addEventButton => '이벤트 추가';

  @override
  String get eventTypeLabel => '종류';

  @override
  String get eventTypeHint => '예: 수유, 수면, 병원';

  @override
  String get eventDetailLabel => '상세';

  @override
  String get eventDetailHint => '예: [7, 9, 11]시, 오전 소아과';

  @override
  String get recordTimeLabel => '기록 시각';

  @override
  String get eventTimeUnknown => '발생 시각 미상';

  @override
  String get clearEventTime => '발생 시각 지우기';

  @override
  String get delete => '삭제';

  @override
  String get cancel => '취소';

  @override
  String get confirm => '확인';

  @override
  String get edit => '수정';

  @override
  String get diaryAdded => '새 일기가 추가되었습니다.';

  @override
  String get diaryUpdated => '일기가 수정되었습니다.';

  @override
  String get diaryDeleted => '일기가 삭제되었습니다.';

  @override
  String get deleteConfirmTitle => '일기 삭제';

  @override
  String get deleteConfirmDesc => '이 일기를 정말 삭제하시겠습니까? 삭제 후에는 복구할 수 없습니다.';

  @override
  String get todayTab => '오늘';

  @override
  String get dateTab => '날짜별';

  @override
  String get todayTimelineTitle => '오늘 기록';

  @override
  String get todayStatusTitle => '오늘 현황';

  @override
  String get startupLoading => '앱을 준비하는 중...';

  @override
  String get startupErrorTitle => '앱 초기화 중 문제가 발생했습니다';

  @override
  String get startupRetry => '다시 시도';

  @override
  String get startupResetData => '모든 데이터 초기화';

  @override
  String get startupResetConfirmMessage =>
      '정말 모든 데이터를 삭제하고 처음부터 다시 시작하시겠습니까?\n이 작업은 되돌릴 수 없습니다.';

  @override
  String get searchTab => '검색';

  @override
  String get searchTitle => '기록 검색';

  @override
  String get searchHint => '메모나 이벤트를 검색해 보세요.';

  @override
  String get searchAction => '검색';

  @override
  String get searchIntroTitle => '지난 기록을 찾아보세요';

  @override
  String get searchIntroDescription => '메모 내용이나 수유, 투약 같은 이벤트 이름으로 찾을 수 있어요.';

  @override
  String searchResultCount(int count) {
    return '검색 결과 $count건';
  }

  @override
  String get searchNoResults => '일치하는 기록이 없어요.';

  @override
  String get searchNoResultsHint => '검색 조건은 유지돼요. 기간을 넓히거나 조건을 하나씩 빼보세요.';

  @override
  String get searchFailed => '검색하지 못했어요. 원본 기록은 그대로 유지됩니다.';

  @override
  String get retrySearch => '다시 검색';

  @override
  String get searchSortLabel => '정렬';

  @override
  String get searchSortRelevance => '관련도순';

  @override
  String get searchSortNewest => '최신순';

  @override
  String get searchSortOldest => '오래된순';

  @override
  String get searchMatchExact => '정확한 문구 일치';

  @override
  String get searchMatchActivityType => '이벤트 종류 일치';

  @override
  String get searchMatchRelated => '관련 표현';

  @override
  String get searchMatchTemperature => '체온 조건 일치';

  @override
  String get searchMatchAuthor => '작성자 조건 일치';

  @override
  String get searchMatchEvent => '이벤트 조건 일치';

  @override
  String get searchMatchDate => '날짜 조건 일치';

  @override
  String get searchFilters => '검색 조건';

  @override
  String get searchClearFilters => '조건 지우기';

  @override
  String get searchApplyFilters => '조건 적용';

  @override
  String get searchDate => '날짜';

  @override
  String get searchAll => '전체';

  @override
  String get searchAllDates => '전체 기간';

  @override
  String get searchToday => '오늘';

  @override
  String get searchLast7Days => '최근 7일';

  @override
  String get searchLast30Days => '최근 30일';

  @override
  String get searchCustomDate => '직접 지정';

  @override
  String get searchEventType => '이벤트 종류';

  @override
  String get searchAuthor => '작성자';

  @override
  String get searchTemperature => '최소 체온';

  @override
  String searchTemperatureAtLeast(String value) {
    return '$value°C 이상';
  }

  @override
  String get searchEventTemperature => '체온';

  @override
  String get searchEventMedication => '투약';

  @override
  String get searchEventFeeding => '수유';

  @override
  String get searchEventDiaper => '기저귀';

  @override
  String get searchEventSleep => '수면';

  @override
  String get searchEventHospital => '병원·진료';

  @override
  String get searchSemanticUnavailable =>
      '의미 검색을 사용할 수 없거나 인덱싱 중이어도 문구·조건 검색은 계속 사용할 수 있어요.';

  @override
  String get searchSameDayContext => '같은 날의 다른 기록';

  @override
  String get searchSameDayContextHint => '맥락을 위한 표시이며 원인이나 관련성을 뜻하지 않아요.';

  @override
  String get dailyAiSummary => 'AI 일간 정리';

  @override
  String get weeklyAiSummary => 'AI 주간 정리';

  @override
  String get summarizeDay => '이날 정리하기';

  @override
  String get summarizeWeek => '이 주 정리하기';

  @override
  String get summarizeWeekSoFar => '현재까지 정리';

  @override
  String get summaryGenerating => '원본 기록을 바탕으로 정리하고 있어요…';

  @override
  String get summaryUnavailable =>
      'AI 정리를 사용할 수 없어요. 원본 기록과 계산된 현황은 그대로 볼 수 있어요.';

  @override
  String get summaryFailed => '정리를 만들지 못했어요. 원본 기록은 변경되지 않았어요.';

  @override
  String get summaryNoRecords => '정리할 원본 기록이 없어요.';

  @override
  String summaryBasis(int count, String time) {
    return '$time까지의 원본 기록 $count개 기준';
  }

  @override
  String get summaryNewRecords => '이 정리 이후 새 기록이 있어요.';

  @override
  String get summarySourceChanged => '이 정리에 사용한 원본 기록이 변경되었어요.';

  @override
  String get summaryEdited => '직접 수정됨';

  @override
  String get summaryEvidence => '근거 기록 보기';

  @override
  String get summaryEvidenceTitle => '정리에 사용한 원본 기록';

  @override
  String get summaryEditTitle => '정리 수정';

  @override
  String get summaryHide => '숨기기';

  @override
  String get summaryRestore => '정리 다시 보기';

  @override
  String get summaryRegenerate => '다시 생성';

  @override
  String get summaryPreviewTitle => '새 정리 확인';

  @override
  String get summaryReplace => '새 정리로 교체';

  @override
  String get weeklyAutoSummary => '주간 AI 정리 자동 생성';

  @override
  String get weeklyAutoSummaryDescription =>
      '월요일부터 일요일까지 완료된 주를 기기 내 AI로 조용히 정리해요.';

  @override
  String get medicalBriefingTitle => '병원 방문 브리핑';

  @override
  String get medicalBriefingDescription =>
      '병원 방문 전 기록한 체온, 투약, 증상, 진료, 예방접종과 사고·다침 사실을 모아 확인해요.';

  @override
  String get briefingSafetyNotice =>
      '기록된 사실만 보여 줍니다. 진단, 인과관계나 치료 조언을 제공하지 않아요. 중요한 내용은 원본 기록에서 다시 확인하세요.';

  @override
  String get briefingPeriod => '브리핑 기간';

  @override
  String briefingDateRange(String from, String to) {
    return '$from~$to';
  }

  @override
  String briefingFactCount(int count) {
    return '기록된 사실 $count건';
  }

  @override
  String get briefingNoFacts => '조건에 맞는 건강 기록이 없어요.';

  @override
  String get briefingNoFactsHint =>
      '기간을 유지하거나 더 넓혀 보세요. 일반 메모와 비의료 이벤트를 의료 사실로 추정하지 않아요.';

  @override
  String get briefingCopy => '브리핑 복사';

  @override
  String get briefingCopied => '브리핑을 복사했어요.';

  @override
  String get briefingShare => '브리핑 공유';

  @override
  String get briefingOpenOriginal => '원본 기록 열기';

  @override
  String get searchMemoResult => '메모';

  @override
  String get searchActivityResult => '이벤트';

  @override
  String get searchReadOnly => '읽기 전용';

  @override
  String get searchResultDetail => '검색 결과 상세';

  @override
  String get settings => '설정';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsIntro => '꼭 필요한 정보와 데이터 보관 방법만 한곳에서 관리합니다.';

  @override
  String get childInformation => '아이 정보';

  @override
  String get childInformationDescription => '아직 기록과 연결된 아이 정보를 저장할 수 없어요.';

  @override
  String get authorProfile => '내 이름과 색상';

  @override
  String get authorProfileDescription => '새 기록에 사용할 작성자 이름과 색상을 관리합니다.';

  @override
  String get authorSetupTitle => '이 기기에서 누가 기록하나요?';

  @override
  String get authorSetupDescription =>
      '가족이 알아볼 수 있는 이름과 색상을 정해 주세요. 실명일 필요는 없으며 새 기록에 자동으로 적용됩니다.';

  @override
  String get authorNicknameLabel => '작성자 이름';

  @override
  String get authorNicknameHint => '예: 엄마, 아빠, 할머니';

  @override
  String get authorColorLabel => '개인 색상';

  @override
  String get authorSave => '이 이름으로 시작';

  @override
  String get authorAdd => '작성자 추가';

  @override
  String get authorEdit => '작성자 수정';

  @override
  String get authorProfilesTitle => '작성자 프로필';

  @override
  String get authorCurrent => '현재 작성자';

  @override
  String get authorUseProfile => '이 작성자로 전환';

  @override
  String get authorNicknameError => '1~30자의 이름을 입력해 주세요.';

  @override
  String get authorProfileLocalNotice =>
      '평소에는 현재 작성자가 자동으로 적용됩니다. 같은 기기를 여러 사람이 사용할 때만 전환하세요.';

  @override
  String get familySharing => '가족과 함께 쓰기';

  @override
  String get familySharingDescription => '현재 기록은 이 기기에만 저장됩니다.';

  @override
  String get familySharingIntro =>
      '다른 보호자와 함께 사용하면 서로 남긴 기록과 할 일을 자동으로 확인할 수 있어요.';

  @override
  String get familySharingNotConnectedTitle => '아직 혼자 사용하고 있어요';

  @override
  String get familySharingNotConnectedDescription =>
      '계정과 초대 방식을 안전하게 연결하기 전까지 현재 기기의 기록은 그대로 유지됩니다.';

  @override
  String get familySharingLocalFirstTitle => '인터넷이 없어도 기록할 수 있어요';

  @override
  String get familySharingLocalFirstDescription =>
      '모든 변경은 먼저 이 기기에 저장되고, 연결이 끊겨도 나중에 보낼 내용이 사라지지 않습니다.';

  @override
  String get familySharingTextOnlyTitle => '사진 원본은 이 기기에 남아요';

  @override
  String get familySharingTextOnlyDescription =>
      '가족 공유에는 텍스트 기록과 첨부 유형·개수만 포함하며 사진과 파일 자체는 보내지 않습니다.';

  @override
  String familySharingPending(int count) {
    return '가족에게 반영할 변경 $count건';
  }

  @override
  String familySharingConflicts(int count) {
    return '확인이 필요한 충돌 $count건';
  }

  @override
  String get familySharingNeverReceived => '아직 가족 기록을 받은 적이 없어요';

  @override
  String familySharingLastReceived(String date, String time) {
    return '마지막으로 가족 기록을 받은 시각: $date $time';
  }

  @override
  String get familySharingOfflineNotice => '인터넷에 연결되면 자동으로 반영됩니다.';

  @override
  String get dataBackupTitle => '데이터 보관 및 백업';

  @override
  String get dataBackupDescription => '기록을 파일로 보관하거나 안전하게 가져옵니다.';

  @override
  String get helpTitle => '도움말';

  @override
  String get helpDescription => '앱의 동작 이유와 언어 설정을 확인합니다.';

  @override
  String get notAvailableYetTitle => '아직 준비 중이에요';

  @override
  String notAvailableYetDescription(String feature) {
    return '$feature 기능은 필요한 데이터 구조와 안전 기준을 갖춘 뒤 제공할 예정입니다.';
  }

  @override
  String get storageSummaryTitle => '현재 백업 범위';

  @override
  String backupContentsSummary(int records, int activities, String size) {
    return '일기 $records건 · 활동 $activities건\n예상 파일 크기 $size';
  }

  @override
  String get backupPrivacyNotice =>
      '백업 파일은 암호화되지 않습니다. 첨부가 든 파일은 안전한 개인 공간에 보관해 주세요.';

  @override
  String get createBackupFile => '백업 파일 만들기';

  @override
  String get createBackupDescription =>
      '복원할 첨부 범위를 선택합니다. 가장 안전한 기본값은 원본 첨부를 함께 보관하는 것입니다.';

  @override
  String get backupModeOriginal => '기록과 원본 첨부';

  @override
  String get backupModeOriginalDescription => '복원에 가장 안전하며 저장 공간을 가장 많이 사용합니다.';

  @override
  String get backupModeReduced => '기록과 용량을 줄인 첨부';

  @override
  String get backupModeReducedDescription =>
      '가능하면 최적화 사진을 사용하고, 약봉투·예방접종 수첩은 원본 품질을 지킵니다.';

  @override
  String get backupModeRecordsOnly => '기록만';

  @override
  String get backupModeRecordsOnlyDescription =>
      '파일은 가장 작지만 사진과 파일은 이 백업으로 복원할 수 없습니다.';

  @override
  String get importBackupFile => '백업 파일 가져오기';

  @override
  String get importBackupDescription => '파일을 바로 합치지 않고 내용과 충돌 가능성을 먼저 보여드립니다.';

  @override
  String get recentlyDeleted => '최근 삭제한 기록';

  @override
  String get recentlyDeletedDescription => '복구 가능한 삭제 기능은 아직 준비 중이에요.';

  @override
  String get helpIntro => '버튼 위치보다 왜 이렇게 동작하는지 먼저 설명드릴게요.';

  @override
  String get offlineHelpQuestion => '왜 인터넷이 없어도 기록할 수 있나요?';

  @override
  String get offlineHelpAnswer =>
      '기록은 먼저 현재 기기에 저장됩니다. 네트워크나 AI 기능에 문제가 생겨도 원문 기록은 계속 작성하고 찾을 수 있어요.';

  @override
  String get duplicateHelpQuestion => '왜 가져온 기록을 자동으로 덮어쓰지 않나요?';

  @override
  String get duplicateHelpAnswer =>
      '같은 기록이 서로 다르면 어느 쪽도 조용히 지우지 않는 편이 안전합니다. 지금은 새 기록만 추가하고 같은 ID의 기록은 건너뜁니다.';

  @override
  String get photoSyncHelpQuestion => '사진은 왜 다른 기기에서 안 보여요?';

  @override
  String get photoSyncHelpAnswer =>
      '가족 공유는 먼저 텍스트 기록에 집중하고 있어 사진은 첨부한 기기에만 저장됩니다. 중요한 사진은 원본 첨부를 포함한 백업 파일로 따로 보관해 주세요.';

  @override
  String get missingDataHelpQuestion => '기록이 적으면 왜 ‘평소보다 적음’으로 판단하지 않나요?';

  @override
  String get missingDataHelpAnswer =>
      '기록이 없는 것은 실제로 적었던 것이 아니라 입력하지 못한 것일 수 있습니다. MLMD는 불완전한 하루를 실제 감소로 단정하지 않습니다.';

  @override
  String get quietNotificationHelpQuestion => '왜 할 일 알림은 기본적으로 조용한가요?';

  @override
  String get quietNotificationHelpAnswer =>
      '돌봄 알림이 아이나 가족을 뜻밖에 깨우지 않도록 하기 위해서예요. 꼭 소리가 필요한 할 일은 만들 때 직접 선택할 수 있습니다.';

  @override
  String get aiSummaryHelpQuestion => 'AI 정리는 무엇을 보고 작성하나요?';

  @override
  String get aiSummaryHelpAnswer =>
      '선택한 기간의 기록만 바탕으로 만든 파생 요약이며 의료 판단이 아닙니다. 원본 기록은 언제나 따로 남아 있습니다.';

  @override
  String get languageSetting => '언어 설정';

  @override
  String get languageSystem => '시스템 설정';

  @override
  String get languageKorean => '한국어(Korean)';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語(Japanese)';

  @override
  String get close => '닫기';

  @override
  String get llmModelError => '모델 파일을 찾을 수 없습니다. AI 분석이 비활성화됩니다.';

  @override
  String get dataManagement => '데이터 관리';

  @override
  String get dataManagementDescription => '전체 일기와 활동을 백업하거나 복원합니다.';

  @override
  String get exportDiary => '일기 내보내기';

  @override
  String get importDiary => '일기 가져오기';

  @override
  String get exportWarningTitle => '평문 백업 내보내기';

  @override
  String exportWarning(int count) {
    return '일기 $count건의 제목, 요약, 본문과 활동이 암호화되지 않은 파일에 포함됩니다.';
  }

  @override
  String exportBackupPreview(
    int records,
    int attachments,
    String size,
    int missing,
  ) {
    return '일기 $records건 · 첨부 $attachments개\n예상 파일 크기 $size\n현재 기기에 없는 첨부 $missing개\n이 백업은 암호화되지 않습니다.';
  }

  @override
  String get exporting => '백업 파일을 만드는 중입니다…';

  @override
  String get importing => '일기를 가져오는 중입니다…';

  @override
  String exportSuccess(int count, int version, String fileName) {
    return '$count건을 v$version 백업으로 내보냈습니다.\n$fileName';
  }

  @override
  String get importPreviewTitle => '가져오기 미리보기';

  @override
  String backupInfo(int version, String appVersion, String exportedAt) {
    return '백업 v$version · 앱 $appVersion\n생성: $exportedAt';
  }

  @override
  String importCounts(int total, int activities) {
    return '일기 $total건 · 활동 $activities건';
  }

  @override
  String get newRecords => '새 일기';

  @override
  String get duplicateRecords => '중복';

  @override
  String get identicalRecords => '내용이 같은 기록';

  @override
  String get conflictingRecords => '확인이 필요한 충돌';

  @override
  String get attachmentsToImport => '이 기기에 가져올 첨부';

  @override
  String importDateRange(String from, String to) {
    return '기록 기간: $from ~ $to';
  }

  @override
  String get safeImportNotice =>
      '가져오기 직전에 현재 기록을 자동 백업합니다. 기존 기록은 덮어쓰지 않고 새 기록만 추가합니다.';

  @override
  String get newerRecords => '최신 백업으로 갱신';

  @override
  String get skippedRecords => '건너뜀';

  @override
  String get conflictPolicy => '중복 처리';

  @override
  String get skipExisting => '기존 일기 건너뛰기';

  @override
  String get overwriteIfNewer => '백업이 더 최신이면 덮어쓰기';

  @override
  String get importAction => '가져오기';

  @override
  String importResult(int inserted, int updated, int skipped) {
    return '추가 $inserted건 · 갱신 $updated건 · 건너뜀 $skipped건';
  }

  @override
  String embeddingFailed(int count) {
    return '검색 색인 $count건은 나중에 다시 생성해야 합니다.';
  }

  @override
  String get transferError => '백업을 처리하지 못했습니다. 파일 형식과 저장 공간을 확인해 주세요.';

  @override
  String get draftSaving => '임시 저장 중…';

  @override
  String get draftSaved => '임시 저장됨';

  @override
  String get draftSaveFailed => '임시 저장하지 못했어요';

  @override
  String get draftSourceChanged =>
      '초안을 만든 뒤 원본 기록이 변경됐어요. 저장하기 전에 내용을 확인해 주세요.';

  @override
  String get discardDraft => '초안 버리기';

  @override
  String get discardDraftTitle => '이 초안을 버릴까요?';

  @override
  String get discardDraftDescription => '작성 중인 내용은 복구할 수 없습니다.';

  @override
  String draftsInProgress(int count) {
    return '작성 중인 기록 $count개';
  }

  @override
  String get continueWriting => '이어서 작성';

  @override
  String get startNewDraft => '새로 작성';

  @override
  String recordCreatedBy(String nickname) {
    return '작성자 $nickname';
  }

  @override
  String get recordSourceDetails => '기록 출처';

  @override
  String recordSourceDevice(String deviceId) {
    return '입력 기기 $deviceId';
  }

  @override
  String get duplicateReviewTitle => '확인할 기록';

  @override
  String get duplicateReviewDescription =>
      '서로 다른 기기에서 같은 시각과 내용으로 저장된 원본을 비교합니다. 확인하기 전에는 어떤 기록도 합치거나 삭제하지 않아요.';

  @override
  String duplicateReviewBanner(int count) {
    return '확인할 기록 $count개';
  }

  @override
  String get duplicateReviewBannerHint => '비슷한 기록인지 확인해 주세요.';

  @override
  String duplicatePendingCount(int count) {
    return '확인 필요 $count개';
  }

  @override
  String get duplicateResolvedTitle => '확인한 기록';

  @override
  String get duplicateNeedsReview => '비슷한 기록 2개';

  @override
  String get duplicateExactReason => '종류, 발생 시각과 내용이 같고 입력 기기가 달라요.';

  @override
  String duplicateUseSource(int number) {
    return '$number번을 기준으로 한 건으로 표시';
  }

  @override
  String get duplicateMarkDistinct => '1번과 2번은 각각 다른 일';

  @override
  String get duplicateReviewLater => '나중에 확인';

  @override
  String get duplicateSameEvent => '같은 사건으로 확인됨';

  @override
  String get duplicateDistinctEvents => '각각 다른 일로 확인됨';

  @override
  String get duplicateDecisionSaved => '중복 판단을 저장했어요. 원본 기록은 그대로 유지됩니다.';

  @override
  String get duplicateChangeDecision => '중복 판단 변경';

  @override
  String get duplicateReviewEmpty => '확인할 기록이 없어요';

  @override
  String get duplicateReviewEmptyHint => '새 후보가 생기면 오늘 화면에 표시됩니다.';

  @override
  String get myRecordsTitle => '나만의 기록';

  @override
  String get createCustomEvent => '새 기록 만들기';

  @override
  String get customEventNameLabel => '기록 이름';

  @override
  String get customEventNameHint => '예: 비타민, 산책 준비';

  @override
  String get customEventNameRequired => '이름을 입력해 주세요.';

  @override
  String get customEventMemoOptionalLabel => '메모 (선택)';

  @override
  String get customEventMemoOptionalHint => '필요한 내용만 짧게 남겨 주세요.';

  @override
  String get customEventMedicationHint =>
      '약을 기록하려는 경우에는 기본 ‘투약’에서 약 이름과 용량을 남길 수 있어요. 이 기록도 그대로 만들 수 있습니다.';

  @override
  String get pinToQuickRecords => '빠른 기록에 고정';

  @override
  String get removeFromQuickRecords => '빠른 기록에서 해제';

  @override
  String get renameCustomEvent => '이름 변경';

  @override
  String get archiveCustomEvent => '보관';

  @override
  String get archiveCustomEventTitle => '이 기록 종류를 보관할까요?';

  @override
  String archiveCustomEventDescription(String name) {
    return '‘$name’은 나만의 기록에서 숨겨지지만 과거 기록은 그대로 유지됩니다.';
  }

  @override
  String get sleepStarted => '수면 기록을 시작했어요.';

  @override
  String get sleepAlreadyActive => '이미 진행 중인 수면이 있어요.';

  @override
  String sleepInProgress(String duration) {
    return '수면 중 · $duration';
  }

  @override
  String sleepSince(String time) {
    return '$time부터';
  }

  @override
  String get wakeUp => '깨어났어요';

  @override
  String get sleepEnded => '수면 기록을 종료했어요.';

  @override
  String get undo => '실행 취소';

  @override
  String get editStartTime => '시작 시각 수정';

  @override
  String get sleepDateYesterday => '어제';

  @override
  String get sleepDateOther => '다른 날짜';

  @override
  String sleepAdjustEarlier(int minutes) {
    return '$minutes분 앞당기기';
  }

  @override
  String sleepAdjustLater(int minutes) {
    return '$minutes분 늦추기';
  }

  @override
  String get addSleepMarkers => '상태 추가';

  @override
  String get sleepMarkersTitle => '관찰한 수면 상태';

  @override
  String get sleepMarkersHint => '여러 개를 선택할 수 있어요. 실제 수면 깊이를 측정한 값은 아닙니다.';

  @override
  String get sleepMarkerRestful => '푹 잠';

  @override
  String get sleepMarkerRestless => '뒤척임';

  @override
  String get sleepMarkerWokeUp => '중간에 깸';

  @override
  String get sleepMarkerFrequentWaking => '자주 깸';

  @override
  String get sleepMarkersSaved => '수면 상태를 저장했어요.';

  @override
  String get directSleepEntry => '끝난 수면 직접 입력';

  @override
  String get sleepStartTime => '시작 시각';

  @override
  String get sleepEndTime => '종료 시각';

  @override
  String get sleepKind => '수면 구분';

  @override
  String get sleepKindUnspecified => '구분 안 함';

  @override
  String get sleepKindNap => '낮잠';

  @override
  String get sleepKindNight => '밤잠';

  @override
  String get sleepKindSuggested => '시각을 기준으로 제안했어요. 필요하면 바꿀 수 있습니다.';

  @override
  String get sleepNote => '메모 (선택)';

  @override
  String get sleepTimeInvalid => '종료 시각은 시작 시각보다 늦어야 해요.';

  @override
  String get sleepFutureInvalid => '끝난 수면은 미래 시각으로 저장할 수 없어요.';

  @override
  String get saveSleep => '수면 기록 저장';

  @override
  String sleepDurationHoursMinutes(int hours, int minutes) {
    return '$hours시간 $minutes분';
  }

  @override
  String sleepDurationHours(int hours) {
    return '$hours시간';
  }

  @override
  String sleepDurationMinutes(int minutes) {
    return '$minutes분';
  }

  @override
  String get sleepDurationLessThanMinute => '1분 미만';

  @override
  String get eliminationUrineAction => '소변을 봤어요';

  @override
  String get eliminationStoolAction => '대변을 봤어요';

  @override
  String get eliminationBothAction => '소변과 대변을 모두 봤어요';

  @override
  String get eliminationUrinePreset => '기저귀·소변';

  @override
  String get eliminationStoolPreset => '기저귀·대변';

  @override
  String get eliminationBothPreset => '기저귀·소변+대변';

  @override
  String get eliminationUrineDetail => '소변';

  @override
  String get eliminationStoolDetail => '대변';

  @override
  String get eliminationBothDetail => '소변+대변';

  @override
  String get eliminationKindTitle => '기록한 내용';

  @override
  String get eliminationSavedHint =>
      '현재 시각으로 저장했어요. 필요한 정보만 더하거나 종류를 바로 바꿀 수 있습니다.';

  @override
  String get eliminationOptionalDetailsTitle => '선택 정보';

  @override
  String get eliminationAmountTitle => '양';

  @override
  String get eliminationAmountLittle => '조금';

  @override
  String get eliminationAmountNormal => '보통';

  @override
  String get eliminationAmountMuch => '많이';

  @override
  String get stoolConsistencyTitle => '상태';

  @override
  String get stoolConsistencyLoose => '묽음';

  @override
  String get stoolConsistencyNormal => '보통';

  @override
  String get stoolConsistencyHard => '단단함';

  @override
  String get stoolColorTitle => '색상';

  @override
  String get stoolColorYellow => '노랑';

  @override
  String get stoolColorBrown => '갈색';

  @override
  String get stoolColorGreen => '녹색';

  @override
  String get stoolColorBlack => '검정';

  @override
  String get stoolColorOther => '기타';

  @override
  String get eliminationObservationHint => '관찰한 사실만 저장하며 질환이나 원인을 판단하지 않습니다.';

  @override
  String get saveEliminationChanges => '변경사항 저장';

  @override
  String get eliminationChangesSaved => '기저귀·배변 정보를 저장했어요.';

  @override
  String get temperatureValueLabel => '체온';

  @override
  String get temperatureValueRequired => '체온을 숫자로 입력해 주세요.';

  @override
  String get temperatureSiteLabel => '측정 부위 (선택)';

  @override
  String get temperatureSiteAxillary => '겨드랑이';

  @override
  String get temperatureSiteEar => '귀';

  @override
  String get temperatureSiteForehead => '이마';

  @override
  String get temperatureSiteRectal => '항문';

  @override
  String get temperatureSiteOther => '기타';

  @override
  String get temperatureNoteLabel => '메모 (선택)';

  @override
  String get medicalAttentionRequired => '주의 필요';

  @override
  String get relatedOfficialGuidance => '관련 공식 자료';

  @override
  String officialGuidanceMatchReason(String reason) {
    return '연결 조건 · $reason';
  }

  @override
  String get openInSystemBrowser => '시스템 브라우저에서 확인';

  @override
  String get officialGuidanceOpenFailed => '공식 자료를 열지 못했어요. 기록 화면은 그대로 유지됩니다.';

  @override
  String get officialGuidanceDisclaimer =>
      '개발자가 확인해 등록한 외부 자료입니다. 앱은 진단이나 치료 방법을 판단하지 않습니다.';

  @override
  String get ingredientCheckRequired => '성분 확인 필요';

  @override
  String get medicationTypeTitle => '약 종류';

  @override
  String get medicationCategoryAntipyretic => '해열제';

  @override
  String get medicationCategoryCoughCold => '기침약·감기약';

  @override
  String get medicationCategoryAntibiotic => '항생제';

  @override
  String get medicationCategoryOintment => '연고·크림';

  @override
  String get medicationCategoryEyeEarNose => '안약·이비인후과 용제';

  @override
  String get medicationCategoryOther => '기타';

  @override
  String get antipyreticIngredientTitle => '해열제 성분';

  @override
  String get ingredientAcetaminophen => '아세트아미노펜';

  @override
  String get ingredientIbuprofen => '이부프로펜';

  @override
  String get ingredientOther => '기타';

  @override
  String get ingredientUnknown => '모름';

  @override
  String get medicationRouteTitle => '투여 방식';

  @override
  String get medicationRouteOral => '먹는 약';

  @override
  String get medicationRouteSuppository => '좌약';

  @override
  String get medicationRouteTopical => '바르는 약';

  @override
  String get medicationRouteInhaled => '흡입약';

  @override
  String get medicationRouteOther => '기타';

  @override
  String get medicationAmountLabel => '용량 및 단위 (선택)';

  @override
  String get medicationSiteLabel => '사용 부위 (선택)';

  @override
  String get antipyreticDupSameIngredientPrompt => '같은 투약을 중복 기록한 것인지 확인해 주세요';

  @override
  String get antipyreticDupDiffIngredientPrompt => '가까운 시간에 다른 성분의 해열제 기록이 있어요';

  @override
  String get antipyreticDupUnknownIngredientPrompt =>
      '이전 기록과의 확인을 위해 성분을 확인해 주세요';

  @override
  String get antipyreticDupSameEventAction => '같은 투약 기록';

  @override
  String get antipyreticDupDistinctEventAction => '별도로 투약';

  @override
  String get antipyreticDupDeferAction => '지금은 모르겠어요';

  @override
  String get antipyreticDuplicateReviewTitle => '해열제 중복·교차 확인';

  @override
  String get sttNoticeTitle => '음성 입력 전 확인';

  @override
  String get sttNoticeBody =>
      '말한 내용에는 아이의 건강이나 투약 정보가 포함될 수 있습니다.\n\n기기에 설정된 음성 인식 서비스에 따라 음성이 외부 서버로 전송될 수 있으며, 이 앱에서는 실제 처리 위치를 보장할 수 없습니다.\n\n음성 인식 서비스의 설정과 개인정보 처리 방식을 확인한 뒤, 서버 전송을 허용할 수 있거나 기기 안에서만 처리된다는 것을 확인한 경우에만 사용해 주세요.\n\n확신하기 어렵다면 키보드로 입력해 주세요.';

  @override
  String get sttNoticeAcceptAction => '확인했고 사용';

  @override
  String get sttNoticeKeyboardAction => '키보드로 입력';

  @override
  String get sttListeningStatus => '음성 듣는 중...';

  @override
  String get sttStopAction => '음성 입력 중지';

  @override
  String get sttMicButtonTooltip => '음성 메모 입력';

  @override
  String get sttNotSupportedTooltip => '현재 환경에서는 음성 입력을 지원하지 않습니다';

  @override
  String get pastNoticesTitle => '이전에 본 안내';

  @override
  String get pastNoticeSttTitle => 'Android 음성 입력 및 개인정보 처리 고지';

  @override
  String pastNoticeStatusAccepted(String date) {
    return '확인함 · $date';
  }

  @override
  String get pastNoticeStatusNotAccepted => '미확인';

  @override
  String get recheckNoticeAction => '고지문 다시 보기';

  @override
  String get trackingPreferencesTitle => '기록 방식';

  @override
  String get trackingPreferencesDescription =>
      '항목마다 자세히·하루 한 번·특이할 때만·숨기기를 선택합니다';

  @override
  String get trackingPreferencesIntro =>
      '아이의 성장과 돌봄 방식에 맞게 항목별 기록 방식을 바꿀 수 있습니다. 변경 전후 기록은 같은 수치 기준으로 직접 비교하지 않습니다.';

  @override
  String trackingModeFor(String eventName) {
    return '$eventName 기록 방식';
  }

  @override
  String get trackingModeDetailed => '매번 자세히 기록';

  @override
  String get trackingModeDailyCheckIn => '하루 한 번 간단히 기록';

  @override
  String get trackingModeNotableOnly => '특이할 때만 기록';

  @override
  String get trackingModeHidden => '빠른 기록에서 숨기기';

  @override
  String get trackingModeDetailedDescription => '개별 기록을 남기고 충분한 날짜끼리 비교합니다.';

  @override
  String get trackingModeDailyCheckInDescription =>
      '평소와 비슷·적게·많이와 메모를 하루 한 번 남깁니다.';

  @override
  String get trackingModeNotableOnlyDescription =>
      '기록이 없는 날을 정상이나 0회로 해석하지 않습니다.';

  @override
  String get trackingModeHiddenDescription => '빠른 입력에서만 숨기며 과거 기록은 유지합니다.';

  @override
  String dailyTrackingCheckInTitle(String eventName) {
    return '$eventName 오늘 기록';
  }

  @override
  String get trackingRelativeLess => '적게';

  @override
  String get trackingRelativeUsual => '평소와 비슷';

  @override
  String get trackingRelativeMore => '많이';

  @override
  String get trackingOptionalMemo => '메모 (선택)';

  @override
  String get syncConflictsTitle => '동기화 충돌 확인';

  @override
  String get syncConflictsReviewAction => '충돌 확인하기';

  @override
  String get syncConflictUnresolved => '결정 필요';

  @override
  String get syncConflictResolved => '해결됨';

  @override
  String get syncConflictLocalVersion => '이 기기';

  @override
  String get syncConflictIncomingVersion => '다른 기기';

  @override
  String get syncConflictKeepLocal => '이 기기 내용 유지';

  @override
  String get syncConflictUseIncoming => '다른 기기 내용 사용';

  @override
  String get syncConflictResolutionWarning =>
      '선택한 내용은 새 변경으로 저장되어 연결된 기기에 공유됩니다.';

  @override
  String get syncConflictResolvedKeepLocal => '이 기기 내용을 유지함';

  @override
  String get syncConflictResolvedUseIncoming => '다른 기기 내용을 사용함';

  @override
  String get syncConflictEmpty => '확인할 동기화 충돌이 없습니다.';

  @override
  String get syncConflictResolveFailed =>
      '충돌을 해결하지 못했습니다. 새로 확인한 뒤 다시 시도해 주세요.';

  @override
  String get syncConflictConfirmTitle => '이 충돌을 해결할까요?';

  @override
  String get syncConflictConfirmAction => '해결';

  @override
  String get syncConflictHistoryTitle => '해결 이력';

  @override
  String syncConflictRevision(int revision) {
    return '리비전 $revision';
  }

  @override
  String get growthChartTitle => '성장';

  @override
  String get growthChartPersonalTrendDescription =>
      '아이의 원본 측정값이 시간에 따라 어떻게 변했는지 봅니다. 측정하지 않은 기간은 추정하지 않습니다.';

  @override
  String get growthChartHeight => '키';

  @override
  String get growthChartWeight => '몸무게';

  @override
  String get growthChartHead => '머리둘레';

  @override
  String get growthChartEmpty => '아직 이 그래프에 표시할 측정값이 없습니다.';

  @override
  String growthChartPointCount(int count) {
    return '원본 측정값 $count개';
  }

  @override
  String get growthChartShowReference => '성장도표 함께 보기';

  @override
  String get growthChartProfileRequired => '백분위 계산에는 정확한 생년월일과 성별이 필요합니다.';

  @override
  String get growthChartReferenceUnavailable =>
      '현재는 개인 추세만 표시합니다. 아이 프로필과 버전이 확인된 공식 기준 데이터가 준비될 때까지 백분위는 숨깁니다.';

  @override
  String get growthChartPercentileExplanation =>
      '백분위는 같은 성별·나이의 참고 분포에서 어느 위치인지 나타냅니다. 높거나 낮은 것이 곧 좋고 나쁨을 뜻하지는 않습니다.';

  @override
  String get quickLaunchEditTitle => '퀵런치 편집';

  @override
  String get quickLaunchEditDescription => '다섯 자리에 자주 쓰는 기록과 세부값을 정해 둘 수 있어요.';

  @override
  String get quickLaunchAll => '전체';

  @override
  String get quickLaunchAdd => '추가';

  @override
  String get quickLaunchChooseEvent => '기록 항목 선택';

  @override
  String get quickLaunchChooseSlot => '바꿀 자리를 선택하세요';

  @override
  String get quickLaunchDisplayLabel => '표시 이름';

  @override
  String get quickLaunchSaveSlot => '이 자리에 저장';

  @override
  String get quickLaunchClearSlot => '자리 비우기';

  @override
  String get quickLaunchMoveLeft => '왼쪽으로 이동';

  @override
  String get quickLaunchMoveRight => '오른쪽으로 이동';

  @override
  String quickLaunchInstantSemantic(String label) {
    return '$label, 누르면 즉시 기록';
  }

  @override
  String quickLaunchFormSemantic(String label) {
    return '$label, 누르면 세부 입력 열림';
  }

  @override
  String quickLaunchCategorySemantic(String label) {
    return '$label, 누르면 선택 열림';
  }

  @override
  String quickLaunchSaved(String label) {
    return '$label 기록을 저장했어요.';
  }

  @override
  String get quickLaunchPresetAmount => '미리 기록할 양';

  @override
  String quickLaunchRecommendationTitle(String childName, String stage) {
    return '$childName의 $stage 퀵런치를 바꿔볼까요?';
  }

  @override
  String get quickLaunchRecommendationDescription =>
      '현재 설정과 추천을 비교한 뒤 원하는 자리만 바꿀 수 있어요. 기록 방식이나 돌봄 시기를 판단하는 안내는 아닙니다.';

  @override
  String get quickLaunchViewChanges => '변경 내용 보기';

  @override
  String get quickLaunchLater => '나중에';

  @override
  String get quickLaunchSkipStage => '이번 단계 건너뛰기';

  @override
  String get quickLaunchApplyAll => '모두 적용';

  @override
  String get quickLaunchApplySelected => '선택 적용';

  @override
  String get quickLaunchCurrent => '현재';

  @override
  String get quickLaunchSuggested => '추천';

  @override
  String get quickLaunchKeep => '유지';

  @override
  String get quickLaunchRecommendationApplied => '추천 퀵런치를 적용했어요.';

  @override
  String get quickLaunchRecommendationUndone => '이전 퀵런치로 되돌렸어요.';

  @override
  String get growthStageNewborn => '신생아';

  @override
  String get growthStageMonth3 => '생후 3개월';

  @override
  String get growthStageMonth6 => '생후 6개월';

  @override
  String get growthStageYear1 => '첫돌';

  @override
  String get childProfilesTitle => '아이 정보';

  @override
  String get childProfilesDescription => '아이마다 이름과 생년월일, 퀵런치를 따로 관리합니다.';

  @override
  String get addChildProfile => '아이 추가';

  @override
  String get editChildProfile => '아이 정보 수정';

  @override
  String get childNameLabel => '아이 이름';

  @override
  String get childBirthDateLabel => '생년월일 (선택)';

  @override
  String get childBirthDateUnknown => '생년월일 입력 안 함';

  @override
  String get selectChildProfile => '현재 기록할 아이로 선택';

  @override
  String get selectedChildProfile => '현재 기록 중';

  @override
  String get deleteChildProfile => '아이 삭제';

  @override
  String get lastChildCannotDelete => '마지막 아이는 삭제할 수 없어요.';
}
