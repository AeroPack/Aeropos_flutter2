import 'package:flutter/material.dart';

class AppColors {
  // Master Palette
  static const Color primary = Color(0xFFFFD700); // Yellow/Gold
  static const Color secondary = Color(0xFFFFE44D); // Soft Yellow
  static const Color accent = Color(0xFFCA8A04); // Appetizing Gold/Amber
  static const Color background = Color(0xFFFFFBEB); // Very Light Yellow
  static const Color surface = Colors.white;
  static const Color text = Color(0xFF450A0A); // Dark Deep Red

  // States
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Grey Scale
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxi = 48.0;
}

class AppShadows {
  static final List<BoxShadow> md = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> lg = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 15,
      offset: const Offset(0, 10),
    ),
  ];
}
