import re

with open('apps/mobile/lib/screens/auth/login_page.dart', 'r') as f:
    content = f.read()

# Add _resetPassword method
reset_password_method = """  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email to reset your password.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Assuming SupabaseClient is available globally or we can use Supabase.instance.client
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not send reset link. Check your email address.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submit() async {"""

content = content.replace("  Future<void> _submit() async {", reset_password_method)

# Add Forgot Password button in build()
old_password_field_end = """                        ),
                      ),
                    ],
                  ),
                ).entrance(context, index: 2),"""

new_password_field_end = """                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _submitting ? null : _resetPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ],
                  ),
                ).entrance(context, index: 2),"""

content = content.replace(old_password_field_end, new_password_field_end)

# Add import for Supabase
if "import 'package:supabase_flutter/supabase_flutter.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:supabase_flutter/supabase_flutter.dart';")

with open('apps/mobile/lib/screens/auth/login_page.dart', 'w') as f:
    f.write(content)
