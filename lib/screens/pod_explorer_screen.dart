import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../services/solid_service.dart';
import '../widgets/animated_entrance.dart';

/// PodExplorerScreen - Browse and manage your Solid Pod contents
///
/// This screen allows you to explore the structure of your Pod
/// and view the files stored in your medi-sync container.
class PodExplorerScreen extends StatefulWidget {
  const PodExplorerScreen({super.key});

  @override
  State<PodExplorerScreen> createState() => _PodExplorerScreenState();
}

class _PodExplorerScreenState extends State<PodExplorerScreen> {
  late Future<List<String>> _healthDataFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    final solidService = context.read<SolidService>();
    _healthDataFuture = solidService.listHealthData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pod Explorer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_refreshData),
          ),
        ],
      ),
      body: Consumer<SolidService>(
        builder: (context, solidService, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pod Structure Overview
                _buildPodStructure(solidService),

                const SizedBox(height: 24),

                // medi-sync Container
                _buildContainerSection(solidService),

                const SizedBox(height: 24),

                // Info Section
                _buildInfoSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build an overview of the Pod structure
  Widget _buildPodStructure(SolidService solidService) {
    final podRoot = solidService.webId?.split('/profile/').first ?? 'Unknown';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloud_outlined,
                  color: Color(0xFF22D3EE),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Pod Structure',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTreeNode(Icons.folder, podRoot.split('/').last.isEmpty
                ? 'Pod Root'
                : podRoot.split('/').last, 0),
            _buildTreeNode(Icons.folder_open, 'profile/', 1),
            _buildTreeNode(Icons.description, 'card', 2),
            _buildTreeNode(Icons.folder_open, 'medi-sync/', 1,
                highlight: true),
          ],
        ),
      ),
    );
  }

  /// Build a single node in the Pod tree view
  Widget _buildTreeNode(IconData icon, String label, int depth,
      {bool highlight = false}) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 20.0, top: 6, bottom: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: highlight ? const Color(0xFF22D3EE) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: highlight ? const Color(0xFF22D3EE) : const Color(0xFFE2E8F0),
              fontFamily: 'monospace',
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the medi-sync container listing section
  Widget _buildContainerSection(SolidService solidService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'medi-sync Container',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Files stored by MediSync in your Pod.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFFA0AEC0),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<String>>(
          future: _healthDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Error loading container: ${snapshot.error}',
                    style: const TextStyle(color: Color(0xFFF87171)),
                  ),
                ),
              );
            }

            final files = snapshot.data ?? [];

            if (files.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.folder_open,
                        size: 48,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'The container is empty',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFA0AEC0),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Text(
                    '${files.length} file${files.length == 1 ? '' : 's'} · Turtle (RDF)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    return AnimatedEntrance(
                      delay: Duration(milliseconds: 60 * index),
                      offset: 24,
                      child: _buildFileTile(files[index]),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Build a single file row with a document icon, size hint, and chevron.
  Widget _buildFileTile(String fileName) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF22D3EE).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.description_outlined,
            color: Color(0xFF22D3EE),
            size: 22,
          ),
        ),
        title: Text(
          fileName,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        subtitle: const Text('Turtle (RDF) · text/turtle'),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  /// Build the information section
  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About Your Pod',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF22D3EE),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A Pod is your personal online datastore. Everything MediSync writes is stored as standard Turtle (RDF) files inside the medi-sync container, so you can inspect, export, or delete it at any time using any Solid-compatible tool.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFA0AEC0),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
