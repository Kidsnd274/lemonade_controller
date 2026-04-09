import 'package:flutter/material.dart';

class NavItem {
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  const NavItem({
    required this.title,
    required this.icon,
    required this.page,
    IconData? selectedIcon,
  }) : selectedIcon = selectedIcon ?? icon;
}
