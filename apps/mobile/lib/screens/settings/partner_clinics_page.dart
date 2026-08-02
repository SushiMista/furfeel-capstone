import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:webview_flutter/webview_flutter.dart';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/theme/shadcn_bridge.dart';

/// Lists FurFeel partner veterinary clinics from the `clinics` table — any
/// clinic an admin adds on the dashboard shows up here automatically.
class PartnerClinicsPage extends StatefulWidget {
  const PartnerClinicsPage({super.key, required this.repository});

  final FurFeelRepository repository;

  @override
  State<PartnerClinicsPage> createState() => _PartnerClinicsPageState();
}

class _PartnerClinicsPageState extends State<PartnerClinicsPage> {
  late final Future<List<Clinic>> _future = widget.repository.fetchClinics();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Partner Clinics')),
      body: FutureBuilder<List<Clinic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Couldn't load partner clinics.",
                style: textTheme.bodyMedium?.copyWith(color: context.ff.inkMuted),
              ),
            );
          }
          final clinics = snapshot.data ?? const [];

          return ListView(
            padding: const EdgeInsets.all(FurFeelTokens.space4),
            children: [
              // ── Header blurb ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(FurFeelTokens.space4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.ff.brand.withValues(alpha: 0.08),
                      context.ff.accent.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                  border: Border.all(color: context.ff.brand.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.ff.brand.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.verified_outlined, size: 20, color: context.ff.brand),
                    ),
                    const SizedBox(width: FurFeelTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FurFeel Partner Clinics',
                            style: textTheme.titleSmall?.copyWith(
                              color: context.ff.brandInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "These clinics are integrated with FurFeel and can "
                            "view your dog's real-time monitoring data.",
                            style: textTheme.bodySmall?.copyWith(color: context.ff.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: FurFeelTokens.space4),

              Text(
                '${clinics.length} PARTNER CLINIC${clinics.length == 1 ? '' : 'S'}',
                style: textTheme.labelSmall,
              ),
              const SizedBox(height: FurFeelTokens.space2),

              if (clinics.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: FurFeelTokens.space5),
                  child: Text(
                    'No partner clinics yet.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: context.ff.inkMuted),
                  ),
                )
              else
                for (final clinic in clinics) ...[
                  _ClinicRow(clinic: clinic),
                  const SizedBox(height: FurFeelTokens.space3),
                ],

              const SizedBox(height: FurFeelTokens.space3),
              Text(
                'Is your clinic not listed? Ask them to partner with FurFeel at '
                'clinics@furfeel.example',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: context.ff.inkMuted),
              ),
              const SizedBox(height: FurFeelTokens.space5),
            ],
          );
        },
      ),
    );
  }
}

/// A collapsed clinic row — tap to expand full details + embedded map.
class _ClinicRow extends StatelessWidget {
  const _ClinicRow({required this.clinic});

  final Clinic clinic;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
      onTap: () => _showClinicDetails(context, clinic),
      child: Container(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        decoration: BoxDecoration(
          color: context.ff.surface,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          border: Border.all(color: context.ff.hairline),
          boxShadow: FurFeelTokens.shadowCard,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [context.ff.brand, context.ff.brandStrong],
                ),
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
              ),
              child: const Icon(Icons.local_hospital_outlined, color: Colors.white, size: 24),
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
                      color: context.ff.ink,
                    ),
                  ),
                  if (clinic.address != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      clinic.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: context.ff.inkMuted),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.ff.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// Full clinic details, including an embedded Google Map built from the
/// clinic's address. Uses shadcn_flutter's [shadcn.AlertDialog] +
/// [shadcn.Button], piloted locally via the [furFeelShadcnTheme] bridge
/// (the app root stays MaterialApp — see shadcn_bridge.dart).
void _showClinicDetails(BuildContext context, Clinic clinic) {
  final shadcnTheme = furFeelShadcnTheme(context);

  showDialog<void>(
    context: context,
    builder: (context) {
      final mapUrl = clinic.mapEmbedUrl;
      final mapController = mapUrl == null
          ? null
          : (WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..loadRequest(Uri.parse(mapUrl)));

      return shadcn.Theme(
        data: shadcnTheme,
        child: shadcn.AlertDialog(
          leading: const Icon(Icons.local_hospital_outlined),
          title: Text(clinic.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (clinic.address != null)
                _DetailLine(icon: Icons.location_on_outlined, text: clinic.address!),
              if (clinic.contactNumber != null) ...[
                const SizedBox(height: FurFeelTokens.space2),
                _DetailLine(icon: Icons.phone_outlined, text: clinic.contactNumber!),
              ],
              if (mapController != null) ...[
                const SizedBox(height: FurFeelTokens.space3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
                  child: SizedBox(
                    height: 200,
                    child: WebViewWidget(controller: mapController),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            shadcn.Button.primary(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    },
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.ff.inkMuted),
        const SizedBox(width: FurFeelTokens.space2),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.ff.inkMuted),
          ),
        ),
      ],
    );
  }
}
