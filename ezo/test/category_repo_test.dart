import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:aeropos/core/database/app_database.dart';
import 'package:aeropos/core/repositories/category_repository.dart';
import 'package:aeropos/core/repositories/sync_repository.dart';
import 'package:aeropos/core/models/category.dart';
import 'package:aeropos/core/di/service_locator.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late CategoryRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());

    // Initialize minimal sync repository for testing
    ServiceLocator.instance.database = database;
    ServiceLocator.instance.syncRepository = SyncRepository(
      db: database,
      tenantId: '1',
      companyId: 'default',
      deviceId: 'TEST',
    );

    repository = CategoryRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('CategoryRepository can add and retrieve categories', () async {
    final uuid = const Uuid().v4();
    final newCategory = Category(
      id: 0,
      uuid: uuid,
      name: 'Test Category',
      description: 'Test Description',
      isActive: true,
    );

    await repository.createCategory(newCategory);

    final categories = await repository.getAllCategories();
    expect(categories.length, 1);
    expect(categories.first.name, 'Test Category');
    expect(categories.first.uuid, uuid);
  });
}
