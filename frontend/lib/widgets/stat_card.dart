// lib/widgets/stat_card.dart
import 'package:flutter/material.dart';
import 'package:frontend/config/app_colors.dart';

/// One tile in a dashboard's stat row: a label, a large figure, and a line of
/// supporting text.
///
/// Shared by every dashboard. The three screens each carried their own copy and
/// had drifted to different type sizes, so the same figure looked different
/// depending on which screen you were on.
class StatCard extends StatelessWidget {
  /// The heading, e.g. "AVAILABLE IN POOL". Rendered upper-case by the caller.
  final String label;

  /// The figure itself, already formatted — this widget does no number
  /// formatting, so callers can show an em dash while the figure is loading.
  final String value;

  /// The line under the figure saying what it counts.
  final String subtitle;

  /// Optional leading icon. Dispatcher's tiles run without one.
  final IconData? icon;

  /// Tints the icon and its rounded backing. Ignored when [icon] is null.
  final Color? iconColor;

  /// Colours the figure. Defaults to the standard body colour.
  final Color? valueColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.subtitle,
    this.icon,
    this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final tint = iconColor ?? AppColors.info;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The label sits opposite the icon, so it is pushed right only
              // when there is an icon to sit opposite. On an icon-less tile the
              // spacer would strand it against the far edge on its own.
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: tint),
                ),
                const Spacer(),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
