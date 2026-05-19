## What's Wrong

The migration code is **not idempotent** - it blindly tries to add `base_unit_id` without checking if the column already exists.

**Why it works on some devices but not Windows:**

1. **Fresh install**: Drift runs `onCreate` using the `Products` table definition which **already includes** `baseUnitId` (defined in `products_table.dart:12`). The column gets created by `createAll()`.

2. **Upgrade path**: The migration at `if (from < 35)` runs for upgrades from older versions. On some devices, if the database was created fresh (new install), the table already has the column from `createAll()`, so when upgrading from an older version, the migration tries to add a column that already exists → **duplicate column error**.

**The fix**: Add a check before adding the column to make the migration idempotent.