import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/core/di/service_locator.dart';

/// Provider for the tenant ID.
/// In a real app, this would be set after login.
final companyIdProvider = StateProvider<int>((ref) {
  // Access the singleton service locator's tenant service
  return ServiceLocator.instance.sessionService.companyId;
});
