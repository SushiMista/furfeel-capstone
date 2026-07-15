import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import '../widgets/auth_form.dart';
import 'login_page.dart';

/// ADDED: real first-run flow (docs/04 Onboarding/sign-up): a warm animated
/// welcome, then create account (Supabase Auth) or sign in. After sign-up the
/// auth stream flips the app into RootShell, whose guided setup takes over
/// (add your dog → pair the harness → done).
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.client});

  final SupabaseClient client;

  Future<String?> _signIn(String email, String password) async {
    try {
      await client.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not sign in. Check your connection and try again.';
    }
  }

  // Login and sign-up cross-link to each other with pushReplacement, so the
  // back gesture always returns to this welcome screen, never ping-pongs.
  void _openLogin(BuildContext context, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => LoginPage(
        signIn: _signIn,
        onCreateAccount: () => _openSignUp(context, replace: true),
      ),
    );
    final navigator = Navigator.of(context);
    replace ? navigator.pushReplacement(route) : navigator.push(route);
  }

  void _openSignUp(BuildContext context, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => SignUpPage(
        client: client,
        onSignIn: () => _openLogin(context, replace: true),
      ),
    );
    final navigator = Navigator.of(context);
    replace ? navigator.pushReplacement(route) : navigator.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reduce = context.reduceMotion;

    Widget staggered(Widget child, int index) {
      if (reduce) return child;
      return child
          .animate(delay: Duration(milliseconds: 120 * index))
          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          .slideY(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOut);
    }

    Widget paw = Icon(Icons.pets, size: 72, color: FurFeelTokens.brand);
    if (!reduce) {
      // One gentle settle-in wiggle, then still — welcoming, not busy.
      paw = paw
          .animate()
          .scale(
            begin: const Offset(0.6, 0.6),
            end: const Offset(1, 1),
            duration: 500.ms,
            curve: Curves.easeOutBack,
          )
          .fadeIn(duration: 300.ms);
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FurFeelTokens.space6),
          child: Column(
            children: [
              const Spacer(),
              paw,
              const SizedBox(height: FurFeelTokens.space4),
              staggered(
                Text(
                  'FurFeel',
                  style: textTheme.displaySmall?.copyWith(
                    color: FurFeelTokens.brandInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                1,
              ),
              const SizedBox(height: FurFeelTokens.space2),
              staggered(
                Text(
                  'Know how your dog is feeling, at home '
                  'or with your clinic, in real time.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: FurFeelTokens.inkMuted),
                ),
                2,
              ),
              const Spacer(),
              staggered(
                ElevatedButton(
                  onPressed: () => _openSignUp(context),
                  child: const Text('Create account'),
                ),
                3,
              ),
              const SizedBox(height: FurFeelTokens.space3),
              staggered(
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(FurFeelTokens.touchTargetMin),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => _openLogin(context),
                  child: const Text('I already have an account'),
                ),
                4,
              ),
              const SizedBox(height: FurFeelTokens.space4),
              staggered(
                Text(
                  'Decision support for you and your care team, never a diagnosis.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
                5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Create account (Supabase Auth). The signup trigger creates the users +
/// user_settings rows server-side; the name travels in user metadata.
/// Same skeleton as the sign-in screen: left-aligned headline, full-width
/// fields, inline error, one primary action.
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, required this.client, this.onSignIn});

  final SupabaseClient client;

  /// Optional cross-link to the sign-in screen.
  final VoidCallback? onSignIn;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || email.isEmpty || _password.text.length < 8) {
      setState(() {
        _error = name.isEmpty
            ? 'Please tell us your name, so the app feels like yours.'
            : email.isEmpty
                ? 'Please enter your email.'
                : 'Password needs at least 8 characters.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final response = await widget.client.auth
          .signUp(email: email, password: _password.text, data: {'name': name});
      if (!mounted) return;
      if (response.session == null) {
        // Email confirmation is on: no session until the link is clicked.
        setState(() {
          _submitting = false;
          _error = 'Almost there. Check your inbox and confirm your email to continue.';
        });
        return;
      }
      // Signed in: the root auth stream swaps to the guided setup.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not create the account. Check your connection and try again.';
      });
    }
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
                  'Let\'s get you set up',
                  style: textTheme.headlineMedium?.copyWith(
                    color: FurFeelTokens.brandInk,
                    fontWeight: FontWeight.w800,
                  ),
                ).entrance(context),
                const SizedBox(height: FurFeelTokens.space2),
                Text(
                  'One account for all your dogs.',
                  style: textTheme.bodyMedium?.copyWith(color: FurFeelTokens.inkMuted),
                ).entrance(context, index: 1),
                const SizedBox(height: FurFeelTokens.space6),
                AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(labelText: 'Your name'),
                      ),
                      const SizedBox(height: FurFeelTokens.space3),
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
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: 'At least 8 characters',
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
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const BusyButtonLabel(label: 'Creating account')
                      : const Text('Create account'),
                ).entrance(context, index: 3),
                if (widget.onSignIn != null) ...[
                  const SizedBox(height: FurFeelTokens.space3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: FurFeelTokens.inkMuted),
                      ),
                      TextButton(
                        onPressed: widget.onSignIn,
                        child: const Text('Sign in'),
                      ),
                    ],
                  ).entrance(context, index: 4),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
