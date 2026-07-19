import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';

/// ADDED: first-launch intro (docs/04 Onboarding: "a real first-run flow").
/// Three swipeable slides that say what FurFeel does in the owner's language,
/// then hand off to the welcome screen. Shown once — the caller persists the
/// seen flag and swaps this out via [onDone].
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onDone});

  /// Called when the user finishes or skips the intro.
  final VoidCallback onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _Slide {
  const _Slide({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    icon: Icons.monitor_heart_outlined,
    title: 'Feel what they feel',
    body: 'The FurFeel harness streams your dog\'s heart rate, breathing, '
        'temperature, and movement, live to your phone.',
  ),
  _Slide(
    icon: Icons.spa_outlined,
    title: 'Stress, made simple',
    body: 'Readings become one clear stress level, with a gentle nudge '
        'when something needs your attention.',
  ),
  _Slide(
    icon: Icons.volunteer_activism_outlined,
    title: 'Care as a team',
    body: 'Your vet can see the same picture you do. FurFeel supports your '
        'decisions together. It never diagnoses.',
  ),
];

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _slides.length - 1;

  void _next(BuildContext context) {
    if (_isLast) {
      widget.onDone();
      return;
    }
    if (context.reduceMotion) {
      _controller.jumpToPage(_index + 1);
    } else {
      _controller.nextPage(
        duration: FurFeelTokens.motionSlow,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip stays mounted (just hidden on the last slide) so the
            // header height never jumps mid-flow.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FurFeelTokens.space3,
                  vertical: FurFeelTokens.space2,
                ),
                child: AnimatedOpacity(
                  opacity: _isLast ? 0 : 1,
                  duration: FurFeelTokens.motionFast,
                  child: IgnorePointer(
                    ignoring: _isLast,
                    child: TextButton(
                      onPressed: widget.onDone,
                      child: const Text('Skip'),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(FurFeelTokens.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++) ...[
                        if (i > 0) const SizedBox(width: FurFeelTokens.space2),
                        AnimatedContainer(
                          duration: FurFeelTokens.motionFast,
                          curve: Curves.easeOut,
                          width: i == _index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? context.ff.brand
                                : context.ff.hairline,
                            borderRadius:
                                BorderRadius.circular(FurFeelTokens.radiusPill),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: FurFeelTokens.space5),
                  ElevatedButton(
                    onPressed: () => _next(context),
                    child: Text(_isLast ? 'Get started' : 'Next'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: FurFeelTokens.space4),
              child: Text(
                'Decision support for you and your care team, never a diagnosis.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: context.ff.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FurFeelTokens.space6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: context.ff.brandSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 64, color: context.ff.brand),
          ).entrance(context),
          const SizedBox(height: FurFeelTokens.space6),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              color: context.ff.brandInk,
              fontWeight: FontWeight.w800,
            ),
          ).entrance(context, index: 1),
          const SizedBox(height: FurFeelTokens.space3),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: context.ff.inkMuted,
              height: 1.5,
            ),
          ).entrance(context, index: 2),
        ],
      ),
    );
  }
}
