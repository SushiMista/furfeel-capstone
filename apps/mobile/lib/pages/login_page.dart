import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import '../widgets/auth_form.dart';
import '../widgets/furfeel_logo.dart';

/// Sign-in callback: returns null on success, or a user-facing error message.
typedef SignIn = Future<String?> Function(String email, String password);

/// Modern sign-in screen with FurFeel branding header, left-aligned form
/// fields, inline error, and Google sign-in option.
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
      // Transparent app bar — just the back arrow, no title clutter.
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
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
                // ── Branding header ──────────────────────────────────────
                const SizedBox(height: FurFeelTokens.space4),
                const Center(child: FurFeelLogo.auth(size: 48, animate: true)),
                const SizedBox(height: FurFeelTokens.space5),

                // ── Divider with subtle brand tint ───────────────────────
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

                // ── Headline ─────────────────────────────────────────────
                Text(
                  'Welcome back',
                  style: textTheme.headlineSmall?.copyWith(
                    color: context.ff.brandInk,
                    fontWeight: FontWeight.w700,
                  ),
                ).entrance(context),
                const SizedBox(height: FurFeelTokens.space2),
                Text(
                  'Sign in to see how your dog is doing.',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: context.ff.inkMuted),
                ).entrance(context, index: 1),
                const SizedBox(height: FurFeelTokens.space5),

                // ── Form fields ──────────────────────────────────────────
                AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
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
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            tooltip: _obscure
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: context.ff.inkMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).entrance(context, index: 2),

                // ── Inline error ─────────────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: FurFeelTokens.space4),
                  InlineFormError(message: _error!),
                ],
                const SizedBox(height: FurFeelTokens.space5),

                // ── Primary CTA ──────────────────────────────────────────
                ElevatedButton(
                  onPressed: _submitting || _googleBusy ? null : _submit,
                  child: _submitting
                      ? const BusyButtonLabel(label: 'Signing in')
                      : const Text('Sign in'),
                ).entrance(context, index: 3),

                // ── Google sign-in ───────────────────────────────────────
                if (widget.onGoogleSignIn != null) ...[
                  const SizedBox(height: FurFeelTokens.space4),
                  const OrDivider(),
                  const SizedBox(height: FurFeelTokens.space4),
                  GoogleSignInButton(
                    busy: _googleBusy,
                    onPressed: _submitting ? null : _submitGoogle,
                  ).entrance(context, index: 4),
                ],

                // ── Create account cross-link ────────────────────────────
                if (widget.onCreateAccount != null) ...[
                  const SizedBox(height: FurFeelTokens.space3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New here?',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: context.ff.inkMuted),
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
