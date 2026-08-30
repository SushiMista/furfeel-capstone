import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# Replace the progress indicator
old_progress = """            if (_currentIndex > 0 && _currentIndex < 8)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(7, (index) {
                      final isActive = index <= _currentIndex - 1;
                      return AnimatedContainer(
                        duration: 300.ms,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? context.ff.brand : context.ff.hairline,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
              ),"""

new_progress = """            if (_currentIndex > 0)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: FurFeelTokens.space6,
                right: FurFeelTokens.space6,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double progress = 0.0;
                        switch (_currentIndex) {
                          case 0: progress = 0.0; break;
                          case 1: progress = 0.60; break; // Name
                          case 2: progress = 0.70; break; // Dog Name
                          case 3: progress = 0.75; break; // Dog Sex
                          case 4: progress = 0.80; break; // Dog Breed
                          case 5: progress = 0.85; break; // Dog Age
                          case 6: progress = 0.90; break; // Dog Weight
                          case 7: progress = 0.95; break; // Create Account
                          case 8: progress = 0.98; break; // OTP
                          case 9: progress = 1.00; break; // Completion
                        }
                        return Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: context.ff.hairline,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            AnimatedContainer(
                              duration: 500.ms,
                              curve: Curves.easeOutCubic,
                              height: 6,
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
                ),
              ).animate().fadeIn(),"""

content = content.replace(old_progress, new_progress)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
