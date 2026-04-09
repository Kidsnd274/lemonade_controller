import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/server_profile.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/services/settings_service.dart';

class ServerProfileHeader extends ConsumerWidget {
  const ServerProfileHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsAsync = ref.watch(settingsProvider);
    final healthAsync = ref.watch(healthInfoProvider);

    final settings = settingsAsync.value ?? const AppSettings();
    final profile = settings.activeProfile;
    final profiles = settings.serverProfiles;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.terminal_rounded,
                    size: 20,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Lemonade Controller',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ServerInfoTile(
              profile: profile,
              profiles: profiles,
              isOnline: healthAsync.hasValue && healthAsync.value!.isHealthy,
              isLoading: healthAsync.isLoading,
              hasError: healthAsync.hasError,
              onProfileSelected: (id) {
                ref.read(settingsProvider.notifier).setActiveProfile(id);
              },
            ),
          ],
        ),
      ),
    );
  }

}

class _ServerInfoTile extends StatelessWidget {
  final ServerProfile profile;
  final List<ServerProfile> profiles;
  final bool isOnline;
  final bool isLoading;
  final bool hasError;
  final ValueChanged<String> onProfileSelected;

  const _ServerInfoTile({
    required this.profile,
    required this.profiles,
    required this.isOnline,
    required this.isLoading,
    required this.hasError,
    required this.onProfileSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onProfileSelected,
      itemBuilder: (context) => [
        for (final p in profiles)
          PopupMenuItem<String>(
            value: p.id,
            child: Row(
              children: [
                if (p.id == profile.id)
                  Icon(Icons.check_rounded, size: 18, color: colorScheme.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              p.id == profile.id ? FontWeight.w600 : null,
                        ),
                      ),
                      Text(
                        p.displayAddress,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
        ),
        child: Row(
          children: [
            _StatusIndicator(
              isOnline: isOnline,
              isLoading: isLoading,
              hasError: hasError,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    profile.displayAddress,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final bool isOnline;
  final bool isLoading;
  final bool hasError;

  const _StatusIndicator({
    required this.isOnline,
    required this.isLoading,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final color = isOnline ? Colors.green : Colors.red.shade400;

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(100),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
