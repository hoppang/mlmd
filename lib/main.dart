import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/objectbox_helper.dart';
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const DiaryDemoPage(),
    );
  }
}

class DiaryDemoPage extends ConsumerWidget {
  const DiaryDemoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 레포지토리 주입 테스트
    final diaryRepository = ref.watch(diaryRepositoryProvider);
    final diaries = diaryRepository.getDiaries();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MLMD - 일기 목록'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: diaries.isEmpty
          ? const Center(child: Text('작성된 일기가 없습니다.'))
          : ListView.builder(
              itemCount: diaries.length,
              itemBuilder: (context, index) {
                final diary = diaries[index];
                return ListTile(
                  title: Text(diary.title),
                  subtitle: Text('최종 수정: ${diary.lastModified}'),
                );
              },
            ),
    );
  }
}
