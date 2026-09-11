/// The safe, typed failure surface for CocktailDB requests.
enum CocktailApiErrorKind {
  network,
  timeout,
  http,
  rateLimited,
  invalidResponse,
  closed,
}

final class CocktailApiException implements Exception {
  const CocktailApiException(this.kind, {this.statusCode, this.retryAfter});

  final CocktailApiErrorKind kind;
  final int? statusCode;
  final Duration? retryAfter;

  @override
  String toString() {
    final status = statusCode == null ? '' : ', statusCode: $statusCode';
    final retry = retryAfter == null ? '' : ', retryAfter: $retryAfter';
    return 'CocktailApiException(kind: $kind$status$retry)';
  }
}
