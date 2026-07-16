import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/share_models.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_entrance.dart';

/// ShareHistoryScreen — list every share, with a live countdown and a revoke
/// action. A single 1-second [Timer] drives all the countdown labels; there is
/// no AI and no network here.
class ShareHistoryScreen extends StatefulWidget {
  const ShareHistoryScreen({super.key});

  @override
  State<ShareHistoryScreen> createState() => _ShareHistoryScreenState();
}

class _ShareHistoryScreenState extends State<ShareHistoryScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Make sure the cache is populated (e.g. when deep-linked here directly).
    final service = context.read<ShareService>();
    if (!service.isLoaded) service.load();

    // Rebuild once a second so countdowns stay current.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share History')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Consumer<ShareService>(
              builder: (context, service, _) {
                final shares = service.shares;
                if (shares.isEmpty) return _empty();

                final active = shares.where((s) => s.isActive()).toList();
                final inactive = shares.where((s) => !s.isActive()).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    if (active.isNotEmpty) ...[
                      _groupLabel('Active (${active.length})'),
                      for (var i = 0; i < active.length; i++)
                        AnimatedEntrance(
                          delay: Duration(milliseconds: 40 * i),
                          offset: 20,
                          child: _shareCard(service, active[i]),
                        ),
                    ],
                    if (inactive.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _groupLabel('Expired / revoked (${inactive.length})'),
                      for (final s in inactive) _shareCard(service, s),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 0.5,
              fontWeight: FontWeight.bold,
            ),
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
            const Icon(Icons.share_outlined,
                size: 56, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text('No shares yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Create a share link to give someone temporary, read-only access.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.go('/share'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Share Health Data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shareCard(ShareService service, HealthShare share) {
    final active = share.isActive();
    final statusColor = active
        ? AppColors.primary
        : (share.revoked ? AppColors.danger : AppColors.textFaint);
    final statusText = active
        ? 'Active'
        : (share.revoked ? 'Revoked' : 'Expired');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${share.records.length} record'
                  '${share.records.length == 1 ? '' : 's'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 18, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    share.recipientEmail,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  active ? Icons.timer_outlined : Icons.timer_off_outlined,
                  size: 18,
                  color: active ? AppColors.primary : AppColors.textFaint,
                ),
                const SizedBox(width: 6),
                Text(
                  active
                      ? 'Expires in ${formatRemaining(share.remaining())}'
                      : (share.revoked
                          ? 'Access revoked'
                          : 'Access has expired'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: active ? AppColors.text : AppColors.textMuted,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (active)
                  TextButton.icon(
                    onPressed: () => _copyLink(share),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy link'),
                  ),
                const Spacer(),
                if (active)
                  TextButton.icon(
                    onPressed: () => _confirmRevoke(service, share),
                    icon: const Icon(Icons.block, size: 16),
                    label: const Text('Revoke'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger),
                  )
                else
                  TextButton.icon(
                    onPressed: () => service.delete(share.token),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _linkFor(String token) => '${Uri.base.origin}/#/shared/$token';

  Future<void> _copyLink(HealthShare share) async {
    await Clipboard.setData(ClipboardData(text: _linkFor(share.token)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  Future<void> _confirmRevoke(ShareService service, HealthShare share) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke access?'),
        content: Text(
          'This immediately ends ${share.recipientEmail}\'s access. The link '
          'will stop working. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await service.revoke(share.token);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Access revoked')),
    );
  }
}
