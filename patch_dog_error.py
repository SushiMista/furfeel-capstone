import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

old_save = """    } catch (e) {
      debugPrint('Failed to save dog profile: $e');
    }"""
new_save = """    } catch (e) {
      debugPrint('Failed to save dog profile: $e');
      if (mounted) setState(() => _error = 'Failed to save dog: $e');
      rethrow;
    }"""
content = content.replace(old_save, new_save)

old_handle = """  Future<void> _handleSuccessfulAuth() async {
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
new_handle = """  Future<void> _handleSuccessfulAuth() async {
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
      await _saveDogProfile();
      _dogSaved = true;
      if (!mounted) return;
      _pageController.animateToPage(9, duration: 400.ms, curve: Curves.easeOutCubic);
      setState(() {
        _currentIndex = 9;
        _busy = false;
      });
    } catch (e) {
      setState(() { _busy = false; _error = 'Could not save dog: $e'; });
    }
  }"""
content = content.replace(old_handle, new_handle)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
