import re

with open('apps/mobile/lib/screens/auth/welcome_page.dart', 'r') as f:
    content = f.read()

# 1. Update SignUpPage logo
signup_logo = "const Center(child: FurFeelLogo.auth(size: 48, animate: true))"
signup_logo_new = "Center(child: Image.asset('assets/photos/logo_title.png', height: 56))"
content = content.replace(signup_logo, signup_logo_new)

# 2. Update AuthPatternBackground to have color
pattern_bg = "body: AuthPatternBackground("
pattern_bg_new = "body: AuthPatternBackground(\n        color: context.ff.hairline,"
content = content.replace(pattern_bg, pattern_bg_new)

# 3. Update Create account button radius
create_btn = "borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd)"
create_btn_new = "borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm)"
# Only replace the first occurrence in the WelcomePage (or all if we want them unified, but we'll do carefully)
# Actually, the WelcomePage has 2 buttons with radiusMd.
content = content.replace(create_btn, create_btn_new, 2) # first two in WelcomePage

# 4. Update 'I already have an account' styling
already_btn_bg = "backgroundColor: context.ff.brand.withValues(alpha: 0.05)"
already_btn_bg_new = "backgroundColor: context.ff.surfaceAlt"
content = content.replace(already_btn_bg, already_btn_bg_new)

already_btn_fg = "foregroundColor: context.ff.brandInk"
already_btn_fg_new = "foregroundColor: context.ff.ink"
content = content.replace(already_btn_fg, already_btn_fg_new)

# 5. Update footer text color (from hairline to inkMuted)
footer_color = "color: context.ff.hairline"
footer_color_new = "color: context.ff.inkMuted"
content = content.replace(footer_color, footer_color_new)

with open('apps/mobile/lib/screens/auth/welcome_page.dart', 'w') as f:
    f.write(content)
