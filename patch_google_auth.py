import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# 1. Add _authStateSub and _dogSaved
old_state_vars = """  bool _busy = false;
  String? _error;

  // State
  String _userName = '';"""

new_state_vars = """  bool _busy = false;
  String? _error;
  
  late final StreamSubscription<AuthState> _authStateSub;
  bool _dogSaved = false;

  // State
  String _userName = '';"""

content = content.replace(old_state_vars, new_state_vars)

# 2. Add imports if needed
if "import 'dart:async';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'dart:async';\nimport 'package:flutter/material.dart';")


# 3. Add to initState
old_init = """  @override
  void initState() {
    super.initState();
    FurFeelApp.isProgressiveOnboarding = true;
  }"""

new_init = """  @override
  void initState() {
    super.initState();
    FurFeelApp.isProgressiveOnboarding = true;
    _authStateSub = widget.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        _handleSuccessfulAuth();
      }
    });
  }

  Future<void> _handleSuccessfulAuth() async {
    if (_dogSaved) return;
    setState(() => _busy = true);
    await _saveDogProfile();
    _dogSaved = true;
    if (!mounted) return;
    _pageController.animateToPage(9, duration: 400.ms, curve: Curves.easeOutCubic);
    setState(() {
      _currentIndex = 9;
      _busy = false;
    });
  }"""
content = content.replace(old_init, new_init)

# 4. Add to dispose
old_dispose = """  @override
  void dispose() {
    FurFeelApp.isProgressiveOnboarding = false;
    _pageController.dispose();"""

new_dispose = """  @override
  void dispose() {
    _authStateSub.cancel();
    FurFeelApp.isProgressiveOnboarding = false;
    _pageController.dispose();"""
content = content.replace(old_dispose, new_dispose)


# 5. Clean up _createAccount and _verifyOtp
old_create_success = """      } else {
        // Authenticated
        await _saveDogProfile();
        if (!mounted) return;
        _pageController.animateToPage(9, duration: 400.ms, curve: Curves.easeOutCubic);
        setState(() {
          _currentIndex = 9;
          _busy = false;
        });
      }"""
new_create_success = """      } else {
        // Authenticated (e.g. if email confirmation is disabled)
        await _handleSuccessfulAuth();
      }"""
content = content.replace(old_create_success, new_create_success)

old_verify_success = """      if (response.session != null) {
        await _saveDogProfile();
        if (!mounted) return;
        _pageController.animateToPage(9, duration: 400.ms, curve: Curves.easeOutCubic);
        setState(() {
          _currentIndex = 9;
          _busy = false;
        });
      }"""
new_verify_success = """      if (response.session != null) {
        await _handleSuccessfulAuth();
      }"""
content = content.replace(old_verify_success, new_verify_success)


with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
