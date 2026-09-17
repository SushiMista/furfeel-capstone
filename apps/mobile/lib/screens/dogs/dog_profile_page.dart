import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/motion.dart';
import 'package:furfeel_mobile/widgets/dog_avatar.dart';

/// Read-only dog profile (QA). The owner can view details and change the
/// profile picture, but cannot edit name/breed/age/etc. since those are
/// managed by the veterinary clinic.
class DogProfilePage extends StatefulWidget {
  const DogProfilePage({
    super.key,
    required this.repository,
    required this.dog,
  });

  final FurFeelRepository repository;
  final Dog dog;

  @override
  State<DogProfilePage> createState() => _DogProfilePageState();
}

class _DogProfilePageState extends State<DogProfilePage> {
  final _picker = ImagePicker();
  bool _busy = false;
  late Dog _dog;
  Future<String>? _photoFuture;

  @override
  void initState() {
    super.initState();
    _dog = widget.dog;
    _initFuture();
  }

  void _initFuture() {
    final path = _dog.photoPath;
    _photoFuture = path == null ? null : widget.repository.getSignedMediaUrl(path);
  }

  Future<void> _changePhoto() async {
    setState(() => _busy = true);
    try {
      final file =
          await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final extension = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final updatedDog =
          await widget.repository.setDogPhoto(_dog.id, bytes, extension);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _dog = updatedDog;
        _initFuture();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tint = dogTint(context, _dog);

    return Scaffold(
      backgroundColor: context.ff.surface,
      body: FutureBuilder<String>(
        future: _photoFuture,
        builder: (context, snapshot) {
          final imageUrl = snapshot.data;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                stretch: true,
                backgroundColor: context.ff.surface,
                iconTheme: IconThemeData(color: context.ff.ink),
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    )
                  else
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.photo_camera, color: Colors.white, size: 18),
                      ),
                      onPressed: _changePhoto,
                    ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Photo
                      if (imageUrl != null)
                        Image.network(imageUrl, fit: BoxFit.cover)
                      else
                        Container(color: tint),

                      // Gradient Scrim fading into surface
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                              context.ff.surface,
                            ],
                            stops: const [0.0, 0.3, 0.8, 1.0],
                          ),
                        ),
                      ),

                      // Massive Typography
                      Positioned(
                        bottom: FurFeelTokens.space5,
                        left: FurFeelTokens.space4,
                        right: FurFeelTokens.space4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _dog.name,
                              style: textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_dog.breed != null)
                              Text(
                                _dog.breed!,
                                style: textTheme.titleMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Stats Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  FurFeelTokens.space4,
                  0,
                  FurFeelTokens.space4,
                  FurFeelTokens.space6,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg)),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.badge_outlined, color: context.ff.brand),
                            title: const Text('Name'),
                            trailing: Text(_dog.name, style: textTheme.bodyMedium),
                          ),
                          ListTile(
                            leading: Icon(Icons.pets_outlined, color: context.ff.brand),
                            title: const Text('Breed'),
                            trailing: Text(_dog.breed ?? '—', style: textTheme.bodyMedium),
                          ),
                          ListTile(
                            leading: Icon(Icons.cake_outlined, color: context.ff.brand),
                            title: const Text('Age'),
                            trailing: Text(
                              _dog.ageYears != null
                                  ? '${_dog.ageYears} ${_dog.ageYears == 1 ? 'year' : 'years'}'
                                  : '—',
                              style: textTheme.bodyMedium,
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              _dog.sex == 'Male' ? Icons.male : Icons.female,
                              color: context.ff.brand,
                            ),
                            title: const Text('Sex'),
                            trailing: Text(_dog.sex ?? '—', style: textTheme.bodyMedium),
                          ),
                          ListTile(
                            leading: Icon(Icons.monitor_weight_outlined, color: context.ff.brand),
                            title: const Text('Weight'),
                            trailing: Text(
                              _dog.weightKg != null ? '${_dog.weightKg} kg' : '—',
                              style: textTheme.bodyMedium,
                            ),
                          ),
                          ListTile(
                            leading: Icon(Icons.local_hospital_outlined, color: context.ff.brand),
                            title: const Text('Monitoring'),
                            trailing: Text(
                              _dog.clinicId != null ? 'Clinic' : 'Home only',
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ).entrance(context),
                    const SizedBox(height: FurFeelTokens.space5),
                    Text(
                      'Dog details are managed by your veterinary clinic to ensure medical records remain accurate.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(color: context.ff.inkMuted),
                    ).entrance(context, index: 1),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
