import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

old_next = """  void _next() {
    FocusScope.of(context).unfocus();
    _error = null;
    if (_currentIndex < 9) {
      _pageController.nextPage(duration: 400.ms, curve: Curves.easeOutCubic);
      setState(() => _currentIndex++);
    }
  }"""

new_next = """  void _next() async {
    FocusScope.of(context).unfocus();
    _error = null;
    
    // Backup state to SharedPreferences in case OS kills app during Google OAuth
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('backup_dog_name', _dogName);
    prefs.setString('backup_dog_sex', _dogSex);
    prefs.setString('backup_dog_breed', _dogBreed);
    prefs.setInt('backup_dog_age_index', _ageIndex);
    prefs.setBool('backup_dog_is_kg', _isKg);
    prefs.setInt('backup_dog_weight', _weightValue);

    if (_currentIndex < 9) {
      _pageController.nextPage(duration: 400.ms, curve: Curves.easeOutCubic);
      setState(() => _currentIndex++);
    }
  }"""

content = content.replace(old_next, new_next)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
