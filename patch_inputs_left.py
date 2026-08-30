import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# Replace textAlign: TextAlign.center in text fields
content = content.replace("textAlign: TextAlign.center,", "")
content = content.replace("alignment: WrapAlignment.center,", "")

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
