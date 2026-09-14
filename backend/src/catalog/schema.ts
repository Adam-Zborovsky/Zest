// Drizzle schema for the shared catalog (M11). See docs/M11.md.
import { integer, pgTable, text, timestamp } from 'drizzle-orm/pg-core';

export const catalogRecipes = pgTable('catalog_recipes', {
  providerId: text('provider_id').primaryKey(),
  name: text('name').notNull(),
  // Validated provider drink record, verbatim, as text JSON.
  source: text('source').notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true, mode: 'string' }).notNull(),
});

/** Single-row table (id is always 1) describing the currently published snapshot. */
export const catalogState = pgTable('catalog_state', {
  id: integer('id').primaryKey(),
  version: text('version').notNull(),
  recipeCount: integer('recipe_count').notNull(),
  publishedAt: timestamp('published_at', { withTimezone: true, mode: 'string' }).notNull(),
  checkedAt: timestamp('checked_at', { withTimezone: true, mode: 'string' }).notNull(),
  lastErrorCode: text('last_error_code'),
});
