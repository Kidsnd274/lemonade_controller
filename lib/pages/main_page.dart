import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/home/home_page.dart';
import 'package:lemonade_controller/pages/models_list/models_page.dart';
import 'package:lemonade_controller/pages/widgets/nav_item.dart';
import 'package:lemonade_controller/pages/settings/settings_page.dart';
import 'package:lemonade_controller/pages/widgets/drawer_content.dart';
import 'package:lemonade_controller/providers/providers.dart';

enum ScreenSize { compact, medium, expanded }

ScreenSize screenSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 600) return ScreenSize.compact;
  if (width < 1024) return ScreenSize.medium;
  return ScreenSize.expanded;
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
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
      title: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      page: const SettingsPage(),
    ),
  ];
  late final List<GlobalKey> _pageKeys;

  @override
  void initState() {
    super.initState();
    _pageKeys = List.generate(_navItems.length, (_) => GlobalKey());
  }

  @override
  Widget build(BuildContext context) {
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
    return Scaffold(
      appBar: _buildAppBar(),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: _selectPage,
            indicatorColor: theme.colorScheme.secondaryContainer,
            backgroundColor: theme.colorScheme.surface,
            minWidth: 72,
            groupAlignment: -0.85,
            destinations: [
              for (final item in _navItems)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.title),
                  padding: const EdgeInsets.symmetric(vertical: 4),
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
      title: Text(
        _navItems[_selectedIndex].title,
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
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
}
