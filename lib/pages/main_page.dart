import 'package:flutter/material.dart';
import 'package:lemonade_controller/pages/home/home_page.dart';
import 'package:lemonade_controller/pages/models_list/models_page.dart';
import 'package:lemonade_controller/pages/models_list/nav_item.dart';
import 'package:lemonade_controller/pages/settings/settings_page.dart';
import 'package:lemonade_controller/pages/widgets/drawer_content.dart';
import 'package:lemonade_controller/services/settings_service.dart';

enum _ScreenSize { compact, medium, expanded }

_ScreenSize _screenSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 600) return _ScreenSize.compact;
  if (width < 1024) return _ScreenSize.medium;
  return _ScreenSize.expanded;
}

class MainPage extends StatefulWidget {
  final SettingsService settings;
  const MainPage({super.key, required this.settings});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  late final List<NavItem> _navItems;
  late final List<GlobalKey> _pageKeys;

  @override
  void initState() {
    super.initState();
    _navItems = [
      NavItem(title: 'Home', icon: Icons.home, page: const HomePage()),
      NavItem(title: 'Models', icon: Icons.view_list, page: ModelsPage()),
      NavItem(
        title: 'Settings',
        icon: Icons.settings,
        page: SettingsPage(settings: widget.settings),
      ),
    ];
    _pageKeys = List.generate(_navItems.length, (_) => GlobalKey());
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = _screenSizeOf(context);
    final content = KeyedSubtree(
      key: _pageKeys[_selectedIndex],
      child: _navItems[_selectedIndex].page,
    );

    return switch (screenSize) {
      _ScreenSize.compact => _buildMobileLayout(content),
      _ScreenSize.medium => _buildTabletLayout(content),
      _ScreenSize.expanded => _buildDesktopLayout(content),
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
            destinations: [
              for (final item in _navItems)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  label: Text(item.title),
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
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Text(_navItems[_selectedIndex].title),
    );
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
  }
}
