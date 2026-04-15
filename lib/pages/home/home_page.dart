import 'package:flutter/material.dart';
import 'package:lemonade_controller/pages/home/widgets/download_progress_card.dart';
import 'package:lemonade_controller/pages/home/widgets/loaded_models_card.dart';
import 'package:lemonade_controller/pages/home/widgets/loading_models_card.dart';
import 'package:lemonade_controller/pages/home/widgets/recipes_card.dart';
import 'package:lemonade_controller/pages/home/widgets/server_status_card.dart';
import 'package:lemonade_controller/pages/home/widgets/system_specs_card.dart';
import 'package:lemonade_controller/pages/main_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    final isCompact = size == ScreenSize.compact;

    if (isCompact) {
      return _MobileLayout();
    }
    return _WideLayout();
  }
}

class _MobileLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [
        ServerStatusCard(),
        SizedBox(height: 8),
        LoadingModelsCard(),
        DownloadProgressCard(),
        LoadedModelsCard(),
        SizedBox(height: 8),
        SystemSpecsCard(),
        SizedBox(height: 8),
        RecipesCard(),
        SizedBox(height: 16),
      ],
    );
  }
}

class _WideLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              const ServerStatusCard(),
              const SizedBox(height: 12),
              const LoadingModelsCard(),
              const DownloadProgressCard(),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Expanded(child: LoadedModelsCard()),
                    SizedBox(width: 12),
                    Expanded(child: SystemSpecsCard()),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const RecipesCard(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
