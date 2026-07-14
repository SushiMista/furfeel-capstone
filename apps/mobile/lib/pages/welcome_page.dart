import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import 'login_page.dart';

/// ADDED: real first-run flow (docs/04 Onboarding/sign-up): a warm animated
/// welcome, then create account (Supabase Auth) or sign in. After sign-up the
/// auth stream flips the app into RootShell, whose guided setup takes over
/// (add your dog → pair the harness → done).
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.client});

  final SupabaseClient client;

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
                  'Know how your dog is feeling — at home '
                  'or with your clinic, in real time.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: FurFeelTokens.inkMuted),
                ),
                2,
              ),
              const Spacer(),
              staggered(
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => SignUpPage(client: client)),
                  ),
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
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LoginPage(
                        signIn: (email, password) async {
                          try {
                            await client.auth
                                .signInWithPassword(email: email, password: password);
                            return null;
                          } on AuthException catch (e) {
                            return e.message;
                          } catch (_) {
                            return 'Could not sign in — please check your connection and try again.';
                          }
                        },
                      ),
                    ),
                  ),
                  child: const Text('I already have an account'),
                ),
                4,
              ),
              const SizedBox(height: FurFeelTokens.space4),
              staggered(
                Text(
                  'Decision support for you and your care team — never a diagnosis.',
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
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, required this.client});

  final SupabaseClient client;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;

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
            ? 'Please tell us your name — it makes the app yours.'
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
          _error = 'Almost there — check your inbox and confirm your email to continue.';
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
        _error = 'Could not create the account — please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FurFeelTokens.space5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Let\'s get you set up', style: textTheme.headlineMedium),
                const SizedBox(height: FurFeelTokens.space2),
                Text(
                  'One account for all your dogs.',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: FurFeelTokens.space5),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Your name'),
                ),
                const SizedBox(height: FurFeelTokens.space3),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: FurFeelTokens.space3),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText: 'At least 8 characters',
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: FurFeelTokens.space3),
                  Container(
                    padding: const EdgeInsets.all(FurFeelTokens.space3),
                    decoration: BoxDecoration(
                      color: FurFeelTokens.statusHighBg,
                      borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: FurFeelTokens.statusHighFg),
                    ),
                  ),
                ],
                const SizedBox(height: FurFeelTokens.space4),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'Creating account…' : 'Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
