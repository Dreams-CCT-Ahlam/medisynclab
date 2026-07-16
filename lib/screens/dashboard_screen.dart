import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/solid_service.dart';
import '../models/health_models.dart';
import '../theme/app_colors.dart';
import '../widgets/health_charts.dart';
import '../widgets/health_score_card.dart';
import '../widgets/health_status_badge.dart';

/// DashboardScreen - sleep & steps charts, status badges, and health score,
/// all driven by the last 7 days of Pod data.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<List<HealthPoint>>? _seriesFuture;

  @override
  void initState() {
    super.initState();
    _seriesFuture = context.read<SolidService>().parseHealthDataForCharts();
  }

  void _refresh() {
    setState(() {
      _seriesFuture = context.read<SolidService>().parseHealthDataForCharts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<SolidService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: FutureBuilder<List<HealthPoint>>(
              future: _seriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _skeleton();
                }

                final points = snapshot.data ?? const <HealthPoint>[];
                if (points.isEmpty) {
                  return _empty();
                }

                final latest = points.last;
                final score = svc.calculateHealthScore(points);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SleepLineChart(points: points),
                      const SizedBox(height: 16),
                      StepsBarChart(points: points),
                      const SizedBox(height: 16),
                      _buildStatusBadges(latest),
                      const SizedBox(height: 16),
                      HealthScoreCard(score: score),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadges(HealthPoint latest) {
    final badges = <Widget>[];
    if (latest.sleepHours != null) {
      badges.add(HealthStatusBadge(
        metricLabel: 'Sleep',
        valueLabel: '${latest.sleepHours!.toStringAsFixed(1)} hours',
        level: HealthStatusBadge.levelForSleep(latest.sleepHours!),
      ));
    }
    if (latest.steps != null) {
      badges.add(HealthStatusBadge(
        metricLabel: 'Steps',
        valueLabel: _thousands(latest.steps!),
        level: HealthStatusBadge.levelForSteps(latest.steps!),
      ));
    }
    if (badges.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(spacing: 12, runSpacing: 12, children: badges),
    );
  }

  Widget _skeleton() {
    Widget box(double height) => Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          box(232),
          const SizedBox(height: 16),
          box(232),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_rounded,
                size: 56, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(
              'Your dashboard is waiting',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Add a health entry in Records to unlock trends, badges, and your score.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  String _thousands(int value) {
    final s = value.abs().toString();
    final buf = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
