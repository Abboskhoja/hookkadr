import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/core/theme/app_theme.dart';
import 'package:hookkadr/features/editor/widgets/contextual_toolbar.dart';

void main() {
  testWidgets('selection replaces global tools and can be dismissed', (
    tester,
  ) async {
    bool selected = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => setState(() => selected = true),
                  child: const Text('Select'),
                ),
                ContextualToolbar(
                  selected: selected,
                  onDismiss: () => setState(() => selected = false),
                  generalTools: const Text('General'),
                  clipTools: const Text('Clip'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Clip'), findsNothing);
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('Clip'), findsOneWidget);
    expect(find.text('General'), findsNothing);
    await tester.tap(find.byTooltip('Tanlovni yopish'));
    await tester.pumpAndSettle();
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Clip'), findsNothing);
  });
}
