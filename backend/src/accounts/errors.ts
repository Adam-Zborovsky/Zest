import type { ErrorCode } from './contract.js';

export class AccountError extends Error {
  constructor(readonly code: ErrorCode, readonly status: number, message: string, readonly retryAfter?: number) {
    super(message);
  }
}

export const unauthorized = () => new AccountError('unauthorized', 401, 'Sign in required.');
export const notFound = () => new AccountError('not_found', 404, 'Not found.');
export const invalidCredentials = () => new AccountError('invalid_credentials', 401, 'Invalid email or password.');
export const emailTaken = () => new AccountError('email_taken', 409, 'An account with this email already exists.');
export const invalidRequest = (message = 'Invalid request.') => new AccountError('invalid_request', 400, message);
export const payloadTooLarge = () => new AccountError('payload_too_large', 413, 'Request body is too large.');
export const unsupportedMediaType = () => new AccountError('unsupported_media_type', 415, 'Unsupported image type.');
export const quotaExceeded = () => new AccountError('quota_exceeded', 413, 'Photo storage quota exceeded.');
