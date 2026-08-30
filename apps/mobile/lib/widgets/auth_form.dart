import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/furfeel_tokens.dart';

/// Inline form error: icon + message on the status-high tokens, sized to the
/// content. Errors live in the form, not in a toast (they aren't transient).
class InlineFormError extends StatelessWidget {
  const InlineFormError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FurFeelTokens.space3),
      decoration: BoxDecoration(
        color: context.ff.statusHighBg,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: context.ff.statusHighFg),
          const SizedBox(width: FurFeelTokens.space2),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.ff.statusHighFg),
            ),
          ),
        ],
      ),
    );
  }
}

/// "or" divider between the primary action and alternative sign-in methods.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: context.ff.hairline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: FurFeelTokens.space3),
          child: Text(
            'or',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: context.ff.inkMuted),
          ),
        ),
        Expanded(child: Divider(color: context.ff.hairline)),
      ],
    );
  }
}

/// Clean vector Google "G" icon.
class GoogleLogoIcon extends StatelessWidget {
  const GoogleLogoIcon({super.key, this.size = 20});

  final double size;

  static const String _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
  <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svg,
      width: size,
      height: size,
    );
  }
}

/// "Continue with Google" secondary action. The caller owns the OAuth call;
/// this stays a dumb button so it is testable without Supabase.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.borderColor,
    this.borderWidth = 1.5,
  });

  final VoidCallback? onPressed;
  final bool busy;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: context.ff.surfaceAlt,
        foregroundColor: context.ff.ink,
        minimumSize: const Size.fromHeight(FurFeelTokens.touchTargetMin),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
        ),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const BusyButtonLabel(label: 'Opening Google')
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                GoogleLogoIcon(size: 20),
                SizedBox(width: FurFeelTokens.space3),
                Text(
                  'Continue with Google',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
    );
  }
}

/// Busy state for a primary button: small spinner + label. Colors inherit the
/// button's disabled foreground so contrast stays theme-managed.
class BusyButtonLabel extends StatelessWidget {
  const BusyButtonLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.ff.inkMuted,
          ),
        ),
        const SizedBox(width: FurFeelTokens.space2),
        Text(label),
      ],
    );
  }
}
