// ============================================================
// As Above, So Below. As Within, So Without.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

// lib/widgets/app_primitives.dart
//
// Phase 4 shared presentation primitives.
//
// Scope rule: a primitive exists here only where the same visual/behavioral
// pattern was already repeated across multiple screens. Every primitive
// consumes semantic theme tokens (ColorScheme + AppSpacing/AppRadii/AppType)
// so it is correct in both light and dark without per-screen overrides.
// Wrappers for widgets Material already styles well are deliberately absent.

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Standard raised surface: card padding, radius, hairline border, optional tap.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final double elevation;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin = EdgeInsets.zero,
    this.color,
    this.borderColor,
    this.radius = AppRadii.lg,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = BorderRadius.circular(radius);
    final content = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainer,
        borderRadius: shape,
        border: Border.all(
          color: borderColor ?? scheme.outlineVariant,
        ),
      ),
      child: child,
    );
    if (elevation > 0) {
      return Card(
        margin: margin,
        elevation: elevation,
        color: color ?? scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: shape,
          side: BorderSide(color: borderColor ?? scheme.outlineVariant),
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      );
    }
    if (onTap == null) return content;
    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        // InkWell is operable but Flutter does not give it the `button`
        // semantic role, so a screen reader announces a card as a generic
        // clickable rather than a control. Centralising it here fixes every
        // AppCard at once.
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: shape,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Failure state with an optional retry. Recovery-oriented copy: name what
/// failed, never blame the user, and always offer a way forward when the
/// failure is retryable.
class AppErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  const AppErrorState({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message case final message?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Network-dependent content that cannot be reached. Deliberately distinct from
/// AppErrorState: locally cached data is still shown around it, so the copy
/// must not imply the user's own data is gone.
class AppOfflineState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const AppOfflineState({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message ??
                  'Offline — showing what is saved on this device. Some things need a connection.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

/// Screen/section title. Replaces the ad-hoc bold text + SizedBox ladder.
/// Title metrics intentionally match the app's dominant existing convention
/// (18 / w700) so centralizing it does not restyle already-shipped screens.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: AppType.title,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle case final subtitle?) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Centered spinner for a screen or section that has no content yet.
class AppLoadingState extends StatelessWidget {
  final String? message;

  const AppLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Nothing here yet" state. Never implies the user failed.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Tappable row: leading icon, title, optional subtitle, trailing affordance.
class AppActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? trailing;
  final bool enabled;

  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.trailing,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = enabled && onTap != null;
    final fg = active ? scheme.onSurface : scheme.disabled;

    return AppCard(
      onTap: active ? onTap : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: (iconColor ?? scheme.primary).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(
              icon,
              size: 20,
              color: active ? (iconColor ?? scheme.primary) : scheme.disabled,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: active ? scheme.onSurfaceVariant : scheme.disabled,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (trailing != null)
            trailing!
          else
            Icon(
              Icons.chevron_right,
              size: 20,
              color: active ? scheme.outline : scheme.disabled,
            ),
        ],
      ),
    );
  }
}
