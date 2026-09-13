/// Shared validation for `ZEST_API_BASE_URL`, used by the recipe gateway
/// client and the account/sync clients. See `docs/ACCOUNTS.md`.
///
/// Allowed: HTTPS to any host; plain HTTP to loopback (`localhost`,
/// `127.0.0.1`, `::1`) or a private IPv4 host (10/8, 172.16/12, 192.168/16).
/// The URL must be absolute, carry no credentials, query, or fragment, and
/// end in `/`.
Uri validateApiBaseUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !uri.path.endsWith('/') ||
      !_allowedScheme(uri)) {
    // Configuration can be sensitive; never include the supplied URI in errors.
    throw ArgumentError(
      'ZEST_API_BASE_URL must be an absolute HTTPS URL (or HTTP to loopback '
      'or a private IPv4 address), without credentials/query/fragment, '
      'ending in /.',
    );
  }
  return uri;
}

bool _allowedScheme(Uri uri) {
  if (uri.scheme == 'https') return true;
  return uri.scheme == 'http' && _allowedHttpHost(uri.host);
}

bool _allowedHttpHost(String host) {
  if (const ['localhost', '127.0.0.1', '::1'].contains(host)) return true;
  return isPrivateIPv4(host);
}

/// True when [host] is a dotted-quad IPv4 address in 10/8, 172.16/12, or
/// 192.168/16.
bool isPrivateIPv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final octets = <int>[];
  for (final part in parts) {
    final value = int.tryParse(part);
    if (value == null || value < 0 || value > 255 || part != value.toString()) {
      return false;
    }
    octets.add(value);
  }
  if (octets[0] == 10) return true;
  if (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) return true;
  if (octets[0] == 192 && octets[1] == 168) return true;
  return false;
}

/// Resolves the account/sync base from the catalog gateway base, per
/// `docs/ACCOUNTS.md`: `http://host/api/cocktails/` becomes `http://host/api/`.
Uri resolveAccountBaseUrl(Uri catalogBase) => catalogBase.resolve('../');
