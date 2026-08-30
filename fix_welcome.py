import re

with open('apps/mobile/lib/screens/auth/welcome_page.dart', 'r') as f:
    content = f.read()

# 1. Add import for OtpVerificationPage if missing
if 'otp_verification_page.dart' not in content:
    content = content.replace("import 'package:furfeel_mobile/screens/home/root_shell.dart';", "import 'package:furfeel_mobile/screens/auth/otp_verification_page.dart';\nimport 'package:furfeel_mobile/screens/home/root_shell.dart';")

# 2. Add confirm password controller
content = content.replace("final _password = TextEditingController();", "final _password = TextEditingController();\n  final _confirmPassword = TextEditingController();")
content = content.replace("_password.dispose();\n    super.dispose();", "_password.dispose();\n    _confirmPassword.dispose();\n    super.dispose();")

# 3. Update submit validation
val_search = """if (name.isEmpty || email.isEmpty || _password.text.length < 8) {
      setState(() {
        _error = name.isEmpty
            ? 'Please tell us your name, so the app feels like yours.'
            : email.isEmpty
                ? 'Please enter your email.'
                : 'Password needs at least 8 characters.';
      });
      return;
    }"""
val_replace = val_search + """
    if (_password.text != _confirmPassword.text) {
      setState(() {
        _error = 'Passwords do not match.';
      });
      return;
    }"""
content = content.replace(val_search, val_replace)

# 4. Update submit routing
route_search = """if (response.session == null) {
        // Email confirmation is on: no session until the link is clicked.
        setState(() {
          _submitting = false;
          _error = 'Almost there. Check your inbox and confirm your email to continue.';
        });
        return;
      }"""
route_replace = """if (response.session == null) {
        setState(() => _submitting = false);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OtpVerificationPage(
              client: widget.client,
              email: email,
            ),
          ),
        );
        return;
      }"""
content = content.replace(route_search, route_replace)

# 5. Add User already registered handler
err_search = """} on AuthException catch (e) {
      if (!mounted) return;"""
err_replace = """} on AuthException catch (e) {
      if (!mounted) return;
      if (e.message.toLowerCase().contains('user already registered')) {
         setState(() {
           _submitting = false;
           _error = 'Account already exists. Please log in instead.';
         });
         return;
      }"""
content = content.replace(err_search, err_replace)

# 6. Add UI field
ui_search = """TextField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: 'At least 8 characters',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: context.ff.inkMuted,
                            ),
                          ),
                        ),
                      ),"""
ui_replace = """TextField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: 'At least 8 characters',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: context.ff.inkMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: FurFeelTokens.space3),
                      TextField(
                        controller: _confirmPassword,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),"""
content = content.replace(ui_search, ui_replace)

# 7. Add unverified interception for _signIn inside WelcomePage (Path 2)
# Need to replace return e.message; in WelcomePage _signIn
signin_search = """return e.message;
    } catch (_) {"""
signin_replace = """if (e.message.toLowerCase().contains('email not confirmed')) {
        try {
          await client.auth.resend(type: OtpType.signup, email: email);
          return 'Email not verified. We sent a new code to your inbox.';
        } catch (_) {}
      }
      return e.message;
    } catch (_) {"""
content = content.replace(signin_search, signin_replace)

with open('apps/mobile/lib/screens/auth/welcome_page.dart', 'w') as f:
    f.write(content)
