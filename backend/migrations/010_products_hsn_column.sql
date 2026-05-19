-- Migration 010: Add hsn column to products, align sku nullability with ORM
ALTER TABLE products ADD COLUMN IF NOT EXISTS hsn TEXT;
ALTER TABLE products ALTER COLUMN sku DROP NOT NULL;
