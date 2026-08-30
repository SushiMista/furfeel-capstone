import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# Replace the catch block in _createAccount
old_catch = """    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _busy = false;
      });
    }"""
new_catch = """    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('user already registered')) {
        setState(() {
          _error = 'Account already exists. Please log in instead.';
          _busy = false;
        });
        return;
      }
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _busy = false;
      });
    }"""
content = content.replace(old_catch, new_catch)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
