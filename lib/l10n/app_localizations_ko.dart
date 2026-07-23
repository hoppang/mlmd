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
  String get vaccinationEvent => '예방접종';

  @override
  String get accidentInjuryEvent => '사고·다침';

  @override
  String get tummyTimeEvent => '터미타임';

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
  String get searchNoResultsHint => '검색어를 줄이거나 다른 표현으로 다시 찾아보세요.';

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
  String get authorProfileDescription => '기록 작성자 표시는 아직 준비 중이에요.';

  @override
  String get familySharing => '가족과 함께 쓰기';

  @override
  String get familySharingDescription => '현재 기록은 이 기기에만 저장됩니다.';

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
      '현재 백업은 기록과 활동을 암호화되지 않은 JSON 파일로 보관합니다. 첨부파일 기능은 아직 포함되지 않습니다.';

  @override
  String get createBackupFile => '백업 파일 만들기';

  @override
  String get createBackupDescription =>
      '현재 기기의 기록과 활동을 다른 곳에 보관할 수 있는 파일로 만듭니다.';

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
}
