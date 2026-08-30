import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# 1. Add Cupertino import
if "import 'package:flutter/cupertino.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/cupertino.dart';")

# 2. Add new state variables
new_state_vars = """  // State
  String _userName = '';
  String _dogName = '';
  String _dogSex = '';
  String _dogBreed = '';
  int _ageIndex = 11; // Default to '1 year'
  bool _isKg = true;
  int _weightValue = 10;
  String _email = '';
"""
content = re.sub(r'  // State\n.*?String _email = \'\';\n', new_state_vars, content, flags=re.DOTALL)

# 3. Update _saveDogProfile to use the new values
old_save_dog = """      final weight = double.tryParse(_dogWeight) ?? 0.0;
      await repo.createDog(DogDraft(
        name: _dogName,
        breed: _dogBreed.isEmpty ? null : _dogBreed,
        birthdate: _dogAge.isNotEmpty ? DateTime.now().subtract(Duration(days: (double.tryParse(_dogAge) ?? 0).toInt() * 365)).toIso8601String() : null,
        weightKg: weight > 0 ? weight : null,"""

new_save_dog = """      final weightKg = _isKg ? _weightValue.toDouble() : _weightValue / 2.20462;
      
      // Calculate approx birthdate from ageIndex
      // 0-10 are months 1-11. 11+ are years 1-25.
      int daysToSubtract = 0;
      if (_ageIndex <= 10) {
        daysToSubtract = (_ageIndex + 1) * 30;
      } else {
        daysToSubtract = (_ageIndex - 10) * 365;
      }
      final birthdate = DateTime.now().subtract(Duration(days: daysToSubtract)).toIso8601String();

      await repo.createDog(DogDraft(
        name: _dogName,
        sex: _dogSex.isEmpty ? null : _dogSex,
        breed: _dogBreed.isEmpty ? null : _dogBreed,
        birthdate: birthdate,
        weightKg: weightKg > 0 ? weightKg : null,"""

content = content.replace(old_save_dog, new_save_dog)

# 4. Update the PageView and Progress bar count
# The array now has 10 steps.
old_pageview = """            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildWelcome(),
                _buildName(),
                _buildDogName(),
                _buildDogBreed(),
                _buildDogAge(),
                _buildDogWeight(),
                _buildCreateAccount(),
                _buildOtp(),
                _buildCompletion(),
              ],
            ),
            if (_currentIndex > 0 && _currentIndex < 7)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(6, (index) {"""

new_pageview = """            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildWelcome(),
                _buildName(),
                _buildDogName(),
                _buildDogSex(),
                _buildDogBreed(),
                _buildDogAge(),
                _buildDogWeight(),
                _buildCreateAccount(),
                _buildOtp(),
                _buildCompletion(),
              ],
            ),
            if (_currentIndex > 0 && _currentIndex < 8)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(7, (index) {"""

content = content.replace(old_pageview, new_pageview)

# 5. Fix _next length checks
content = content.replace("if (_currentIndex < 8) {", "if (_currentIndex < 9) {")

# 6. Center the content in _buildStepContainer
old_expanded = """            const SizedBox(height: FurFeelTokens.space6),
            Expanded(child: child),
            if (_error != null) ...["""

new_expanded = """            const SizedBox(height: FurFeelTokens.space6),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: child,
                ),
              ),
            ),
            if (_error != null) ...["""

content = content.replace(old_expanded, new_expanded)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
