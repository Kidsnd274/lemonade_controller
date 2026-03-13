import 'package:flutter/material.dart';
import 'package:lemonade_controller/pages/home/home_page.dart';
import 'package:lemonade_controller/pages/models/models_page.dart';
import 'package:lemonade_controller/pages/settings/settings_page.dart';
import 'package:lemonade_controller/services/settings_service.dart';

class MainPage extends StatefulWidget {
  final SettingsService settings;
  const MainPage({super.key, required this.settings});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  final List<String> _pageTitles = ['Home', 'Models', 'Settings'];

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomePage(),
      ModelsPage(),
      SettingsPage(settings: widget.settings),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(  // TODO: This should be changable based on the page.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_pageTitles[_selectedIndex]),
      ),
      drawer: Drawer( // TODO: Drawer itself should be a widget?
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Lemonade Controller',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: _selectedIndex == 0,
              onTap: () => _selectPage(0),
            ),
            ListTile(
              leading: const Icon(Icons.view_list),
              title: const Text('Models'),
              selected: _selectedIndex == 1,
              onTap: () => _selectPage(1),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              selected: _selectedIndex == 2,
              onTap: () => _selectPage(2),
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }
}
