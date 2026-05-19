import 'package:drift/drift.dart' as drift;
import 'package:aeropos/core/database/app_database.dart';
import '../services/i_sync_service.dart';
import 'package:uuid/uuid.dart';

class CategoryViewModel {
  final AppDatabase _database;
  final ISyncService _syncService;
  final _uuid = const Uuid();

  CategoryViewModel(this._database, this._syncService);

  // Expose stream of products from DB
  Stream<List<CategoryEntity>> get allCategories =>
      _database.watchAllCategories();

  Future<void> addCategory({
    required String name,
    String? subcategory,
    String? description,
  }) async {
    final uuid = _uuid.v4();
    final entry = CategoriesCompanion(
      uuid: drift.Value(uuid),
      name: drift.Value(name),
      subcategory: drift.Value(subcategory),
      description: drift.Value(description),
      isActive: const drift.Value(true),
      tenantId: const drift.Value(1),
      syncStatus: const drift.Value(1),
      isDeleted: const drift.Value(false),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    );

    await _database.insertCategory(entry);
    await _syncService.logOperation(
      entity: 'categories',
      entityId: uuid,
      opType: 1,
      data: {
        'uuid': uuid,
        'name': name,
        'subcategory': subcategory,
        'is_active': true,
        'is_deleted': false,
      },
    );
  }

  Future<void> updateCategory(CategoryEntity category) async {
    await _database.updateCategory(category);
    await _syncService.logOperation(
      entity: 'categories',
      entityId: category.uuid,
      opType: 2,
      data: {
        'uuid': category.uuid,
        'name': category.name,
        'subcategory': category.subcategory,
        'is_active': category.isActive,
        'is_deleted': category.isDeleted,
      },
    );
  }

  Future<void> deleteCategory(int id) async {
    final entity = await (_database.select(_database.categories)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    await _database.deleteCategory(id);
    if (entity != null) {
      await _syncService.logOperation(
        entity: 'categories',
        entityId: entity.uuid,
        opType: 3,
        data: {'uuid': entity.uuid, 'is_deleted': true},
      );
    }
  }

  Future<void> syncPendingCategories() async {
    try {
      await _syncService.push();
    } catch (e) {
      print('CategoryViewModel syncPendingCategories error: $e');
    }
  }

  Future<void> fetchAndSync() async {
    try {
      await _syncService.pull();
    } catch (e) {
      print('CategoryViewModel fetchAndSync error: $e');
    }
  }
}
