import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/home/widgets/dashboard_card.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

class SystemSpecsCard extends ConsumerWidget {
  const SystemSpecsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sysInfoAsync = ref.watch(systemInfoProvider);
    final theme = Theme.of(context);

    return DashboardCard(
      title: 'System Specs',
      icon: Icons.computer_outlined,
      child: sysInfoAsync.when(
        data: (info) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SpecRow(
                icon: Icons.memory,
                label: 'Processor',
                value: info.processor,
              ),
              const SizedBox(height: 10),
              _SpecRow(
                icon: Icons.storage_outlined,
                label: 'Memory',
                value: info.physicalMemory,
              ),
              const SizedBox(height: 10),
              _SpecRow(
                icon: Icons.desktop_windows_outlined,
                label: 'OS',
                value: info.osVersion,
              ),
              const SizedBox(height: 14),
              Text(
                'Devices',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...info.availableDevices.map(
                (device) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DeviceTile(
                    label: device.label,
                    detail: device.detail,
                    iconType: device.icon,
                  ),
                ),
              ),
            ],
          );
        },
        error: (err, _) => _ErrorRow(error: err.toString()),
        loading: () => const _LoadingIndicator(),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SpecRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final String label;
  final String detail;
  final String iconType;

  const _DeviceTile({
    required this.label,
    required this.detail,
    required this.iconType,
  });

  IconData get _icon => switch (iconType) {
        'cpu' => Icons.memory,
        'gpu' => Icons.auto_awesome,
        'npu' => Icons.psychology,
        _ => Icons.developer_board,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(_icon, size: 16, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String error;
  const _ErrorRow({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
