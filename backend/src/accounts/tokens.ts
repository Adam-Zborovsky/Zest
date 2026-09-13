import { createHash, randomBytes } from 'node:crypto';

/** 32 random bytes, base64url-encoded, per docs/ACCOUNTS.md. */
export function defaultTokenGenerator(): string {
  return randomBytes(32).toString('base64url');
}

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
