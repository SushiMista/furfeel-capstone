import 'package:flutter/material.dart';

import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/motion.dart';
import 'package:furfeel_mobile/widgets/brand_photo_frame.dart';

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
  const _Slide({
    required this.icon,
    required this.photo,
    required this.title,
    required this.body,
  });

  /// Fallback mark shown in the arch until [photo] is sourced.
  final IconData icon;

  /// Curated stock photo for this slide (assets/photos/…).
  final String photo;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    icon: Icons.monitor_heart_outlined,
    photo: 'assets/photos/onboarding_monitoring.jpg',
    title: 'Feel what they feel',
    body:
        'The FurFeel harness streams your dog\'s heart rate, breathing, '
        'temperature, and movement, live to your phone.',
  ),
  _Slide(
    icon: Icons.spa_outlined,
    photo: 'assets/photos/onboarding_stress.jpg',
    title: 'Stress, made simple',
    body:
        'Readings become one clear stress level, with a gentle nudge '
        'when something needs your attention.',
  ),
  _Slide(
    icon: Icons.volunteer_activism_outlined,
    photo: 'assets/photos/onboarding_care.jpg',
    title: 'Care as a team',
    body:
        'Your vet can see the same picture you do. FurFeel supports your '
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
                itemBuilder: (context, i) => _SlideView(
                  slide: _slides[i],
                  slideIndex: i,
                  totalSlides: _slides.length,
                  isLast: i == _slides.length - 1,
                  onNext: () => _next(context),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: FurFeelTokens.space4, top: FurFeelTokens.space2),
              child: Text(
                'Decision support for you and your care team, never a diagnosis.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: context.ff.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.slideIndex,
    required this.totalSlides,
    required this.isLast,
    required this.onNext,
  });

  final _Slide slide;
  final int slideIndex;
  final int totalSlides;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Centred when there's room; scrolls when there isn't (a taller arch frame,
    // a small viewport, or a large text scale) instead of overflowing.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FurFeelTokens.space6,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BrandPhotoFrame(
                  asset: slide.photo,
                  width: 190,
                  fallbackIcon: slide.icon,
                  semanticLabel: slide.title,
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
                const SizedBox(height: FurFeelTokens.space6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < totalSlides; i++) ...[
                      if (i > 0) const SizedBox(width: FurFeelTokens.space2),
                      Container(
                        width: i == slideIndex ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == slideIndex
                              ? context.ff.brand
                              : context.ff.hairline,
                          borderRadius: BorderRadius.circular(
                            FurFeelTokens.radiusPill,
                          ),
                        ),
                      ),
                    ],
                  ],
                ).entrance(context, index: 3),
                const SizedBox(height: FurFeelTokens.space5),
                ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: context.ff.brand, // Explicitly use the blue brand color
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, FurFeelTokens.touchTargetMin),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
                    ),
                  ),
                  child: Text(isLast ? 'Get started' : 'Next'),
                ).entrance(context, index: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
