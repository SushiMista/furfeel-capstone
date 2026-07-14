import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';

/// Sign-in callback: returns null on success, or a user-facing error message.
typedef SignIn = Future<String?> Function(String email, String password);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.signIn});

  final SignIn signIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;

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
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FurFeelTokens.space5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(FurFeelTokens.space5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'FurFeel',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(
                        color: FurFeelTokens.brandInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: FurFeelTokens.space2),
                    Text(
                      'Welcome back — your best friend missed you.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: FurFeelTokens.space5),
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
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
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
                      child: Text(_submitting ? 'Signing in…' : 'Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
