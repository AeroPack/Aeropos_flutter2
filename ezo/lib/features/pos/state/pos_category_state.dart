import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:aeropos/core/database/app_database.dart';

// 1. Stream Provider for Categories
final categoryStreamProvider = StreamProvider.autoDispose<List<CategoryEntity>>((ref) {
  // Access the singleton viewmodel
  final viewModel = ServiceLocator.instance.categoryViewModel;
  return viewModel.allCategories;
});

// Let's use int? for the selected Category ID, or null for "All"
final selectedCategoryProvider = StateProvider<int?>((ref) => null);
