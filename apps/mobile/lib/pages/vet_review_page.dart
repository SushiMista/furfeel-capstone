import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/friendly_time.dart';
import '../widgets/stress_pill.dart';

/// Vet Review, owner side (docs/04 module 5): the clinic's notes and confirmed
/// stress assessments for this dog. Read-only in MVP (threaded follow-up is
/// listed as optional in the doc and left as future work).
class VetReviewPage extends StatefulWidget {
  const VetReviewPage({super.key, required this.repository, required this.dog});

  final FurFeelRepository repository;
  final Dog dog;

  @override
  State<VetReviewPage> createState() => _VetReviewPageState();
}

class _VetReviewPageState extends State<VetReviewPage> {
  List<VetNote> _notes = [];
  List<StressLabelEntry> _labels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        widget.repository.fetchVetNotes(widget.dog.id),
        widget.repository.fetchStressLabels(widget.dog.id),
      ]);
      if (!mounted) return;
      setState(() {
        _notes = results[0] as List<VetNote>;
        _labels = results[1] as List<StressLabelEntry>;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong loading the vet review. Pull to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Vet review — ${widget.dog.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(FurFeelTokens.space4),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FurFeelTokens.space4),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: FurFeelTokens.statusHighOwner),
                      ),
                    ),
                  Text('CONFIRMED ASSESSMENTS', style: textTheme.labelSmall),
                  const SizedBox(height: FurFeelTokens.space2),
                  if (_labels.isEmpty)
                    _softPanel(
                      'No confirmed assessments yet — your clinic reviews '
                      '${widget.dog.name}\'s readings and confirms them here',
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final (i, label) in _labels.indexed) ...[
                            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                            _LabelTile(label: label),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: FurFeelTokens.space5),
                  Text('NOTES FROM YOUR CLINIC', style: textTheme.labelSmall),
                  const SizedBox(height: FurFeelTokens.space2),
                  if (_notes.isEmpty)
                    _softPanel('No notes yet — recommendations from your vet will appear here')
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final (i, note) in _notes.indexed) ...[
                            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                            _NoteTile(note: note),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: FurFeelTokens.space4),
                  Text(
                    'Vet reviews support your care decisions — they are not a diagnosis.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _softPanel(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(FurFeelTokens.space5),
        decoration: BoxDecoration(
          color: FurFeelTokens.surfaceAlt,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: FurFeelTokens.inkMuted),
        ),
      );
}

class _LabelTile extends StatelessWidget {
  const _LabelTile({required this.label});

  final StressLabelEntry label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StressPill(level: label.confirmedLevel),
              const SizedBox(width: FurFeelTokens.space3),
              Expanded(
                child: Text(
                  '${label.vetName ?? 'Your clinic'} · ${friendlyTimestamp(label.createdAt)}',
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (label.note != null) ...[
            const SizedBox(height: FurFeelTokens.space2),
            Text(label.note!, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});

  final VetNote note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.note, style: textTheme.bodyMedium),
          const SizedBox(height: FurFeelTokens.space1),
          Text(
            '${note.authorName ?? 'Clinic staff'} · ${friendlyTimestamp(note.createdAt)}',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
