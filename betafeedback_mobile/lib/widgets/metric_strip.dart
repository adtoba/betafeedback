import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// A single figure inside a [MetricStrip].
class Metric {
  const Metric({
    required this.label,
    required this.value,
    this.tint,
    this.onTap,
  });

  final String label;
  final String value;

  /// Colors the figure when it needs attention (open bugs, failures, …).
  final Color? tint;
  final VoidCallback? onTap;
}

/// Row of headline figures divided by hairlines — the summary band at the top
/// of a project.
class MetricStrip extends StatelessWidget {
  const MetricStrip({super.key, required this.metrics});

  final List<Metric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tones = AppTones.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tones.hairline, width: AppStroke.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      // Cells set the height; the dividers stretch to match it.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0)
                Container(
                  width: AppStroke.hairline,
                  margin: const EdgeInsets.symmetric(vertical: AppSpace.md),
                  color: tones.hairline,
                ),
              Expanded(child: _MetricCell(metric: metrics[i], theme: theme)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.metric, required this.theme});

  final Metric metric;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.md + 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            metric.value,
            maxLines: 1,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: metric.tint ?? theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            metric.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );

    if (metric.onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: metric.onTap, child: content),
    );
  }
}
