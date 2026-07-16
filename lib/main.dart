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
import 'services/llm_title_service.dart';
import 'widgets/similar_diary_panel.dart';
import 'providers/locale_provider.dart';

void main() async {
  // Flutter의 바인딩을 먼저 초기화합니다.
  WidgetsFlutterBinding.ensureInitialized();

  // 1. flutter_gemma 초기화 (LiteRT-LM 엔진 등록)
  await FlutterGemma.initialize(
    inferenceEngines: [LiteRtLmEngine()],
  );

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
    print('[LLM] 모델 파일을 찾을 수 없습니다. 제목 자동 생성이 비활성화됩니다.');
    print('[LLM] 다음 위치에 파일을 놓아주세요: ${candidatePaths.join(", ")}');
    if (FlutterGemma.hasActiveModel()) {
      await FlutterGemma.clearActiveInferenceIdentity();
    }
    return;
  }

  if (FlutterGemma.hasActiveModel()) {
    print('[LLM] 기존 모델 등록 초기화 (fileType 재설정)...');
    await FlutterGemma.clearActiveInferenceIdentity();
  }

  print('[LLM] 모델 파일 발견: $foundPath — 등록 중...');
  try {
    await FlutterGemma.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(foundPath).install();
    print('[LLM] 모델 등록 완료.');
  } catch (e) {
    print('[LLM] 모델 등록 실패: $e');
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
      supportedLocales: const [
        Locale('ko'),
        Locale('en'),
        Locale('ja'),
      ],
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

class DiaryDemoPage extends ConsumerWidget {
  const DiaryDemoPage({super.key});

  void _showFormDialog(BuildContext context, [DiaryEntity? diary]) {
    showDialog(
      context: context,
      builder: (context) => DiaryFormDialog(diary: diary),
    );
  }

  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final currentMode = ref.watch(localeProvider);
            final loc = AppLocalizations.of(context)!;

            return AlertDialog(
              title: Text(loc.settingsTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.languageSetting, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AppLocaleMode>(
                    value: currentMode,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(loc.close, style: const TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaries = ref.watch(diaryListProvider);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loc.appTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade700,
        elevation: 4,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => _showSettingsDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SimilarDiaryPanel(
              onDiaryTap: (diary) => _showFormDialog(context, diary),
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
                            onTap: () => _showFormDialog(context, diary),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          diary.lastModified.toString().substring(0, 10),
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
                                    diary.content,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
        onPressed: () => _showFormDialog(context),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(loc.newDiary),
      ),
    );
  }
}

/// 일기 작성 및 수정을 위한 다이얼로그
class DiaryFormDialog extends ConsumerStatefulWidget {
  final DiaryEntity? diary;

  const DiaryFormDialog({
    super.key,
    this.diary,
  });

  @override
  ConsumerState<DiaryFormDialog> createState() => _DiaryFormDialogState();
}

class _DiaryFormDialogState extends ConsumerState<DiaryFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _isGeneratingTitle = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.diary?.title);
    _contentController = TextEditingController(text: widget.diary?.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onConfirm() async {
    final loc = AppLocalizations.of(context)!;
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    String title = _titleController.text.trim();

    // 제목 미입력 시 LLM으로 자동 생성
    if (title.isEmpty) {
      setState(() => _isGeneratingTitle = true);
      try {
        final currentLocale = Localizations.localeOf(context).languageCode;
        title = await LlmTitleService().generate(
          content,
          fallback: content.length > 20 ? content.substring(0, 20) : content,
          languageCode: currentLocale,
        );
      } finally {
        if (mounted) setState(() => _isGeneratingTitle = false);
      }
    }

    if (!mounted) return;

    if (widget.diary != null) {
      ref.read(diaryListProvider.notifier).updateDiary(widget.diary!, title, content);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.diaryUpdated),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ref.read(diaryListProvider.notifier).addDiary(title, content);
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
        Navigator.pop(context); // 수정 대화상자 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.diaryDeleted),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.diary != null;
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        isEdit ? loc.editDiary : loc.newDiary,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                autofocus: !isEdit,
                decoration: InputDecoration(
                  hintText: loc.titleHint,
                  labelText: loc.titleLabel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
                  ),
                  suffixIcon: _isGeneratingTitle
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contentController,
                maxLines: 6,
                autofocus: isEdit,
                decoration: InputDecoration(
                  hintText: loc.contentHint,
                  labelText: loc.contentLabel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            if (isEdit)
              TextButton.icon(
                onPressed: _onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(loc.delete, style: const TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.cancel, style: const TextStyle(color: Colors.grey)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isGeneratingTitle ? null : _onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isGeneratingTitle
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isEdit ? loc.edit : loc.confirm),
            ),
          ],
        ),
      ],
    );
  }
}
