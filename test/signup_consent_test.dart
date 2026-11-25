import 'package:egg_farm/core/auth_state.dart';
import 'package:egg_farm/screens/signup_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('signup consent starts unchecked and legal viewer is bilingual',
      (tester) async {
    final auth = AuthState();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: const MaterialApp(home: SignupScreen()),
      ),
    );

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    final createAccount = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    expect(createAccount.onPressed, isNull);
    expect(
      find.textContaining('I consent to using my name, farm details'),
      findsNothing,
    );

    final consentText = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('I am 18+ and agree'),
      ),
    );
    final spans = (consentText.text as TextSpan).children!.cast<TextSpan>();
    final privacyLink =
        spans.firstWhere((span) => span.text == 'Privacy Policy');
    (privacyLink.recognizer as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    expect(find.text('मराठी'), findsOneWidget);
    expect(find.text('Consent & data notice'), findsOneWidget);

    await tester.tap(find.text('मराठी'));
    await tester.pumpAndSettle();
    expect(find.text('अटी व शर्ती'), findsOneWidget);
    expect(find.text('संमती व माहितीची सूचना'), findsOneWidget);
  });
}
