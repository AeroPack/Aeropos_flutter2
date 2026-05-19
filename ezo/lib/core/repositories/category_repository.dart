import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/category.dart';
import '../di/service_locator.dart';
import 'sync_repository.dart';

class CategoryRepository {
  final AppDatabase _database;

  CategoryRepository(this._database);

  Future<List<Category>> getAllCategories() async {
    final entities = await (_database.select(
      _database.categories,
    )..where((t) => t.isDeleted.equals(false))).get();
    return entities.map(_mapToDomain).toList();
  }

  Stream<List<Category>> watchAllCategories() {
    return (_database.select(_database.categories)
          ..where((t) => t.isDeleted.equals(false)))
        .watch()
        .map((entities) => entities.map(_mapToDomain).toList());
  }

  Future<Category?> getCategoryById(int id) async {
    final all = await getAllCategories();
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<int> createCategory(Category category) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    final tenantId = category.id > 0 ? 0 : 1;

    return await _database.transaction(() async {
      final companion = CategoriesCompanion.insert(
        uuid: category.uuid,
        name: category.name,
        subcategory: Value(category.subcategory),
        description: Value(category.description),
        isActive: Value(category.isActive),
        tenantId: tenantId,
        isDeleted: Value(category.isDeleted),
      );
      final id = await _database.into(_database.categories).insert(companion);

      await syncRepo.logOperation(
        entity: 'categories',
        entityId: category.uuid,
        opType: SyncOpType.insert,
        data: category.toJson(),
      );

      return id;
    });
  }

  Future<bool> updateCategory(Category category) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    final now = DateTime.now();

    return await _database.transaction(() async {
      final companion = CategoriesCompanion(
        id: Value(category.id),
        uuid: Value(category.uuid),
        name: Value(category.name),
        subcategory: Value(category.subcategory),
        description: Value(category.description),
        isActive: Value(category.isActive),
        updatedAt: Value(now),
        isDeleted: Value(category.isDeleted),
      );
      final success = await _database
          .update(_database.categories)
          .replace(companion);

      if (success) {
        await syncRepo.logOperation(
          entity: 'categories',
          entityId: category.uuid,
          opType: SyncOpType.update,
          data: category.toJson(),
        );
      }

      return success;
    });
  }

  Future<int> deleteCategory(int id) async {
    final syncRepo = ServiceLocator.instance.syncRepository;
    final now = DateTime.now();

    final entity = await (_database.select(
      _database.categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entity == null) return 0;

    return await _database.transaction(() async {
      final result =
          await (_database.update(
            _database.categories,
          )..where((t) => t.id.equals(id))).write(
            CategoriesCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(now),
            ),
          );

      if (result > 0) {
        await syncRepo.logOperation(
          entity: 'categories',
          entityId: entity.uuid,
          opType: SyncOpType.delete,
          data: _mapToDomain(entity).toJson(),
        );
      }

      return result;
    });
  }

  Category _mapToDomain(CategoryEntity entity) {
    return Category(
      id: entity.id,
      uuid: entity.uuid,
      name: entity.name,
      subcategory: entity.subcategory,
      description: entity.description,
      isActive: entity.isActive,
      isDeleted: entity.isDeleted,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
