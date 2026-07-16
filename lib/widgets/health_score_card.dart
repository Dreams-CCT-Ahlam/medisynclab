import 'package:flutter/material.dart';

import '../models/health_models.dart';

/// A hero card summarizing the overall health score: a big X/10 number that
/// counts up on entry, a 5-star rating, a trend arrow, and the three
/// component sub-scores as animated meters.
class HealthScoreCard extends StatelessWidget {
  const HealthScoreCard({super.key, required this.score});

  final HealthScore score;

  @override
  Widget build(BuildContext context) {
    final accent = score.level.color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            Color.lerp(const Color(0xFF1E293B), accent, 0.18)!,
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Health Score',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFFA0AEC0),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              _TrendPill(trend: score.trend),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Count-up big number.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score.outOfTen),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (context, value, _) => Text(
                  value.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 48,
                        height: 1,
                        color: accent,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 2),
                child: Text(
                  '/10',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFA0AEC0),
                      ),
                ),
              ),
              const Spacer(),
              _StarRating(stars: score.stars, color: accent),
            ],
          ),
          const SizedBox(height: 20),
          _ScoreMeter(
              label: 'Sleep', value: score.sleepScore, color: accent),
          const SizedBox(height: 10),
          _ScoreMeter(
              label: 'Steps', value: score.stepsScore, color: accent),
          const SizedBox(height: 10),
          _ScoreMeter(
              label: 'Consistency',
              value: score.consistencyScore,
              color: accent),
        ],
      ),
    );
  }
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.trend});

  final HealthTrend trend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trend.arrow, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            trend.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.stars, required this.color});

  final int stars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < stars;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 22,
          color: filled ? color : const Color(0xFF475569),
        );
      }),
    );
  }
}

class _ScoreMeter extends StatelessWidget {
  const _ScoreMeter({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label; // e.g. "Sleep"
  final double value; // 0–100
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFA0AEC0),
                ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, fraction, _) => LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: const Color(0xFF0F172A),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text(
            '${value.round()}',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
