import { randomUUID } from 'node:crypto';
import { mkdir, readFile, rename, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';

export type PhotoMime = 'image/jpeg' | 'image/png' | 'image/webp';

/** Sniffs the true image type from its magic bytes; never trusts a caller-supplied header alone. */
export function sniffPhotoType(bytes: Buffer): PhotoMime | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if (bytes.length >= 8 &&
    bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47 &&
    bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a) return 'image/png';
  if (bytes.length >= 12 &&
    bytes.subarray(0, 4).toString('ascii') === 'RIFF' &&
    bytes.subarray(8, 12).toString('ascii') === 'WEBP') return 'image/webp';
  return null;
}

const USER_ID_RE = /^[0-9a-f-]{36}$/;
const ENTRY_ID_RE = /^[0-9a-f]{32}$/;

/** PHOTO_DIR/<userId>/<entryId>; both path segments come only from validated ids. */
export function photoPath(photoDir: string, userId: string, entryId: string): string {
  if (!USER_ID_RE.test(userId)) throw new Error('Invalid user id.');
  if (!ENTRY_ID_RE.test(entryId)) throw new Error('Invalid entry id.');
  return path.join(photoDir, userId, entryId);
}

/**
 * Writes bytes to a fresh temp file in the given directory and returns its path.
 * The caller renames it into place only once it knows this write should win
 * (last-edit-wins), so a losing write can never clobber a newer photo on disk.
 */
export async function writeTempFile(dir: string, bytes: Buffer): Promise<string> {
  await mkdir(dir, { recursive: true });
  const tempPath = path.join(dir, `.upload-${randomUUID()}.tmp`);
  await writeFile(tempPath, bytes);
  return tempPath;
}

export async function commitTempFile(tempPath: string, finalPath: string): Promise<void> {
  await mkdir(path.dirname(finalPath), { recursive: true });
  await rename(tempPath, finalPath);
}

export async function discardTempFile(tempPath: string): Promise<void> {
  await rm(tempPath, { force: true });
}

export async function removePhotoFile(filePath: string): Promise<void> {
  await rm(filePath, { force: true });
}

export async function readPhotoFile(filePath: string): Promise<Buffer | null> {
  try {
    return await readFile(filePath);
  } catch (error) {
    if (error instanceof Error && 'code' in error && (error as NodeJS.ErrnoException).code === 'ENOENT') return null;
    throw error;
  }
}
