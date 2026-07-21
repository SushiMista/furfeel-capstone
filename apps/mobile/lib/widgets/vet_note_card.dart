import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/friendly_time.dart';
import 'name_avatar.dart';

/// ADDED (QA): clinician note shown inline on Home — the doctor's photo, name,
/// timestamp, and comment, no navigation required. New notes arrive live via
/// the vet_notes Realtime signal.
class VetNoteCard extends StatelessWidget {
  const VetNoteCard({super.key, required this.repository, required this.note});

  final FurFeelRepository repository;
  final VetNoteFeedItem note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NameAvatar(
                  name: note.authorName,
                  avatarPath: note.authorAvatarPath,
                  repository: repository,
                ),
                const SizedBox(width: FurFeelTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note.authorName, style: textTheme.titleMedium),
                      Text(
                        friendlyTimestamp(note.createdAt),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.medical_information_outlined,
                    size: 18, color: context.ff.inkMuted),
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
