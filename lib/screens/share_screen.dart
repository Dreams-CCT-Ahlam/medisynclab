import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/share_models.dart';
import '../services/share_service.dart';
import '../services/solid_service.dart';
import '../theme/app_colors.dart';

/// ShareScreen — create a time-limited, read-only share of health records.
///
/// The flow is entirely local: pick a recipient, an expiry window, and which
/// records to include, then we snapshot those records and generate a unique
/// link. NO Claude/AI calls are made — the data is displayed as-is.
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  ShareDuration _duration = ShareDuration.oneDay;

  /// Available Pod files (loaded once) and the set the user has ticked.
  Future<List<String>>? _filesFuture;
  final Set<String> _selected = {};

  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _filesFuture = context.read<SolidService>().listHealthData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Health Data'),
        actions: [
          IconButton(
            tooltip: 'Share history',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/share-history'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _intro(),
                    const SizedBox(height: 24),
                    _sectionLabel('Recipient email'),
                    const SizedBox(height: 8),
                    _emailField(),
                    const SizedBox(height: 24),
                    _sectionLabel('Access expires after'),
                    const SizedBox(height: 8),
                    _durationSelector(),
                    const SizedBox(height: 24),
                    _sectionLabel('Data to share'),
                    const SizedBox(height: 8),
                    _dataSelector(),
                    const SizedBox(height: 28),
                    _shareButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_clock, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Generate a temporary, read-only link to share selected records '
              'with your doctor. Access ends automatically when it expires, and '
              'you can revoke it anytime.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        hintText: 'doctor@clinic.com',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (value) {
        final v = (value ?? '').trim();
        if (v.isEmpty) return 'Please enter the recipient\'s email';
        // Lightweight check — good enough for a demo, no external validator.
        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
        if (!ok) return 'Please enter a valid email address';
        return null;
      },
    );
  }

  Widget _durationSelector() {
    return SegmentedButton<ShareDuration>(
      segments: [
        for (final d in ShareDuration.values)
          ButtonSegment<ShareDuration>(value: d, label: Text(d.label)),
      ],
      selected: {_duration},
      onSelectionChanged: (s) => setState(() => _duration = s.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _dataSelector() {
    return FutureBuilder<List<String>>(
      future: _filesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final files = {...(snapshot.data ?? <String>[])}.toList()..sort();

        if (files.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'No health records to share yet. Add some in Records first.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          );
        }

        return Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < files.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                CheckboxListTile(
                  value: _selected.contains(files[i]),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selected.add(files[i]);
                    } else {
                      _selected.remove(files[i]);
                    }
                  }),
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(files[i]),
                  secondary: const Icon(Icons.description_outlined,
                      color: AppColors.textMuted, size: 20),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _shareButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _creating ? null : _handleShare,
        icon: _creating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.ios_share, size: 18),
        label: Text(_creating ? 'Preparing link…' : 'Create share link'),
      ),
    );
  }

  Future<void> _handleShare() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one record to share')),
      );
      return;
    }

    setState(() => _creating = true);

    final solidService = context.read<SolidService>();
    final shareService = context.read<ShareService>();

    // Snapshot each selected record now so the recipient view needs no Pod
    // access later. Reads run concurrently; unreadable files are skipped.
    final selectedFiles = _selected.toList()..sort();
    final reads = await Future.wait(selectedFiles.map(solidService.readHealthData));

    final records = <SharedRecord>[];
    for (var i = 0; i < selectedFiles.length; i++) {
      final data = reads[i];
      if (data == null) continue;
      final fields = <String, String>{
        for (final e in data.entries)
          if (!e.key.startsWith('_')) e.key: '${e.value}',
      };
      records.add(SharedRecord(
        fileName: selectedFiles[i],
        fields: fields,
        raw: (data['_raw'] as String?) ?? '',
      ));
    }

    if (!mounted) return;

    if (records.isEmpty) {
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(solidService.errorMessage ??
              'Could not read the selected records. Please try again.'),
        ),
      );
      return;
    }

    final share = await shareService.createShare(
      recipientEmail: _emailController.text,
      duration: _duration,
      records: records,
    );

    if (!mounted) return;
    setState(() => _creating = false);
    _showLinkDialog(share);
  }

  /// Build the shareable link for [token].
  ///
  /// The router uses hash-based URLs on web, so the recipient route lives after
  /// the `#`. [Uri.base] gives the current origin at runtime.
  String _linkFor(String token) {
    final origin = Uri.base.origin;
    return '$origin/#/shared/$token';
  }

  void _showLinkDialog(HealthShare share) {
    final link = _linkFor(share.token);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Share link ready'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send this link to ${share.recipientEmail}. It gives read-only '
              'access to ${share.records.length} record'
              '${share.records.length == 1 ? '' : 's'} and expires in '
              '${_duration.label}.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push('/share-history');
            },
            child: const Text('View history'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy link'),
          ),
        ],
      ),
    );
  }
}
