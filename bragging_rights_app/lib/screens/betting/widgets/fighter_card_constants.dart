import 'package:flutter/material.dart';

/// Constants for standardized fighter card dimensions and layout
class FighterCardDimensions {
  // Container dimensions
  static const double cardWidth = 140.0;
  static const double cardHeight = 180.0;
  static const double cardPadding = 12.0;

  // Avatar dimensions
  static const double avatarSize = 70.0;
  static const double avatarBorderWidth = 2.0;

  // Spacing
  static const double avatarToNameSpacing = 8.0;
  static const double nameToRecordSpacing = 4.0;

  // Text zones
  static const double nameZoneHeight = 32.0;
  static const double recordZoneHeight = 16.0;

  // Font sizes
  static const double nameFontSize = 13.0;
  static const double recordFontSize = 11.0;
  static const double methodBadgeFontSize = 10.0;

  // Method badge
  static const double methodBadgeTop = 5.0;
  static const double methodBadgeRight = 5.0;
  static const double methodBadgeHeight = 24.0;
  static const EdgeInsets methodBadgePadding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);

  // Text constraints
  static const int nameMaxLines = 2;
  static const int nameMaxLength = 20;

  // Border radius
  static const double borderRadius = 8.0;
}

/// Utility class for text processing in fighter cards
class FighterCardTextUtils {
  /// Truncates fighter name intelligently
  static String truncateFighterName(String fullName) {
    if (fullName.length <= FighterCardDimensions.nameMaxLength) {
      return fullName;
    }

    // Split into parts
    final parts = fullName.split(' ');

    if (parts.length == 1) {
      // Single long name, truncate with ellipsis
      return '${fullName.substring(0, FighterCardDimensions.nameMaxLength - 3)}...';
    }

    if (parts.length == 2) {
      // First name + last initial
      final firstName = parts[0];
      final lastInitial = parts[1].isNotEmpty ? parts[1][0] : '';
      return '$firstName $lastInitial.';
    }

    if (parts.length >= 3) {
      // Complex name - try different strategies
      final firstName = parts[0];
      final lastName = parts.last;

      // Try first + last initial
      final firstPlusInitial = '$firstName ${lastName[0]}.';
      if (firstPlusInitial.length <= FighterCardDimensions.nameMaxLength) {
        return firstPlusInitial;
      }

      // Just use first name if it fits
      if (firstName.length <= FighterCardDimensions.nameMaxLength - 3) {
        return '$firstName...';
      }

      // Truncate first name
      return '${firstName.substring(0, FighterCardDimensions.nameMaxLength - 3)}...';
    }

    return fullName;
  }

  /// Formats fighter record consistently
  static String formatRecord(String? record) {
    if (record == null || record.isEmpty) {
      return '—';
    }

    // Ensure consistent format (XX-X-X)
    final parts = record.split('-');
    if (parts.length >= 2) {
      return record;
    }

    return '—';
  }
}