import 'package:flutter/material.dart';

class PerformanceMeter extends StatelessWidget {
  final String label;
  final double? percent;
  final String valueLabel;
  final IconData icon;
  final bool telemetryUnavailable;
  final double size;

  const PerformanceMeter({
    super.key,
    required this.label,
    required this.percent,
    required this.valueLabel,
    required this.icon,
    this.telemetryUnavailable = false,
    this.size = 132,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = percent?.clamp(0, 100).toDouble();
    final color = telemetryUnavailable || normalized == null
        ? theme.colorScheme.outline
        : theme.colorScheme.primary;

    return Semantics(
      label: '$label $valueLabel',
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.square(
                    dimension: size - 8,
                    child: CircularProgressIndicator(
                      value: (normalized ?? 0) / 100,
                      strokeWidth: size < 100 ? 7 : 10,
                      strokeCap: StrokeCap.round,
                      color: color,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: size * .18, color: color),
                      const SizedBox(height: 4),
                      Text(
                        valueLabel,
                        style:
                            (size < 100
                                    ? theme.textTheme.titleMedium
                                    : theme.textTheme.titleLarge)
                                ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: size < 100 ? 4 : 8),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
