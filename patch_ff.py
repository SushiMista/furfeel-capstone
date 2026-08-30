with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

content = content.replace("Theme.of(context).extension<FurFeelPalette>()!", "context.ff")

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
