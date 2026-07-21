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
