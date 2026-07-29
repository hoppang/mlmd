import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/diary_entity.dart';
import '../domain/growth_trend.dart';

class GrowthChartPage extends StatefulWidget {
  const GrowthChartPage({required this.diaries, super.key});

  final List<DiaryEntity> diaries;

  @override
  State<GrowthChartPage> createState() => _GrowthChartPageState();
}

class _GrowthChartPageState extends State<GrowthChartPage> {
  GrowthMetric _metric = GrowthMetric.height;
  bool _referenceRequested = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final points = buildGrowthTrend(widget.diaries, _metric);
    return Scaffold(
      appBar: AppBar(title: Text(loc.growthChartTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    loc.growthChartPersonalTrendDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<GrowthMetric>(
                    key: const Key('growth-metric-selector'),
                    segments: [
                      ButtonSegment(
                        value: GrowthMetric.height,
                        label: Text(loc.growthChartHeight),
                      ),
                      ButtonSegment(
                        value: GrowthMetric.weight,
                        label: Text(loc.growthChartWeight),
                      ),
                      ButtonSegment(
                        value: GrowthMetric.headCircumference,
                        label: Text(loc.growthChartHead),
                      ),
                    ],
                    selected: {_metric},
                    onSelectionChanged: (selection) {
                      setState(() => _metric = selection.single);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: points.isEmpty
                          ? _GrowthEmptyState(message: loc.growthChartEmpty)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Semantics(
                                  label: loc.growthChartPointCount(
                                    points.length,
                                  ),
                                  child: SizedBox(
                                    key: const Key('personal-growth-chart'),
                                    height: 280,
                                    child: CustomPaint(
                                      painter: _GrowthTrendPainter(
                                        points: points,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        gridColor: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _PointList(points: points, metric: _metric),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    key: const Key('growth-reference-toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(loc.growthChartShowReference),
                    subtitle: Text(loc.growthChartProfileRequired),
                    value: _referenceRequested,
                    onChanged: (value) {
                      setState(() => _referenceRequested = value);
                    },
                  ),
                  if (_referenceRequested)
                    Card(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(loc.growthChartReferenceUnavailable),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    loc.growthChartPercentileExplanation,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GrowthEmptyState extends StatelessWidget {
  const _GrowthEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('growth-chart-empty'),
    height: 240,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.show_chart, size: 42),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _PointList extends StatelessWidget {
  const _PointList({required this.points, required this.metric});

  final List<GrowthTrendPoint> points;
  final GrowthMetric metric;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale);
    final unit = metric == GrowthMetric.weight ? 'kg' : 'cm';
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: points
          .map(
            (point) => Chip(
              label: Text(
                '${dateFormat.format(point.measuredAt)} · '
                '${_formatValue(point.value)}$unit',
              ),
            ),
          )
          .toList(),
    );
  }

  String _formatValue(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class _GrowthTrendPainter extends CustomPainter {
  const _GrowthTrendPainter({
    required this.points,
    required this.color,
    required this.gridColor,
  });

  final List<GrowthTrendPoint> points;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 18.0;
    const verticalPadding = 18.0;
    final chart = Rect.fromLTRB(
      horizontalPadding,
      verticalPadding,
      size.width - horizontalPadding,
      size.height - verticalPadding,
    );
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index++) {
      final y = chart.top + chart.height * index / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    var minValue = points.map((point) => point.value).reduce(math.min);
    var maxValue = points.map((point) => point.value).reduce(math.max);
    if (minValue == maxValue) {
      minValue -= math.max(1, minValue * 0.05);
      maxValue += math.max(1, maxValue * 0.05);
    } else {
      final padding = (maxValue - minValue) * 0.12;
      minValue -= padding;
      maxValue += padding;
    }
    final firstTime = points.first.measuredAt.millisecondsSinceEpoch;
    final lastTime = points.last.measuredAt.millisecondsSinceEpoch;
    final timeSpan = math.max(1, lastTime - firstTime);

    Offset offsetFor(GrowthTrendPoint point) {
      final xRatio =
          (point.measuredAt.millisecondsSinceEpoch - firstTime) / timeSpan;
      final yRatio = (point.value - minValue) / (maxValue - minValue);
      return Offset(
        chart.left + chart.width * xRatio,
        chart.bottom - chart.height * yRatio,
      );
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final offset = offsetFor(points[index]);
      if (index == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    if (points.length > 1) canvas.drawPath(path, linePaint);
    for (final point in points) {
      canvas.drawCircle(offsetFor(point), 5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthTrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}
