/// Thrown by [SyncApi] implementations for a transport failure (no network,
/// server unreachable, timeout). `SyncEngine` maps this to
/// `SyncPhase.offline`.
final class SyncOfflineException implements Exception {
  const SyncOfflineException([this.message = 'The server is unreachable.']);

  final String message;

  @override
  String toString() => 'SyncOfflineException: $message';
}

/// Thrown after a [SyncApi] implementation calls
/// `AccountRepository.expireSession` on a 401. `SyncEngine` maps this to
/// `SyncPhase.failed` once the session is cleared.
final class SyncUnauthorizedException implements Exception {
  const SyncUnauthorizedException();

  @override
  String toString() => 'SyncUnauthorizedException';
}

/// Any other server-reported failure (4xx/5xx not covered above, or a
/// malformed response). `SyncEngine` maps this to `SyncPhase.failed`.
final class SyncApiException implements Exception {
  const SyncApiException(this.statusCode, [this.code]);

  final int statusCode;
  final String? code;

  @override
  String toString() => 'SyncApiException($statusCode, $code)';
}
