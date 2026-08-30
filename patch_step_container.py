import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

pattern = re.compile(r'  Widget _buildStepContainer\(\{.*?(?=  @override\n  Widget build)', re.DOTALL)

new_step_container = """  Widget _buildStepContainer({
    required String title,
    String? subtitle,
    required Widget child,
    required VoidCallback onContinue,
    bool canContinue = true,
    bool showBack = true,
  }) {
    final textTheme = Theme.of(context).textTheme;
    
    // Calculate progress based on current index
    double progress = 0.0;
    switch (_currentIndex) {
      case 0: progress = 0.0; break;
      case 1: progress = 0.60; break;
      case 2: progress = 0.70; break;
      case 3: progress = 0.75; break;
      case 4: progress = 0.80; break;
      case 5: progress = 0.85; break;
      case 6: progress = 0.90; break;
      case 7: progress = 0.95; break;
      case 8: progress = 0.98; break;
      case 9: progress = 1.00; break;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showBack)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _busy ? null : _back,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              )
            else
              const SizedBox(height: 48),
            
            const SizedBox(height: FurFeelTokens.space2),
            
            // 1. Large question/title
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
            ],
            
            // 4. Interactive input/selector
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: child,
                ),
              ),
            ),
            
            // Inline error if any
            if (_error != null) ...[
              InlineFormError(message: _error!),
              const SizedBox(height: FurFeelTokens.space4),
            ],
            
            // 5. Continue button
            ElevatedButton(
              onPressed: canContinue && !_busy ? onContinue : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: context.ff.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd)),
                elevation: 0,
              ),
              child: _busy
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, duration: 400.ms),
            const SizedBox(height: FurFeelTokens.space3),
          ],
        ),
      ),
    );
  }

"""

content = pattern.sub(new_step_container, content)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
