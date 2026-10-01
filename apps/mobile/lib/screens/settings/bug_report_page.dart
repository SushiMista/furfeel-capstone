import 'package:flutter/material.dart';

import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';

class BugReportPage extends StatefulWidget {
  const BugReportPage({super.key});

  @override
  State<BugReportPage> createState() => _BugReportPageState();
}

class _BugReportPageState extends State<BugReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isSubmitting = false;
  String _category = 'bug';

  final _categories = {
    'bug': 'General Bug',
    'ui_issue': 'UI/Design Issue',
    'device_connection': 'Device Connection',
    'telemetry_error': 'Sensor/Data Error',
    'other': 'Other',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    final settings = SettingsScope.of(context);

    try {
      await settings.repository.submitBugReport(
        reporterName: settings.profile?.firstName ?? 'User',
        reporterEmail: settings.profile?.email ?? 'Unknown',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bug report submitted successfully! Thank you.'),
            backgroundColor: context.ff.statusCalmFg,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: context.ff.statusHighFg,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = context.ff;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(FurFeelTokens.space4),
          children: [
            Text(
              'Found a bug or issue? Let us know so we can fix it. Your report will be sent directly to the FurFeel engineering team.',
              style: textTheme.bodyMedium?.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: FurFeelTokens.space4),
            
            Text('Category', style: textTheme.labelSmall),
            const SizedBox(height: FurFeelTokens.space2),
            Container(
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: FurFeelTokens.space3),
                ),
                items: _categories.entries.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
            ),
            const SizedBox(height: FurFeelTokens.space4),

            Text('Title', style: textTheme.labelSmall),
            const SizedBox(height: FurFeelTokens.space2),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Brief summary of the issue',
                filled: true,
                fillColor: p.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a title' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: FurFeelTokens.space4),

            Text('Description', style: textTheme.labelSmall),
            const SizedBox(height: FurFeelTokens.space2),
            TextFormField(
              controller: _descriptionController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'What happened? What were you doing when it occurred?',
                filled: true,
                fillColor: p.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a description' : null,
            ),
            const SizedBox(height: FurFeelTokens.space6),

            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                ),
              ),
              child: _isSubmitting 
                  ? const SizedBox(
                      width: 24, height: 24, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    )
                  : const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
