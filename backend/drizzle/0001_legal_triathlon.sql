CREATE TABLE "bar_items" (
	"user_id" text NOT NULL,
	"ingredient_id" text NOT NULL,
	"display_name" text NOT NULL,
	"location" text NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"deleted" boolean DEFAULT false NOT NULL,
	"revision" integer NOT NULL,
	CONSTRAINT "bar_items_user_id_ingredient_id_pk" PRIMARY KEY("user_id","ingredient_id")
);
--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "bar_revision" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "bar_items" ADD CONSTRAINT "bar_items_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "bar_items_user_revision_idx" ON "bar_items" USING btree ("user_id","revision");