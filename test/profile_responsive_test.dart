import 'package:egg_farm/core/auth_state.dart';
import 'package:egg_farm/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('Farm Profile responds at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = AuthState()
        ..user = {
          'owner_name': 'Farm Owner',
          'farm_name': 'Primary Farm',
          'mobile': '9876543210',
          'low_stock_threshold': 10,
          'kg_per_bag': 50,
          'default_tax_percent': 0,
          'eggs_per_tray': 30,
        };
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: const MaterialApp(
            home: Scaffold(body: ProfileScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Defaults'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(7));
      final threshold = tester.getRect(fields.at(3));
      final kilograms = tester.getRect(fields.at(4));
      final tax = tester.getRect(fields.at(5));
      final eggs = tester.getRect(fields.at(6));

      if (width >= 768) {
        expect(kilograms.top, closeTo(threshold.top, 1));
        expect(kilograms.left, greaterThan(threshold.right));
        expect(eggs.top, closeTo(tax.top, 1));
        expect(tax.top, greaterThan(threshold.bottom));
      } else {
        expect(kilograms.top, greaterThan(threshold.bottom));
        expect(tax.top, greaterThan(kilograms.bottom));
        expect(eggs.top, greaterThan(tax.bottom));
      }

      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      final saveSize =
          tester.getSize(find.widgetWithText(FilledButton, 'Save changes'));
      final logoutSize =
          tester.getSize(find.widgetWithText(OutlinedButton, 'Logout'));
      if (width >= 768) {
        expect(saveSize.width, inInclusiveRange(200, 240));
        expect(logoutSize.width, inInclusiveRange(160, 200));
      } else {
        expect(saveSize.width, greaterThan(300));
        expect(logoutSize.width, greaterThan(300));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
