import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/solid_service.dart';
import '../theme/app_colors.dart';

/// PodInfoScreen — a read-only view of the user's Solid identity: their WebID,
/// display name, and the Pod root derived from the WebID.
///
/// Purely informational. No AI, no writes — just surfaces what [SolidService]
/// already knows about the current session.
class PodInfoScreen extends StatelessWidget {
  const PodInfoScreen({super.key});

  /// Derive the Pod root from a WebID, mirroring SolidService's own logic:
  /// `https://pods.example/alice/profile/card#me` -> `https://pods.example/alice/`.
  static String? _podRootFrom(String? webId) {
    if (webId == null || webId.isEmpty) return null;
    final base = webId.split('/profile/').first;
    return base.endsWith('/') ? base : '$base/';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebID & Profile')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Consumer<SolidService>(
              builder: (context, solid, _) {
                final webId = solid.webId;
                final name = solid.profile?['name']?.toString() ?? 'User';
                final podRoot = _podRootFrom(webId);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    _identityHeader(context, name),
                    const SizedBox(height: 24),
                    _field(context, 'Display name', name, Icons.person_outline),
                    _field(context, 'WebID', webId ?? '—', Icons.badge_outlined,
                        copyable: true),
                    _field(context, 'Pod root', podRoot ?? '—',
                        Icons.cloud_outlined,
                        copyable: true),
                    _field(
                      context,
                      'Session',
                      solid.isLoggedIn ? 'Connected' : 'Not connected',
                      Icons.link,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityHeader(BuildContext context, String name) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.verified_user,
              color: AppColors.onPrimary, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(
                'Your Solid identity',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(BuildContext context, String label, String value, IconData icon,
      {bool copyable = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    value,
                    style: const TextStyle(color: AppColors.text),
                  ),
                ],
              ),
            ),
            if (copyable && value != '—')
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy, size: 18),
                color: AppColors.textMuted,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copied')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
