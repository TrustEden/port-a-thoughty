import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/processed_doc.dart';
import '../state/app_state.dart';
import '../widgets/app_header.dart';
import '../widgets/project_selector.dart';

class DocsScreen extends StatelessWidget {
  const DocsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PortaThoughtyState>();
    final docs = state.docs;
    final lastDoc = state.lastProcessedDoc;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
      children: [
        const AppHeader(),
        const SizedBox(height: 18),
        const ProjectSelector(),
        if (lastDoc != null)
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18014F8E),
                  blurRadius: 26,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Processed "${lastDoc.title}" moments ago. Need to revert?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => state.undoLastProcess(),
                  child: const Text('Undo'),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Docs & summaries',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: () => _showTokenEstimator(context),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Token safety'),
              ),
            ],
          ),
        ),
        if (docs.isEmpty)
          const _EmptyDocsPlaceholder()
        else
          ...docs.map(
            (doc) => _DocCard(
              doc: doc,
              onPreview: () => _showDocPreview(context, doc),
              onShare: () => _shareDoc(context, doc),
              onDelete: () => _confirmDeleteDoc(context, doc),
              canShare: (doc.markdownPath ?? '').isNotEmpty,
            ),
          ),
      ],
    );
  }

  Future<void> _showDocPreview(BuildContext context, ProcessedDoc doc) {
    return showModalBottomSheet<void>(
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return FutureBuilder<String?>(
          future: _loadMarkdown(doc.markdownPath),
          builder: (context, snapshot) {
            final content = snapshot.data;
            final error = snapshot.error;
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final hasContent = (content?.trim().isNotEmpty ?? false);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.article_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              doc.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            _dateLabel(doc.createdAt),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Key bullet points',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 12),
                      if (doc.summary.isEmpty)
                        Text(
                          'Summary preview not available.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        ...doc.summary.map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('- '),
                                Expanded(
                                  child: Text(
                                    line,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Markdown export',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 12),
                      if (loading)
                        const Center(child: CircularProgressIndicator())
                      else if (error != null)
                        Text(
                          'Could not load Markdown: $error',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        )
                      else if (!hasContent)
                        Text(
                          'Markdown file missing or empty. Try reprocessing the notes.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12),
                            ),
                          ),
                          child: SelectableText(
                            content!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: hasContent
                            ? () => _shareDoc(context, doc)
                            : null,
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _loadMarkdown(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      return file.readAsString();
    } catch (error) {
      return Future<String?>.error(error);
    }
  }

  Future<void> _shareDoc(BuildContext context, ProcessedDoc doc) async {
    final path = doc.markdownPath;
    final messenger = ScaffoldMessenger.of(context);
    if (path == null || path.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Markdown file missing. Try reprocessing this doc.'),
        ),
      );
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Markdown file not found on disk.')),
      );
      return;
    }

    try {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/markdown')],
        text: doc.title,
        subject: doc.title,
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to share document: $error')),
      );
    }
  }

  Future<void> _confirmDeleteDoc(BuildContext context, ProcessedDoc doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
          'This will permanently delete "${doc.title}" and its markdown file. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final state = context.read<PortaThoughtyState>();
      final success = await state.deleteDoc(doc);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted')),
        );
      }
    }
  }

  Future<void> _showTokenEstimator(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Token & API safeguards',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'In the production build this panel would:\n'
                '- Estimate tokens before sending to Groq/OpenAI\n'
                '- Warn if a batch exceeds the context window\n'
                '- Show cost projections when API keys are configured\n'
                '- Offer a local cap for anonymous usage',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.doc,
    required this.onPreview,
    required this.onShare,
    required this.onDelete,
    required this.canShare,
  });

  final ProcessedDoc doc;
  final VoidCallback onPreview;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final bool canShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12014F8E),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onPreview,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/docs.png',
                    width: 60,
                    height: 60,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${doc.summary.length} bullet points - ${_timeAgo(doc.createdAt)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: onPreview,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...doc.summary
                  .take(3)
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('- '),
                          Expanded(
                            child: Text(
                              line,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (doc.summary.length > 3)
                Text(
                  '+ ${doc.summary.length - 3} more bullet${doc.summary.length - 3 == 1 ? '' : 's'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPreview,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Preview'),
                  ),
                  OutlinedButton.icon(
                    onPressed: canShare ? onShare : null,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                  ),
                  OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      shape: const CircleBorder(),
                    ),
                    child: Image.asset(
                      'assets/trashicon.png',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
  }
}

class _EmptyDocsPlaceholder extends StatelessWidget {
  const _EmptyDocsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 48),
      padding: const EdgeInsets.fromLTRB(26, 40, 26, 44),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Image.asset('assets/logo.png', height: 64, fit: BoxFit.contain),
          const SizedBox(height: 16),
          Text(
            'No docs yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Process a few notes from the queue to generate your first Markdown summary.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
