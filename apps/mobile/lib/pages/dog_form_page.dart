import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

/// Pet Creation / Profiles (docs/04 module 2): create or edit a dog — name,
/// breed, birthdate (→ age), sex, weight, medical notes, photo, and the clinic
/// linkage that puts the dog on that clinic's live monitoring board.
class DogFormPage extends StatefulWidget {
  const DogFormPage({super.key, required this.repository, this.dog});

  final FurFeelRepository repository;

  /// Null = create a new dog; non-null = edit this dog.
  final Dog? dog;

  @override
  State<DogFormPage> createState() => _DogFormPageState();
}

class _DogFormPageState extends State<DogFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _breed;
  late final TextEditingController _weight;
  late final TextEditingController _notes;
  final _picker = ImagePicker();

  DateTime? _birthdate;
  String _sex = 'unknown';
  String? _clinicId;
  List<Clinic> _clinics = [];
  XFile? _photo;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.dog != null;

  @override
  void initState() {
    super.initState();
    final dog = widget.dog;
    _name = TextEditingController(text: dog?.name ?? '');
    _breed = TextEditingController(text: dog?.breed ?? '');
    _weight = TextEditingController(text: dog?.weightKg?.toString() ?? '');
    _notes = TextEditingController(text: dog?.notes ?? '');
    _birthdate = dog?.birthdate == null ? null : DateTime.tryParse(dog!.birthdate!);
    _sex = dog?.sex ?? 'unknown';
    _clinicId = dog?.clinicId;
    // The save button says "Add <name>" — keep it live as the owner types.
    _name.addListener(() => setState(() {}));
    widget.repository.fetchClinics().then((clinics) {
      // Dedupe by id — duplicate DropdownMenuItem values trip the framework's
      // "exactly one item with value" assert (dropdown.dart:1852).
      final seen = <String>{};
      final unique = clinics.where((c) => seen.add(c.id)).toList();
      if (mounted) setState(() => _clinics = unique);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 2),
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      helpText: 'When was your dog born?',
    );
    if (picked != null && mounted) setState(() => _birthdate = picked);
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null && mounted) setState(() => _photo = file);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final draft = DogDraft(
        name: _name.text.trim(),
        breed: _breed.text.trim().isEmpty ? null : _breed.text.trim(),
        birthdate: _birthdate == null
            ? null
            : '${_birthdate!.year}-${_birthdate!.month.toString().padLeft(2, '0')}-'
                '${_birthdate!.day.toString().padLeft(2, '0')}',
        sex: _sex,
        weightKg: double.tryParse(_weight.text.trim()),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        clinicId: _clinicId,
      );
      var dog = _isEdit
          ? await widget.repository.updateDog(widget.dog!.id, draft)
          : await widget.repository.createDog(draft);
      final photo = _photo;
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final ext = photo.name.contains('.') ? photo.name.split('.').last.toLowerCase() : 'jpg';
        dog = await widget.repository.setDogPhoto(dog.id, bytes, ext);
      }
      if (!mounted) return;
      Navigator.of(context).pop(dog);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = err is FurFeelDataException
            ? err.message
            : 'Saving failed — please check your connection and try again.';
      });
    }
  }

  Future<void> _delete() async {
    final dog = widget.dog;
    if (dog == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${dog.name}?'),
        content: const Text(
          'This removes the profile from your account. Monitoring history that a '
          'clinic already has is kept for their records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.deleteDog(dog.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = err is FurFeelDataException
            ? err.message
            : 'Removing failed — please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit ${widget.dog!.name}' : 'Add your dog'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Remove profile',
              onPressed: _saving ? null : _delete,
              icon: Icon(Icons.delete_outline, color: context.ff.inkMuted),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(FurFeelTokens.space4),
          children: [
            Center(
              child: InkWell(
                onTap: _saving ? null : _pickPhoto,
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: context.ff.brandSoft,
                  child: _photo != null
                      ? Icon(Icons.check_circle_outline,
                          size: 32, color: context.ff.brand)
                      : Icon(Icons.add_a_photo_outlined,
                          size: 28, color: context.ff.brand),
                ),
              ),
            ),
            const SizedBox(height: FurFeelTokens.space2),
            Center(
              child: Text(
                _photo != null ? _photo!.name : 'Add a photo (optional)',
                style: textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: FurFeelTokens.space4),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Every pup needs a name' : null,
            ),
            const SizedBox(height: FurFeelTokens.space3),
            TextFormField(
              controller: _breed,
              decoration: const InputDecoration(labelText: 'Breed (optional)'),
            ),
            const SizedBox(height: FurFeelTokens.space3),
            InkWell(
              onTap: _saving ? null : _pickBirthdate,
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Birthdate (optional)'),
                child: Text(
                  _birthdate == null
                      ? 'Tap to pick'
                      : '${_birthdate!.year}-${_birthdate!.month.toString().padLeft(2, '0')}-'
                          '${_birthdate!.day.toString().padLeft(2, '0')}',
                  style: _birthdate == null
                      ? TextStyle(color: context.ff.inkMuted)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: FurFeelTokens.space3),
            DropdownButtonFormField<String>(
              initialValue: _sex,
              decoration: const InputDecoration(labelText: 'Sex'),
              items: const [
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'unknown', child: Text('Prefer not to say')),
              ],
              onChanged: (v) => setState(() => _sex = v ?? 'unknown'),
            ),
            const SizedBox(height: FurFeelTokens.space3),
            TextFormField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Weight in kg (optional)'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                return double.tryParse(v.trim()) == null ? 'Numbers only, e.g. 12.5' : null;
              },
            ),
            const SizedBox(height: FurFeelTokens.space3),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Medical history / notes (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: FurFeelTokens.space5),
            Text('VETERINARY CLINIC', style: textTheme.labelSmall),
            const SizedBox(height: FurFeelTokens.space2),
            DropdownButtonFormField<String?>(
              initialValue: _clinicId,
              decoration: const InputDecoration(labelText: 'Monitored by (optional)'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Home monitoring only'),
                ),
                // While clinics load (or if the dog's clinic isn't in the
                // partner list) the selected value must still exist exactly
                // once in items, or the dropdown asserts and the edit form
                // flashes an error frame. Keeping a placeholder also avoids
                // silently unlinking the dog's clinic.
                if (_clinicId != null && !_clinics.any((c) => c.id == _clinicId))
                  DropdownMenuItem<String?>(
                    value: _clinicId,
                    child: const Text('Your current clinic'),
                  ),
                for (final clinic in _clinics)
                  DropdownMenuItem<String?>(value: clinic.id, child: Text(clinic.name)),
              ],
              onChanged: (v) => setState(() => _clinicId = v),
            ),
            const SizedBox(height: FurFeelTokens.space2),
            Text(
              'Choosing a clinic shares live readings with their monitoring board, '
              'so their team can keep an eye on your dog too.',
              style: textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: FurFeelTokens.space4),
              Container(
                padding: const EdgeInsets.all(FurFeelTokens.space3),
                decoration: BoxDecoration(
                  color: context.ff.statusHighBg,
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: context.ff.statusHighOwner),
                ),
              ),
            ],
            const SizedBox(height: FurFeelTokens.space5),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving ? 'Saving…' : (_isEdit ? 'Save changes' : 'Add ${_dogNameOrDog()}'),
              ),
            ),
            const SizedBox(height: FurFeelTokens.space5),
          ],
        ),
      ),
    );
  }

  String _dogNameOrDog() {
    final name = _name.text.trim();
    return name.isEmpty ? 'dog' : name;
  }
}
