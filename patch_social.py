import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# Add Google button to _buildCreateAccount
old_create = """            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );"""
new_create = """            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            const OrDivider(),
            const SizedBox(height: 16),
            GoogleSignInButton(
              busy: _busy,
              onPressed: _signInWithGoogle,
            ),
          ],
        ),
      ),
    );"""
content = content.replace(old_create, new_create)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
