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
  String get titleHint => '비워두면 AI가 자동으로 제목을 생성합니다.';

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
  String get analyzeButton => 'AI 분석';

  @override
  String get analyzingLabel => 'AI가 분석 중입니다…';

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
  String get searchHint => '지난 기록을 찾아봅니다.';

  @override
  String similarCount(int count) {
    return '유사한 일기 $count건';
  }

  @override
  String get noSimilarDiary => '유사한 일기가 없습니다.';

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
}
