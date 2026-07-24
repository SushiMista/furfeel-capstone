import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../theme/shadcn_bridge.dart';
import '../util/errors.dart';
import '../util/friendly_time.dart';
import '../util/motion.dart';
import '../widgets/dog_avatar.dart';
import '../widgets/name_avatar.dart';
import '../widgets/retry_message.dart';
import 'media_thread_page.dart';
import 'observation_page.dart';

/// Chat (docs/04): the owner's messaging front door. The conversation
/// substrate already existed — `media_messages` threads hanging off a
/// submitted observation, RLS'd to the dog's owner + that dog's clinic staff
/// and live over Realtime — but the only way in was Profile → Observation
/// Assessment → tap a past submission. This gives it a top-level home.
///
/// Multi-dog accounts pick a dog first (conversations are per dog, because
/// access is granted per dog); a single-dog owner skips straight to the
/// thread list, since a one-row picker is pure friction.
class ChatTab extends StatefulWidget {
  const ChatTab({super.key, required this.repository, required this.dogs});

  final FurFeelRepository repository;
  final List<Dog> dogs;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  /// Latest submission per dog, for the picker's preview line. Same
  /// parallel per-dog shape MultiDogHomeTab already uses for overviews.
  Map<String, MediaSubmission?> _latest = const {};
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.dogs.length > 1) {
      _loadPreviews();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadPreviews() async {
    try {
      final lists = await Future.wait(
        widget.dogs.map((d) => widget.repository.fetchMediaSubmissions(d.id, limit: 1)),
      );
      if (!mounted) return;
      setState(() {
        _latest = {
          for (final (i, list) in lists.indexed) widget.dogs[i].id: list.firstOrNull,
        };
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = loadErrorMessage(e, 'your conversations');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // One dog = no picker; the thread list IS the chat tab.
    if (widget.dogs.length == 1) {
      return DogChatView(repository: widget.repository, dog: widget.dogs.first);
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return RetryMessage(message: _error!, onRefresh: _loadPreviews);
    }

    final textTheme = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _loadPreviews,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          Text('Messages', style: textTheme.headlineMedium),
          const SizedBox(height: FurFeelTokens.space1),
          Text(
            'Conversations with your care team, one per dog.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: FurFeelTokens.space4),
          for (final (i, dog) in widget.dogs.indexed)
            Padding(
              padding: EdgeInsets.only(top: i > 0 ? FurFeelTokens.space3 : 0),
              child: _DogChatRow(
                repository: widget.repository,
                dog: dog,
                latest: _latest[dog.id],
                onTap: () => Navigator.of(context)
                    .push(
                      MaterialPageRoute<void>(
                        builder: (_) => DogChatPage(
                          repository: widget.repository,
                          dog: dog,
                        ),
                      ),
                    )
                    .then((_) => _loadPreviews()),
              ).entrance(context, index: i),
            ),
        ],
      ),
    );
  }
}

class _DogChatRow extends StatelessWidget {
  const _DogChatRow({
    required this.repository,
    required this.dog,
    required this.latest,
    required this.onTap,
  });

  final FurFeelRepository repository;
  final Dog dog;
  final MediaSubmission? latest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = latest?.reviewNote ?? latest?.note;

    return PressScale(
      child: Material(
        color: context.ff.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(FurFeelTokens.space4),
            decoration: BoxDecoration(
              border: Border.all(color: context.ff.hairline),
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
            ),
            child: Row(
              children: [
                DogAvatar(dog: dog, repository: repository, radius: 24),
                const SizedBox(width: FurFeelTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dog.name,
                        style: textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        preview?.trim().isNotEmpty == true
                            ? preview!.trim()
                            : 'No messages yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (latest != null) ...[
                  const SizedBox(width: FurFeelTokens.space2),
                  Text(
                    friendlyTimestamp(latest!.createdAt),
                    style: textTheme.bodySmall,
                  ),
                ],
                Icon(Icons.chevron_right, size: 20, color: context.ff.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One dog's chat, wrapped for pushing from the multi-dog picker.
class DogChatPage extends StatelessWidget {
  const DogChatPage({super.key, required this.repository, required this.dog});

  final FurFeelRepository repository;
  final Dog dog;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(dog.name)),
        body: DogChatView(repository: repository, dog: dog),
      );
}

/// One dog's care-team conversation: the clinic's latest reminder pinned on
/// top, then every conversation thread for this dog.
///
/// Rendered inline as the whole Chat tab for a single-dog owner, or inside
/// [DogChatPage] when pushed from the picker — hence a View, not a Page.
class DogChatView extends StatefulWidget {
  const DogChatView({super.key, required this.repository, required this.dog});

  final FurFeelRepository repository;
  final Dog dog;

  @override
  State<DogChatView> createState() => _DogChatViewState();
}

class _DogChatViewState extends State<DogChatView> {
  List<VetNoteFeedItem> _notes = const [];
  List<MediaSubmission> _submissions = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        widget.repository.fetchVetNoteFeed(widget.dog.id),
        widget.repository.fetchMediaSubmissions(widget.dog.id),
      ]);
      if (!mounted) return;
      setState(() {
        _notes = results[0] as List<VetNoteFeedItem>;
        _submissions = results[1] as List<MediaSubmission>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = loadErrorMessage(e, "${widget.dog.name}'s conversations");
      });
    }
  }

  Future<void> _openObservation() => Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ObservationPage(repository: widget.repository, dog: widget.dog),
        ),
      )
      .then((_) => _load());

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return RetryMessage(message: _error!, onRefresh: _load);

    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          if (_notes.isNotEmpty) ...[
            Text('FROM YOUR CARE TEAM', style: textTheme.labelSmall),
            const SizedBox(height: FurFeelTokens.space2),
            _ReminderCard(repository: widget.repository, note: _notes.first)
                .entrance(context),
            if (_notes.length > 1) ...[
              const SizedBox(height: FurFeelTokens.space2),
              Text(
                '${_notes.length - 1} earlier '
                '${_notes.length - 1 == 1 ? 'note' : 'notes'} from your clinic',
                style: textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: FurFeelTokens.space5),
          ],
          Row(
            children: [
              Expanded(child: Text('CONVERSATIONS', style: textTheme.labelSmall)),
              TextButton.icon(
                onPressed: _openObservation,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: FurFeelTokens.space2),
          if (_submissions.isEmpty)
            _EmptyChat(dogName: widget.dog.name, onStart: _openObservation)
                .entrance(context, index: 1)
          else
            for (final (i, s) in _submissions.indexed)
              Padding(
                padding: EdgeInsets.only(top: i > 0 ? FurFeelTokens.space3 : 0),
                child: _ThreadRow(
                  submission: s,
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
                ).entrance(context, index: 1 + i),
              ),
        ],
      ),
    );
  }
}

/// The clinic's latest note, pinned above the threads. Person-authored
/// (`vet_notes`) — deliberately NOT the rule-derived Care Insights guidance,
/// which would read as a message from a named clinician when no clinician
/// wrote it.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.repository, required this.note});

  final FurFeelRepository repository;
  final VetNoteFeedItem note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return shadcn.Theme(
      data: furFeelShadcnTheme(context),
      child: shadcn.Card(
        filled: true,
        fillColor: context.ff.brandSoft,
        borderColor: context.ff.hairline,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NameAvatar(
                  name: note.authorName,
                  repository: repository,
                  avatarPath: note.authorAvatarPath,
                  radius: 14,
                ),
                const SizedBox(width: FurFeelTokens.space2),
                Expanded(
                  child: Text(
                    note.authorName,
                    style: textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(friendlyTimestamp(note.createdAt), style: textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: FurFeelTokens.space3),
            Text(note.note, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.submission, required this.onTap});

  final MediaSubmission submission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final replied = submission.reviewedAt != null;
    final preview = submission.reviewNote ?? submission.note;

    return PressScale(
      child: Material(
        color: context.ff.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(FurFeelTokens.space4),
            decoration: BoxDecoration(
              border: Border.all(color: context.ff.hairline),
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.ff.brandSoft,
                    borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
                  ),
                  child: Icon(
                    submission.mediaType == 'video'
                        ? Icons.videocam_outlined
                        : Icons.photo_outlined,
                    size: 20,
                    color: context.ff.brand,
                  ),
                ),
                const SizedBox(width: FurFeelTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview?.trim().isNotEmpty == true
                            ? preview!.trim()
                            : 'Shared an observation',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          // Word + icon, never colour alone (docs/19).
                          Icon(
                            replied ? Icons.mark_chat_read_outlined : Icons.schedule,
                            size: 13,
                            color: replied
                                ? context.ff.statusCalmFg
                                : context.ff.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            replied ? 'Reviewed' : 'Awaiting your clinic',
                            style: textTheme.bodySmall?.copyWith(
                              color: replied
                                  ? context.ff.statusCalmFg
                                  : context.ff.inkMuted,
                            ),
                          ),
                          Text(
                            ' · ${friendlyTimestamp(submission.createdAt)}',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: context.ff.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state that explains how a conversation starts rather than showing a
/// bare "No messages". Today a thread hangs off a shared observation, so the
/// call to action is honest about needing a photo or video.
class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.dogName, required this.onStart});

  final String dogName;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return shadcn.Theme(
      data: furFeelShadcnTheme(context),
      child: shadcn.Card(
        filled: true,
        fillColor: context.ff.surfaceAlt,
        borderColor: context.ff.hairline,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        padding: const EdgeInsets.all(FurFeelTokens.space5),
        child: Column(
          children: [
            Icon(Icons.forum_outlined, size: 28, color: context.ff.inkMuted),
            const SizedBox(height: FurFeelTokens.space3),
            Text(
              'No conversations yet',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FurFeelTokens.space2),
            Text(
              'Share a photo or video of $dogName and your clinic can reply '
              'right here.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: FurFeelTokens.space4),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Share an observation'),
            ),
          ],
        ),
      ),
    );
  }
}
