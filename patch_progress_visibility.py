import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

old_stack = """                      return Stack(
                        children: [
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: context.ff.hairline,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          AnimatedContainer("""

new_stack = """                      return Stack(
                        children: [
                          Container(
                            width: constraints.maxWidth,
                            height: 3,
                            decoration: BoxDecoration(
                              color: context.ff.hairline,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          AnimatedContainer("""

content = content.replace(old_stack, new_stack)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
