// Wire types for accounts and the synced collection. The specification is
// docs/ACCOUNTS.md; synthetic examples live in contract/accounts/ and are
// parsed by both the backend and Flutter test suites.

export interface UserRecord {
  /** UUID; scopes every entry and photo. */
  id: string;
  /** Normalized: trimmed and lowercased. */
  email: string;
  /** ISO-8601 UTC. */
  createdAt: string;
}

export interface SessionRecord {
  /** 32 random bytes, base64url. Returned once; the server stores only its SHA-256. */
  token: string;
  /** ISO-8601 UTC; 30 days after sign-in, no sliding renewal. */
  expiresAt: string;
}

export interface AuthRequest {
  email: string;
  password: string;
}

export interface AuthResponse {
  user: UserRecord;
  session: SessionRecord;
}

export type EntryKind = 'saved' | 'variation';

export interface VariationIngredientRecord {
  name: string;
  measure: string;
}

export interface VariationRecord {
  name: string;
  ingredients: VariationIngredientRecord[];
  method: string;
  notes: string;
}

export interface EntryRecord {
  /** ^[0-9a-f]{32}$, client-generated; primary key is (user_id, id). */
  id: string;
  kind: EntryKind;
  /** ^[0-9]{1,20}$ */
  sourceRecipeId: string;
  /** Opaque Recipe.toJson() snapshot, at most 64 KiB serialized; null only on a tombstone. */
  source: Record<string, unknown> | null;
  /** Present exactly for a live variation. */
  variation: VariationRecord | null;
  /** YYYY-MM-DD, a real calendar date. */
  day: string;
  hasPhoto: boolean;
  photoUpdatedAt: string | null;
  createdAt: string;
  /** Last-edit-wins key; rejected when more than 24 hours ahead of the server clock. */
  updatedAt: string;
  deleted: boolean;
  /** Server-assigned per-user revision. Absent on a PUT body. */
  revision?: number;
}

export type EntryPutBody = Omit<EntryRecord, 'revision'>;

export interface SyncPageResponse {
  /** Ascending revision order. */
  entries: EntryRecord[];
  /** Last revision included, or the requested `since` when empty. */
  revision: number;
  hasMore: boolean;
}

export type ErrorCode =
  | 'invalid_request'
  | 'invalid_credentials'
  | 'email_taken'
  | 'unauthorized'
  | 'not_found'
  | 'payload_too_large'
  | 'unsupported_media_type'
  | 'quota_exceeded'
  | 'rate_limited'
  | 'internal_error';

export interface ErrorResponse {
  error: { code: ErrorCode; message: string };
}

export const AccountLimits = {
  maxEmailLength: 254,
  minPasswordLength: 10,
  maxPasswordLength: 128,
  maxSourceBytes: 64 * 1024,
  maxPhotoBytes: 4 * 1024 * 1024,
  photoQuotaBytes: 512 * 1024 * 1024,
  sessionDays: 30,
  maxClockSkewMs: 24 * 60 * 60 * 1000,
  defaultPullLimit: 200,
  maxPullLimit: 500,
} as const;
