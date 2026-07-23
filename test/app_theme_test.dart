import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mlmd/core/presentation/app_empty_state.dart';
import 'package:mlmd/core/presentation/app_section_header.dart';
import 'package:mlmd/core/theme/app_theme.dart';
import 'package:mlmd/core/theme/app_tokens.dart';

void main() {
  group('app theme contract', () {
    test('uses shared colors, radii, and surfaces', () {
      final theme = buildAppTheme();

      expect(theme.useMaterial3, isTrue);
      expect(
        theme.scaffoldBackgroundColor,
        theme.colorScheme.surfaceContainerLowest,
      );
      expect(theme.appBarTheme.backgroundColor, theme.colorScheme.primary);
      expect(theme.appBarTheme.foregroundColor, theme.colorScheme.onPrimary);
      expect(theme.cardTheme.color, theme.colorScheme.surface);
      expect(theme.cardTheme.margin, EdgeInsets.zero);

      final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
      final cardRadius = cardShape.borderRadius as BorderRadius;
      expect(cardRadius.topLeft, const Radius.circular(AppRadii.card));

      final inputBorder =
          theme.inputDecorationTheme.border! as OutlineInputBorder;
      expect(
        inputBorder.borderRadius.topLeft,
        const Radius.circular(AppRadii.control),
      );
    });

    test('keeps all button variants at least 48 logical pixels high', () {
      final theme = buildAppTheme();
      final styles = [
        theme.filledButtonTheme.style,
        theme.outlinedButtonTheme.style,
        theme.textButtonTheme.style,
        theme.elevatedButtonTheme.style,
      ];

      for (final style in styles) {
        final minimumSize = style?.minimumSize?.resolve(<WidgetState>{});
        expect(minimumSize, isNotNull);
        expect(
          minimumSize!.height,
          greaterThanOrEqualTo(AppSizes.minimumInteractiveDimension),
        );
      }
    });
  });

  testWidgets('shared presentation components follow the app theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: Column(
            children: [
              AppSectionHeader(title: 'Section'),
              Expanded(
                child: AppEmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Nothing here',
                  description: 'Add the first record.',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Section'), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Add the first record.'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);

    final context = tester.element(find.byType(AppEmptyState));
    final icon = tester.widget<Icon>(find.byIcon(Icons.inbox_outlined));
    expect(icon.color, Theme.of(context).colorScheme.outline);
  });
}
