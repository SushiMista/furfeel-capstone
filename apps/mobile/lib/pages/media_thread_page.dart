import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/friendly_time.dart';

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
    } catch (_) {
      // Thread stays at whatever we had; pull-to-refresh retries.
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Couldn\'t send — please check your connection and try again.';
      });
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
                              color: FurFeelTokens.surfaceAlt,
                              child: Icon(Icons.photo_outlined,
                                  size: 40, color: FurFeelTokens.inkMuted),
                            )
                          : Image.network(
                              _mediaUrl!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                height: 180,
                                color: FurFeelTokens.surfaceAlt,
                                child: Icon(Icons.broken_image_outlined,
                                    size: 40, color: FurFeelTokens.inkMuted),
                              ),
                            ),
                    )
                  else
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: FurFeelTokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_outlined,
                                size: 32, color: FurFeelTokens.inkMuted),
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

                  // Thread: owner note, clinic review, then replies in order.
                  if (submission.note != null)
                    _Bubble(
                      mine: true,
                      author: 'You',
                      body: submission.note!,
                      timestamp: submission.createdAt,
                    ),
                  if (submission.reviewNote != null)
                    _Bubble(
                      mine: false,
                      author: 'Your care team',
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
                      body: message.body,
                      timestamp: message.createdAt,
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
                          style: TextStyle(color: FurFeelTokens.statusHighOwner)),
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

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.mine,
    required this.author,
    required this.body,
    this.timestamp,
  });

  final bool mine;
  final String author;
  final String body;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: FurFeelTokens.space3),
        padding: const EdgeInsets.all(FurFeelTokens.space3),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: mine ? FurFeelTokens.brandSoft : FurFeelTokens.surfaceAlt,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(author,
                style: textTheme.labelSmall?.copyWith(color: FurFeelTokens.inkMuted)),
            const SizedBox(height: 2),
            Text(body, style: textTheme.bodyMedium),
            if (timestamp != null) ...[
              const SizedBox(height: 2),
              Text(friendlyTimestamp(timestamp!), style: textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
