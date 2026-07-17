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
}
