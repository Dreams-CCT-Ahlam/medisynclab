import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../services/solid_service.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_entrance.dart';
import '../widgets/beating_heart.dart';
import '../widgets/feature_tile.dart';

/// HomeScreen - the tile-grid dashboard (HealthPod-inspired).
///
/// The home is now a launcher: a welcome header plus a grid of feature tiles.
/// Each tile opens a focused screen (dashboard, AI coach, records, pod info,
/// pod explorer). The heavy lifting lives in those dedicated screens.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Make sure the medi-sync container exists so the feature screens have a
    // place to read/write. Best-effort; failures surface inside those screens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SolidService>().createMediSyncContainer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Center(
                child: Text('🏥', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            const Text('MediSync Lab'),
            const SizedBox(width: 8),
            const BeatingHeart(),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<SolidService>(
        builder: (context, solidService, _) {
          final userName = solidService.profile?['name'] ?? 'there';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcome(userName),
                      const SizedBox(height: 24),
                      _buildGrid(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcome(String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $userName! 👋',
          style: Theme.of(context)
              .textTheme
              .displayMedium
              ?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          'Your health data lives in your Solid Pod — pick a tool to get started.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    final tiles = <Widget>[
      FeatureTile(
        icon: Icons.insights_rounded,
        title: 'Health Dashboard',
        subtitle: 'Sleep & steps trends, badges, and your score',
        color: AppColors.primary,
        onTap: () => context.push('/dashboard'),
      ),
      FeatureTile(
        icon: Icons.auto_awesome_rounded,
        title: 'AI Health Coach',
        subtitle: 'A private insight on your latest entry',
        color: AppColors.accent,
        onTap: () => context.push('/coach'),
      ),
      FeatureTile(
        icon: Icons.folder_shared_rounded,
        title: 'Records',
        subtitle: 'View, add, and delete your health data',
        color: AppColors.primary,
        onTap: () => context.push('/records'),
      ),
      FeatureTile(
        icon: Icons.ios_share_rounded,
        title: 'Share with Doctor',
        subtitle: 'Temporary, read-only links you can revoke',
        color: AppColors.accent,
        onTap: () => context.push('/share'),
      ),
      FeatureTile(
        icon: Icons.badge_rounded,
        title: 'WebID & Profile',
        subtitle: 'Your identity and Pod connection',
        color: AppColors.accent,
        onTap: () => context.push('/pod-info'),
      ),
      FeatureTile(
        icon: Icons.travel_explore_rounded,
        title: 'Pod Explorer',
        subtitle: 'Browse the structure of your Pod',
        color: AppColors.primary,
        onTap: () => context.push('/pod-explorer'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive: 1 column on narrow phones, 2–3 on wider screens.
        final width = constraints.maxWidth;
        final crossAxisCount = width < 500
            ? 1
            : width < 760
                ? 2
                : 3;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.15,
          children: [
            for (var i = 0; i < tiles.length; i++)
              AnimatedEntrance(
                delay: Duration(milliseconds: 60 * i),
                offset: 24,
                child: tiles[i],
              ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final solidService = context.read<SolidService>();
    await solidService.logout();
    if (mounted) {
      context.go('/login');
    }
  }
}
