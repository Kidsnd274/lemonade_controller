import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/home/home_page.dart';
import 'package:lemonade_controller/pages/downloads/downloads_page.dart';
import 'package:lemonade_controller/pages/logs/logs_page.dart';
import 'package:lemonade_controller/pages/models_list/models_page.dart';
import 'package:lemonade_controller/pages/presets/presets_page.dart';
import 'package:lemonade_controller/pages/pull/pull_page.dart';
import 'package:lemonade_controller/pages/widgets/nav_item.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/pages/settings/settings_page.dart';
import 'package:lemonade_controller/pages/widgets/drawer_content.dart';
import 'package:lemonade_controller/providers/providers.dart';
import 'package:lemonade_controller/providers/service_providers.dart';

enum ScreenSize { compact, medium, expanded }

ScreenSize screenSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 600) return ScreenSize.compact;
  if (width < 1024) return ScreenSize.medium;
  return ScreenSize.expanded;
}

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage>
    with WidgetsBindingObserver {
  static const _bottomNavItemCount = 2;
  int _selectedIndex = 0;

  static final List<NavItem> _navItems = [
    NavItem(
      title: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      page: const HomePage(),
    ),
    NavItem(
      title: 'Models',
      icon: Icons.view_list_outlined,
      selectedIcon: Icons.view_list,
      page: ModelsPage(),
    ),
    NavItem(
      title: 'Pull',
      icon: Icons.download_outlined,
      selectedIcon: Icons.download,
      page: ProviderScope(
        overrides: [
          downloadsPollingIntervalProvider.overrideWithValue(
            const Duration(milliseconds: 500),
          ),
        ],
        child: const PullPage(),
      ),
    ),
    NavItem(
      title: 'Downloads',
      icon: Icons.downloading_outlined,
      selectedIcon: Icons.downloading,
      page: const DownloadsPage(),
    ),
    NavItem(
      title: 'Presets',
      icon: Icons.playlist_add_check_outlined,
      selectedIcon: Icons.playlist_add_check,
      page: const PresetsPage(),
    ),
    NavItem(
      title: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      page: const SettingsPage(),
    ),
    NavItem(
      title: 'Logs',
      icon: Icons.terminal_outlined,
      selectedIcon: Icons.terminal,
      page: const LogsPage(),
    ),
  ];
  late final List<GlobalKey> _pageKeys;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageKeys = List.generate(_navItems.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appForegroundProvider.notifier).state =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(autoRefreshProvider);

    final screenSize = screenSizeOf(context);
    final content = KeyedSubtree(
      key: _pageKeys[_selectedIndex],
      child: _navItems[_selectedIndex].page,
    );

    return switch (screenSize) {
      ScreenSize.compact => _buildMobileLayout(content),
      ScreenSize.medium => _buildTabletLayout(content),
      ScreenSize.expanded => _buildDesktopLayout(content),
    };
  }

  Widget _buildMobileLayout(Widget content) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: Drawer(
        child: DrawerContent(
          items: _navItems,
          selectedIndex: _selectedIndex,
          bottomItemCount: _bottomNavItemCount,
          onTap: (index) {
            _selectPage(index);
            Navigator.pop(context);
          },
        ),
      ),
      body: content,
    );
  }

  Widget _buildTabletLayout(Widget content) {
    final theme = Theme.of(context);
    final primaryCount = _navItems.length - _bottomNavItemCount;
    return Scaffold(
      appBar: _buildAppBar(),
      body: Row(
        children: [
          Column(
            children: [
              Expanded(
                child: NavigationRail(
                  selectedIndex: _selectedIndex < primaryCount
                      ? _selectedIndex
                      : null,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: _selectPage,
                  indicatorColor: theme.colorScheme.secondaryContainer,
                  backgroundColor: theme.colorScheme.surface,
                  minWidth: 72,
                  groupAlignment: -0.85,
                  destinations: [
                    for (final item in _navItems.take(primaryCount))
                      _railDestination(item),
                  ],
                ),
              ),
              SizedBox(
                height: 152,
                child: NavigationRail(
                  selectedIndex: _selectedIndex >= primaryCount
                      ? _selectedIndex - primaryCount
                      : null,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (index) =>
                      _selectPage(primaryCount + index),
                  indicatorColor: theme.colorScheme.secondaryContainer,
                  backgroundColor: theme.colorScheme.surface,
                  minWidth: 72,
                  groupAlignment: 0,
                  destinations: [
                    for (final item in _navItems.skip(primaryCount))
                      _railDestination(item),
                  ],
                ),
              ),
            ],
          ),
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: theme.colorScheme.outlineVariant,
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(Widget content) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: _buildAppBar(),
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: DrawerContent(
              items: _navItems,
              selectedIndex: _selectedIndex,
              bottomItemCount: _bottomNavItemCount,
              onTap: _selectPage,
            ),
          ),
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: theme.colorScheme.outlineVariant,
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final theme = Theme.of(context);
    return AppBar(
      centerTitle: false,
      title: Text(
        _navItems[_selectedIndex].title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      scrolledUnderElevation: 1,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Consumer(
            builder: (context, ref, child) {
              final refreshAll = ref.watch(refreshAllProvider);
              return IconButton.filledTonal(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () => refreshAll(),
                tooltip: 'Refresh all',
              );
            },
          ),
        ),
      ],
    );
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
  }

  NavigationRailDestination _railDestination(NavItem item) {
    return NavigationRailDestination(
      icon: Icon(item.icon),
      selectedIcon: Icon(item.selectedIcon),
      label: Text(item.title),
      padding: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}
