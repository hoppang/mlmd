import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/objectbox_helper.dart';
import 'models/diary_entity.dart';
import 'repositories/diary_repository.dart';

void main() async {
  // Flutter의 바인딩을 먼저 초기화합니다.
  WidgetsFlutterBinding.ensureInitialized();

  // 1. ObjectBoxHelper 비동기 초기화
  final obxHelper = await ObjectBoxHelper.create();

  runApp(
    ProviderScope(
      overrides: [
        // 2. Riverpod 프로바이더 오버라이드 등록
        objectBoxProvider.overrideWithValue(obxHelper),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MLMD App',
      debugShowCheckedModeBanner: false,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaries = ref.watch(diaryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MLMD - 일기 목록',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade700,
        elevation: 4,
        centerTitle: true,
      ),
      body: diaries.isEmpty
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
                  const Text(
                    '작성된 일기가 없습니다.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '하단의 + 버튼을 눌러 첫 일기를 작성해 보세요.',
                    style: TextStyle(color: Colors.grey),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(context),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('새 일기 작성'),
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
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.diary?.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (widget.diary != null) {
      ref.read(diaryListProvider.notifier).updateDiary(widget.diary!, text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('일기가 수정되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ref.read(diaryListProvider.notifier).addDiary(text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('새 일기가 추가되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    Navigator.pop(context);
  }

  void _onDelete() {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일기 삭제'),
        content: const Text('이 일기를 정말 삭제하시겠습니까? 삭제 후에는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (!mounted) return;
      if (confirmed == true) {
        ref.read(diaryListProvider.notifier).deleteDiary(widget.diary!.id);
        Navigator.pop(context); // 수정 대화상자 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('일기가 삭제되었습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.diary != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        isEdit ? '일기 수정' : '새 일기 작성',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _controller,
          maxLines: 6,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '오늘 하루 어떤 일이 있었나요? 자유롭게 입력해 주세요.',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
            ),
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
                label: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(isEdit ? '수정' : '확인'),
            ),
          ],
        ),
      ],
    );
  }
}

