import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/furfeel_tokens.dart';

/// ADDED: motion helpers (docs/19 §5a). Every animation in the app routes
/// through these so reduced-motion is honored in exactly one place.
extension ReduceMotionX on BuildContext {
  /// True when the OS asks for reduced motion — fall back to instant.
  bool get reduceMotion => MediaQuery.of(this).disableAnimations;
}

extension FurFeelEntrance on Widget {
  /// Standard card entrance: gentle fade + slide-up with a per-index stagger
  /// (docs/19 §5a "Home cards stagger fade + slide-up"). No-op under
  /// reduced motion.
  Widget entrance(BuildContext context, {int index = 0}) {
    if (context.reduceMotion) return this;
    return animate(delay: Duration(milliseconds: 50 * index))
        .fadeIn(duration: FurFeelTokens.motionSlow, curve: Curves.easeOut)
        .slideY(
          begin: 0.06,
          end: 0,
          duration: FurFeelTokens.motionSlow,
          curve: Curves.easeOut,
        );
  }
}

/// Wraps a tappable in a press-scale (docs/19 §5a micro-interactions).
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.98,
    this.enableHapticFeedback = false,
    this.curve = Curves.easeOut,
  });

  final Widget child;
  final double scale;
  final bool enableHapticFeedback;
  final Curve curve;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return widget.child;
    return Listener(
      onPointerDown: (_) {
        if (widget.enableHapticFeedback) {
          HapticFeedback.lightImpact();
        }
        setState(() => _pressed = true);
      },
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: FurFeelTokens.motionFast,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}
