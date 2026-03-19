import 'package:flutter/material.dart';
import 'package:lemonade_controller/pages/models_list/nav_item.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: colorScheme.primaryContainer),
          child: Text(
            'Lemonade Controller',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        for (var i = 0; i < items.length; i++)
          ListTile(
            leading: Icon(
              items[i].icon,
              color: selectedIndex == i
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            title: Text(items[i].title),
            selected: selectedIndex == i,
            selectedTileColor: colorScheme.primaryContainer.withOpacity(0.3),
            selectedColor: colorScheme.primary,
            onTap: () => onTap(i),
          ),
      ],
    );
  }
}
