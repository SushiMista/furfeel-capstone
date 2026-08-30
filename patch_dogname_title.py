import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# Replace the title in _buildDogName
old_title = '      title: "What\'s your dog\'s name? 🐶",'
new_title = '      title: "Hi ${_userName.split(\' \').first},\\nwhat\'s your dog\'s name? 🐶",'

content = content.replace(old_title, new_title)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
