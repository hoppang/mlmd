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
  String get titleHint => '空白の場合、内容の最初の行をタイトルにします。';

  @override
  String get contentLabel => '内容（原文）';

  @override
  String get contentHint => '今日一日どんなことがありましたか？自由に書いてください。';

  @override
  String get summaryLabel => 'まとめ';

  @override
  String get summaryHint => '今日を1〜3文でまとめてください。';

  @override
  String get simpleModeLabel => '簡単入力';

  @override
  String get manualModeLabel => '直接入力';

  @override
  String get analyzeButton => 'AIで整理';

  @override
  String get analyzingLabel => 'AIが記録を整理しています…';

  @override
  String get saveRecord => '保存';

  @override
  String get aiUnavailableDescription => '現在AIを使用できません。元の記録はそのまま保存できます。';

  @override
  String get aiAnalysisFailed => 'AI整理に失敗しました。元の文章はそのまま残っています。';

  @override
  String get retryAiAnalysis => 'AI整理を再試行';

  @override
  String get aiAnalysisApplied => 'AI整理の結果を適用しました。入力した元の文章はそのまま保存されます。';

  @override
  String get previewSection => '分析結果のプレビュー';

  @override
  String get addEventButton => 'イベント追加';

  @override
  String get eventTypeLabel => '種類';

  @override
  String get eventTypeHint => '例: 授乳、睡眠、病院';

  @override
  String get eventDetailLabel => '詳細';

  @override
  String get eventDetailHint => '例: [7, 9, 11]時、小児科外来';

  @override
  String get recordTimeLabel => '記録時刻';

  @override
  String get eventTimeUnknown => '発生時刻不明';

  @override
  String get clearEventTime => '発生時刻を消去';

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
  String get todayTab => '今日';

  @override
  String get dateTab => '日付別';

  @override
  String get todayTimelineTitle => '今日の記録';

  @override
  String get todayStatusTitle => '今日の状況';

  @override
  String get startupLoading => 'アプリを準備しています...';

  @override
  String get startupErrorTitle => '初期化中に問題が発生しました';

  @override
  String get startupRetry => '再試行';

  @override
  String get startupResetData => 'すべてのデータを初期化';

  @override
  String get startupResetConfirmMessage =>
      '本当にすべてのデータを削除して最初からやり直しますか？\nこの操作は元に戻せません。';

  @override
  String get searchTab => '検索';

  @override
  String get searchTitle => '記録を検索';

  @override
  String get searchHint => 'メモやイベントを検索してください。';

  @override
  String get searchAction => '検索';

  @override
  String get searchIntroTitle => '過去の記録を探す';

  @override
  String get searchIntroDescription => 'メモの内容や授乳、投薬などのイベント名で検索できます。';

  @override
  String searchResultCount(int count) {
    return '検索結果 $count件';
  }

  @override
  String get searchNoResults => '一致する記録がありません。';

  @override
  String get searchNoResultsHint => '検索語を短くするか、別の表現を試してください。';

  @override
  String get searchFailed => '検索できませんでした。元の記録は変更されていません。';

  @override
  String get retrySearch => 'もう一度検索';

  @override
  String get searchSortLabel => '並び順';

  @override
  String get searchSortRelevance => '関連度順';

  @override
  String get searchSortNewest => '新しい順';

  @override
  String get searchSortOldest => '古い順';

  @override
  String get searchMatchExact => '完全一致';

  @override
  String get searchMatchActivityType => 'イベント種類の一致';

  @override
  String get searchMatchRelated => '関連する表現';

  @override
  String get searchMemoResult => 'メモ';

  @override
  String get searchActivityResult => 'イベント';

  @override
  String get searchReadOnly => '読み取り専用';

  @override
  String get searchResultDetail => '検索結果の詳細';

  @override
  String get settings => '設定';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsIntro => '必要な情報とデータの保管方法だけをここで管理します。';

  @override
  String get childInformation => '子どもの情報';

  @override
  String get childInformationDescription => '子どもの情報を記録に紐づける機能は準備中です。';

  @override
  String get authorProfile => '自分の名前と色';

  @override
  String get authorProfileDescription => '記録の作成者表示は準備中です。';

  @override
  String get familySharing => '家族と一緒に使う';

  @override
  String get familySharingDescription => '現在、記録はこの端末にのみ保存されます。';

  @override
  String get dataBackupTitle => 'データ保管とバックアップ';

  @override
  String get dataBackupDescription => '記録をファイルに保管し、安全に読み込みます。';

  @override
  String get helpTitle => 'ヘルプ';

  @override
  String get helpDescription => 'アプリの動作理由と言語設定を確認します。';

  @override
  String get notAvailableYetTitle => 'まだ準備中です';

  @override
  String notAvailableYetDescription(String feature) {
    return '$featureは、必要なデータ構造と安全基準を整えてから提供する予定です。';
  }

  @override
  String get storageSummaryTitle => '現在のバックアップ範囲';

  @override
  String backupContentsSummary(int records, int activities, String size) {
    return '日記 $records件 · 活動 $activities件\n推定ファイルサイズ $size';
  }

  @override
  String get backupPrivacyNotice =>
      '現在のバックアップは記録と活動を暗号化されていないJSONファイルに保存します。添付ファイルにはまだ対応していません。';

  @override
  String get createBackupFile => 'バックアップファイルを作成';

  @override
  String get createBackupDescription => 'この端末の記録と活動を別の場所に保管できるファイルにします。';

  @override
  String get importBackupFile => 'バックアップファイルを読み込む';

  @override
  String get importBackupDescription => '追加する前に内容と競合の可能性を確認できます。';

  @override
  String get recentlyDeleted => '最近削除した記録';

  @override
  String get recentlyDeletedDescription => '復元できる削除機能はまだ準備中です。';

  @override
  String get helpIntro => 'ボタンの場所だけでなく、なぜこのように動作するかを説明します。';

  @override
  String get offlineHelpQuestion => 'なぜインターネットがなくても記録できますか？';

  @override
  String get offlineHelpAnswer =>
      '記録はまずこの端末に保存されます。ネットワークやAI機能に問題があっても、元の記録を作成して探すことができます。';

  @override
  String get duplicateHelpQuestion => 'なぜ読み込んだ記録を自動で上書きしないのですか？';

  @override
  String get duplicateHelpAnswer =>
      '内容が異なる場合、どちらかを自動で消すのは安全ではありません。現在は新しい記録だけを追加し、同じIDの記録はスキップします。';

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
  String get llmModelError => 'モデルファイルが見つかりません。AI分析が無効になっています。';

  @override
  String get dataManagement => 'データ管理';

  @override
  String get dataManagementDescription => 'すべての日記と活動をバックアップまたは復元します。';

  @override
  String get exportDiary => '日記をエクスポート';

  @override
  String get importDiary => '日記をインポート';

  @override
  String get exportWarningTitle => '平文バックアップのエクスポート';

  @override
  String exportWarning(int count) {
    return '$count件の日記のタイトル、要約、本文、活動が暗号化されていないファイルに保存されます。';
  }

  @override
  String get exporting => 'バックアップファイルを作成しています…';

  @override
  String get importing => '日記をインポートしています…';

  @override
  String exportSuccess(int count, int version, String fileName) {
    return '$count件をv$versionバックアップとしてエクスポートしました。\n$fileName';
  }

  @override
  String get importPreviewTitle => 'インポートのプレビュー';

  @override
  String backupInfo(int version, String appVersion, String exportedAt) {
    return 'バックアップ v$version · アプリ $appVersion\n作成: $exportedAt';
  }

  @override
  String importCounts(int total, int activities) {
    return '日記 $total件 · 活動 $activities件';
  }

  @override
  String get newRecords => '新しい日記';

  @override
  String get duplicateRecords => '重複';

  @override
  String get identicalRecords => '同じ内容';

  @override
  String get conflictingRecords => '確認が必要な競合';

  @override
  String importDateRange(String from, String to) {
    return '記録期間: $from ～ $to';
  }

  @override
  String get safeImportNotice =>
      '読み込み直前に現在の記録を自動でバックアップします。既存の記録は上書きせず、新しい記録だけを追加します。';

  @override
  String get newerRecords => '新しいバックアップで更新';

  @override
  String get skippedRecords => 'スキップ';

  @override
  String get conflictPolicy => '重複の処理';

  @override
  String get skipExisting => '既存の日記をスキップ';

  @override
  String get overwriteIfNewer => 'バックアップが新しい場合のみ上書き';

  @override
  String get importAction => 'インポート';

  @override
  String importResult(int inserted, int updated, int skipped) {
    return '追加 $inserted件 · 更新 $updated件 · スキップ $skipped件';
  }

  @override
  String embeddingFailed(int count) {
    return '$count件の検索インデックスは後で再生成する必要があります。';
  }

  @override
  String get transferError => 'バックアップを処理できませんでした。ファイル形式と空き容量を確認してください。';

  @override
  String get draftSaving => '下書きを保存中…';

  @override
  String get draftSaved => '下書きを保存しました';

  @override
  String get draftSaveFailed => '下書きを保存できませんでした';

  @override
  String get draftSourceChanged => 'この下書きの作成後に元の記録が変更されました。保存前に内容を確認してください。';

  @override
  String get discardDraft => '下書きを破棄';

  @override
  String get discardDraftTitle => 'この下書きを破棄しますか？';

  @override
  String get discardDraftDescription => '作成中の内容は復元できません。';

  @override
  String draftsInProgress(int count) {
    return '作成中の記録 $count件';
  }

  @override
  String get continueWriting => '続きを書く';

  @override
  String get startNewDraft => '新しく作成';
}
