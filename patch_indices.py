import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# Fix _createAccount OTP redirect
old_create_otp = """      if (response.session == null) {
        // Needs OTP
        _pageController.animateToPage(7, duration: 400.ms, curve: Curves.easeOutCubic);
        setState(() {
          _currentIndex = 7;
          _busy = false;
        });"""
new_create_otp = """      if (response.session == null) {
        // Needs OTP
        _pageController.animateToPage(8, duration: 400.ms, curve: Curves.easeOutCubic);
        setState(() {
          _currentIndex = 8;
          _busy = false;
        });"""
content = content.replace(old_create_otp, new_create_otp)

# Fix _createAccount Success redirect
old_create_success = """        // Authenticated
        await _saveDogProfile();
        if (!mounted) return;
        _pageController.animateToPage(8, duration: 400.ms, curve: Curves.easeOutCubic);
        setState(() {
          _currentIndex = 8;
          _busy = false;
        });"""
new_create_success = """        // Authenticated
        await _saveDogProfile();
        if (!mounted) return;
        _pageController.animateToPage(9, duration: 400.ms, curve: Curves.easeOutCubic);
        setState(() {
          _currentIndex = 9;
          _busy = false;
        });"""
content = content.replace(old_create_success, new_create_success)

# Fix _verifyOtp Success redirect
old_verify_success = """      if (response.session != null) {
        await _saveDogProfile();
        if (!mounted) return;
        _pageController.animateToPage(8, duration: 400.ms, curve: Curves.easeOutCubic);
        setState(() {
          _currentIndex = 8;
          _busy = false;
        });"""
new_verify_success = """      if (response.session != null) {
        await _saveDogProfile();
        if (!mounted) return;
        _pageController.animateToPage(9, duration: 400.ms, curve: Curves.easeOutCubic);
        setState(() {
          _currentIndex = 9;
          _busy = false;
        });"""
content = content.replace(old_verify_success, new_verify_success)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
