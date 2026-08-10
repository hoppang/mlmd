import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/core/presentation/adaptive_detail.dart';

void main() {
  Future<void> pumpLauncher(
    WidgetTester tester, {
    required ValueChanged<String?> onResult,
    bool expandedDialog = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                final result = await showAdaptiveDetail<String>(
                  context: context,
                  expandedDialog: expandedDialog,
                  builder: (detailContext) => Material(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('공통 상세 내용'),
                        FilledButton(
                          key: const Key('complete-detail'),
                          onPressed: () =>
                              Navigator.pop(detailContext, 'completed'),
                          child: const Text('완료'),
                        ),
                      ],
                    ),
                  ),
                );
                onResult(result);
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('공통 상세를 독립 페이지로 열고 결과를 반환한다', (tester) async {
    String? result;
    await pumpLauncher(tester, onResult: (value) => result = value);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('adaptive-detail-page')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('공통 상세 내용'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete-detail')));
    await tester.pumpAndSettle();
    expect(result, 'completed');
  });

  testWidgets('페이지 전환은 팝업 표면을 만들지 않는다', (tester) async {
    String? result;
    await pumpLauncher(tester, onResult: (value) => result = value);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('adaptive-detail-page')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('공통 상세 내용'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete-detail')));
    await tester.pumpAndSettle();
    expect(result, 'completed');
  });

  testWidgets('expanded detail also uses the full page route', (tester) async {
    await pumpLauncher(tester, onResult: (_) {}, expandedDialog: true);

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    final page = find.byKey(const Key('adaptive-detail-page'));
    expect(page, findsOneWidget);
    expect(tester.getSize(page), const Size(800, 600));
  });
}
