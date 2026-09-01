// lib/config/app_colors.dart
//
// Every colour the app paints, named for what it means rather than what it
// looks like. A screen that reads `AppColors.border` instead of
// `Colors.grey[300]` can be restyled from here alone, and two screens asking
// for the same meaning are guaranteed to agree.
import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // ─── Brand ───────────────────────────────────────────────────────
  /// The dark green on primary buttons.
  static const Color brand = Color(0xFF1A7A3D);

  /// Text and icons sitting on top of [brand].
  static const Color onBrand = Colors.white;

  // ─── Surfaces ────────────────────────────────────────────────────
  /// The page behind the cards.
  static final Color pageBg = Colors.grey[50]!;

  /// Cards, dialogs, the app bar, input fills.
  static const Color surface = Colors.white;

  /// Recessed areas inside a card — read-only fields, table headers.
  static final Color surfaceMuted = Colors.grey[100]!;

  /// The scrim behind a modal.
  static const Color scrim = Colors.black54;

  /// Card shadow. Already carries its own opacity — do not re-fade it.
  static final Color shadow = Colors.black.withValues(alpha: 0.04);

  // ─── Lines ───────────────────────────────────────────────────────
  /// Hairline between rows, and the outline of a raised card.
  static final Color border = Colors.grey[200]!;

  /// The heavier outline used by inputs and framed containers.
  static final Color borderStrong = Colors.grey[300]!;

  // ─── Text ────────────────────────────────────────────────────────
  /// Body copy and values.
  static final Color textPrimary = Colors.grey[700]!;

  /// Field labels and supporting lines under a value.
  static final Color textSecondary = Colors.grey[600]!;

  /// Timestamps and other low-priority detail.
  static final Color textMuted = Colors.grey[500]!;

  /// Placeholder text in an empty field.
  static final Color textFaint = Colors.grey[400]!;

  /// Hints and disabled icons.
  static const Color textDisabled = Colors.grey;

  // ─── Status ──────────────────────────────────────────────────────
  // Each status has a solid colour for icons and chips, plus the tint and
  // outline used when it fills a whole banner.
  static const Color success = Colors.green;
  static final Color successBg = Colors.green[50]!;
  static final Color successBorder = Colors.green[200]!;
  static final Color successText = Colors.green[800]!;

  static const Color info = Colors.blue;
  static final Color infoBg = Colors.blue[50]!;
  static final Color infoBorder = Colors.blue[200]!;
  static final Color infoText = Colors.blue[700]!;

  static const Color warning = Colors.orange;
  static final Color warningBg = Colors.orange[50]!;
  static final Color warningBorder = Colors.orange[200]!;
  static final Color warningText = Colors.orange[800]!;

  static const Color danger = Colors.red;
  static final Color dangerBg = Colors.red[50]!;

  // ─── Tag status ──────────────────────────────────────────────────
  /// The chip colour for a tag's status, for every status the API returns.
  ///
  /// One place rather than a switch per sheet: the two that existed had drifted
  /// apart, so the same tag could be drawn in different colours depending on
  /// which sheet you were looking at.
  static Color tagStatus(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return success;
      case 'printed':
        return info;
      case 'dispatched':
        return warning;
      case 'installed':
        return accent;
      case 'lost':
      case 'lost printed':
      case 'damaged':
        return danger;
      case 'jam paper':
        // Amber, not red: the code is not lost, it just has to go through the
        // printer again.
        return Colors.deepOrange;
      case 'do not use':
        // Grey rather than red: it is not a loss or a fault, the code is simply
        // withdrawn and will never be printed.
        return Colors.blueGrey;
      default:
        return textDisabled;
    }
  }

  /// Used only by the "installed" status and the matching stat card.
  static const Color accent = Colors.purple;
}
