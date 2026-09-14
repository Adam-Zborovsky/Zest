// Drizzle schema for accounts and the synced collection. See docs/ACCOUNTS.md.
import { boolean, index, integer, pgTable, primaryKey, text, timestamp } from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: text('id').primaryKey(),
  email: text('email').notNull().unique(),
  passwordHash: text('password_hash').notNull(),
  revision: integer('revision').notNull().default(0),
  // Home-bar changes use an independent cursor from collection entries.
  barRevision: integer('bar_revision').notNull().default(0),
  createdAt: timestamp('created_at', { withTimezone: true, mode: 'string' }).notNull(),
});

export const sessions = pgTable('sessions', {
  tokenHash: text('token_hash').primaryKey(),
  userId: text('user_id').notNull().references(() => users.id),
  createdAt: timestamp('created_at', { withTimezone: true, mode: 'string' }).notNull(),
  expiresAt: timestamp('expires_at', { withTimezone: true, mode: 'string' }).notNull(),
  revokedAt: timestamp('revoked_at', { withTimezone: true, mode: 'string' }),
  lastUsedAt: timestamp('last_used_at', { withTimezone: true, mode: 'string' }),
});

export const entries = pgTable('entries', {
  userId: text('user_id').notNull().references(() => users.id),
  id: text('id').notNull(),
  kind: text('kind').notNull(),
  sourceRecipeId: text('source_recipe_id').notNull(),
  source: text('source'),
  variation: text('variation'),
  day: text('day').notNull(),
  hasPhoto: boolean('has_photo').notNull().default(false),
  photoMime: text('photo_mime'),
  photoBytes: integer('photo_bytes'),
  photoUpdatedAt: timestamp('photo_updated_at', { withTimezone: true, mode: 'string' }),
  createdAt: timestamp('created_at', { withTimezone: true, mode: 'string' }).notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true, mode: 'string' }).notNull(),
  deleted: boolean('deleted').notNull().default(false),
  revision: integer('revision').notNull(),
}, (table) => [
  primaryKey({ columns: [table.userId, table.id] }),
  index('entries_user_revision_idx').on(table.userId, table.revision),
]);

/** One durable home-bar state per normalized ingredient identity and user. */
export const barItems = pgTable('bar_items', {
  userId: text('user_id').notNull().references(() => users.id),
  ingredientId: text('ingredient_id').notNull(),
  displayName: text('display_name').notNull(),
  location: text('location').notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true, mode: 'string' }).notNull(),
  deleted: boolean('deleted').notNull().default(false),
  revision: integer('revision').notNull(),
}, (table) => [
  primaryKey({ columns: [table.userId, table.ingredientId] }),
  index('bar_items_user_revision_idx').on(table.userId, table.revision),
]);
