import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/motion.dart';
import 'package:furfeel_mobile/widgets/auth_form.dart';
import 'package:furfeel_mobile/widgets/auth_pattern_background.dart';
import 'package:furfeel_mobile/screens/auth/login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({
    super.key,
    required this.client,
  });

  final SupabaseClient client;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _emergencyContact = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _otp = TextEditingController();

  String? _error;
  bool _submitting = false;
  bool _googleBusy = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _needsOtp = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _emergencyContact.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final name = _name.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final emergencyContact = _emergencyContact.text.trim();
    final password = _password.text;
    final confirmPassword = _confirmPassword.text;

    final hasLength = password.length >= 8;
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#\$%\^&\*~`\(\)\-_\+=\[\]\{\}\|;:,.<>\/?]'));
    final isPasswordStrong = hasLength && hasUpper && hasLower && hasNumber && hasSpecial;

    if (name.isEmpty || email.isEmpty) {
      setState(() {
        _submitting = false;
        _error = 'Please enter your name and a valid email.';
      });
      return;
    }
    if (!isPasswordStrong) {
      setState(() {
        _submitting = false;
        _error = 'Please ensure your password meets all requirements.';
      });
      return;
    }
    if (password != confirmPassword) {
      setState(() {
        _submitting = false;
        _error = 'Passwords do not match.';
      });
      return;
    }

    try {
      final response = await widget.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': phone.isEmpty ? null : phone,
          'emergency_contact': emergencyContact.isEmpty ? null : emergencyContact,
        },
      );
      if (!mounted) return;

      if (response.session == null) {
        setState(() {
          _needsOtp = true;
          _submitting = false;
        });
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('user already registered')) {
        setState(() {
          _error = 'This email is already registered. Log in instead.';
          _submitting = false;
        });
      } else {
        setState(() {
          _error = e.message;
          _submitting = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _submitting = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otp.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the 6-digit code.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final response = await widget.client.auth.verifyOTP(
        type: OtpType.signup,
        email: _email.text.trim(),
        token: otp,
      );
      if (!mounted) return;

      if (response.session != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        setState(() {
          _error = 'Verification failed. Try again.';
          _submitting = false;
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not verify code.';
        _submitting = false;
      });
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      await widget.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : 'io.furfeel.app://login-callback',
        authScreenLaunchMode: LaunchMode.platformDefault,
        queryParams: {'prompt': 'select_account'},
      );
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = e.message; _googleBusy = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not start Google sign-in. Check your connection.'; _googleBusy = false; });
    }
  }

  void _openLogin(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(
          signIn: (email, password) async {
            try {
              await widget.client.auth.signInWithPassword(email: email, password: password);
              return null;
            } on AuthException catch (e) {
              return e.message;
            } catch (_) {
              return 'Could not sign in.';
            }
          },
          onGoogleSignIn: () async {
            _submitGoogle();
            return null;
          },
          onCreateAccount: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => SignUpPage(client: widget.client)),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool met) {
    return Row(
      children: [
        Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, 
             color: met ? Colors.green : Colors.grey, size: 16),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: met ? Colors.green : Colors.grey, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    final pass = _password.text;
    final hasLength = pass.length >= 8;
    final hasUpper = pass.contains(RegExp(r'[A-Z]'));
    final hasLower = pass.contains(RegExp(r'[a-z]'));
    final hasNumber = pass.contains(RegExp(r'[0-9]'));
    final hasSpecial = pass.contains(RegExp(r'[!@#\$%\^&\*~`\(\)\-_\+=\[\]\{\}\|;:,.<>\/?]'));
    
    int strengthCount = 0;
    if (hasLength) strengthCount++;
    if (hasUpper) strengthCount++;
    if (hasLower) strengthCount++;
    if (hasNumber) strengthCount++;
    if (hasSpecial) strengthCount++;
    
    String strengthLabel = 'Weak';
    Color strengthColor = Colors.red;
    if (strengthCount >= 3 && strengthCount < 5) {
       strengthLabel = 'Medium';
       strengthColor = Colors.orange;
    } else if (strengthCount == 5) {
       strengthLabel = 'Strong';
       strengthColor = Colors.green;
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: AuthPatternBackground(
        color: context.ff.brand,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: FurFeelTokens.space5,
                  vertical: FurFeelTokens.space4,
                ),
                children: [
                  const SizedBox(height: FurFeelTokens.space4),
                  Center(
                    child: Image.asset(
                      'assets/photos/logo_title.png',
                      height: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: FurFeelTokens.space5),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          context.ff.brand.withValues(alpha: 0.20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: FurFeelTokens.space5),

                  if (_needsOtp) ...[
                    Text(
                      'Check your email',
                      style: textTheme.headlineSmall?.copyWith(
                        color: context.ff.brandInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ).entrance(context),
                    const SizedBox(height: FurFeelTokens.space2),
                    Text(
                      'We sent a 6-digit verification code to ${_email.text.trim()}.',
                      style: textTheme.bodyMedium?.copyWith(color: context.ff.inkMuted),
                    ).entrance(context, index: 1),
                    const SizedBox(height: FurFeelTokens.space5),
                    TextField(
                      controller: _otp,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(letterSpacing: 8, fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Verification Code',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _verifyOtp(),
                    ).entrance(context, index: 2),
                    const SizedBox(height: FurFeelTokens.space5),
                    if (_error != null) ...[
                      InlineFormError(message: _error!),
                      const SizedBox(height: FurFeelTokens.space4),
                    ],
                    ElevatedButton(
                      onPressed: _submitting ? null : _verifyOtp,
                      child: _submitting
                          ? const BusyButtonLabel(label: 'Verifying')
                          : const Text('Verify'),
                    ).entrance(context, index: 3),
                  ] else ...[
                    Text(
                      'Create an account',
                      style: textTheme.headlineSmall?.copyWith(
                        color: context.ff.brandInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ).entrance(context),
                    const SizedBox(height: FurFeelTokens.space2),
                    Text(
                      'Sign up to monitor your dog\'s wellbeing.',
                      style: textTheme.bodyMedium?.copyWith(color: context.ff.inkMuted),
                    ).entrance(context, index: 1),
                    const SizedBox(height: FurFeelTokens.space5),

                    AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Full Name *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: FurFeelTokens.space3),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email *',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: FurFeelTokens.space3),
                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: FurFeelTokens.space3),
                          TextField(
                            controller: _emergencyContact,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Emergency Contact',
                              prefixIcon: Icon(Icons.health_and_safety_outlined),
                            ),
                          ),
                          const SizedBox(height: FurFeelTokens.space3),
                          TextField(
                            controller: _password,
                            obscureText: _obscure,
                            onChanged: (_) => setState((){}),
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Password *',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: context.ff.inkMuted,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (pass.isNotEmpty) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: strengthColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(strengthLabel, style: TextStyle(color: strengthColor, fontWeight: FontWeight.bold, fontSize: 12)),
                              ]
                            ),
                            const SizedBox(height: 8),
                            _buildRequirementRow('8+ characters', hasLength),
                            const SizedBox(height: 4),
                            _buildRequirementRow('Uppercase letter', hasUpper),
                            const SizedBox(height: 4),
                            _buildRequirementRow('Lowercase letter', hasLower),
                            const SizedBox(height: 4),
                            _buildRequirementRow('Number', hasNumber),
                            const SizedBox(height: 4),
                            _buildRequirementRow('Special character', hasSpecial),
                            const SizedBox(height: 16),
                          ],
                          TextField(
                            controller: _confirmPassword,
                            obscureText: _obscureConfirm,
                            onChanged: (_) => setState((){}),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Confirm Password *',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                icon: Icon(
                                  _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: context.ff.inkMuted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).entrance(context, index: 2),

                    if (_error != null) ...[
                      const SizedBox(height: FurFeelTokens.space4),
                      InlineFormError(message: _error!),
                    ],
                    const SizedBox(height: FurFeelTokens.space5),

                    ElevatedButton(
                      onPressed: _submitting || _googleBusy ? null : _submit,
                      child: _submitting
                          ? const BusyButtonLabel(label: 'Creating account')
                          : const Text('Create account'),
                    ).entrance(context, index: 3),

                    const SizedBox(height: FurFeelTokens.space4),
                    const OrDivider(),
                    const SizedBox(height: FurFeelTokens.space4),
                    GoogleSignInButton(
                      busy: _googleBusy,
                      onPressed: _submitting ? null : _submitGoogle,
                    ).entrance(context, index: 4),

                    const SizedBox(height: FurFeelTokens.space3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: textTheme.bodyMedium?.copyWith(color: context.ff.inkMuted),
                        ),
                        TextButton(
                          onPressed: () => _openLogin(context),
                          child: const Text('Sign in'),
                        ),
                      ],
                    ).entrance(context, index: 5),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
