import 'package:flutter/material.dart';
import 'package:lemonade_controller/pages/home/home_page.dart';
import 'package:lemonade_controller/pages/models/models_page.dart';
import 'package:lemonade_controller/pages/models/nav_item.dart';
import 'package:lemonade_controller/pages/settings/settings_page.dart';
import 'package:lemonade_controller/pages/widgets/drawer_content.dart';
import 'package:lemonade_controller/services/settings_service.dart';

class MainPage extends StatefulWidget {
  final SettingsService settings;
  const MainPage({super.key, required this.settings});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  late final List<NavItem> _navItems;

  @override
  void initState() {
    super.initState();
    _navItems = [
      NavItem(title: 'Home', icon: Icons.home, page: const HomePage()),
      NavItem(title: 'Models', icon: Icons.view_list, page: ModelsPage()),
      NavItem(title: 'Settings', icon: Icons.settings, page: SettingsPage(settings: widget.settings)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;

    final content = _navItems[_selectedIndex].page;
    final drawerContent = DrawerContent(
      items: _navItems,
      selectedIndex: _selectedIndex,
      onTap: _selectPage,
    );

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(_navItems[_selectedIndex].title),
        ),
        drawer: Drawer(child: drawerContent),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_navItems[_selectedIndex].title),
      ),
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: Material(elevation: 1, child: drawerContent),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
    if (MediaQuery.sizeOf(context).width < 600) {
      Navigator.pop(context); // only close the drawer overlay on mobile
    }
  }
}
