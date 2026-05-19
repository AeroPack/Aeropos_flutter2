ALTER TABLE "products" ADD COLUMN "hsn" text;--> statement-breakpoint
ALTER TABLE "products" ALTER COLUMN "sku" DROP NOT NULL;
