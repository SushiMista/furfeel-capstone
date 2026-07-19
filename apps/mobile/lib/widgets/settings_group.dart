import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';

/// iOS-Settings-style inset group: small uppercase header, a rounded surface
/// containing rows separated by hairlines that are inset past the icon tile,
/// and an optional muted footer line. Pure layout -- rows come in as children.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    this.header,
    this.footer,
    this.headerAction,
    required this.children,
  });

  final String? header;
  final String? footer;

  /// Optional small trailing action beside the header (e.g. "Add").
  final Widget? headerAction;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null || headerAction != null)
          Padding(
            padding: const EdgeInsets.only(
              left: FurFeelTokens.space4,
              right: FurFeelTokens.space2,
              bottom: FurFeelTokens.space2,
            ),
            child: Row(
              children: [
                if (header != null)
                  Expanded(child: Text(header!, style: textTheme.labelSmall))
                else
                  const Spacer(),
                ?headerAction,
              ],
            ),
          ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.ff.surface,
            borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
            border: Border.all(color: context.ff.hairline),
          ),
          child: Column(
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    // Inset past the leading tile so hairlines align with text.
                    indent: 60,
                    color: context.ff.hairline,
                  ),
                child,
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(
              left: FurFeelTokens.space4,
              right: FurFeelTokens.space4,
              top: FurFeelTokens.space2,
            ),
            child: Text(footer!, style: textTheme.bodySmall),
          ),
      ],
    );
  }
}

/// One row in a [SettingsGroup]: iOS-style rounded icon tile, title, optional
/// subtitle, optional trailing widget, chevron when tappable.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.icon,
    this.iconColor,
    this.iconBackground,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.destructive = false,
  });

  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackground;

  /// Custom leading widget (e.g. an avatar); wins over [icon].
  final Widget? leading;

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  /// Destructive rows (sign out) render in the status-high tokens.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleColor = destructive ? context.ff.statusHighFg : context.ff.ink;

    Widget? lead = leading;
    if (lead == null && icon != null) {
      lead = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: iconBackground ??
              (destructive ? context.ff.statusHighBg : context.ff.brandSoft),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: iconColor ??
              (destructive ? context.ff.statusHighFg : context.ff.brand),
        ),
      );
    }

    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FurFeelTokens.space4,
          vertical: FurFeelTokens.space3,
        ),
        child: Row(
          children: [
            if (lead != null) ...[
              lead,
              const SizedBox(width: FurFeelTokens.space3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            ?trailing,
            if (onTap != null && showChevron)
              Icon(Icons.chevron_right, size: 20, color: context.ff.inkMuted),
          ],
        ),
      ),
    );

    return onTap != null ? PressScale(child: row) : row;
  }
}
