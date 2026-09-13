import { argon2id, hash, verify, type HashOptions } from 'argon2';

export type Argon2Options = HashOptions;

/** OWASP minimum for Argon2id (docs/ACCOUNTS.md). Tests inject cheaper parameters. */
export const DEFAULT_ARGON2_OPTIONS: Argon2Options = {
  type: argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1,
};

export async function hashPassword(password: string, options: Argon2Options): Promise<string> {
  return hash(password, options);
}

export async function verifyPassword(digest: string, password: string): Promise<boolean> {
  return verify(digest, password);
}

/**
 * A fixed hash verified on every unknown-email login, so response time does not
 * reveal whether an account exists. Computed once per process with the active
 * argon2 parameters, never with a hardcoded hash whose cost could drift from them.
 */
let dummyHash: Promise<string> | undefined;
export function getDummyHash(options: Argon2Options): Promise<string> {
  dummyHash ??= hash('correct horse battery staple placeholder', options);
  return dummyHash;
}

/** Test-only: forces recomputation, since node:test files can share module state. */
export function resetDummyHashForTests(): void {
  dummyHash = undefined;
}
