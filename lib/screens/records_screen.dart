import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/solid_service.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_entrance.dart';

/// RecordsScreen - view, add, and delete the health-data files in your Pod.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  Future<List<String>>? _filesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _filesFuture = context.read<SolidService>().listHealthData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final solidService = context.watch<SolidService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Records'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddHealthDataDialog(solidService),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Add data'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: FutureBuilder<List<String>>(
              future: _filesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final files = {...(snapshot.data ?? <String>[])}.toList()
                  ..sort();

                if (files.isEmpty) {
                  return _empty();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                  itemCount: files.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: Text(
                          '${files.length} file${files.length == 1 ? '' : 's'} · Turtle (RDF)',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      );
                    }
                    final name = files[index - 1];
                    return AnimatedEntrance(
                      delay: Duration(milliseconds: 40 * (index - 1)),
                      offset: 20,
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.description_outlined,
                                color: AppColors.primary, size: 22),
                          ),
                          title: Text(name),
                          subtitle: const Text('Tap to view · Turtle (RDF)'),
                          onTap: () => _showFileContents(solidService, name),
                          trailing: IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: AppColors.danger),
                            onPressed: () =>
                                _confirmDelete(solidService, name),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
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
            const Icon(Icons.folder_open,
                size: 56, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text('No health data yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Tap "Add data" to store your first entry in your Pod.',
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

  /// View the contents of a health-data file, with a Copy button.
  Future<void> _showFileContents(SolidService solidService, String fileName) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.description, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(fileName, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<Map<String, dynamic>?>(
            future: solidService.readHealthData(fileName),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final data = snapshot.data;
              if (data == null) {
                return const Text('Could not read this file.');
              }

              final raw = (data['_raw'] as String?) ?? '';
              final entries =
                  data.entries.where((e) => !e.key.startsWith('_')).toList();

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...entries.map(
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
                            Expanded(child: Text('${e.value}')),
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 4),
                    Text(
                      'Raw (Turtle)',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SelectableText(
                        raw.isEmpty ? '(empty)' : raw,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: raw));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Copied to clipboard')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      SolidService solidService, String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Delete $fileName? This cannot be undone.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await solidService.deleteHealthData(fileName);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '$fileName deleted'
            : (solidService.errorMessage ?? 'Failed to delete file')),
      ),
    );

    if (ok) _reload();
  }

  void _showAddHealthDataDialog(SolidService solidService) {
    final fileNameController = TextEditingController();
    final sleepHoursController = TextEditingController();
    final stepsController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Health Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fileNameController,
              decoration: const InputDecoration(
                labelText: 'File Name',
                hintText: 'e.g., daily_log_2026_07_14',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sleepHoursController,
              decoration: const InputDecoration(
                labelText: 'Sleep Hours',
                hintText: 'e.g., 7.5',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stepsController,
              decoration: const InputDecoration(
                labelText: 'Steps',
                hintText: 'e.g., 8000',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final fileName = fileNameController.text.trim();
              if (fileName.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a file name')),
                );
                return;
              }

              final data = {
                'sleepHours': sleepHoursController.text.trim(),
                'steps': stepsController.text.trim(),
                'timestamp': DateTime.now().toIso8601String(),
              };

              final success =
                  await solidService.writeHealthData(fileName, data);

              if (!mounted) return;
              Navigator.pop(dialogContext);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success
                      ? 'Health data saved!'
                      : (solidService.errorMessage ?? 'Failed to save')),
                ),
              );

              if (success) _reload();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
