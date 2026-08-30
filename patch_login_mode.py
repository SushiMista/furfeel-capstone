import re

with open('apps/mobile/lib/main.dart', 'r') as f:
    content = f.read()

old_auth = """            authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,"""
new_auth = """            authScreenLaunchMode: LaunchMode.platformDefault,"""

content = content.replace(old_auth, new_auth)

with open('apps/mobile/lib/main.dart', 'w') as f:
    f.write(content)
