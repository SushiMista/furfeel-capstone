import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

old_auth = """        redirectTo: kIsWeb ? Uri.base.origin : 'io.furfeel.app://login-callback',
        authScreenLaunchMode:
            kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        queryParams: {'prompt': 'select_account'},"""

new_auth = """        redirectTo: kIsWeb ? Uri.base.origin : 'io.furfeel.app://login-callback',
        authScreenLaunchMode: LaunchMode.platformDefault,
        queryParams: {'prompt': 'select_account'},"""

content = content.replace(old_auth, new_auth)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
