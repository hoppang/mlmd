import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/objectbox_helper.dart';
import 'models/diary_entity.dart';
import 'repositories/diary_repository.dart';
import 'services/embedding_service.dart';
import 'services/llm_diary_service.dart';
import 'services/llm_title_service.dart';
import 'widgets/similar_diary_panel.dart';
import 'widgets/import_preview_dialog.dart';
import 'widgets/transfer_progress_dialog.dart';
import 'providers/locale_provider.dart';
import 'utils/logger.dart';
import 'transfer/canonical_transfer_document.dart';
import 'transfer/diary_transfer_exception.dart';
import 'transfer/diary_transfer_service.dart';

void main() async {
  // Flutter의 바인딩을 먼저 초기화합니다.
  WidgetsFlutterBinding.ensureInitialized();

  // 1. flutter_gemma 초기화 (LiteRT-LM 엔진 등록)
  await FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()]);

  // 1-1. Qwen3 모델 미등록 시 로컬 파일에서 자동 등록
  await _registerModelIfNeeded();

  // 2. ObjectBoxHelper 비동기 초기화
  final obxHelper = await ObjectBoxHelper.create();

  // 3. EmbeddingService 비동기 초기화 (모델 로딩 및 토크나이저 준비)
  final embeddingService = EmbeddingService();
  await embeddingService.init();

  // 4. SharedPreferences 비동기 초기화
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        // Riverpod 프로바이더 오버라이드 등록
        objectBoxProvider.overrideWithValue(obxHelper),
        embeddingServiceProvider.overrideWithValue(embeddingService),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _registerModelIfNeeded() async {
  // flutter_gemma가 관리하는 활성 모델은 원본 다운로드 파일과 독립적입니다.
  // 이미 설치된 모델을 앱 시작마다 해제하거나 다시 설치하지 않습니다.
  if (FlutterGemma.hasActiveModel()) {
    logger.i('[LLM] 기존 활성 모델을 사용합니다.');
    return;
  }

  // 플랫폼별 탐색 경로
  final candidatePaths = <String>[
    if (Platform.isWindows)
      '${Platform.environment['USERPROFILE']}\\Downloads\\gemma4-e2b-it.litertlm',
    if (Platform.isAndroid) '/sdcard/Download/gemma4-e2b-it.litertlm',
    if (Platform.isMacOS)
      '${Platform.environment['HOME']}/Downloads/gemma4-e2b-it.litertlm',
  ];

  // 로컬 파일 탐색
  String? foundPath;
  for (final p in candidatePaths) {
    if (await File(p).exists()) {
      foundPath = p;
      break;
    }
  }

  if (foundPath == null) {
    logger.w('[LLM] 모델 파일을 찾을 수 없습니다. 제목 자동 생성이 비활성화됩니다.');
    logger.i('[LLM] 다음 위치에 파일을 놓아주세요: ${candidatePaths.join(", ")}');
    return;
  }

  logger.i('[LLM] 모델 파일 발견: $foundPath — 등록 중...');
  try {
    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(foundPath).install();
    logger.i('[LLM] 모델 등록 완료.');
  } catch (e) {
    logger.e('[LLM] 모델 등록 실패: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider.notifier).locale;
    // Watch localeProvider to trigger rebuilds when language changes
    ref.watch(localeProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en'), Locale('ja')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FA),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const DiaryDemoPage(),
    );
  }
}

class DiaryDemoPage extends ConsumerStatefulWidget {
  const DiaryDemoPage({super.key});

  @override
  ConsumerState<DiaryDemoPage> createState() => _DiaryDemoPageState();
}

class _DiaryDemoPageState extends ConsumerState<DiaryDemoPage> {
  bool _initialNavDone = false;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 이후: 오늘 일기가 있으면 상세 페이지로 자동 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialNavDone) return;
      _initialNavDone = true;
      final diaries = ref.read(diaryListProvider);
      final now = DateTime.now();
      for (final diary in diaries) {
        if (diary.date.year == now.year &&
            diary.date.month == now.month &&
            diary.date.day == now.day) {
          _navigateToFormPage(context, diary);
          break;
        }
      }
    });
  }

  void _navigateToFormPage(BuildContext context, [DiaryEntity? diary]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DiaryFormPage(diary: diary)),
    );
  }

  DiaryTransferService get _transferService =>
      DiaryTransferService(repository: ref.read(diaryRepositoryProvider));

  Future<void> _exportDiaries() async {
    final loc = AppLocalizations.of(context)!;
    final count = ref.read(diaryListProvider).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.exportWarningTitle),
        content: Text(loc.exportWarning(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.exportDiary),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    var progressShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransferProgressDialog(message: loc.exporting),
    );
    try {
      await Future<void>.delayed(Duration.zero);
      final result = await _transferService.exportToPlatform(
        dialogTitle: loc.exportDiary,
        shareSubject: loc.exportDiary,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      progressShown = false;
      if (!result.cancelled) {
        await _showTransferMessage(
          context,
          loc.exportDiary,
          loc.exportSuccess(
            result.diaryCount,
            result.schemaVersion,
            result.fileName,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _logTransferError('export', error);
      await _showTransferMessage(context, loc.exportDiary, loc.transferError);
    }
  }

  Future<void> _importDiaries() async {
    final loc = AppLocalizations.of(context)!;
    var progressShown = false;
    try {
      final service = _transferService;
      final prepared = await service.pickAndPrepareImport(
        dialogTitle: loc.importDiary,
      );
      if (prepared == null || !mounted) return;
      final policy = await showDialog<ImportConflictPolicy>(
        context: context,
        builder: (_) => ImportPreviewDialog(
          prepared: prepared,
          previewFor: (policy) => service.preview(prepared, policy),
        ),
      );
      if (policy == null || !mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TransferProgressDialog(message: loc.importing),
      );
      progressShown = true;
      await Future<void>.delayed(Duration.zero);
      final result = service.apply(prepared, policy);
      ref.read(diaryListProvider.notifier).reload();
      final embeddingFailed = await ref
          .read(diaryListProvider.notifier)
          .regenerateEmbeddings(result.affectedRecordIds);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      progressShown = false;
      final message = StringBuffer(
        loc.importResult(result.inserted, result.updated, result.skipped),
      );
      if (embeddingFailed > 0) {
        message
          ..writeln()
          ..write(loc.embeddingFailed(embeddingFailed));
      }
      await _showTransferMessage(context, loc.importDiary, message.toString());
    } catch (error) {
      if (!mounted) return;
      if (progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _logTransferError('import', error);
      await _showTransferMessage(context, loc.importDiary, loc.transferError);
    }
  }

  Future<void> _showTransferMessage(
    BuildContext context,
    String title,
    String message,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.close),
        ),
      ],
    ),
  );

  void _logTransferError(String stage, Object error) {
    final code = error is DiaryTransferException
        ? error.code
        : error.runtimeType.toString();
    logger.e('[transfer] $stage failed ($code)');
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final currentMode = ref.watch(localeProvider);
            final loc = AppLocalizations.of(context)!;

            return AlertDialog(
              title: Text(
                loc.settingsTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.languageSetting,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AppLocaleMode>(
                    initialValue: currentMode,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: AppLocaleMode.system,
                        child: Text(loc.languageSystem),
                      ),
                      DropdownMenuItem(
                        value: AppLocaleMode.korean,
                        child: Text(loc.languageKorean),
                      ),
                      DropdownMenuItem(
                        value: AppLocaleMode.english,
                        child: Text(loc.languageEnglish),
                      ),
                      DropdownMenuItem(
                        value: AppLocaleMode.japanese,
                        child: Text(loc.languageJapanese),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        ref.read(localeProvider.notifier).setLocale(mode);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    loc.dataManagement,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.dataManagementDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exportDiaries,
                          icon: const Icon(Icons.upload_file),
                          label: Text(loc.exportDiary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _importDiaries,
                          icon: const Icon(Icons.download_for_offline_outlined),
                          label: Text(loc.importDiary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    loc.close,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final diaries = ref.watch(diaryListProvider);
    final loc = AppLocalizations.of(context)!;

    final now = DateTime.now();
    DiaryEntity? todayDiary;
    for (final diary in diaries) {
      if (diary.date.year == now.year &&
          diary.date.month == now.month &&
          diary.date.day == now.day) {
        todayDiary = diary;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.appTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal.shade700,
        elevation: 4,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SimilarDiaryPanel(
              onDiaryTap: (diary) => _navigateToFormPage(context, diary),
            ),
          ),
          Expanded(
            child: diaries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.book_outlined,
                          size: 64,
                          color: Colors.teal.shade200,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.noDiaryTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.noDiaryDesc,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: diaries.length,
                    itemBuilder: (context, index) {
                      final diary = diaries[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _navigateToFormPage(context, diary),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          diary.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade50,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          diary.lastModified
                                              .toString()
                                              .substring(0, 10),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.teal.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    diary.summary.isNotEmpty
                                        ? diary.summary
                                        : diary.content,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // 이벤트 칩
                                  if (diary.activities.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _buildEventChips(diary),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToFormPage(context, todayDiary),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        icon: Icon(todayDiary != null ? Icons.edit : Icons.add),
        label: Text(todayDiary != null ? loc.edit : loc.newDiary),
      ),
    );
  }

  /// 일기 카드에 이벤트 칩을 표시합니다.
  Widget _buildEventChips(DiaryEntity diary) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: diary.activities.map((a) {
        return Chip(
          label: Text(
            '${a.type} ${a.details}',
            style: const TextStyle(fontSize: 11),
          ),
          backgroundColor: Colors.teal.shade50,
          side: BorderSide(color: Colors.teal.shade100),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

/// 일기 작성 및 수정을 위한 페이지
class DiaryFormPage extends ConsumerStatefulWidget {
  final DiaryEntity? diary;

  const DiaryFormPage({super.key, this.diary});

  @override
  ConsumerState<DiaryFormPage> createState() => _DiaryFormPageState();
}

// ---------------------------------------------------------------------------
// 입력 모드
// ---------------------------------------------------------------------------
enum _InputMode { simple, manual }

// ---------------------------------------------------------------------------
// 이벤트 항목 (UI용 가변 모델)
// ---------------------------------------------------------------------------
class _EditableActivity {
  final TextEditingController typeController;
  final TextEditingController detailController;

  _EditableActivity({required String type, required String detail})
    : typeController = TextEditingController(text: type),
      detailController = TextEditingController(text: detail);

  String get type => typeController.text.trim();
  String get detail => detailController.text.trim();

  void dispose() {
    typeController.dispose();
    detailController.dispose();
  }
}

class _DiaryFormPageState extends ConsumerState<DiaryFormPage> {
  // 공통
  late final TextEditingController _titleController;

  // 간단 입력 모드
  late final TextEditingController _rawController;
  bool _isAnalyzing = false;

  // 직접 입력 모드
  late final TextEditingController _summaryController;
  late final TextEditingController _contentController;
  final List<_EditableActivity> _activities = [];

  _InputMode _mode = _InputMode.simple;

  @override
  void initState() {
    super.initState();
    final d = widget.diary;
    _titleController = TextEditingController(text: d?.title);
    _rawController = TextEditingController(text: d?.content);
    _summaryController = TextEditingController(text: d?.summary);
    _contentController = TextEditingController(text: d?.content);

    // 수정 시 기존 이벤트 로드 + 직접 입력 모드 고정
    if (d != null) {
      for (final a in d.activities) {
        _activities.add(_EditableActivity(type: a.type, detail: a.details));
      }
      // 수정 시에는 항상 직접 입력 모드
      _mode = _InputMode.manual;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rawController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    for (final activity in _activities) {
      activity.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // AI 분석 (간단 입력 모드)
  // ---------------------------------------------------------------------------
  Future<void> _onAnalyze() async {
    final raw = _rawController.text.trim();
    if (raw.isEmpty) return;
    setState(() => _isAnalyzing = true);
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final result = await LlmDiaryService().generate(
        raw,
        languageCode: locale,
      );
      if (!mounted) return;
      setState(() {
        // 봸석 결과를 상세 필드에 반영
        _titleController.text = result.title;
        _summaryController.text = result.summary;
        for (final activity in _activities) {
          activity.dispose();
        }
        _activities
          ..clear()
          ..addAll(
            result.activities.map(
              (a) => _EditableActivity(type: a.type, detail: a.detail),
            ),
          );
        // 분석 완료 후 자동으로 상세 탭으로 전환
        _mode = _InputMode.manual;
      });
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 저장
  // ---------------------------------------------------------------------------
  Future<void> _onConfirm() async {
    final loc = AppLocalizations.of(context)!;

    if (_mode == _InputMode.simple && widget.diary == null) {
      final raw = _rawController.text.trim();
      if (raw.isEmpty) return;
      // 간단 입력 모드에서 확인(FAB) 클릭 시, LLM 분석 수행 후 상세 모드로 자동 전환 (저장 안 함)
      await _onAnalyze();
      return;
    }

    String title = _titleController.text.trim();
    // 상세 입력 모드
    String summary = _summaryController.text.trim();
    // 간단 입력한 원문은 만약을 위해 저장(content)만 하고, 수정 시 UI에선 숨겨짐
    String content = _rawController.text.trim().isNotEmpty
        ? _rawController.text.trim()
        : _synthesizeRaw();

    if (content.isEmpty && summary.isEmpty) return;

    // 제목 미입력 시 LLM
    if (title.isEmpty && (content.isNotEmpty || summary.isNotEmpty)) {
      final base = summary.isNotEmpty ? summary : content;
      final locale = Localizations.localeOf(context).languageCode;
      title = await LlmTitleService().generate(base, languageCode: locale);
    }

    List<ActivitySummary> activities = _activities
        .where((a) => a.type.isNotEmpty)
        .map((a) => ActivitySummary(type: a.type, detail: a.detail))
        .toList();

    if (!mounted) return;

    if (widget.diary != null) {
      await ref
          .read(diaryListProvider.notifier)
          .updateDiary(
            widget.diary!,
            title,
            summary,
            content,
            activitySummaries: activities,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.diaryUpdated),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await ref
          .read(diaryListProvider.notifier)
          .addDiary(title, summary, content, activitySummaries: activities);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.diaryAdded),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    Navigator.pop(context);
  }

  void _onDelete() {
    final loc = AppLocalizations.of(context)!;
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.deleteConfirmTitle),
        content: Text(loc.deleteConfirmDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text(loc.delete),
          ),
        ],
      ),
    ).then((confirmed) {
      if (!mounted) return;
      if (confirmed == true) {
        ref.read(diaryListProvider.notifier).deleteDiary(widget.diary!.id);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.diaryDeleted),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 이벤트 편집 (manual)
  // ---------------------------------------------------------------------------
  void _addActivity() {
    setState(() => _activities.add(_EditableActivity(type: '', detail: '')));
  }

  void _removeActivity(int index) {
    setState(() => _activities.removeAt(index).dispose());
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.diary != null;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? loc.editDiary : loc.newDiary,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _onDelete,
            ),
        ],
      ),
      body: Column(
        children: [
          // 모드 토글 (새 일기 작성 시에만 표시)
          if (!isEdit) _buildModeToggle(loc),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _mode == _InputMode.simple
                  ? _buildSimpleMode(loc)
                  : _buildManualMode(loc),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAnalyzing ? null : _onConfirm,
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        icon: _isAnalyzing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                (_mode == _InputMode.simple && !isEdit)
                    ? Icons.auto_awesome
                    : Icons.check,
              ),
        label: Text(
          isEdit
              ? loc.edit
              : (_mode == _InputMode.simple ? loc.analyzeButton : loc.confirm),
        ),
      ),
    );
  }

  // --- 모드 토글 ---
  Widget _buildModeToggle(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<_InputMode>(
        segments: [
          ButtonSegment(
            value: _InputMode.simple,
            label: Text(loc.simpleModeLabel),
            icon: const Icon(Icons.auto_awesome, size: 16),
          ),
          ButtonSegment(
            value: _InputMode.manual,
            label: Text(loc.manualModeLabel),
            icon: const Icon(Icons.edit_note, size: 16),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (s) {
          final newMode = s.first;
          if (newMode == _InputMode.simple && _mode == _InputMode.manual) {
            // 상세 → 간단: summary + 이벤트로 간단 입력 합성
            final synthesized = _synthesizeRaw();
            if (synthesized.isNotEmpty) {
              _rawController.text = synthesized;
            }
          }
          setState(() => _mode = newMode);
        },
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  /// 상세 필드(summary + 이벤트)를 합산하여 간단 입력 텍스트를 생성합니다.
  String _synthesizeRaw() {
    final parts = <String>[];
    final summary = _summaryController.text.trim();
    if (summary.isNotEmpty) parts.add(summary);
    final eventsStr = _activities
        .where((a) => a.type.isNotEmpty)
        .map((a) => a.detail.isNotEmpty ? '${a.type}: ${a.detail}' : a.type)
        .join('\n');
    if (eventsStr.isNotEmpty) parts.add(eventsStr);
    return parts.join('\n');
  }

  // ---------------------------------------------------------------------------
  // 간단 입력 모드 UI
  // ---------------------------------------------------------------------------
  Widget _buildSimpleMode(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        // 제목 (AI 분석 후 수정 가능)
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: loc.titleLabel,
            hintText: loc.titleHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 간단 입력 필드
        TextField(
          controller: _rawController,
          maxLines: 10,
          autofocus: widget.diary == null,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            labelText: loc.simpleModeLabel,
            hintText: loc.contentHint,
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 80), // FAB 여백
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 직접 입력 모드 UI
  // ---------------------------------------------------------------------------
  Widget _buildManualMode(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        // 제목
        TextField(
          controller: _titleController,
          autofocus: widget.diary == null,
          decoration: InputDecoration(
            labelText: loc.titleLabel,
            hintText: loc.titleHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 요약
        TextField(
          controller: _summaryController,
          maxLines: 4,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            labelText: loc.summaryLabel,
            hintText: loc.summaryHint,
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 이벤트 목록
        Row(
          children: [
            const Icon(Icons.event_note, size: 18, color: Colors.teal),
            const SizedBox(width: 6),
            Text(
              loc.eventTypeLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addActivity,
              icon: const Icon(Icons.add, size: 18),
              label: Text(loc.addEventButton),
              style: TextButton.styleFrom(foregroundColor: Colors.teal),
            ),
          ],
        ),
        ..._activities.asMap().entries.map((entry) {
          final idx = entry.key;
          final act = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // 종류
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: act.typeController,
                    decoration: InputDecoration(
                      hintText: loc.eventTypeHint,
                      labelText: loc.eventTypeLabel,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 상세
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: act.detailController,
                    decoration: InputDecoration(
                      hintText: loc.eventDetailHint,
                      labelText: loc.eventDetailLabel,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                // 삭제
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                  onPressed: () => _removeActivity(idx),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 80), // FAB 여백
      ],
    );
  }
}
