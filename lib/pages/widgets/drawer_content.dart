import 'package:flutter/material.dart';
import 'package:lemonade_controller/pages/models/nav_item.dart';

class DrawerContent extends StatelessWidget {
  final List<NavItem> items;
  final int selectedIndex;
  final Function(int) onTap;

  const DrawerContent({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  static const List<Map<String, dynamic>> _items = [
    {'icon': Icons.home, 'title': 'Home', 'index': 0},
    {'icon': Icons.view_list, 'title': 'Models', 'index': 1},
    {'icon': Icons.settings, 'title': 'Settings', 'index': 2},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const DrawerHeader(
          decoration: BoxDecoration(color: Colors.blue),
          child: Text(
            'Lemonade Controller', // TODO: Colours should be based on theme
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
        for (var i = 0; i < items.length; i++)
          ListTile(
            leading: Icon(items[i].icon),
            title: Text(items[i].title),
            selected: selectedIndex == i,
            onTap: () => onTap(i),
          ),
      ],
    );
  }
}
