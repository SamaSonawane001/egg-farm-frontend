import 'package:egg_farm/core/auth_state.dart';
import 'package:egg_farm/core/api_client.dart';
import 'package:egg_farm/widgets/app_shell.dart';
import 'package:egg_farm/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('primary farm supplies the shared brand identity', () {
    final auth = AuthState()
      ..farms = [
        {
          'farm_id': 'primary',
          'farm_name': 'Aditya services',
          'is_primary': true,
          'avatar_url': '/primary-logo.png',
          'signature_url': '/primary-signature.png',
          'payment_qr_url': '/primary-qr.png',
        },
        {
          'farm_id': 'unit',
          'farm_name': 'Aditya service 2nd farm',
          'is_primary': false,
          'avatar_url': '/unit-logo.png',
        },
      ]
      ..user = {'farm_name': 'Aditya service 2nd farm'};
    addTearDown(auth.dispose);

    expect(auth.farmName, 'Aditya services');
    expect(auth.avatarUrl, '/primary-logo.png');
    expect(auth.signatureUrl, '/primary-signature.png');
    expect(auth.paymentQrUrl, '/primary-qr.png');
  });

  test('route refreshes are limited to authentication transitions', () async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.token = null;
    ApiClient.instance.farmId = null;
    final auth = AuthState();
    var routeRefreshes = 0;
    auth.routeRefreshListenable.addListener(() => routeRefreshes++);
    addTearDown(() {
      ApiClient.instance.token = null;
      ApiClient.instance.farmId = null;
      auth.dispose();
    });

    await auth.init();
    expect(routeRefreshes, 1);

    auth.notifyListeners();
    expect(routeRefreshes, 1);

    await auth.logout();
    expect(routeRefreshes, 2);
  });

  testWidgets('active DataLoader reloads with the latest farm ID',
      (tester) async {
    ApiClient.instance.farmId = null;
    addTearDown(() => ApiClient.instance.farmId = null);
    final loadedFarmIds = <String?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: DataLoader<String>(
          load: () async {
            loadedFarmIds.add(ApiClient.instance.farmId);
            return '${ApiClient.instance.farmId}';
          },
          builder: (context, farmId, reload) => Text(farmId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loadedFarmIds, [null]);

    ApiClient.instance.farmId = 'farm-2';
    await tester.pump();
    await tester.pumpAndSettle();

    expect(loadedFarmIds, [null, 'farm-2']);
    expect(find.text('farm-2'), findsOneWidget);
  });

  testWidgets('switching farms reloads the routed screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthState();
    var loadCount = 0;
    final loadedFarmIds = <String?>[];
    addTearDown(() {
      ApiClient.instance.farmId = null;
      auth.dispose();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          home: AppShell(
            location: '/dashboard',
            child: _FarmDataProbe(
              onLoad: () {
                loadCount++;
                loadedFarmIds.add(ApiClient.instance.farmId);
              },
            ),
          ),
        ),
      ),
    );
    expect(loadCount, 1);

    auth.notifyListeners();
    await tester.pump();
    expect(loadCount, 1);

    await tester.tap(find.byTooltip('Switch farm'));
    await tester.pumpAndSettle();
    expect(find.text('Choose farm'), findsOneWidget);

    await tester.tap(find.textContaining('All Farms Combined'));
    expect(auth.selectedFarmId, 'all');
    await tester.pump();
    expect(loadCount, 2);
    await tester.pumpAndSettle();

    expect(loadCount, 2);
    expect(loadedFarmIds.last, 'all');
    expect(auth.selectedFarmId, 'all');
    expect(ApiClient.instance.farmId, 'all');
    expect((await SharedPreferences.getInstance()).getString('farmId'), 'all');
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('routed scroll content stays bounded at ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = AuthState()
        ..user = {
          'id': 'owner',
          'farm_name':
              'A very long farm name that should remain ellipsized in the header',
          'owner_name': 'Farm Owner',
          'mobile': '1234567890',
        };

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: MaterialApp(
            home: AppShell(
              location: '/dashboard',
              child: ListView(
                children: [
                  const SizedBox(height: 1000, child: Text('Scrollable page')),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Farm')),
                        DataColumn(label: Text('Net')),
                      ],
                      rows: [
                        for (var index = 0; index < 12; index++)
                          DataRow(cells: [
                            DataCell(Text('Farm $index')),
                            DataCell(Text('$index')),
                          ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: MaterialApp(
            home: AppShell(
              location: '/medicines',
              child: Column(
                children: [
                  const Text('Screen filter controls'),
                  Expanded(
                    child: ListView(
                      children: const [
                        SizedBox(height: 1000, child: Text('Screen content')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}

class _FarmDataProbe extends StatefulWidget {
  final VoidCallback onLoad;
  const _FarmDataProbe({required this.onLoad});

  @override
  State<_FarmDataProbe> createState() => _FarmDataProbeState();
}

class _FarmDataProbeState extends State<_FarmDataProbe> {
  @override
  void initState() {
    super.initState();
    widget.onLoad();
  }

  @override
  Widget build(BuildContext context) => const Text('Farm data');
}
