// Shared validation for the accounts and sync contract. See docs/ACCOUNTS.md.
import { AccountLimits } from './contract.js';
import type { EntryPutBody, HomeBarItemPutBody, VariationRecord } from './contract.js';

export class ValidationError extends Error {}

export function normalizeEmail(raw: unknown): string {
  if (typeof raw !== 'string') throw new ValidationError('Email is required.');
  const email = raw.trim().toLowerCase();
  if (!email || email.length > AccountLimits.maxEmailLength || /\s/.test(email)) {
    throw new ValidationError('Invalid email.');
  }
  const at = email.indexOf('@');
  if (at <= 0 || at !== email.lastIndexOf('@') || at === email.length - 1) {
    throw new ValidationError('Invalid email.');
  }
  return email;
}

export function validatePassword(raw: unknown): string {
  if (typeof raw !== 'string') throw new ValidationError('Password is required.');
  const length = Array.from(raw).length;
  if (length < AccountLimits.minPasswordLength || length > AccountLimits.maxPasswordLength) {
    throw new ValidationError('Password must be 10 to 128 characters.');
  }
  return raw;
}

const ENTRY_ID_RE = /^[0-9a-f]{32}$/;
const SOURCE_RECIPE_ID_RE = /^[0-9]{1,20}$/;
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

export function validateEntryId(value: unknown): string {
  if (typeof value !== 'string' || !ENTRY_ID_RE.test(value)) throw new ValidationError('Invalid entry id.');
  return value;
}

function isRealCalendarDate(day: string): boolean {
  const match = DAY_RE.exec(day);
  if (!match) return false;
  const [year, month, date] = day.split('-').map(Number) as [number, number, number];
  const parsed = new Date(Date.UTC(year, month - 1, date));
  return parsed.getUTCFullYear() === year && parsed.getUTCMonth() === month - 1 && parsed.getUTCDate() === date;
}

function trimmedString(value: unknown, maxLength: number, field: string): string {
  if (typeof value !== 'string') throw new ValidationError(`Invalid ${field}.`);
  const trimmed = value.trim();
  if (trimmed.length > maxLength) throw new ValidationError(`${field} is too long.`);
  return trimmed;
}

function validateVariation(value: unknown): VariationRecord {
  if (typeof value !== 'object' || value === null) throw new ValidationError('Invalid variation.');
  const record = value as Record<string, unknown>;
  const name = trimmedString(record.name, 120, 'variation name');
  const method = trimmedString(record.method, 8000, 'variation method');
  const notes = trimmedString(record.notes, 4000, 'variation notes');
  if (!Array.isArray(record.ingredients) || record.ingredients.length > 30) {
    throw new ValidationError('Invalid variation ingredients.');
  }
  const ingredients = record.ingredients.map((raw) => {
    if (typeof raw !== 'object' || raw === null) throw new ValidationError('Invalid variation ingredient.');
    const ingredient = raw as Record<string, unknown>;
    return {
      name: trimmedString(ingredient.name, 120, 'ingredient name'),
      measure: trimmedString(ingredient.measure, 80, 'ingredient measure'),
    };
  });
  return { name, method, notes, ingredients };
}

function isIsoTimestamp(value: unknown): value is string {
  return typeof value === 'string' && !Number.isNaN(Date.parse(value)) && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/.test(value);
}

export interface ValidatedEntry extends EntryPutBody {}

/** Validates an entry PUT body against the wire contract. `pathId` must match the body id. */
export function validateEntryBody(value: unknown, pathId: string, now: number): ValidatedEntry {
  if (typeof value !== 'object' || value === null) throw new ValidationError('Invalid entry body.');
  const record = value as Record<string, unknown>;
  const id = validateEntryId(record.id);
  if (id !== pathId) throw new ValidationError('Entry id must match the path.');
  if (record.kind !== 'saved' && record.kind !== 'variation') throw new ValidationError('Invalid entry kind.');
  if (typeof record.sourceRecipeId !== 'string' || !SOURCE_RECIPE_ID_RE.test(record.sourceRecipeId)) {
    throw new ValidationError('Invalid sourceRecipeId.');
  }
  if (typeof record.day !== 'string' || !isRealCalendarDate(record.day)) throw new ValidationError('Invalid day.');
  if (typeof record.deleted !== 'boolean') throw new ValidationError('Invalid deleted flag.');
  if (typeof record.createdAt !== 'string' || !isIsoTimestamp(record.createdAt)) throw new ValidationError('Invalid createdAt.');
  if (!isIsoTimestamp(record.updatedAt)) throw new ValidationError('Invalid updatedAt.');
  if (Date.parse(record.updatedAt) - now > AccountLimits.maxClockSkewMs) {
    throw new ValidationError('updatedAt is too far in the future.');
  }
  if (typeof record.hasPhoto !== 'boolean') throw new ValidationError('Invalid hasPhoto.');
  if (record.photoUpdatedAt !== null && !isIsoTimestamp(record.photoUpdatedAt)) {
    throw new ValidationError('Invalid photoUpdatedAt.');
  }

  let source: Record<string, unknown> | null = null;
  let variation: VariationRecord | null = null;
  if (record.deleted) {
    if (record.source !== null || record.variation !== null) {
      throw new ValidationError('A tombstone must not carry source or variation data.');
    }
  } else {
    if (typeof record.source !== 'object' || record.source === null || Array.isArray(record.source)) {
      throw new ValidationError('Invalid source.');
    }
    if (Buffer.byteLength(JSON.stringify(record.source)) > AccountLimits.maxSourceBytes) {
      throw new ValidationError('source is too large.');
    }
    source = record.source as Record<string, unknown>;
    if (record.kind === 'variation') {
      if (record.variation === null) throw new ValidationError('A variation entry requires variation data.');
      variation = validateVariation(record.variation);
    } else if (record.variation !== null) {
      throw new ValidationError('A saved entry must not carry variation data.');
    }
  }

  return {
    id, kind: record.kind, sourceRecipeId: record.sourceRecipeId, source, variation,
    day: record.day, hasPhoto: record.hasPhoto, photoUpdatedAt: record.photoUpdatedAt as string | null,
    createdAt: record.createdAt, updatedAt: record.updatedAt, deleted: record.deleted,
  };
}

export function validatePhotoUpdatedAt(value: unknown, now: number): string {
  if (!isIsoTimestamp(value)) throw new ValidationError('Invalid updatedAt.');
  if (Date.parse(value) - now > AccountLimits.maxClockSkewMs) {
    throw new ValidationError('updatedAt is too far in the future.');
  }
  return value;
}

export function validateSince(value: unknown): number {
  if (typeof value !== 'string' || !/^\d+$/.test(value)) throw new ValidationError('Invalid since.');
  const since = Number(value);
  if (!Number.isSafeInteger(since) || since < 0) throw new ValidationError('Invalid since.');
  return since;
}

export function validateLimit(value: unknown): number {
  if (value === undefined) return AccountLimits.defaultPullLimit;
  if (typeof value !== 'string' || !/^\d+$/.test(value)) throw new ValidationError('Invalid limit.');
  const limit = Number(value);
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > AccountLimits.maxPullLimit) {
    throw new ValidationError('Invalid limit.');
  }
  return limit;
}

const INGREDIENT_ALIASES: Readonly<Record<string, string>> = {
  'dark rums': 'dark rum',
  'light rums': 'light rum',
  'white rums': 'white rum',
  'mint leaves': 'mint leaf',
  'ice cubes': 'ice cube',
};

/** Mirrors Flutter's `normalizeIngredientName` identity rules. */
export function normalizeIngredientId(value: unknown): string {
  if (typeof value !== 'string') throw new ValidationError('Invalid ingredient id.');
  if (/[\u0000-\u001f\u007f]/u.test(value)) throw new ValidationError('Invalid ingredient id.');
  const normalized = value.trim().toLowerCase().replace(/\s+/gu, ' ');
  if (!normalized || normalized.length > AccountLimits.maxHomeBarDisplayNameLength) {
    throw new ValidationError('Invalid ingredient id.');
  }
  return INGREDIENT_ALIASES[normalized] ?? normalized;
}

export function validateIngredientId(value: unknown): string {
  const normalized = normalizeIngredientId(value);
  if (value !== normalized) throw new ValidationError('Ingredient id must be normalized.');
  return normalized;
}

function validateHomeBarDisplayName(value: unknown): string {
  if (typeof value !== 'string') throw new ValidationError('Invalid displayName.');
  if (/[\u0000-\u001f\u007f]/u.test(value)) throw new ValidationError('Invalid displayName.');
  const displayName = value.trim();
  if (!displayName || displayName.length > AccountLimits.maxHomeBarDisplayNameLength) {
    throw new ValidationError('Invalid displayName.');
  }
  return displayName;
}

export interface ValidatedHomeBarItem extends HomeBarItemPutBody {}

/** Strictly validates an M10 home-bar PUT body and its decoded route identity. */
export function validateHomeBarItemBody(value: unknown, pathIngredientId: string, now: number): ValidatedHomeBarItem {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new ValidationError('Invalid home-bar item body.');
  }
  const record = value as Record<string, unknown>;
  const allowedKeys = ['ingredientId', 'displayName', 'location', 'updatedAt', 'deleted'];
  if (Object.keys(record).some((key) => !allowedKeys.includes(key)) ||
      allowedKeys.some((key) => !(key in record))) {
    throw new ValidationError('Invalid home-bar item body.');
  }
  const ingredientId = validateIngredientId(record.ingredientId);
  if (ingredientId !== pathIngredientId) throw new ValidationError('Ingredient id must match the path.');
  const displayName = validateHomeBarDisplayName(record.displayName);
  if (record.location !== 'stocked' && record.location !== 'shopping') {
    throw new ValidationError('Invalid home-bar location.');
  }
  if (!isIsoTimestamp(record.updatedAt)) throw new ValidationError('Invalid updatedAt.');
  if (Date.parse(record.updatedAt) - now > AccountLimits.maxClockSkewMs) {
    throw new ValidationError('updatedAt is too far in the future.');
  }
  if (typeof record.deleted !== 'boolean') throw new ValidationError('Invalid deleted flag.');
  return { ingredientId, displayName, location: record.location, updatedAt: record.updatedAt, deleted: record.deleted };
}
