import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/friendly_time.dart';
import '../util/errors.dart';
import '../widgets/name_avatar.dart';

/// One submission's conversation (QA item 12): the photo/video, the owner's
/// note, the clinic's review, and a back-and-forth reply thread
/// (media_messages) — like an email chain under the media.
class MediaThreadPage extends StatefulWidget {
  const MediaThreadPage({
    super.key,
    required this.repository,
    required this.dog,
    required this.submission,
  });

  final FurFeelRepository repository;
  final Dog dog;
  final MediaSubmission submission;

  @override
  State<MediaThreadPage> createState() => _MediaThreadPageState();
}

class _MediaThreadPageState extends State<MediaThreadPage> {
  final _reply = TextEditingController();
  List<MediaMessage> _messages = const [];
  String? _mediaUrl;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.submission.mediaType == 'image') {
      widget.repository.getSignedMediaUrl(widget.submission.storagePath).then((url) {
        if (mounted) setState(() => _mediaUrl = url);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final messages =
          await widget.repository.fetchMediaMessages(widget.submission.id);
      if (mounted) setState(() => _messages = messages);
    } catch (e) {
      // Keep whatever we already had, but never let a first-load failure look
      // like an empty conversation (state audit).
      if (mounted && _messages.isEmpty) {
        setState(() => _error = loadErrorMessage(e, 'this conversation'));
      }
    }
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message =
          await widget.repository.sendMediaMessage(widget.submission.id, body);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
        _reply.clear();
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = actionErrorMessage(e, 'Sending');
      });
    }
  }

  /// Full CRUD (docs/04 module 5): edit your own reply's text.
  Future<void> _editMessage(MediaMessage message) async {
    final controller = TextEditingController(text: message.body);
    final newBody = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: controller, maxLines: 4, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Not disposed here: the dialog's TextField is still mounted during its
    // exit animation when this Future resolves, so an immediate dispose()
    // crashes it mid-transition. It's a one-shot local controller — letting
    // it go out of scope is safe.
    if (newBody == null || newBody.isEmpty || !mounted) return;
    try {
      final updated = await widget.repository.updateMediaMessage(message.id, newBody);
      if (!mounted) return;
      setState(() {
        _messages = [for (final m in _messages) if (m.id == message.id) updated else m];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(actionErrorMessage(e, 'Saving'))));
    }
  }

  /// Delete is irreversible — confirm first.
  Future<void> _deleteMessage(MediaMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this message?'),
        content: const Text('This can\'t be undone.'),
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
      await widget.repository.deleteMediaMessage(message.id);
      if (!mounted) return;
      setState(() => _messages = _messages.where((m) => m.id != message.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(actionErrorMessage(e, 'Deleting'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final submission = widget.submission;

    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(FurFeelTokens.space4),
                children: [
                  // The media itself, up top like an email attachment.
                  if (submission.mediaType == 'image')
                    ClipRRect(
                      borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                      child: _mediaUrl == null
                          ? Container(
                              height: 180,
                              color: context.ff.surfaceAlt,
                              child: Icon(Icons.photo_outlined,
                                  size: 40, color: context.ff.inkMuted),
                            )
                          : Image.network(
                              _mediaUrl!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                height: 180,
                                color: context.ff.surfaceAlt,
                                child: Icon(Icons.broken_image_outlined,
                                    size: 40, color: context.ff.inkMuted),
                              ),
                            ),
                    )
                  else
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: context.ff.surfaceAlt,
                        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_outlined,
                                size: 32, color: context.ff.inkMuted),
                            const SizedBox(height: FurFeelTokens.space1),
                            Text('Video shared with your clinic',
                                style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: FurFeelTokens.space2),
                  Text(
                    'Shared ${friendlyTimestamp(submission.createdAt)} · '
                    'Supplementary — not used by the stress classifier.',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: FurFeelTokens.space4),

                  // Thread: owner note, clinic review, then replies in order —
                  // a messaging thread (docs/04 module 5), sender avatar +
                  // name, bubbles aligned by author.
                  if (submission.note != null)
                    _Bubble(
                      mine: true,
                      author: submission.submitterName ?? 'You',
                      avatarPath: submission.submitterAvatarPath,
                      repository: widget.repository,
                      body: submission.note!,
                      timestamp: submission.createdAt,
                    ),
                  if (submission.reviewNote != null)
                    _Bubble(
                      mine: false,
                      author: submission.reviewerName ?? 'Your care team',
                      avatarPath: submission.reviewerAvatarPath,
                      repository: widget.repository,
                      body: submission.reviewNote!,
                      timestamp: submission.reviewedAt,
                    )
                  else if (!submission.isReviewed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: FurFeelTokens.space2),
                      child: Text(
                        'Your clinic hasn\'t reviewed this yet — you can still add '
                        'more details below.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall,
                      ),
                    ),
                  for (final message in _messages)
                    _Bubble(
                      // The dog's owner is the signed-in user in this app;
                      // anything not authored by a clinic account reads "You".
                      mine: message.authorUserId == widget.dog.ownerUserId,
                      author: message.authorUserId == widget.dog.ownerUserId
                          ? 'You'
                          : (message.authorName ?? 'Your care team'),
                      avatarPath: message.authorAvatarPath,
                      repository: widget.repository,
                      body: message.body,
                      timestamp: message.createdAt,
                      // Full CRUD (docs/04 module 5): only your own replies —
                      // never the clinic's — are editable/deletable.
                      onEdit: message.authorUserId == widget.dog.ownerUserId
                          ? () => _editMessage(message)
                          : null,
                      onDelete: message.authorUserId == widget.dog.ownerUserId
                          ? () => _deleteMessage(message)
                          : null,
                    ),
                ],
              ),
            ),
          ),
          // Composer.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FurFeelTokens.space4, 0, FurFeelTokens.space4, FurFeelTokens.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FurFeelTokens.space2),
                      child: Text(_error!,
                          style: TextStyle(color: context.ff.statusHighOwner)),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reply,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Reply to your clinic…',
                          ),
                        ),
                      ),
                      const SizedBox(width: FurFeelTokens.space2),
                      IconButton.filled(
                        tooltip: 'Send',
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One message, Messenger-style: sender avatar beside a bubble aligned to
/// their side, name + timestamp inside.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.mine,
    required this.author,
    required this.body,
    required this.repository,
    this.avatarPath,
    this.timestamp,
    this.onEdit,
    this.onDelete,
  });

  final bool mine;
  final String author;
  final String body;
  final String? avatarPath;
  final FurFeelRepository repository;
  final DateTime? timestamp;

  /// Full CRUD (docs/04 module 5): non-null only for your own replies —
  /// long-press to edit or delete, Messenger-style. Null for the submission
  /// note and the clinic's review, which aren't editable here.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onEdit?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.ff.statusHighOwner),
              title: Text('Delete', style: TextStyle(color: context.ff.statusHighOwner)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final avatar = NameAvatar(
      name: author,
      avatarPath: avatarPath,
      repository: repository,
      radius: 14,
    );
    final editable = onEdit != null || onDelete != null;
    final bubble = Flexible(
      child: GestureDetector(
        onLongPress: editable ? () => _showActions(context) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: FurFeelTokens.space3),
          padding: const EdgeInsets.all(FurFeelTokens.space3),
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: mine ? context.ff.brandSoft : context.ff.surfaceAlt,
            borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(author,
                  style: textTheme.labelSmall?.copyWith(color: context.ff.inkMuted)),
              const SizedBox(height: 2),
              Text(body, style: textTheme.bodyMedium),
              if (timestamp != null) ...[
                const SizedBox(height: 2),
                Text(friendlyTimestamp(timestamp!), style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );

    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: mine
          ? [bubble, const SizedBox(width: FurFeelTokens.space2), avatar]
          : [avatar, const SizedBox(width: FurFeelTokens.space2), bubble],
    );
  }
}
