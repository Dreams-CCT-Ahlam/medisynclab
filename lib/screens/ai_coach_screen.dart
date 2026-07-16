import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/solid_service.dart';
import '../services/ai_service.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_entrance.dart';

/// The data backing the AI Health Coach card.
class _CoachData {
  _CoachData({
    required this.fileName,
    required this.data,
    required this.insight,
    required this.timestamp,
  });

  final String fileName;
  final Map<String, dynamic> data;
  final String insight;
  final String timestamp; // ISO-8601 generation time
}

/// AiCoachScreen - shows a private AI insight for the most recent Pod entry.
class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final AiService _aiService = AiService();
  Future<_CoachData?>? _coachFuture;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _coachFuture = _loadLatestInsight(context.read<SolidService>());
  }

  Future<_CoachData?> _loadLatestInsight(SolidService svc,
      {bool force = false}) async {
    final files = await svc.listHealthData();
    if (files.isEmpty) return null;

    final sorted = [...files]..sort();
    final latest = sorted.last;

    final data = await svc.readHealthData(latest);
    if (data == null) return null;

    String insight;
    String timestamp;

    final cached = force ? null : await svc.getCachedInsight(latest);
    if (cached != null && cached['insight'] is String) {
      insight = cached['insight'] as String;
      timestamp =
          (cached['timestamp'] as String?) ?? DateTime.now().toIso8601String();
    } else {
      insight = await _aiService.analyzeHealthData(data);
      timestamp = DateTime.now().toIso8601String();
      await svc.cacheInsight(latest, insight, timestamp);
    }

    return _CoachData(
      fileName: latest,
      data: data,
      insight: insight,
      timestamp: timestamp,
    );
  }

  void _refresh({bool force = false}) {
    final svc = context.read<SolidService>();
    final future = _loadLatestInsight(svc, force: force);
    setState(() {
      _coachFuture = future;
      if (force) _isRefreshing = true;
    });
    future.whenComplete(() {
      if (mounted && _isRefreshing) {
        setState(() => _isRefreshing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Health Coach'),
        actions: [
          IconButton(
            tooltip: 'Get a fresh insight',
            onPressed: _isRefreshing ? null : () => _refresh(force: true),
            icon: SpinningIcon(
              icon: Icons.refresh,
              spinning: _isRefreshing,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        'Your latest insight',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<_CoachData?>(
                    future: _coachFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _coachCard(
                          border: AppColors.border,
                          child: const Row(
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                  child: Text('Analyzing your latest data…')),
                            ],
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return _coachCard(
                          border: AppColors.danger,
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.danger, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                        'Unable to generate insight right now'),
                                    const SizedBox(height: 6),
                                    TextButton(
                                      onPressed: () => _refresh(force: true),
                                      child: const Text('Try again'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final coach = snapshot.data;
                      if (coach == null) {
                        return _coachCard(
                          border: AppColors.border,
                          child: const Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  color: AppColors.textFaint),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Add health data in Records to get your first AI insight.',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return AnimatedEntrance(child: _buildInsightCard(coach));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The insight card: sentiment gradient, left accent bar, soft shadow,
  /// translucent metric chips, and a relative timestamp.
  Widget _buildInsightCard(_CoachData coach) {
    final sentiment = _sentimentOf(coach.insight);
    final gradient = sentiment.gradient;
    final accent = sentiment.accent;
    final sleep = coach.data['sleepHours']?.toString();
    final steps = coach.data['steps']?.toString();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
          ),
          // IntrinsicHeight gives the Row a bounded height (the content
          // column's height) so the full-height accent bar's
          // CrossAxisAlignment.stretch resolves instead of forcing infinite
          // height inside the scroll view.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('💡', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI Health Coach',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.85),
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                  Text(
                                    coach.fileName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.7),
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (sleep != null || steps != null) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (sleep != null && sleep.isNotEmpty)
                                _metricChip('😴 $sleep h sleep'),
                              if (steps != null && steps.isNotEmpty)
                                _metricChip('👟 $steps steps'),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          coach.insight,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Generated ${_relativeTime(coach.timestamp)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _coachCard({required Color border, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  Widget _metricChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }

  /// Map the insight's sentiment to a gradient + accent color.
  ({List<Color> gradient, Color accent}) _sentimentOf(String insight) {
    final t = insight.toLowerCase();
    const red = ['low', 'need', 'should', 'warning', "don't", 'avoid'];
    const green = ['great', 'excellent', 'good', 'keep it up', 'well', 'nice'];
    const yellow = ['could', 'try', 'consider', 'improve', 'aim'];

    if (red.any(t.contains)) {
      return (
        gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
        accent: const Color(0xFFB91C1C),
      );
    }
    if (green.any(t.contains)) {
      return (
        gradient: const [Color(0xFF10B981), Color(0xFF059669)],
        accent: const Color(0xFF047857),
      );
    }
    if (yellow.any(t.contains)) {
      return (
        gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
        accent: const Color(0xFFB45309),
      );
    }
    // Default: the brand teal.
    return (
      gradient: const [AppColors.primary, AppColors.primaryDark],
      accent: const Color(0xFF115E59),
    );
  }

  String _relativeTime(String iso) {
    try {
      final then = DateTime.parse(iso);
      final diff = DateTime.now().difference(then);
      if (diff.inSeconds < 45) return 'just now';
      if (diff.inMinutes < 60) {
        final m = diff.inMinutes;
        return '$m minute${m == 1 ? '' : 's'} ago';
      }
      if (diff.inHours < 24) {
        final h = diff.inHours;
        return '$h hour${h == 1 ? '' : 's'} ago';
      }
      final d = diff.inDays;
      return '$d day${d == 1 ? '' : 's'} ago';
    } catch (_) {
      return 'recently';
    }
  }
}
