import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

old_block = """            // 1. Large question/title
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: context.ff.ink,
              ),
            ).animate().fadeIn().slideY(begin: 0.1, duration: 400.ms),
            
            // 2. Optional short supporting text
            if (subtitle != null) ...[
              const SizedBox(height: FurFeelTokens.space3),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: context.ff.inkMuted,
                  height: 1.3,
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, duration: 400.ms),
            ],
            
            // 3. Minimal progress bar (Only show if past welcome)
            if (_currentIndex > 0) ...[
              const SizedBox(height: FurFeelTokens.space5),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            width: constraints.maxWidth,
                            height: 3,
                            decoration: BoxDecoration(
                              color: context.ff.hairline,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          AnimatedContainer(
                            duration: 500.ms,
                            curve: Curves.easeOutCubic,
                            height: 3,
                            width: constraints.maxWidth * progress,
                            decoration: BoxDecoration(
                              color: context.ff.brand,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms),
            ],"""

new_block = """            // 1. Large question/title
            Text(
              title,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.ff.brandInk,
              ),
            ).animate().fadeIn().slideY(begin: 0.1, duration: 400.ms),
            
            // 2. Optional short supporting text
            if (subtitle != null) ...[
              const SizedBox(height: FurFeelTokens.space2),
              Text(
                subtitle,
                style: textTheme.titleMedium?.copyWith(
                  color: context.ff.inkMuted,
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, duration: 400.ms),
            ],
            
            // 3. Progress bar (Only show if past welcome)
            if (_currentIndex > 0) ...[
              const SizedBox(height: FurFeelTokens.space5),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        width: constraints.maxWidth,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.ff.hairline,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      AnimatedContainer(
                        duration: 500.ms,
                        curve: Curves.easeOutCubic,
                        height: 8,
                        width: constraints.maxWidth * progress,
                        decoration: BoxDecoration(
                          color: context.ff.brand,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  );
                },
              ).animate().fadeIn(delay: 100.ms),
            ],"""

content = content.replace(old_block, new_block)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
