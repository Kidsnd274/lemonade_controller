import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/main_page.dart';
import 'package:lemonade_controller/services/settings_service.dart';
import 'package:lemonade_controller/theme/theme_def.dart';
import 'package:lemonade_controller/utils/vram_estimator.dart';
import 'package:logger/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Logger.level = Level.debug;
  runApp(ProviderScope(child: LemonadeController()));
}

class LemonadeController extends ConsumerWidget {
  const LemonadeController({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    settingsAsync.whenData((s) => setParamOverrides(s.modelParamOverrides));

    return settingsAsync.when(
      loading: () => MaterialApp(
        theme: lightTheme,
        darkTheme: darkTheme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, st) => MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Failed to load settings: $e')),
        ),
      ),
      data: (settings) => MaterialApp(
        title: 'Lemonade Controller',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: settings.themeMode,
        builder: (context, child) {
          final scale = settings.uiScale;
          if (scale == 1.0) return child!;
          final mq = MediaQuery.of(context);
          final scaledSize = mq.size / scale;
          return MediaQuery(
            data: mq.copyWith(size: scaledSize),
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: scaledSize.width,
                height: scaledSize.height,
                child: child,
              ),
            ),
          );
        },
        home: const MainPage(),
      ),
    );
  }
}
