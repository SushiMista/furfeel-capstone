import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

old_handle = """  Future<void> _handleSuccessfulAuth() async {
    if (_dogSaved) return;
    setState(() => _busy = true);
    
    // If state was lost (OS kill), attempt restore from backup
    if (_dogName.isEmpty) {"""

new_handle = """  bool _isSavingDog = false;

  Future<void> _handleSuccessfulAuth() async {
    if (_dogSaved || _isSavingDog) return;
    _isSavingDog = true; // Lock immediately to prevent race conditions
    setState(() => _busy = true);
    
    // If state was lost (OS kill), attempt restore from backup
    if (_dogName.isEmpty) {"""

content = content.replace(old_handle, new_handle)

old_catch = """    } catch (e) {
      setState(() { _busy = false; _error = 'Could not save dog: $e'; });
    }"""

new_catch = """    } catch (e) {
      _isSavingDog = false; // Unlock so they can retry
      setState(() { _busy = false; _error = 'Could not save dog: $e'; });
    }"""

content = content.replace(old_catch, new_catch)


with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
