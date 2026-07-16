// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'ふくちゃん日記';

  @override
  String get noDiaryTitle => '作成された日記がありません。';

  @override
  String get noDiaryDesc => '下の＋ボタンを押して最初の日記を書いてみましょう。';

  @override
  String get newDiary => '新しい日記を作成';

  @override
  String get editDiary => '日記を編集';

  @override
  String get titleLabel => 'タイトル (任意)';

  @override
  String get titleHint => '空白の場合、AIが自動でタイトルを生成します。';

  @override
  String get contentLabel => '内容';

  @override
  String get contentHint => '今日一日どんなことがありましたか？自由に書いてください。';

  @override
  String get delete => '削除';

  @override
  String get cancel => 'キャンセル';

  @override
  String get confirm => '確認';

  @override
  String get edit => '修正';

  @override
  String get diaryAdded => '新しい日記が追加されました。';

  @override
  String get diaryUpdated => '日記が修正されました。';

  @override
  String get diaryDeleted => '日記が削除されました。';

  @override
  String get deleteConfirmTitle => '日記の削除';

  @override
  String get deleteConfirmDesc => '本当にこの日記を削除しますか？削除後は元に戻せません。';

  @override
  String get searchHint => '過去の記録を検索します。';

  @override
  String similarCount(int count) {
    return '類似した日記 $count件';
  }

  @override
  String get noSimilarDiary => '類似した日記はありません。';

  @override
  String get settings => '設定';

  @override
  String get settingsTitle => '設定';

  @override
  String get languageSetting => '言語設定';

  @override
  String get languageSystem => 'システム設定';

  @override
  String get languageKorean => '한국어(Korean)';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語(Japanese)';

  @override
  String get close => '閉じる';

  @override
  String get llmModelError => 'モデルファイルが見つかりません。タイトルの自動生成が無効になっています。';
}
