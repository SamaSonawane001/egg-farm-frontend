import 'package:egg_farm/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tabs = [
    ResponsiveHistoryTab(
      label: 'Purchase & delivery history',
      mobileLabel: 'Purchases & deliveries',
      icon: Icons.local_shipping_outlined,
    ),
    ResponsiveHistoryTab(
      label: 'Usage & consumption',
      mobileLabel: 'Usage & consumption',
      icon: Icons.restaurant_outlined,
    ),
  ];

  Future<void> pumpResponsiveLayout(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ResponsiveSectionHeader(
                  title: 'Usage history',
                  subtitle: 'Selected month: 2026-11',
                  actions: [
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Change month'),
                    ),
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add),
                      label: const Text('Log usage'),
                    ),
                  ],
                ),
                ResponsiveHistoryTabs(
                  tabs: tabs,
                  selected: 0,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('stacks history controls on a narrow phone viewport',
      (tester) async {
    await pumpResponsiveLayout(tester, const Size(360, 800));

    expect(find.text('Selected month: 2026-11'), findsOneWidget);
    expect(find.text('Log usage'), findsOneWidget);
    expect(find.text('Change month'), findsOneWidget);
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses segmented history tabs on a wide viewport', (tester) async {
    await pumpResponsiveLayout(tester, const Size(900, 800));

    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
