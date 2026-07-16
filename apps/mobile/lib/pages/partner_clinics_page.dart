import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';

/// A hardcoded list of FurFeel partner veterinary clinics.
/// To add a new clinic, append a [_ClinicData] entry to [_partnerClinics].
const _partnerClinics = [
  _ClinicData(
    name: 'Bethlehem Animal Clinic',
    address: '123 Bethlehem St, Batangas City',
    phone: '+63 43 000 0001',
    specialties: ['Small Animals', 'Surgery', 'Dermatology'],
    isAccepting: true,
  ),
  _ClinicData(
    name: 'Assumpta Dog & Cat Clinic',
    address: '45 Assumpta Ave, Lipa City',
    phone: '+63 43 000 0002',
    specialties: ['General Practice', 'Dental Care', 'Vaccination'],
    isAccepting: true,
  ),
];

class _ClinicData {
  const _ClinicData({
    required this.name,
    required this.address,
    required this.phone,
    required this.specialties,
    required this.isAccepting,
  });
  final String name;
  final String address;
  final String phone;
  final List<String> specialties;
  final bool isAccepting;
}

/// Lists all partner veterinary clinics that work with FurFeel.
/// Adding new clinics is a one-line change in [_partnerClinics] above.
class PartnerClinicsPage extends StatelessWidget {
  const PartnerClinicsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Partner Clinics')),
      body: ListView(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          // ── Header blurb ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(FurFeelTokens.space4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FurFeelTokens.brand.withValues(alpha: 0.08),
                  FurFeelTokens.accent.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
              border: Border.all(
                color: FurFeelTokens.brand.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FurFeelTokens.brand.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_outlined,
                    size: 20,
                    color: FurFeelTokens.brand,
                  ),
                ),
                const SizedBox(width: FurFeelTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FurFeel Partner Clinics',
                        style: textTheme.titleSmall?.copyWith(
                          color: FurFeelTokens.brandInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'These clinics are integrated with FurFeel and can '
                        'view your dog\'s real-time monitoring data.',
                        style: textTheme.bodySmall
                            ?.copyWith(color: FurFeelTokens.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: FurFeelTokens.space4),

          // ── Clinic count label ────────────────────────────────────────
          Text(
            '${_partnerClinics.length} PARTNER CLINIC${_partnerClinics.length == 1 ? '' : 'S'}',
            style: textTheme.labelSmall,
          ),
          const SizedBox(height: FurFeelTokens.space2),

          // ── Clinic cards ──────────────────────────────────────────────
          for (final clinic in _partnerClinics) ...[
            _ClinicCard(clinic: clinic),
            const SizedBox(height: FurFeelTokens.space3),
          ],

          const SizedBox(height: FurFeelTokens.space3),
          Text(
            'Is your clinic not listed? Ask them to partner with FurFeel at '
            'clinics@furfeel.example',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall
                ?.copyWith(color: FurFeelTokens.inkMuted),
          ),
          const SizedBox(height: FurFeelTokens.space5),
        ],
      ),
    );
  }
}

class _ClinicCard extends StatelessWidget {
  const _ClinicCard({required this.clinic});

  final _ClinicData clinic;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: FurFeelTokens.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        border: Border.all(color: FurFeelTokens.hairline),
        boxShadow: FurFeelTokens.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Clinic header ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(FurFeelTokens.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [FurFeelTokens.brand, FurFeelTokens.brandStrong],
                    ),
                    borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
                  ),
                  child: const Icon(
                    Icons.local_hospital_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: FurFeelTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clinic.name,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: FurFeelTokens.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: FurFeelTokens.statusCalmBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              clinic.isAccepting
                                  ? 'Accepting patients'
                                  : 'Not accepting',
                              style: textTheme.labelSmall?.copyWith(
                                color: clinic.isAccepting
                                    ? FurFeelTokens.statusCalmFg
                                    : FurFeelTokens.inkMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: FurFeelTokens.space2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: FurFeelTokens.brandSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'FurFeel Partner',
                              style: textTheme.labelSmall?.copyWith(
                                color: FurFeelTokens.brandStrong,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: FurFeelTokens.hairline),

          // ── Details ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(FurFeelTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  text: clinic.address,
                ),
                const SizedBox(height: FurFeelTokens.space3),
                _DetailRow(
                  icon: Icons.phone_outlined,
                  text: clinic.phone,
                ),
                const SizedBox(height: FurFeelTokens.space3),
                Wrap(
                  spacing: FurFeelTokens.space2,
                  runSpacing: FurFeelTokens.space2,
                  children: [
                    for (final specialty in clinic.specialties)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: FurFeelTokens.surfaceAlt,
                          borderRadius: BorderRadius.circular(
                              FurFeelTokens.radiusPill),
                          border: Border.all(color: FurFeelTokens.hairline),
                        ),
                        child: Text(
                          specialty,
                          style: textTheme.bodySmall?.copyWith(
                            color: FurFeelTokens.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: FurFeelTokens.inkMuted),
        const SizedBox(width: FurFeelTokens.space2),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: FurFeelTokens.inkMuted),
          ),
        ),
      ],
    );
  }
}
