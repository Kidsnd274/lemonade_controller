import 'package:flutter/material.dart';
import 'package:lemonade_controller/pages/widgets/nav_item.dart';
import 'package:lemonade_controller/pages/widgets/server_profile_header.dart';

class DrawerContent extends StatelessWidget {
  final List<NavItem> items;
  final int selectedIndex;
  final Function(int) onTap;
  final int bottomItemCount;

  const DrawerContent({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.bottomItemCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final splitIndex = (items.length - bottomItemCount).clamp(0, items.length);

    Widget navTile(int index) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: _NavTile(
        item: items[index],
        selected: selectedIndex == index,
        colorScheme: colorScheme,
        textTheme: theme.textTheme,
        onTap: () => onTap(index),
      ),
    );

    return Column(
      children: [
        const ServerProfileHeader(),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [for (var i = 0; i < splitIndex; i++) navTile(i)],
          ),
        ),
        if (bottomItemCount > 0) ...[
          Divider(
            height: 1,
            indent: 12,
            endIndent: 12,
            color: colorScheme.outlineVariant,
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = splitIndex; i < items.length; i++) navTile(i),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.selected,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colorScheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 22,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Text(
                item.title,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
