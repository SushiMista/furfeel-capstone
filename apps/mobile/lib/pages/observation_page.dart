import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/friendly_time.dart';
import '../util/errors.dart';
import 'media_thread_page.dart';

/// Observation Assessment (docs/04 module 3): the owner shares notes, photos,
/// and short videos with the clinic. Supplementary material only — every view
/// says so, and it is NEVER a classifier input (ADR-010).
class ObservationPage extends StatefulWidget {
  const ObservationPage({super.key, required this.repository, required this.dog});

  final FurFeelRepository repository;
  final Dog dog;

  @override
  State<ObservationPage> createState() => _ObservationPageState();
}

class _ObservationPageState extends State<ObservationPage> {
  final _note = TextEditingController();
  final _picker = ImagePicker();

  List<MediaSubmission> _submissions = [];
  XFile? _pickedFile;
  String? _pickedType; // 'image' | 'video'
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.repository.fetchMediaSubmissions(widget.dog.id);
      if (!mounted) return;
      setState(() {
        _submissions = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = loadErrorMessage(e, 'your submissions');
      });
    }
  }

  Future<void> _pick(bool video) async {
    final file = video
        ? await _picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(seconds: 30),
          )
        : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;
    setState(() {
      _pickedFile = file;
      _pickedType = video ? 'video' : 'image';
    });
  }

  Future<void> _submit() async {
    final file = _pickedFile;
    final type = _pickedType;
    if (file == null || type == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'bin';
      final submission = await widget.repository.submitObservation(
        dogId: widget.dog.id,
        bytes: bytes,
        fileExtension: ext,
        mediaType: type,
        note: _note.text,
      );
      if (!mounted) return;
      setState(() {
        _submissions = [submission, ..._submissions];
        _pickedFile = null;
        _pickedType = null;
        _note.clear();
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shared with your clinic')),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = err is FurFeelDataException
            ? err.message
            : actionErrorMessage(err, 'The upload');
      });
    }
  }

  /// Delete is irreversible (docs/04 module 5 CRUD) — confirm first, same
  /// pattern as the account-deletion confirm elsewhere in the app.
  Future<void> _deleteSubmission(MediaSubmission submission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this observation?'),
        content: const Text(
          'This removes the photo or video and its conversation for good — '
          'your clinic will no longer be able to see it. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: context.ff.statusHighOwner)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.deleteMediaSubmission(submission);
      if (!mounted) return;
      setState(() => _submissions = _submissions.where((s) => s.id != submission.id).toList());
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(actionErrorMessage(err, 'Deleting'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('Observations — ${widget.dog.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(FurFeelTokens.space4),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(FurFeelTokens.space5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SHARE SOMETHING YOU NOTICED', style: textTheme.labelSmall),
                          const SizedBox(height: FurFeelTokens.space3),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _submitting ? null : () => _pick(false),
                                  icon: const Icon(Icons.photo_outlined),
                                  label: const Text('Photo'),
                                ),
                              ),
                              const SizedBox(width: FurFeelTokens.space3),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _submitting ? null : () => _pick(true),
                                  icon: const Icon(Icons.videocam_outlined),
                                  label: const Text('Short video'),
                                ),
                              ),
                            ],
                          ),
                          if (_pickedFile != null) ...[
                            const SizedBox(height: FurFeelTokens.space3),
                            Row(
                              children: [
                                Icon(
                                  _pickedType == 'video'
                                      ? Icons.videocam
                                      : Icons.photo,
                                  size: 18,
                                  color: context.ff.brand,
                                ),
                                const SizedBox(width: FurFeelTokens.space2),
                                Expanded(
                                  child: Text(
                                    _pickedFile!.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed: _submitting
                                      ? null
                                      : () => setState(() {
                                            _pickedFile = null;
                                            _pickedType = null;
                                          }),
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: FurFeelTokens.space3),
                          TextField(
                            controller: _note,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'What did you notice? (optional)',
                              alignLabelWithHint: true,
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: FurFeelTokens.space3),
                            Text(
                              _error!,
                              style: TextStyle(color: context.ff.statusHighOwner),
                            ),
                          ],
                          const SizedBox(height: FurFeelTokens.space4),
                          ElevatedButton(
                            onPressed:
                                _submitting || _pickedFile == null ? null : _submit,
                            child: Text(_submitting ? 'Sharing…' : 'Share with clinic'),
                          ),
                          const SizedBox(height: FurFeelTokens.space3),
                          Text(
                            'Supplementary — not used by the stress classifier. '
                            'Your clinic reviews these alongside the readings.',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: FurFeelTokens.space5),
                  Text('PAST SUBMISSIONS', style: textTheme.labelSmall),
                  const SizedBox(height: FurFeelTokens.space2),
                  if (_submissions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(FurFeelTokens.space5),
                      decoration: BoxDecoration(
                        color: context.ff.surfaceAlt,
                        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                      ),
                      child: Text(
                        'Nothing shared yet — photos and videos help your clinic '
                        'see the moments behind the readings',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.ff.inkMuted),
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final (i, s) in _submissions.indexed) ...[
                            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                            // QA item 12: each submission opens its own
                            // conversation with the clinic.
                            InkWell(
                              onTap: () => Navigator.of(context)
                                  .push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => MediaThreadPage(
                                        repository: widget.repository,
                                        dog: widget.dog,
                                        submission: s,
                                      ),
                                    ),
                                  )
                                  .then((_) => _load()),
                              child: _SubmissionTile(
                                submission: s,
                                onDelete: () => _deleteSubmission(s),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({required this.submission, required this.onDelete});

  final MediaSubmission submission;
  final VoidCallback onDelete;

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
              Icon(
                submission.mediaType == 'video' ? Icons.videocam : Icons.photo,
                size: 18,
                color: context.ff.inkMuted,
              ),
              const SizedBox(width: FurFeelTokens.space2),
              Expanded(
                child: Text(
                  friendlyTimestamp(submission.createdAt),
                  style: textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 18, color: context.ff.inkMuted),
                visualDensity: VisualDensity.compact,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FurFeelTokens.space3,
                  vertical: FurFeelTokens.space1,
                ),
                decoration: BoxDecoration(
                  color: submission.isReviewed
                      ? context.ff.statusCalmBg
                      : context.ff.brandSoft,
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
                ),
                child: Text(
                  submission.isReviewed ? 'Reviewed' : 'Awaiting review',
                  style: TextStyle(
                    fontSize: FurFeelTokens.typeCaptionSize,
                    fontWeight: FontWeight.w600,
                    color: submission.isReviewed
                        ? context.ff.statusCalmFg
                        : context.ff.brandStrong,
                  ),
                ),
              ),
            ],
          ),
          if (submission.note != null) ...[
            const SizedBox(height: FurFeelTokens.space2),
            Text(submission.note!, style: textTheme.bodyMedium),
          ],
          if (submission.reviewNote != null) ...[
            const SizedBox(height: FurFeelTokens.space2),
            Text('Clinic: ${submission.reviewNote!}', style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
