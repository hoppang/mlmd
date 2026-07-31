import 'package:flutter/foundation.dart';
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

  testWidgets('Android에서는 공통 내용을 하단 시트로 열고 결과를 반환한다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    String? result;
    await pumpLauncher(tester, onResult: (value) => result = value);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('공통 상세 내용'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete-detail')));
    await tester.pumpAndSettle();
    expect(result, 'completed');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows에서는 같은 내용과 결과를 중앙 대화상자로 유지한다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    String? result;
    await pumpLauncher(tester, onResult: (value) => result = value);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('공통 상세 내용'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete-detail')));
    await tester.pumpAndSettle();
    expect(result, 'completed');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows expanded detail fills the window with a safe inset', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await pumpLauncher(tester, onResult: (_) {}, expandedDialog: true);

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    final dialog = find.byKey(const Key('expanded-adaptive-detail-dialog'));
    expect(dialog, findsOneWidget);
    final surface = find.byKey(const Key('expanded-adaptive-detail-surface'));
    expect(surface, findsOneWidget);
    expect(tester.getSize(surface), const Size(752, 552));
    debugDefaultTargetPlatformOverride = null;
  });
}
