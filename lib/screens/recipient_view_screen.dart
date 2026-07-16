import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/share_models.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../widgets/beating_heart.dart';

/// RecipientViewScreen — what a doctor sees when they open a shared link.
///
/// This screen is read-only and completely self-contained: it renders the
/// snapshot stored in the [HealthShare] with NO Pod access, NO login, and NO
/// AI analysis. If the token is unknown, revoked, or expired, access is denied.
class RecipientViewScreen extends StatefulWidget {
  const RecipientViewScreen({super.key, required this.token});

  final String token;

  @override
  State<RecipientViewScreen> createState() => _RecipientViewScreenState();
}

class _RecipientViewScreenState extends State<RecipientViewScreen> {
  late Future<HealthShare?> _shareFuture;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _shareFuture = context.read<ShareService>().findByToken(widget.token);
    // Refresh the countdown / auto-expire the view once a second.
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
            const Text('MediSync Lab · Shared'),
            const SizedBox(width: 8),
            const BeatingHeart(),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: FutureBuilder<HealthShare?>(
              future: _shareFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final share = snapshot.data;
                if (share == null) {
                  return _denied(
                    icon: Icons.link_off,
                    title: 'Link not found',
                    message:
                        'This share link is invalid or has been removed.',
                  );
                }
                if (share.revoked) {
                  return _denied(
                    icon: Icons.block,
                    title: 'Access revoked',
                    message:
                        'The owner has revoked access to this shared data.',
                  );
                }
                if (share.isExpired()) {
                  return _denied(
                    icon: Icons.timer_off,
                    title: 'Access expired',
                    message: 'This share link is no longer valid.',
                  );
                }

                return _content(share);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _denied({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
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

  Widget _content(HealthShare share) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        _expiryBanner(share),
        const SizedBox(height: 20),
        Text(
          'Shared health records',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Read-only · shared with ${share.recipientEmail}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        for (final record in share.records) _recordCard(record),
      ],
    );
  }

  Widget _expiryBanner(HealthShare share) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Access expires in ${formatRemaining(share.remaining())}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'This is a temporary, read-only view of shared data.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordCard(SharedRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.fileName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (record.fields.isEmpty)
              Text(
                'No readable fields in this record.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              )
            else
              ...record.fields.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(child: Text(e.value)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
