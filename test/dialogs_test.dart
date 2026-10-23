import 'package:famnest/l10n/app_localizations.dart';
import 'package:famnest/widgets/text_prompt_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(void Function(BuildContext) onPressed) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => TextButton(
      onPressed: () => onPressed(context),
      child: const Text('open'),
    ),
  ),
);

void main() {
  testWidgets('cancelling the text prompt closes cleanly', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(
      _app((context) async {
        result = await showTextPrompt(
          context,
          title: 'Custom call…',
          actionLabel: 'Send',
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Leaving soon');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isNull);
  });

  testWidgets('submitting returns trimmed text', (tester) async {
    String? result;
    await tester.pumpWidget(
      _app((context) async {
        result = await showTextPrompt(
          context,
          title: 'Custom call…',
          actionLabel: 'Send',
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Leaving soon ');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(result, 'Leaving soon');
  });
}
