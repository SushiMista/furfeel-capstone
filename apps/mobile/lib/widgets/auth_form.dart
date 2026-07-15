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
        color: FurFeelTokens.statusHighBg,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: FurFeelTokens.statusHighFg),
          const SizedBox(width: FurFeelTokens.space2),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: FurFeelTokens.statusHighFg),
            ),
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
            color: FurFeelTokens.inkMuted,
          ),
        ),
        const SizedBox(width: FurFeelTokens.space2),
        Text(label),
      ],
    );
  }
}
