import 'package:flutter/material.dart';

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

/// "Continue with Google" secondary action. The caller owns the OAuth call;
/// this stays a dumb button so it is testable without Supabase.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed, this.busy = false});

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(FurFeelTokens.touchTargetMin),
        shape: const StadiumBorder(),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const BusyButtonLabel(label: 'Opening Google')
          : const Text('Continue with Google'),
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
