import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RefundMethod { wallet, cash }

const _refundMethodKey = 'default_refund_method';

class ReturnSettingsNotifier extends StateNotifier<RefundMethod> {
  ReturnSettingsNotifier() : super(RefundMethod.wallet) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_refundMethodKey);
    if (saved != null) {
      state = saved == 'cash' ? RefundMethod.cash : RefundMethod.wallet;
    }
  }

  Future<void> setRefundMethod(RefundMethod method) async {
    state = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _refundMethodKey,
      method == RefundMethod.cash ? 'cash' : 'wallet',
    );
  }
}

final returnSettingsProvider =
    StateNotifierProvider<ReturnSettingsNotifier, RefundMethod>(
      (ref) => ReturnSettingsNotifier(),
    );
