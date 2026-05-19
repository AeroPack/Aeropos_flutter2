import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PosLayoutType {
  compact,
  restaurant,
  retail,
  touch,
  dualScreen;

  String get displayName {
    switch (this) {
      case PosLayoutType.compact:
        return 'Compact';
      case PosLayoutType.restaurant:
        return 'Restaurant';
      case PosLayoutType.retail:
        return 'Retail';
      case PosLayoutType.touch:
        return 'Touch';
      case PosLayoutType.dualScreen:
        return 'Dual Screen';
    }
  }

  IconData get icon {
    switch (this) {
      case PosLayoutType.compact:
        return Icons.grid_view_rounded;
      case PosLayoutType.restaurant:
        return Icons.restaurant_menu;
      case PosLayoutType.retail:
        return Icons.storefront;
      case PosLayoutType.touch:
        return Icons.touch_app;
      case PosLayoutType.dualScreen:
        return Icons.devices;
    }
  }

  String get description {
    switch (this) {
      case PosLayoutType.compact:
        return 'Dense grid, maximum info';
      case PosLayoutType.restaurant:
        return 'Order types, large images';
      case PosLayoutType.retail:
        return 'Barcode input, receipt cart';
      case PosLayoutType.touch:
        return 'Large buttons, number pad';
      case PosLayoutType.dualScreen:
        return 'Cashier + customer view';
    }
  }
}

const _prefKey = 'pos_layout_type';

class PosLayoutNotifier extends StateNotifier<PosLayoutType> {
  PosLayoutNotifier() : super(PosLayoutType.compact) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      try {
        final loadedLayout = PosLayoutType.values.firstWhere(
          (e) => e.name == saved,
        );
        state = loadedLayout;
      } catch (_) {
        // Keep default on invalid value
      }
    }
  }

  Future<void> setLayout(PosLayoutType layout) async {
    state = layout;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, layout.name);
  }
}

final posLayoutProvider =
    StateNotifierProvider<PosLayoutNotifier, PosLayoutType>(
      (ref) => PosLayoutNotifier(),
    );
