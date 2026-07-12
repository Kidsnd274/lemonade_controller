import 'package:flutter/material.dart';
import 'package:lemonade_controller/providers/inference_activity_provider.dart';

class InferenceActivityPanel extends StatefulWidget {
  final InferenceActivityState activity;

  const InferenceActivityPanel({super.key, required this.activity});

  @override
  State<InferenceActivityPanel> createState() => _InferenceActivityPanelState();
}

class _InferenceActivityPanelState extends State<InferenceActivityPanel> {
  String? _expandedSecondaryKey;

  @override
  void didUpdateWidget(covariant InferenceActivityPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_expandedSecondaryKey != null &&
        !widget.activity.activeRequests.any(
          (request) => request.key == _expandedSecondaryKey,
        )) {
      _expandedSecondaryKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = widget.activity.activeRequests;
    if (requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActivityHeader(activity: widget.activity),
        const SizedBox(height: 8),
        if (requests.length == 1)
          _RequestCard(
            task: requests.single,
            now: widget.activity.now,
            title: 'Active request',
            detailed: true,
          )
        else ...[
          Text(
            '${requests.length - 1} other ${requests.length == 2 ? 'request is' : 'requests are'} sharing server capacity.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < requests.length; index++) ...[
            _RequestCard(
              task: requests[index],
              now: widget.activity.now,
              title: index == 0 ? 'Main request' : 'Concurrent request',
              detailed:
                  index == 0 || requests[index].key == _expandedSecondaryKey,
              onToggle: index == 0
                  ? null
                  : () => setState(() {
                      _expandedSecondaryKey =
                          _expandedSecondaryKey == requests[index].key
                          ? null
                          : requests[index].key;
                    }),
            ),
            if (index != requests.length - 1) const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  final InferenceActivityState activity;

  const _ActivityHeader({required this.activity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = activity.activeRequests.length;
    return Row(
      children: [
        Icon(
          Icons.auto_awesome_outlined,
          size: 17,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Live inference',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count active',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  final InferenceTaskActivity task;
  final DateTime now;
  final String title;
  final bool detailed;
  final VoidCallback? onToggle;

  const _RequestCard({
    required this.task,
    required this.now,
    required this.title,
    required this.detailed,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      child: Padding(
        padding: detailed
            ? const EdgeInsets.all(12)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: detailed
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RequestHeader(
                    task: task,
                    title: title,
                    detailed: detailed,
                    canToggle: onToggle != null,
                  ),
                  const SizedBox(height: 10),
                  _StageRail(phase: task.phase),
                  const SizedBox(height: 12),
                  _DetailedProgress(task: task, now: now),
                ],
              )
            : _CompactRequestRow(task: task, now: now, title: title),
      ),
    );

    return Semantics(
      button: onToggle != null,
      expanded: onToggle == null ? null : detailed,
      label: onToggle == null
          ? null
          : '${detailed ? 'Hide' : 'Show'} details for ${_requestIdentity(task)}',
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: title == 'Main request'
                ? theme.colorScheme.primary.withAlpha(150)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: onToggle == null
            ? content
            : InkWell(onTap: onToggle, child: content),
      ),
    );
  }
}

class _RequestHeader extends StatelessWidget {
  final InferenceTaskActivity task;
  final String title;
  final bool detailed;
  final bool canToggle;

  const _RequestHeader({
    required this.task,
    required this.title,
    required this.detailed,
    required this.canToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _RequestIdentityBlock(task: task, title: title),
        ),
        _PhaseChip(phase: task.phase),
        if (canToggle) ...[
          const SizedBox(width: 4),
          Icon(
            detailed ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );
  }
}

class _CompactRequestRow extends StatelessWidget {
  final InferenceTaskActivity task;
  final DateTime now;
  final String title;

  const _CompactRequestRow({
    required this.task,
    required this.now,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RequestHeader(
                task: task,
                title: title,
                detailed: false,
                canToggle: true,
              ),
              const SizedBox(height: 7),
              SizedBox(
                width: constraints.maxWidth * .68,
                child: _CompactProgress(task: task, now: now),
              ),
            ],
          );
        }

        final progressWidth = (constraints.maxWidth * .26)
            .clamp(150.0, 240.0)
            .toDouble();
        return Row(
          children: [
            Expanded(
              child: _RequestIdentityBlock(task: task, title: title),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: progressWidth,
              child: _CompactProgress(task: task, now: now),
            ),
            const SizedBox(width: 14),
            _PhaseChip(phase: task.phase),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        );
      },
    );
  }
}

class _RequestIdentityBlock extends StatelessWidget {
  final InferenceTaskActivity task;
  final String title;

  const _RequestIdentityBlock({required this.task, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          _requestIdentity(task),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PhaseChip extends StatelessWidget {
  final InferencePhase phase;

  const _PhaseChip({required this.phase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: phase == InferencePhase.completed
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _phaseBadgeLabel(phase),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: phase == InferencePhase.completed
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _StageRail extends StatelessWidget {
  final InferencePhase phase;

  const _StageRail({required this.phase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const stages = [
      (InferencePhase.received, 'Received'),
      (InferencePhase.promptProcessing, 'Prompt'),
      (InferencePhase.generating, 'Generating'),
      (InferencePhase.completed, 'Done'),
    ];
    final current = phase.index;
    return Semantics(
      label: 'Request stage: ${_phaseLabel(phase)}',
      child: Row(
        children: [
          for (var index = 0; index < stages.length; index++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
                decoration: BoxDecoration(
                  color: index == current
                      ? theme.colorScheme.primaryContainer
                      : index < current
                      ? theme.colorScheme.tertiaryContainer.withAlpha(150)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (index < current)
                      Icon(
                        Icons.check,
                        size: 12,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    if (index < current) const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        stages[index].$2,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: index == current
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: index == current
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (index != stages.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _DetailedProgress extends StatelessWidget {
  final InferenceTaskActivity task;
  final DateTime now;

  const _DetailedProgress({required this.task, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = task.promptProgress;
    final eta = task.promptEtaAt(now);
    final metrics = <String>['${_formatDuration(task.elapsedAt(now))} elapsed'];
    String status;
    double? indicatorValue;

    switch (task.phase) {
      case InferencePhase.received:
        status = 'Waiting for compute';
      case InferencePhase.promptProcessing:
        indicatorValue = progress;
        if (progress == null) {
          status = 'Preparing prompt';
        } else if (progress >= 1) {
          status = 'Finalizing prompt';
        } else {
          status = '${(progress * 100).round()}% processed';
          if (task.promptTokensPerSecond case final speed?) {
            metrics.add('${speed.toStringAsFixed(1)} tk/s');
          }
          metrics.add(
            task.promptProgressPerSecond == null
                ? 'Estimating time remaining'
                : eta == Duration.zero
                ? 'Almost done'
                : '~${_formatDuration(eta!)} left',
          );
        }
      case InferencePhase.generating:
        status = 'Generating response';
        if (task.decodedTokens case final tokens?) {
          metrics.add('$tokens tok generated');
        }
        if (task.generationTokensPerSecond case final speed?) {
          metrics.add('${speed.toStringAsFixed(1)} tk/s');
        }
      case InferencePhase.completed:
        status = 'Completed';
        indicatorValue = 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (task.phase == InferencePhase.promptProcessing &&
                progress != null)
              Text(
                '${(progress * 100).round()}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Semantics(
          label: status,
          value: progress == null
              ? null
              : '${(progress * 100).round()} percent',
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: indicatorValue ?? 0),
            duration: const Duration(milliseconds: 220),
            builder: (context, value, _) => LinearProgressIndicator(
              value: indicatorValue == null ? null : value,
              minHeight: 7,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final metric in metrics)
              Text(
                metric,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CompactProgress extends StatelessWidget {
  final InferenceTaskActivity task;
  final DateTime now;

  const _CompactProgress({required this.task, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = task.phase == InferencePhase.promptProcessing
        ? task.promptProgress
        : task.phase == InferencePhase.completed
        ? 1.0
        : null;
    final detail = switch (task.phase) {
      InferencePhase.received => 'Waiting for compute',
      InferencePhase.promptProcessing =>
        task.promptProgress == null
            ? 'Preparing prompt'
            : '${(task.promptProgress! * 100).round()}% · ${task.promptTokensPerSecond?.toStringAsFixed(1) ?? '—'} tk/s',
      InferencePhase.generating =>
        '${task.decodedTokens ?? 0} tok · ${task.generationTokensPerSecond?.toStringAsFixed(1) ?? '—'} tk/s',
      InferencePhase.completed => 'Completed',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 5,
          borderRadius: BorderRadius.circular(5),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(task.elapsedAt(now)),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _requestIdentity(InferenceTaskActivity task) {
  if (task.taskId == null) return 'Incoming request';
  return 'Request #${task.taskId} · Slot ${task.slotId ?? '—'}';
}

String _phaseLabel(InferencePhase phase) => switch (phase) {
  InferencePhase.received => 'Received',
  InferencePhase.promptProcessing => 'Prompt',
  InferencePhase.generating => 'Generating',
  InferencePhase.completed => 'Done',
};

String _phaseBadgeLabel(InferencePhase phase) => switch (phase) {
  InferencePhase.received => 'Received',
  InferencePhase.promptProcessing => 'Prompt Processing',
  InferencePhase.generating => 'Token Generation',
  InferencePhase.completed => 'Done',
};

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 359999);
  if (totalSeconds < 60) return '${totalSeconds}s';
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes < 60) return '${minutes}m ${seconds}s';
  final hours = minutes ~/ 60;
  return '${hours}h ${minutes % 60}m';
}
