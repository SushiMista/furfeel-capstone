import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# Add import for SharedPreferences if needed
if "import 'package:shared_preferences/shared_preferences.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:shared_preferences/shared_preferences.dart';")

# Backup the draft in _next
old_next = """  void _next() {
    FocusScope.of(context).unfocus();
    _error = null;
    if (_currentIndex < 9) {
      _pageController.animateToPage(_currentIndex + 1, duration: 400.ms, curve: Curves.easeOutCubic);
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
      _pageController.animateToPage(_currentIndex + 1, duration: 400.ms, curve: Curves.easeOutCubic);
      setState(() => _currentIndex++);
    }
  }"""
content = content.replace(old_next, new_next)

# Restore draft in _handleSuccessfulAuth if state is empty
old_handle = """  Future<void> _handleSuccessfulAuth() async {
    if (_dogSaved) return;
    
    // Safety check: if dogName is empty, it means they logged into an existing
    // account from the signup page OR state was lost. We shouldn't create a blank dog.
    if (_dogName.isEmpty) {
       _dogSaved = true;
       if (!mounted) return;
       _pageController.animateToPage(9, duration: 400.ms, curve: Curves.easeOutCubic);
       setState(() {
         _currentIndex = 9;
         _busy = false;
       });
       return;
    }

    setState(() => _busy = true);
    try {
      await _saveDogProfile();"""

new_handle = """  Future<void> _handleSuccessfulAuth() async {
    if (_dogSaved) return;
    setState(() => _busy = true);
    
    // If state was lost (OS kill), attempt restore from backup
    if (_dogName.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      _dogName = prefs.getString('backup_dog_name') ?? '';
      _dogSex = prefs.getString('backup_dog_sex') ?? '';
      _dogBreed = prefs.getString('backup_dog_breed') ?? '';
      _ageIndex = prefs.getInt('backup_dog_age_index') ?? 0;
      _isKg = prefs.getBool('backup_dog_is_kg') ?? true;
      _weightValue = prefs.getInt('backup_dog_weight') ?? 10;
    }

    // Safety check
    if (_dogName.isEmpty) {
       _dogSaved = true;
       if (!mounted) return;
       _pageController.animateToPage(9, duration: 400.ms, curve: Curves.easeOutCubic);
       setState(() {
         _currentIndex = 9;
         _busy = false;
       });
       return;
    }

    try {
      await _saveDogProfile();"""
content = content.replace(old_handle, new_handle)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
