import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

/// Dog health management page — three tabs: Vaccination Records, Medical
/// History, and Archived Pets. All sections are UI-ready stubs; data wiring
/// to Supabase comes in a later sprint.
class DogHealthPage extends StatelessWidget {
  const DogHealthPage({super.key, required this.dog});

  final Dog dog;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(dog.name),
          bottom: TabBar(
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Vaccines'),
              Tab(text: 'Medical'),
              Tab(text: 'Archived'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _VaccinationTab(dog: dog),
            _MedicalHistoryTab(dog: dog),
            _ArchivedTab(),
          ],
        ),
      ),
    );
  }
}

// ── Vaccination Records ───────────────────────────────────────────────────────

class _VaccinationTab extends StatelessWidget {
  const _VaccinationTab({required this.dog});

  final Dog dog;

  // Placeholder records — replace with real data once DB is wired
  static const _placeholderVaccines = <_VaccineRecord>[
    _VaccineRecord(
      name: 'Rabies',
      date: 'Jan 15, 2025',
      nextDue: 'Jan 15, 2026',
      clinic: 'Bethlehem Animal Clinic',
      status: 'Up to date',
    ),
    _VaccineRecord(
      name: 'DHPP (Distemper combo)',
      date: 'Mar 3, 2025',
      nextDue: 'Mar 3, 2026',
      clinic: 'Bethlehem Animal Clinic',
      status: 'Up to date',
    ),
    _VaccineRecord(
      name: 'Bordetella',
      date: 'Jun 10, 2024',
      nextDue: 'Jun 10, 2025',
      clinic: 'Assumpta Dog & Cat Clinic',
      status: 'Overdue',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      children: [
        _SectionBanner(
          icon: Icons.vaccines_outlined,
          title: 'Vaccination Records',
          subtitle: 'Keep track of ${dog.name}\'s immunization history',
          color: context.ff.brand,
        ),
        const SizedBox(height: FurFeelTokens.space4),
        for (final v in _placeholderVaccines) ...[
          _VaccineCard(record: v),
          const SizedBox(height: FurFeelTokens.space3),
        ],
        const SizedBox(height: FurFeelTokens.space3),
        _AddRecordButton(label: 'Add vaccination record'),
        const SizedBox(height: FurFeelTokens.space4),
        Text(
          'Vaccination data will sync with your partner clinic once connected.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: context.ff.inkMuted),
        ),
      ],
    );
  }
}

class _VaccineRecord {
  const _VaccineRecord({
    required this.name,
    required this.date,
    required this.nextDue,
    required this.clinic,
    required this.status,
  });

  final String name;
  final String date;
  final String nextDue;
  final String clinic;
  final String status; // 'Up to date' | 'Overdue' | 'Upcoming'
}

class _VaccineCard extends StatelessWidget {
  const _VaccineCard({required this.record});

  final _VaccineRecord record;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isOverdue = record.status == 'Overdue';
    final statusColor =
        isOverdue ? context.ff.statusHighFg : context.ff.statusCalmFg;
    final statusBg =
        isOverdue ? context.ff.statusHighBg : context.ff.statusCalmBg;

    return Container(
      decoration: BoxDecoration(
        color: context.ff.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        border: Border.all(color: context.ff.hairline),
        boxShadow: FurFeelTokens.shadowCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.name,
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius:
                        BorderRadius.circular(FurFeelTokens.radiusPill),
                  ),
                  child: Text(
                    record.status,
                    style: textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FurFeelTokens.space3),
            _InfoLine(icon: Icons.event_outlined, label: 'Given', value: record.date),
            const SizedBox(height: FurFeelTokens.space2),
            _InfoLine(
              icon: Icons.event_repeat_outlined,
              label: 'Next due',
              value: record.nextDue,
              valueColor: isOverdue ? context.ff.statusHighFg : null,
            ),
            const SizedBox(height: FurFeelTokens.space2),
            _InfoLine(
              icon: Icons.local_hospital_outlined,
              label: 'Clinic',
              value: record.clinic,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Medical History ───────────────────────────────────────────────────────────

class _MedicalHistoryTab extends StatelessWidget {
  const _MedicalHistoryTab({required this.dog});

  final Dog dog;

  static const _placeholderHistory = <_MedicalEntry>[
    _MedicalEntry(
      title: 'Annual wellness exam',
      date: 'Apr 2, 2025',
      clinic: 'Bethlehem Animal Clinic',
      vet: 'Dr. Santos',
      note: 'Healthy weight. Dental cleaning recommended.',
      category: 'Check-up',
    ),
    _MedicalEntry(
      title: 'Ear infection treatment',
      date: 'Nov 20, 2024',
      clinic: 'Assumpta Dog & Cat Clinic',
      vet: 'Dr. Reyes',
      note: 'Otitis externa, left ear. Prescribed ear drops (7 days).',
      category: 'Treatment',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      children: [
        _SectionBanner(
          icon: Icons.medical_services_outlined,
          title: 'Medical History',
          subtitle: 'Past visits, treatments, and diagnoses',
          color: context.ff.accent,
        ),
        const SizedBox(height: FurFeelTokens.space4),
        for (final entry in _placeholderHistory) ...[
          _MedicalCard(entry: entry),
          const SizedBox(height: FurFeelTokens.space3),
        ],
        const SizedBox(height: FurFeelTokens.space3),
        _AddRecordButton(label: 'Add medical record'),
        const SizedBox(height: FurFeelTokens.space4),
        Text(
          'Medical records from partner clinics will appear here once linked.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: context.ff.inkMuted),
        ),
      ],
    );
  }
}

class _MedicalEntry {
  const _MedicalEntry({
    required this.title,
    required this.date,
    required this.clinic,
    required this.vet,
    required this.note,
    required this.category,
  });

  final String title;
  final String date;
  final String clinic;
  final String vet;
  final String note;
  final String category;
}

class _MedicalCard extends StatelessWidget {
  const _MedicalCard({required this.entry});

  final _MedicalEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: context.ff.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        border: Border.all(color: context.ff.hairline),
        boxShadow: FurFeelTokens.shadowCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.ff.surfaceAlt,
                    borderRadius:
                        BorderRadius.circular(FurFeelTokens.radiusPill),
                    border: Border.all(color: context.ff.hairline),
                  ),
                  child: Text(
                    entry.category,
                    style: textTheme.labelSmall?.copyWith(
                      color: context.ff.inkMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FurFeelTokens.space3),
            _InfoLine(icon: Icons.event_outlined, label: 'Date', value: entry.date),
            const SizedBox(height: FurFeelTokens.space2),
            _InfoLine(
              icon: Icons.local_hospital_outlined,
              label: 'Clinic',
              value: entry.clinic,
            ),
            const SizedBox(height: FurFeelTokens.space2),
            _InfoLine(
              icon: Icons.person_outlined,
              label: 'Veterinarian',
              value: entry.vet,
            ),
            const SizedBox(height: FurFeelTokens.space3),
            Container(
              padding: const EdgeInsets.all(FurFeelTokens.space3),
              decoration: BoxDecoration(
                color: context.ff.surfaceAlt,
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
              ),
              child: Text(
                entry.note,
                style: textTheme.bodySmall
                    ?.copyWith(color: context.ff.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Archived Pets ─────────────────────────────────────────────────────────────

class _ArchivedTab extends StatelessWidget {
  const _ArchivedTab();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.ff.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 36,
                color: context.ff.inkMuted,
              ),
            ),
            const SizedBox(height: FurFeelTokens.space4),
            Text(
              'No archived pets',
              style: textTheme.titleMedium?.copyWith(
                color: context.ff.brandInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: FurFeelTokens.space2),
            Text(
              'Pets you archive will appear here. Archived pets '
              'retain their monitoring history.',
              textAlign: TextAlign.center,
              style:
                  textTheme.bodySmall?.copyWith(color: context.ff.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionBanner extends StatelessWidget {
  const _SectionBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: FurFeelTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.ff.brandInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: textTheme.bodySmall
                      ?.copyWith(color: context.ff.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: context.ff.inkMuted),
        const SizedBox(width: FurFeelTokens.space2),
        Text(
          '$label: ',
          style: textTheme.bodySmall?.copyWith(color: context.ff.inkMuted),
        ),
        Expanded(
          child: Text(
            value,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: valueColor ?? context.ff.ink,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _AddRecordButton extends StatelessWidget {
  const _AddRecordButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label — coming soon'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      icon: const Icon(Icons.add),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(FurFeelTokens.touchTargetMin),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        ),
      ),
    );
  }
}
