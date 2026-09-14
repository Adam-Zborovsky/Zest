CREATE TABLE "catalog_recipes" (
	"provider_id" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"source" text NOT NULL,
	"updated_at" timestamp with time zone NOT NULL
);
--> statement-breakpoint
CREATE TABLE "catalog_state" (
	"id" integer PRIMARY KEY NOT NULL,
	"version" text NOT NULL,
	"recipe_count" integer NOT NULL,
	"published_at" timestamp with time zone NOT NULL,
	"checked_at" timestamp with time zone NOT NULL,
	"last_error_code" text
);
