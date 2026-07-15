import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import '../widgets/auth_form.dart';

/// Sign-in callback: returns null on success, or a user-facing error message.
typedef SignIn = Future<String?> Function(String email, String password);

/// Modern-minimal sign-in (docs/19 tokens, docs/04 auth flow): left-aligned
/// headline, full-width fields, inline error, one primary action. No card
/// chrome; the screen itself is the surface.
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.signIn,
    this.onGoogleSignIn,
    this.onCreateAccount,
  });

  final SignIn signIn;

  /// Optional Google OAuth starter: returns null on success (navigation is
  /// handled by the root auth stream), or a user-facing error message.
  final Future<String?> Function()? onGoogleSignIn;

  /// Optional cross-link to the sign-up screen ("New here? Create account").
  final VoidCallback? onCreateAccount;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;
  bool _googleBusy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.signIn(_email.text.trim(), _password.text);
    if (!mounted) return;
    if (error == null) {
      // Signed in: the root auth stream swaps to the home shell.
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    final error = await widget.onGoogleSignIn!();
    if (!mounted) return;
    if (error == null) {
      // Stay busy: the page is about to redirect (web) or the session will
      // arrive via deep link and the root auth stream pops this screen.
      return;
    }
    setState(() {
      _googleBusy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: FurFeelTokens.space5,
                vertical: FurFeelTokens.space4,
              ),
              children: [
                Text(
                  'Welcome back',
                  style: textTheme.headlineMedium?.copyWith(
                    color: FurFeelTokens.brandInk,
                    fontWeight: FontWeight.w800,
                  ),
                ).entrance(context),
                const SizedBox(height: FurFeelTokens.space2),
                Text(
                  'Sign in to see how your dog is doing.',
                  style: textTheme.bodyMedium?.copyWith(color: FurFeelTokens.inkMuted),
                ).entrance(context, index: 1),
                const SizedBox(height: FurFeelTokens.space6),
                AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: FurFeelTokens.space3),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: FurFeelTokens.inkMuted,
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
                      ? const BusyButtonLabel(label: 'Signing in')
                      : const Text('Sign in'),
                ).entrance(context, index: 3),
                if (widget.onGoogleSignIn != null) ...[
                  const SizedBox(height: FurFeelTokens.space4),
                  const OrDivider(),
                  const SizedBox(height: FurFeelTokens.space4),
                  GoogleSignInButton(
                    busy: _googleBusy,
                    onPressed: _submitting ? null : _submitGoogle,
                  ).entrance(context, index: 4),
                ],
                if (widget.onCreateAccount != null) ...[
                  const SizedBox(height: FurFeelTokens.space3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New here?',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: FurFeelTokens.inkMuted),
                      ),
                      TextButton(
                        onPressed: widget.onCreateAccount,
                        child: const Text('Create account'),
                      ),
                    ],
                  ).entrance(context, index: 5),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
