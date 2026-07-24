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
  String get recordAction => '記録する';

  @override
  String get recordSheetTitle => '何を記録しますか？';

  @override
  String get quickRecordsTitle => 'クイック記録';

  @override
  String get recentRecordsTitle => '最近使った項目';

  @override
  String get allCategoriesTitle => 'すべてのカテゴリー';

  @override
  String get basicCareCategory => '基本ケア';

  @override
  String get healthMedicalCategory => '健康・医療';

  @override
  String get activityPlayCategory => '活動・遊び';

  @override
  String get growthMemoryCategory => '成長・思い出';

  @override
  String get feedingEvent => '授乳';

  @override
  String get mealEvent => '離乳食・食事';

  @override
  String get waterSnackEvent => '水分・おやつ';

  @override
  String get waterEvent => '水分';

  @override
  String get snackEvent => 'おやつ';

  @override
  String get feedingMethodLabel => '授乳方法';

  @override
  String get breastFeedingOption => '母乳';

  @override
  String get bottleFeedingOption => '哺乳瓶';

  @override
  String get feedingTimeOnlyOption => '時刻のみ';

  @override
  String get breastSideLabel => '授乳した側';

  @override
  String get leftSideOption => '左';

  @override
  String get rightSideOption => '右';

  @override
  String get bottleContentsLabel => '哺乳瓶の内容';

  @override
  String get formulaOption => 'ミルク';

  @override
  String get expressedMilkOption => '搾乳';

  @override
  String get otherOption => 'その他';

  @override
  String get amountStyleLabel => '飲食量';

  @override
  String get qualitativeAmountOption => '感覚で';

  @override
  String get fractionAmountOption => '提供量に対して';

  @override
  String get exactAmountOption => '正確な量';

  @override
  String get sipAmountOption => 'ひと口';

  @override
  String get biteAmountOption => '味見だけ';

  @override
  String get littleAmountOption => '少し';

  @override
  String get normalAmountOption => '普通';

  @override
  String get muchAmountOption => 'たくさん';

  @override
  String get quarterAmountOption => '¼';

  @override
  String get halfAmountOption => '半分';

  @override
  String get almostAllAmountOption => 'ほぼ全部';

  @override
  String get allAmountOption => '全部';

  @override
  String get exactAmountLabel => '量';

  @override
  String get amountUnitLabel => '単位';

  @override
  String get mealTypeLabel => '食事区分';

  @override
  String get breakfastOption => '朝食';

  @override
  String get lunchOption => '昼食';

  @override
  String get dinnerOption => '夕食';

  @override
  String get foodNameLabel => '食べ物（任意）';

  @override
  String get snackNameLabel => 'おやつ名（任意）';

  @override
  String get reactionLabel => '反応（任意）';

  @override
  String get ateWellOption => 'よく食べた';

  @override
  String get averageReactionOption => '普通';

  @override
  String get refusedOption => '拒否';

  @override
  String get memoOptionalLabel => 'メモ（任意）';

  @override
  String get cupAmountOption => 'カップ基準';

  @override
  String get cupAmountInfoTitle => 'カップ単位について';

  @override
  String get cupAmountInfoBody =>
      'ベビー用カップは製品ごとに異なりますが、200mL前後のものが多いです。カップ単位は目安であり、正確なmLには換算しません。';

  @override
  String get exactAmountRequired => '0より大きい量を入力してください。';

  @override
  String get sleepEvent => '睡眠';

  @override
  String get diaperEvent => 'おむつ・排便';

  @override
  String get pumpingEvent => '搾乳';

  @override
  String get temperatureEvent => '体温';

  @override
  String get medicationEvent => '投薬';

  @override
  String get symptomEvent => '症状・体調';

  @override
  String get hospitalEvent => '通院・相談';

  @override
  String get vaccinationEvent => '予防接種';

  @override
  String get accidentInjuryEvent => '事故・けが';

  @override
  String get tummyTimeEvent => 'タミータイム';

  @override
  String get bathEvent => '入浴';

  @override
  String get growthMeasurementEvent => '身長・体重測定';

  @override
  String get memoEvent => 'メモ';

  @override
  String get eventDetailOptionalLabel => '詳細（任意）';

  @override
  String get eventDetailOptionalHint => '量、状態、短いメモを入力できます。';

  @override
  String get writeDetailedRecord => '長いメモとAI整理';

  @override
  String get backToRecordTypes => '記録の種類に戻る';

  @override
  String get savingQuickRecord => '保存中…';

  @override
  String get quickRecordSaveFailed => '記録を保存できませんでした。入力内容は保持されています。';

  @override
  String quickRecordSaved(String type) {
    return '$typeを記録しました。';
  }

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
  String get searchNoResultsHint => '検索条件は保持されます。期間を広げるか、条件を一つずつ外してください。';

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
  String get searchMatchTemperature => '体温条件に一致';

  @override
  String get searchMatchAuthor => '作成者条件に一致';

  @override
  String get searchMatchEvent => 'イベント条件に一致';

  @override
  String get searchMatchDate => '日付条件に一致';

  @override
  String get searchFilters => '検索条件';

  @override
  String get searchClearFilters => '条件をクリア';

  @override
  String get searchApplyFilters => '条件を適用';

  @override
  String get searchDate => '日付';

  @override
  String get searchAll => 'すべて';

  @override
  String get searchAllDates => '全期間';

  @override
  String get searchToday => '今日';

  @override
  String get searchLast7Days => '過去7日';

  @override
  String get searchLast30Days => '過去30日';

  @override
  String get searchCustomDate => '期間を指定';

  @override
  String get searchEventType => 'イベント種類';

  @override
  String get searchAuthor => '作成者';

  @override
  String get searchTemperature => '最低体温';

  @override
  String searchTemperatureAtLeast(String value) {
    return '$value°C以上';
  }

  @override
  String get searchEventTemperature => '体温';

  @override
  String get searchEventMedication => '投薬';

  @override
  String get searchEventFeeding => '授乳';

  @override
  String get searchEventDiaper => 'おむつ';

  @override
  String get searchEventSleep => '睡眠';

  @override
  String get searchEventHospital => '病院・診療';

  @override
  String get searchSemanticUnavailable =>
      '意味検索が利用できない場合や索引作成中でも、文言・条件検索は利用できます。';

  @override
  String get searchSameDayContext => '同じ日の他の記録';

  @override
  String get searchSameDayContextHint => '文脈のための表示であり、原因や関連性を示すものではありません。';

  @override
  String get dailyAiSummary => 'AI日次まとめ';

  @override
  String get weeklyAiSummary => 'AI週間まとめ';

  @override
  String get summarizeDay => 'この日をまとめる';

  @override
  String get summarizeWeek => 'この週をまとめる';

  @override
  String get summarizeWeekSoFar => '現在までをまとめる';

  @override
  String get summaryGenerating => '元の記録をもとにまとめています…';

  @override
  String get summaryUnavailable => 'AIまとめは利用できません。元の記録と計算済みの状況はそのまま確認できます。';

  @override
  String get summaryFailed => 'まとめを作成できませんでした。元の記録は変更されていません。';

  @override
  String get summaryNoRecords => 'まとめる元の記録がありません。';

  @override
  String summaryBasis(int count, String time) {
    return '$timeまでの元の記録$count件に基づく';
  }

  @override
  String get summaryNewRecords => 'このまとめの後に新しい記録があります。';

  @override
  String get summarySourceChanged => 'このまとめに使用した元の記録が変更されました。';

  @override
  String get summaryEdited => '手動で編集済み';

  @override
  String get summaryEvidence => '元の記録を見る';

  @override
  String get summaryEvidenceTitle => 'まとめに使用した元の記録';

  @override
  String get summaryEditTitle => 'まとめを編集';

  @override
  String get summaryHide => '非表示';

  @override
  String get summaryRestore => 'まとめを再表示';

  @override
  String get summaryRegenerate => 'もう一度作成';

  @override
  String get summaryPreviewTitle => '新しいまとめを確認';

  @override
  String get summaryReplace => '新しいまとめに置換';

  @override
  String get weeklyAutoSummary => '週間AIまとめの自動作成';

  @override
  String get weeklyAutoSummaryDescription => '月曜から日曜までの完了した週を、端末内AIで静かにまとめます。';

  @override
  String get medicalBriefingTitle => '受診前ブリーフィング';

  @override
  String get medicalBriefingDescription =>
      '受診前に記録した体温、投薬、症状、受診、予防接種、事故・けがの事実を確認します。';

  @override
  String get briefingSafetyNotice =>
      '記録された事実のみを表示します。診断、因果関係、治療の助言は行いません。重要な内容は元の記録で再確認してください。';

  @override
  String get briefingPeriod => 'ブリーフィング期間';

  @override
  String briefingDateRange(String from, String to) {
    return '$from～$to';
  }

  @override
  String briefingFactCount(int count) {
    return '記録された事実$count件';
  }

  @override
  String get briefingNoFacts => '条件に合う健康記録がありません。';

  @override
  String get briefingNoFactsHint =>
      '期間をそのままにするか、広げてください。一般メモや医療以外のイベントを医療上の事実として推測しません。';

  @override
  String get briefingCopy => 'ブリーフィングをコピー';

  @override
  String get briefingCopied => 'ブリーフィングをコピーしました。';

  @override
  String get briefingShare => 'ブリーフィングを共有';

  @override
  String get briefingOpenOriginal => '元の記録を開く';

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
  String get authorProfileDescription => '新しい記録に使う作成者名と色を管理します。';

  @override
  String get authorSetupTitle => 'この端末で誰が記録しますか？';

  @override
  String get authorSetupDescription =>
      '家族が分かる名前と色を選んでください。実名でなくてもよく、新しい記録に自動で適用されます。';

  @override
  String get authorNicknameLabel => '作成者名';

  @override
  String get authorNicknameHint => '例：ママ、パパ、おばあちゃん';

  @override
  String get authorColorLabel => '個人カラー';

  @override
  String get authorSave => 'この名前で始める';

  @override
  String get authorAdd => '作成者を追加';

  @override
  String get authorEdit => '作成者を編集';

  @override
  String get authorProfilesTitle => '作成者プロフィール';

  @override
  String get authorCurrent => '現在の作成者';

  @override
  String get authorUseProfile => 'この作成者に切り替える';

  @override
  String get authorNicknameError => '1〜30文字の名前を入力してください。';

  @override
  String get authorProfileLocalNotice =>
      '通常は現在の作成者が自動で適用されます。同じ端末を複数人で使う場合だけ切り替えてください。';

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

  @override
  String recordCreatedBy(String nickname) {
    return '作成者 $nickname';
  }

  @override
  String get recordSourceDetails => '記録元';

  @override
  String recordSourceDevice(String deviceId) {
    return '入力端末 $deviceId';
  }

  @override
  String get duplicateReviewTitle => '確認する記録';

  @override
  String get duplicateReviewDescription =>
      '別の端末で同じ時刻・内容として保存された元記録を比較します。確認前に結合や削除は行いません。';

  @override
  String duplicateReviewBanner(int count) {
    return '確認する記録 $count件';
  }

  @override
  String get duplicateReviewBannerHint => '同じ出来事か確認してください。';

  @override
  String duplicatePendingCount(int count) {
    return '要確認 $count件';
  }

  @override
  String get duplicateResolvedTitle => '確認済みの記録';

  @override
  String get duplicateNeedsReview => '似た記録2件';

  @override
  String get duplicateExactReason => '種類、発生時刻、内容が同じで、入力端末が異なります。';

  @override
  String duplicateUseSource(int number) {
    return '$number番を基準に1件として表示';
  }

  @override
  String get duplicateMarkDistinct => '1番と2番は別の出来事';

  @override
  String get duplicateReviewLater => '後で確認';

  @override
  String get duplicateSameEvent => '同じ出来事として確認済み';

  @override
  String get duplicateDistinctEvents => '別の出来事として確認済み';

  @override
  String get duplicateDecisionSaved => '判断を保存しました。元の記録は変更されません。';

  @override
  String get duplicateChangeDecision => '重複判断を変更';

  @override
  String get duplicateReviewEmpty => '確認する記録はありません';

  @override
  String get duplicateReviewEmptyHint => '新しい候補は「今日」に表示されます。';

  @override
  String get myRecordsTitle => '自分の記録';

  @override
  String get createCustomEvent => '新しい記録を作成';

  @override
  String get customEventNameLabel => '記録名';

  @override
  String get customEventNameHint => '例：ビタミン、散歩の準備';

  @override
  String get customEventNameRequired => '名前を入力してください。';

  @override
  String get customEventMemoOptionalLabel => 'メモ（任意）';

  @override
  String get customEventMemoOptionalHint => '必要な内容だけを短く残してください。';

  @override
  String get customEventMedicationHint =>
      '薬の場合は基本の「投薬」で薬名と用量を記録できます。この記録もそのまま作成できます。';

  @override
  String get pinToQuickRecords => 'クイック記録に固定';

  @override
  String get removeFromQuickRecords => 'クイック記録から解除';

  @override
  String get renameCustomEvent => '名前を変更';

  @override
  String get archiveCustomEvent => 'アーカイブ';

  @override
  String get archiveCustomEventTitle => 'この記録タイプをアーカイブしますか？';

  @override
  String archiveCustomEventDescription(String name) {
    return '「$name」は自分の記録から非表示になりますが、過去の記録はそのまま残ります。';
  }
}
