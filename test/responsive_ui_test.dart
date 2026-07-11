import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/models/loaded_model.dart';
import 'package:lemonade_controller/pages/models_list/models_page.dart';
import 'package:lemonade_controller/pages/widgets/drawer_content.dart';
import 'package:lemonade_controller/pages/widgets/nav_item.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/providers/service_providers.dart';
import 'package:lemonade_controller/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('mobile filters commit only when Apply is tapped', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpModelsPage(tester);

    expect(find.text('Filters'), findsOneWidget);
    expect(find.byType(DropdownButton<String?>), findsNothing);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.tap(find.text('Q6_K'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Filters (2)'), findsOneWidget);
    expect(find.text('1 of 2 models'), findsOneWidget);
    expect(find.text('Custom-model'), findsOneWidget);
    expect(find.text('Built-in-model'), findsNothing);

    await tester.tap(find.text('Filters (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    Navigator.of(tester.element(find.text('Filters'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Filters (2)'), findsOneWidget);
    expect(find.text('1 of 2 models'), findsOneWidget);
  });

  testWidgets('desktop models page retains inline quant dropdown', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpModelsPage(tester);

    expect(find.byType(DropdownButton<String?>), findsOneWidget);
    expect(find.text('Filters'), findsNothing);
  });

  testWidgets('drawer pins Settings and Logs below primary navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = -1;
    final items = <NavItem>[
      for (final title in [
        'Home',
        'Models',
        'Pull',
        'Downloads',
        'Presets',
        'Settings',
        'Logs',
      ])
        NavItem(title: title, icon: Icons.circle, page: const SizedBox()),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(_FakeApiClient())],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 800,
              child: DrawerContent(
                items: items,
                selectedIndex: 0,
                bottomItemCount: 2,
                onTap: (index) => selected = index,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getCenter(find.text('Settings')).dy, greaterThan(650));
    expect(tester.getCenter(find.text('Logs')).dy, greaterThan(700));
    await tester.tap(find.text('Logs'));
    expect(selected, 6);
  });
}

Future<void> _pumpModelsPage(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApiClient()),
        modelsProvider.overrideWith((ref) async => _models),
      ],
      child: const MaterialApp(home: Scaffold(body: ModelsPage())),
    ),
  );
  await tester.pumpAndSettle();
}

final _models = [
  LemonadeModel.fromJson({
    'id': 'Custom-model',
    'checkpoint': 'owner/custom-model:Q6_K',
    'labels': ['custom'],
  }),
  LemonadeModel.fromJson({
    'id': 'builtin.Built-in-model',
    'checkpoint': 'owner/built-in-model:Q4_K_M',
  }),
];

class _FakeApiClient extends LemonadeApiClient {
  _FakeApiClient() : super(baseUrl: 'http://localhost');

  @override
  Future<Map<String, dynamic>> getHealth() async => {
    'status': 'ok',
    'version': '10.10.0',
    'websocket_port': 0,
  };

  @override
  Future<List<LoadedModel>> getLoadedModels() async => [];
}
