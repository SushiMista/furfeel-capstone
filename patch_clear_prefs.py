import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

old_handle = """    try {
      await _saveDogProfile();
      _dogSaved = true;
      if (!mounted) return;"""

new_handle = """    try {
      await _saveDogProfile();
      _dogSaved = true;
      
      // Clean up the temporary backup now that it's safely in the database
      final prefs = await SharedPreferences.getInstance();
      for (final key in ['backup_dog_name', 'backup_dog_sex', 'backup_dog_breed', 'backup_dog_age_index', 'backup_dog_is_kg', 'backup_dog_weight']) {
        prefs.remove(key);
      }
      
      if (!mounted) return;"""
content = content.replace(old_handle, new_handle)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
