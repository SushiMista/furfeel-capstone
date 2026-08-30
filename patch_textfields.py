import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# Make the large text fields lighter and slightly more aesthetic
content = content.replace(
    "style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600)",
    "style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w400)"
)
content = content.replace(
    "style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)",
    "style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400)"
)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
