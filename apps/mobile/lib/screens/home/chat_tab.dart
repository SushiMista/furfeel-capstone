import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import 'package:furfeel_mobile/data/furfeel_repository.dart';
=======
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:url_launcher/url_launcher.dart';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/theme/shadcn_bridge.dart';
import 'package:furfeel_mobile/util/errors.dart';
import 'package:furfeel_mobile/util/friendly_time.dart';
import 'package:furfeel_mobile/util/motion.dart';
<<<<<<< HEAD
import 'package:furfeel_mobile/widgets/dog_avatar.dart';
import 'package:furfeel_mobile/widgets/section_header.dart';
import 'package:furfeel_mobile/widgets/name_avatar.dart';
import 'package:furfeel_mobile/widgets/retry_message.dart';
import 'package:furfeel_mobile/screens/observations/media_thread_page.dart';
import 'package:furfeel_mobile/screens/observations/observation_page.dart';

/// Chat (docs/04): the owner's messaging front door. The conversation
/// substrate already existed — `media_messages` threads hanging off a
/// submitted observation, RLS'd to the dog's owner + that dog's clinic staff
/// and live over Realtime — but the only way in was Profile → Observation
/// Assessment → tap a past submission. This gives it a top-level home.
///
/// Multi-dog accounts pick a dog first (conversations are per dog, because
/// access is granted per dog); a single-dog owner skips straight to the
/// thread list, since a one-row picker is pure friction.
=======
import 'package:furfeel_mobile/widgets/alert_card.dart';
import 'package:furfeel_mobile/widgets/dog_avatar.dart';
import 'package:furfeel_mobile/widgets/name_avatar.dart';
import 'package:furfeel_mobile/widgets/retry_message.dart';

const _notMonitoredNotice =
    'Not monitored around the clock. For emergencies, call your clinic.';

/// Messages (docs/04, ADR-026): one ongoing conversation with the clinic per
/// dog, because access is granted per dog.
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
class ChatTab extends StatefulWidget {
  const ChatTab({super.key, required this.repository, required this.dogs});

  final FurFeelRepository repository;
  final List<Dog> dogs;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
<<<<<<< HEAD
  /// Latest submission per dog, for the picker's preview line. Same
  /// parallel per-dog shape MultiDogHomeTab already uses for overviews.
  Map<String, MediaSubmission?> _latest = const {};
=======
  Map<String, DogMessageThread> _threads = const {};
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
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
=======
    _load();
  }

  Future<void> _load() async {
    try {
      final threads = await widget.repository.fetchDogMessageThreads();
      if (!mounted) return;
      setState(() {
        _threads = {for (final t in threads) t.dogId: t};
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
<<<<<<< HEAD
        _error = loadErrorMessage(e, 'your conversations');
=======
        _error = loadErrorMessage(e, 'your messages');
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
      });
    }
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
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
=======
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return RetryMessage(message: _error!, onRefresh: _load);

    final textTheme = Theme.of(context).textTheme;
    // Latest conversation first; dogs with no messages keep their order below.
    final dogs = [...widget.dogs]..sort((a, b) {
        final at = _threads[a.id]?.lastAt, bt = _threads[b.id]?.lastAt;
        if (at == null || bt == null) return at == bt ? 0 : (at == null ? 1 : -1);
        return bt.compareTo(at);
      });

    return RefreshIndicator(
      onRefresh: _load,
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          Text('Messages', style: textTheme.headlineMedium),
<<<<<<< HEAD
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
=======
          const SizedBox(height: FurFeelTokens.space3),
          for (final (i, dog) in dogs.indexed)
            _DogChatRow(
              repository: widget.repository,
              dog: dog,
              thread: _threads[dog.id],
              onTap: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute<void>(
                      builder: (_) => DogChatPage(
                        repository: widget.repository,
                        dog: dog,
                      ),
                    ),
                  )
                  .then((_) => _load()),
            ).entrance(context, index: i),
          const SizedBox(height: FurFeelTokens.space4),
          Text(
            _notMonitoredNotice,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
        ],
      ),
    );
  }
}

class _DogChatRow extends StatelessWidget {
  const _DogChatRow({
    required this.repository,
    required this.dog,
<<<<<<< HEAD
    required this.latest,
=======
    required this.thread,
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
    required this.onTap,
  });

  final FurFeelRepository repository;
  final Dog dog;
<<<<<<< HEAD
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
=======
  final DogMessageThread? thread;
  final VoidCallback onTap;

  String get _preview {
    final t = thread;
    if (t == null) return 'Start a conversation';
    if (t.lastBody != null) return t.lastBody!;
    if (t.lastHasMedia) return 'Photo or video';
    return 'Shared an alert';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final unread = thread?.unreadCount ?? 0;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: FurFeelTokens.space3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.ff.hairline)),
        ),
        child: Row(
          children: [
            DogAvatar(dog: dog, repository: repository, radius: 22),
            const SizedBox(width: FurFeelTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dog.name, style: textTheme.titleMedium),
                  Text(
                    _preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: unread > 0 ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
            if (unread > 0)
              Semantics(
                label: '$unread unread',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FurFeelTokens.space2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.ff.brand,
                    borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
                  ),
                  child: Text(
                    '$unread',
                    style: textTheme.labelSmall?.copyWith(color: Colors.white),
                  ),
                ),
              ),
          ],
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
        ),
      ),
    );
  }
}

<<<<<<< HEAD
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

=======
/// One dog's conversation with the clinic. [alert] arrives attached when the
/// owner came from Message vet, and the owner can remove it before sending.
class DogChatPage extends StatefulWidget {
  const DogChatPage({
    super.key,
    required this.repository,
    required this.dog,
    this.alert,
    this.reading,
    this.draft,
  });

  final FurFeelRepository repository;
  final Dog dog;
  final Alert? alert;
  final TelemetryReading? reading;

  /// Starting text for the message box, e.g. which day the owner is asking about.
  final String? draft;

  @override
  State<DogChatPage> createState() => _DogChatPageState();
}

class _DogChatPageState extends State<DogChatPage> {
  late final _text = TextEditingController(text: widget.draft);
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  List<DogMessage> _messages = const [];
  VetNoteFeedItem? _latestNote;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  late Alert? _alert = widget.alert;
  XFile? _pickedFile;
  String? _pickedType; // 'image' | 'video'

  Unsubscribe? _unsubscribe;

>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
  @override
  void initState() {
    super.initState();
    _load();
<<<<<<< HEAD
=======
    _unsubscribe = widget.repository.subscribeToDogMessages(widget.dog.id, _load);
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
<<<<<<< HEAD
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
=======
        widget.repository.fetchDogMessages(widget.dog.id),
        widget.repository.fetchVetNoteFeed(widget.dog.id),
      ]);
      if (!mounted) return;
      setState(() {
        _messages = results[0] as List<DogMessage>;
        _latestNote = (results[1] as List<VetNoteFeedItem>).firstOrNull;
        _loading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
      widget.repository.markDogMessagesRead(widget.dog.id).ignore();
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
<<<<<<< HEAD
        _error = loadErrorMessage(e, "${widget.dog.name}'s conversations");
=======
        _error = loadErrorMessage(e, "${widget.dog.name}'s messages");
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
      });
    }
  }

<<<<<<< HEAD
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
            SectionHeader(title: 'From your care team'),
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
              Expanded(child: Text('Conversations', style: TextStyle(fontSize: FurFeelTokens.typeH3Size, fontWeight: FontWeight.w800, color: context.ff.ink))),
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
=======
  Future<void> _pick({required bool video}) async {
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

  void _chooseAttachment() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pick(video: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Short video'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pick(video: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSend =>
      !_sending &&
      (_text.text.trim().isNotEmpty || _pickedFile != null || _alert != null);

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _sending = true);
    final file = _pickedFile;
    try {
      await widget.repository.sendDogMessage(
        dogId: widget.dog.id,
        body: _text.text,
        mediaBytes: file == null ? null : await file.readAsBytes(),
        mediaExtension: file == null
            ? null
            : (file.name.contains('.')
                ? file.name.split('.').last.toLowerCase()
                : 'bin'),
        mediaType: _pickedType,
        alertId: _alert?.id,
        readingId: _alert == null ? null : widget.reading?.id,
      );
      if (!mounted) return;
      _text.clear();
      setState(() {
        _pickedFile = null;
        _pickedType = null;
        _alert = null;
      });
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(actionErrorMessage(err, 'Sending'))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _edit(DogMessage message) async {
    final controller = TextEditingController(text: message.body);
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: controller, maxLines: 4, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (updated == null || updated.trim().isEmpty || !mounted) return;
    try {
      await widget.repository.updateDogMessage(message.id, updated);
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(actionErrorMessage(err, 'Saving'))),
      );
    }
  }

  Future<void> _delete(DogMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this message?'),
        content: const Text('It will be removed for you and your clinic.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: context.ff.statusHighOwner),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.deleteDogMessage(message);
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(actionErrorMessage(err, 'Deleting'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.dog.name}'s vet")),
      body: Column(
        children: [
          Expanded(child: _buildConversation(context)),
          _buildComposer(context),
        ],
      ),
    );
  }

  Widget _buildConversation(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return RetryMessage(message: _error!, onRefresh: _load);
    final textTheme = Theme.of(context).textTheme;
    final userId = widget.repository.currentUserId;
    final note = _latestNote;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          Text(
            _notMonitoredNotice,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: FurFeelTokens.space3),
          if (note != null) ...[
            _ReminderCard(repository: widget.repository, note: note),
            const SizedBox(height: FurFeelTokens.space3),
          ],
          if (_messages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(FurFeelTokens.space5),
              child: Text(
                'Send your clinic a message, photo or short video about '
                '${widget.dog.name}.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            )
          else
            for (final message in _messages)
              _Bubble(
                repository: widget.repository,
                message: message,
                mine: message.authorUserId == userId,
                onEdit: () => _edit(message),
                onDelete: () => _delete(message),
              ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final alert = _alert;
    final file = _pickedFile;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(FurFeelTokens.space2),
        decoration: BoxDecoration(
          color: context.ff.surface,
          border: Border(top: BorderSide(color: context.ff.hairline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (alert != null)
              _AttachmentChip(
                icon: alertTypeIcon(alert.type),
                title: alertHeadline(alert.type) ?? alert.message,
                subtitle: _readingSummary(
                  context,
                  widget.reading?.heartRateBpm,
                  widget.reading?.ambientTemperatureC,
                  widget.reading?.capturedAt,
                ),
                removeLabel: 'Remove alert',
                onRemove: () => setState(() => _alert = null),
              ),
            if (file != null)
              _AttachmentChip(
                icon: _pickedType == 'video'
                    ? Icons.videocam_outlined
                    : Icons.photo_outlined,
                title: file.name,
                removeLabel: 'Remove attachment',
                onRemove: () => setState(() {
                  _pickedFile = null;
                  _pickedType = null;
                }),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Add a photo or video',
                  icon: const Icon(Icons.attach_file),
                  onPressed: _sending ? null : _chooseAttachment,
                ),
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 4000,
                    buildCounter: (_, {required currentLength,
                        required isFocused, maxLength}) => null,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Send',
                  icon: Icon(Icons.send, color: _canSend ? context.ff.brand : null),
                  onPressed: _canSend ? _send : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "87 bpm · 24.6°C · 3:08 PM", with the reading's own time, so an older alert
/// never passes off a later reading as what happened then.
String? _readingSummary(
  BuildContext context,
  int? heartRate,
  double? temperature,
  DateTime? capturedAt,
) {
  final settings = SettingsScope.of(context);
  final parts = [
    if (heartRate != null) '$heartRate bpm',
    if (temperature != null)
      '${settings.formatTemperature(temperature)}${settings.temperatureUnitLabel}',
    if (capturedAt != null)
      MaterialLocalizations.of(context)
          .formatTimeOfDay(TimeOfDay.fromDateTime(capturedAt)),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.icon,
    required this.title,
    required this.removeLabel,
    required this.onRemove,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String removeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: FurFeelTokens.space2),
      padding: const EdgeInsets.only(left: FurFeelTokens.space3),
      decoration: BoxDecoration(
        color: context.ff.surfaceAlt,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.ff.inkMuted),
          const SizedBox(width: FurFeelTokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge),
                if (subtitle != null) Text(subtitle!, style: textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: removeLabel,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
        ],
      ),
    );
  }
}

<<<<<<< HEAD
/// The clinic's latest note, pinned above the threads. Person-authored
/// (`vet_notes`) — deliberately NOT the rule-derived Care Insights guidance,
/// which would read as a message from a named clinician when no clinician
/// wrote it.
=======
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.repository,
    required this.message,
    required this.mine,
    required this.onEdit,
    required this.onDelete,
  });

  final FurFeelRepository repository;
  final DogMessage message;
  final bool mine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.body != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onEdit();
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.ff.statusHighOwner),
              title: Text('Delete', style: TextStyle(color: context.ff.statusHighOwner)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onDelete();
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
    final author = mine ? 'You' : (message.authorName ?? 'Your care team');
    final alertType = message.alertType;
    final bubble = Flexible(
      child: GestureDetector(
        onLongPress: mine ? () => _showActions(context) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: FurFeelTokens.space3),
          padding: const EdgeInsets.all(FurFeelTokens.space3),
          constraints: const BoxConstraints(maxWidth: 270),
          decoration: BoxDecoration(
            color: mine ? context.ff.brandSoft : context.ff.surfaceAlt,
            borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine) ...[
                Text(author,
                    style: textTheme.labelSmall?.copyWith(color: context.ff.inkMuted)),
                const SizedBox(height: 2),
              ],
              if (alertType != null) ...[
                Row(
                  children: [
                    Icon(alertTypeIcon(alertType), size: 16, color: context.ff.inkMuted),
                    const SizedBox(width: FurFeelTokens.space1),
                    Expanded(
                      child: Text(
                        alertHeadline(alertType) ?? 'Alert',
                        style: textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                if (_readingSummary(
                      context,
                      message.heartRateBpm,
                      message.ambientTemperatureC,
                      message.readingCapturedAt,
                    ) case final summary?)
                  Text(summary, style: textTheme.bodySmall),
                const SizedBox(height: FurFeelTokens.space1),
              ],
              if (message.mediaPath != null)
                _MessageMedia(repository: repository, message: message),
              if (message.body != null) Text(message.body!, style: textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(
                friendlyTimestamp(message.createdAt) +
                    (message.editedAt != null ? ' · edited' : ''),
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );

    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!mine) ...[
          NameAvatar(
            name: author,
            avatarPath: message.authorAvatarPath,
            repository: repository,
            radius: 14,
          ),
          const SizedBox(width: FurFeelTokens.space2),
        ],
        bubble,
      ],
    );
  }
}

/// Media lives in a private bucket, so it loads through a short-lived URL.
class _MessageMedia extends StatefulWidget {
  const _MessageMedia({required this.repository, required this.message});

  final FurFeelRepository repository;
  final DogMessage message;

  @override
  State<_MessageMedia> createState() => _MessageMediaState();
}

class _MessageMediaState extends State<_MessageMedia> {
  late final Future<String> _url =
      widget.repository.getSignedMediaUrl(widget.message.mediaPath!);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FurFeelTokens.space1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        child: FutureBuilder<String>(
          future: _url,
          builder: (context, snapshot) {
            final url = snapshot.data;
            if (snapshot.hasError) {
              return const SizedBox(
                height: 80,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              );
            }
            if (url == null) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (widget.message.mediaType == 'video') {
              return Material(
                color: context.ff.surface,
                child: InkWell(
                  onTap: () => launchUrl(Uri.parse(url)),
                  child: const SizedBox(
                    height: 90,
                    width: double.infinity,
                    child: Center(
                      child: Icon(Icons.play_circle_outline, size: 36,
                          semanticLabel: 'Play video'),
                    ),
                  ),
                ),
              );
            }
            return Image.network(
              url,
              semanticLabel: 'Photo shared in chat',
              errorBuilder: (_, _, _) => const SizedBox(
                height: 80,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The clinic's latest note, pinned above the conversation. Person-authored
/// (`vet_notes`), deliberately NOT the rule-derived Care Insights guidance,
/// which would read as a message from a clinician when no clinician wrote it.
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
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
<<<<<<< HEAD

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
=======
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
