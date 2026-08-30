import re

with open('apps/mobile/lib/screens/auth/welcome_page.dart', 'r') as f:
    content = f.read()

start_str = "  @override\n  Widget build(BuildContext context) {"
end_str = "}\n"

start_idx = content.find(start_str)
end_idx = content.rfind(end_str)

if start_idx != -1 and end_idx != -1:
    new_build_method = """  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reduce = context.reduceMotion;

    Widget staggered(Widget child, int index) {
      if (reduce) return child;
      return child
          .animate(delay: Duration(milliseconds: 100 * index))
          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          .slideY(begin: 0.05, end: 0, duration: 400.ms, curve: Curves.easeOut);
    }

    return Scaffold(
      backgroundColor: context.ff.surface,
      body: AuthPatternBackground(
        color: context.ff.hairline,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: FurFeelTokens.space5),
            child: Column(
              children: [
                const Spacer(flex: 3),
                staggered(
                  Center(
                    child: Image.asset(
                      'assets/photos/logo_title.png',
                      height: 200,
                    ),
                  ),
                  0,
                ),
                const SizedBox(height: FurFeelTokens.space5),
                staggered(
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: FurFeelTokens.space3),
                    child: Text(
                      'Know how your dog is feeling, at home or\\nwith your clinic, in real time.',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        color: context.ff.inkMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  1,
                ),
                const Spacer(flex: 3),
                staggered(
                  ElevatedButton(
                    onPressed: _googleBusy ? null : () => _openSignUp(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.ff.brand,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(FurFeelTokens.touchTargetMin),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
                      ),
                    ),
                    child: const Text(
                      'Create account',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  2,
                ),
                const SizedBox(height: FurFeelTokens.space3),
                staggered(
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.ff.surfaceAlt,
                      foregroundColor: context.ff.ink,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(FurFeelTokens.touchTargetMin),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
                      ),
                    ),
                    onPressed: _googleBusy ? null : () => _openLogin(context),
                    child: const Text(
                      'I already have an account',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  3,
                ),
                const SizedBox(height: FurFeelTokens.space4),
                staggered(
                  const OrDivider(),
                  4,
                ),
                const SizedBox(height: FurFeelTokens.space4),
                staggered(
                  GoogleSignInButton(
                    busy: _googleBusy,
                    onPressed: _signInWithGoogle,
                  ),
                  5,
                ),
                const Spacer(flex: 2),
                staggered(
                  Padding(
                    padding: const EdgeInsets.only(bottom: FurFeelTokens.space4),
                    child: Text(
                      'Decision support for you and your care team, never a\\ndiagnosis.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: context.ff.inkMuted,
                        height: 1.3,
                      ),
                    ),
                  ),
                  6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
"""
    new_content = content[:start_idx] + new_build_method + "}\n"
    with open('apps/mobile/lib/screens/auth/welcome_page.dart', 'w') as f:
        f.write(new_content)
    print("Done")
else:
    print("Could not find bounds")
