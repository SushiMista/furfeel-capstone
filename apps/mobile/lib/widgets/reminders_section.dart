import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../data/reminder_scheduler.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

/// "Care reminders" section on the dog detail screen (docs/04 P3.12).
/// Self-loading: fetches this dog's reminders + the user's notification
/// settings, renders the list with add/edit/delete, and keeps the on-device
/// notification schedule in sync. Owner-only via RLS.
class RemindersSection extends StatefulWidget {
  const RemindersSection({
    super.key,
    required this.repository,
    required this.dog,
    this.scheduler,
  });

  final FurFeelRepository repository;
  final Dog dog;

  /// Injectable for tests; production creates a real one.
  final ReminderScheduler? scheduler;

  @override
  State<RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends State<RemindersSection> {
  List<CareReminder> _reminders = const [];
  UserSettings _settings = const UserSettings();
  bool _loading = true;
  late final ReminderScheduler _scheduler =
      widget.scheduler ?? ReminderScheduler();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reminders = await widget.repository.fetchReminders(widget.dog.id);
      final settings = await widget.repository.fetchMySettings();
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _settings = settings;
        _loading = false;
      });
      await _scheduler.syncAll(reminders, settings);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([CareReminder? existing]) async {
    final draft = await showModalBottomSheet<_ReminderDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReminderSheet(existing: existing),
    );
    if (draft == null) return;
    try {
      final saved = await widget.repository.saveReminder(
        id: existing?.id,
        dogId: widget.dog.id,
        title: draft.title,
        notes: draft.notes,
        dueAt: draft.dueAt,
        repeat: draft.repeat,
      );
      await _scheduler.syncReminder(saved, _settings);
      await _load();
    } catch (e) {
      _toast(e);
    }
  }

  Future<void> _delete(CareReminder r) async {
    try {
      await widget.repository.deleteReminder(r.id);
      await _scheduler.cancel(r.id);
      await _load();
    } catch (e) {
      _toast(e);
    }
  }

  void _toast(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('FurFeelDataException: ', ''))));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FurFeelTokens.space5),
      decoration: BoxDecoration(
        color: context.ff.surfaceAlt,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined,
                  size: 18, color: context.ff.warm),
              const SizedBox(width: FurFeelTokens.space2),
              Text('CARE REMINDERS', style: textTheme.labelSmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add reminder',
                onPressed: () => _edit(),
              ),
            ],
          ),
          const SizedBox(height: FurFeelTokens.space2),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: FurFeelTokens.space3),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_reminders.isEmpty)
            Text(
              'No reminders yet. Add one for ${widget.dog.name}\'s meals, '
              'medication or vet visits.',
              style: textTheme.bodyMedium,
            )
          else
            for (final r in _reminders)
              _ReminderTile(
                reminder: r,
                onEdit: () => _edit(r),
                onDelete: () => _delete(r),
              ),
          if (!_loading && !_settings.notificationsEnabled)
            Padding(
              padding: const EdgeInsets.only(top: FurFeelTokens.space3),
              child: Text(
                'Notifications are off in Settings — reminders won\'t alert you until you turn them back on.',
                style: textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.onEdit,
    required this.onDelete,
  });

  final CareReminder reminder;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FurFeelTokens.space1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.title, style: textTheme.titleMedium),
                Text(describeReminderSchedule(reminder), style: textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// "Every day at 08:00" / "Every week on Mon at 14:30" / "Once on 2026-08-01 at 09:00".
String describeReminderSchedule(CareReminder r) {
  final t = '${r.dueAt.hour.toString().padLeft(2, '0')}:'
      '${r.dueAt.minute.toString().padLeft(2, '0')}';
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return switch (r.repeat) {
    ReminderRepeat.daily => 'Every day at $t',
    ReminderRepeat.weekly => 'Every week on ${days[r.dueAt.weekday - 1]} at $t',
    ReminderRepeat.none => 'Once on ${r.dueAt.year}-'
        '${r.dueAt.month.toString().padLeft(2, '0')}-'
        '${r.dueAt.day.toString().padLeft(2, '0')} at $t',
  };
}

// --- Add/edit bottom sheet ---

class _ReminderDraft {
  _ReminderDraft(this.title, this.notes, this.dueAt, this.repeat);
  final String title;
  final String? notes;
  final DateTime dueAt;
  final ReminderRepeat repeat;
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({this.existing});
  final CareReminder? existing;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime _dueAt = widget.existing?.dueAt ??
      DateTime.now().add(const Duration(hours: 1));
  late ReminderRepeat _repeat = widget.existing?.repeat ?? ReminderRepeat.daily;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time == null) return;
    setState(() => _dueAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        FurFeelTokens.space5,
        FurFeelTokens.space5,
        FurFeelTokens.space5,
        FurFeelTokens.space5 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null ? 'New reminder' : 'Edit reminder',
              style: textTheme.titleLarge),
          const SizedBox(height: FurFeelTokens.space4),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Morning medication',
            ),
          ),
          const SizedBox(height: FurFeelTokens.space3),
          TextField(
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
            ),
          ),
          const SizedBox(height: FurFeelTokens.space4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(describeReminderSchedule(CareReminder(
                    id: '',
                    dogId: '',
                    title: '',
                    dueAt: _dueAt,
                    repeat: _repeat,
                    active: true,
                  ))),
                  onPressed: _pickDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: FurFeelTokens.space3),
          DropdownButtonFormField<ReminderRepeat>(
            initialValue: _repeat,
            decoration: const InputDecoration(labelText: 'Repeat'),
            items: [
              for (final r in ReminderRepeat.values)
                DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: (v) => setState(() => _repeat = v ?? ReminderRepeat.none),
          ),
          const SizedBox(height: FurFeelTokens.space5),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: FurFeelTokens.space3),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final title = _title.text.trim();
                    if (title.isEmpty) return;
                    Navigator.pop(
                      context,
                      _ReminderDraft(
                        title,
                        _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                        _dueAt,
                        _repeat,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}