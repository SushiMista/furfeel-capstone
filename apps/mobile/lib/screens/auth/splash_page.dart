import 'dart:async';

import 'package:flutter/material.dart';

import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/widgets/furfeel_logo.dart';

/// Startup screen: the plain wordmark from the top bar and, when a real wait
/// follows, a small spinner. It appears only while the app starts; screens
/// after that load with skeletons shaped like their content.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key}) : _showLoader = false;

  /// Adds a small spinner (after a short delay). Use only where the wait is a
  /// real network call that can hang. On a fast cold start a loader adds noise.
  const SplashPage.loading({super.key}) : _showLoader = true;

  final bool _showLoader;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: context.ff.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FurFeelLogo(size: 22),
            const SizedBox(height: FurFeelTokens.space4),
            // Reserve the loader's height either way so the wordmark never
            // shifts up when the spinner appears.
            SizedBox(
              height: 18,
              width: 18,
              child: _showLoader ? _DelayedLoader(reduce: reduce) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A spinner that is not built at all until the wait has gone on a
/// beat — a loader that flashes for 200ms reads as a glitch, so a load that
/// resolves quickly should never show one.
///
/// The delay applies to everyone, reduced motion included: it exists to avoid
/// a flash, which is not a motion preference. Reduced motion only skips the
/// fade, so the spinner appears instantly instead of easing in.
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

    final spinner = CircularProgressIndicator(
      strokeWidth: 2,
      color: context.ff.brand,
    );
    if (widget.reduce) return spinner;
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 240),
      child: spinner,
    );
  }
}
