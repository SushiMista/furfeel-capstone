import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';
import '../widgets/furfeel_logo.dart';

/// Brand splash: shown on cold start while the app decides where to route, and
/// again while a signed-in user's settings load.
///
/// This screen's job is to *continue* the Android 12+ system splash, not to
/// replace it. The OS draws the launcher icon on `@color/splash_background`
/// before Flutter exists (see android/.../values-v31/styles.xml); this page
/// then comes up on the same background with the same mark, so the handoff
/// reads as one moment instead of two screens. Hence `FurFeelLogo.auth` — the
/// same gradient paw + wordmark the auth screens use — rather than a bare
/// icon that would visibly jump on the swap.
///
/// Static under reduced motion (`FurFeelLogo` honours it internally).
class SplashPage extends StatelessWidget {
  const SplashPage({super.key}) : _showLoader = false;

  /// Adds an indeterminate bar (after a short delay). Use only where the wait
  /// is a real network call that can hang — the signed-in settings load. On a
  /// fast cold start a loader adds noise and makes launch *feel* slower.
  const SplashPage.loading({super.key}) : _showLoader = true;

  final bool _showLoader;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      // Matches the native splash colour exactly, so the swap is invisible.
      backgroundColor: context.ff.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FurFeelLogo.auth(showTagline: true),
            SizedBox(height: FurFeelTokens.space6),
            // Reserve the loader's height either way so the wordmark never
            // shifts up when the bar appears.
            SizedBox(
              height: 2,
              width: 120,
              child: _showLoader ? _DelayedLoader(reduce: reduce) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// An indeterminate bar that is not built at all until the wait has gone on a
/// beat — a loader that flashes for 200ms reads as a glitch, so a load that
/// resolves quickly should never show one.
///
/// The delay applies to everyone, reduced motion included: it exists to avoid
/// a flash, which is not a motion preference. Reduced motion only skips the
/// fade, so the bar appears instantly instead of easing in.
class _DelayedLoader extends StatefulWidget {
  const _DelayedLoader({required this.reduce});

  final bool reduce;

  @override
  State<_DelayedLoader> createState() => _DelayedLoaderState();
}

class _DelayedLoaderState extends State<_DelayedLoader> {
  static const _delay = Duration(milliseconds: 600);

  Timer? _timer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_delay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
      child: LinearProgressIndicator(
        minHeight: 2,
        color: context.ff.brand,
        backgroundColor: context.ff.brandSoft,
      ),
    );
    if (widget.reduce) return bar;
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 240),
      child: bar,
    );
  }
}
