import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/health_models.dart';

// Palette (kept local so the charts read as one system).
const _cyan = Color(0xFF22D3EE);
const _purple = Color(0xFFA78BFA);
const _grid = Color(0xFF334155);
const _axisText = Color(0xFF94A3B8);

/// Shared chart chrome: a titled, rounded card wrapper with an "average" pill.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.averageLabel,
    required this.child,
  });

  final String title;
  final String averageLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _grid),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  averageLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _cyan,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(height: 180, child: child),
        ],
      ),
    );
  }
}

/// Friendly empty state shown when there isn't enough data to plot.
class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: title,
      averageLabel: '—',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insights_outlined,
                size: 40, color: Color(0xFF64748B)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFA0AEC0),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sleep trend as an animated, curved line chart (last 7 days).
class SleepLineChart extends StatelessWidget {
  const SleepLineChart({super.key, required this.points});

  final List<HealthPoint> points;

  @override
  Widget build(BuildContext context) {
    final withSleep = points.where((p) => p.sleepHours != null).toList();
    if (withSleep.isEmpty) {
      return const _ChartEmpty(
        title: 'Sleep Trend (Last 7 Days)',
        message: 'Add sleep data to see your trend here.',
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final s = points[i].sleepHours;
      if (s != null) spots.add(FlSpot(i.toDouble(), s));
    }
    final avg = withSleep.map((p) => p.sleepHours!).reduce((a, b) => a + b) /
        withSleep.length;

    return _ChartCard(
      title: 'Sleep Trend (Last 7 Days)',
      averageLabel: 'avg ${avg.toStringAsFixed(1)} h',
      child: LineChart(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: 0,
          maxY: 12,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 3,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: _grid, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles:
                AxisTitles(sideTitles: _bottomSideTitles(points)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 3,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: _axisText, fontSize: 11),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: avg,
                color: _cyan.withValues(alpha: 0.6),
                strokeWidth: 1.5,
                dashArray: [6, 4],
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF0F172A),
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(1)} h',
                        const TextStyle(
                            color: _cyan, fontWeight: FontWeight.bold),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: _cyan,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: _cyan,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF0F172A),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: _cyan.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Steps trend as an animated bar chart with a cyan→purple gradient (last 7
/// days) and a dashed 10k reference line.
class StepsBarChart extends StatelessWidget {
  const StepsBarChart({super.key, required this.points});

  final List<HealthPoint> points;

  @override
  Widget build(BuildContext context) {
    final withSteps = points.where((p) => p.steps != null).toList();
    if (withSteps.isEmpty) {
      return const _ChartEmpty(
        title: 'Steps Trend (Last 7 Days)',
        message: 'Add step data to see your trend here.',
      );
    }

    final avg = withSteps.map((p) => p.steps!).reduce((a, b) => a + b) /
        withSteps.length;

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < points.length; i++) {
      final steps = points[i].steps;
      if (steps == null) continue;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: steps.toDouble(),
              width: 16,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
              ),
              gradient: const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [_cyan, _purple],
              ),
            ),
          ],
        ),
      );
    }

    return _ChartCard(
      title: 'Steps Trend (Last 7 Days)',
      averageLabel: 'avg ${avg.round()}',
      child: BarChart(
        swapAnimationDuration: const Duration(milliseconds: 800),
        swapAnimationCurve: Curves.easeInOut,
        BarChartData(
          minY: 0,
          maxY: 15000,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 5000,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: _grid, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: _bottomSideTitles(points)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 5000,
                getTitlesWidget: (value, meta) => Text(
                  '${(value / 1000).round()}k',
                  style: const TextStyle(color: _axisText, fontSize: 11),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 10000,
                color: _purple.withValues(alpha: 0.6),
                strokeWidth: 1.5,
                dashArray: [6, 4],
              ),
            ],
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF0F172A),
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                '${rod.toY.round()}',
                const TextStyle(color: _cyan, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          barGroups: groups,
        ),
      ),
    );
  }
}

/// Bottom day-of-week axis labels shared by both charts.
SideTitles _bottomSideTitles(List<HealthPoint> points) {
  return SideTitles(
    showTitles: true,
    reservedSize: 28,
    getTitlesWidget: (value, meta) {
      final i = value.round();
      if (i < 0 || i >= points.length || (value - i).abs() > 0.01) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          points[i].weekdayLabel,
          style: const TextStyle(color: _axisText, fontSize: 11),
        ),
      );
    },
  );
}
