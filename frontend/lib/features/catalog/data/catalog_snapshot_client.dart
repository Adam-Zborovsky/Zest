import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/network/api_base_url.dart';
import '../../../core/network/cocktail_api_exception.dart';
import '../../discovery/domain/recipe.dart';
import '../domain/catalog_snapshot.dart';

/// The `ZEST_API_BASE_URL` default, mirrored from `CocktailDbClient` so both
/// clients agree on the local gateway without one importing the other.
const _defaultApiBaseUrl = 'http://127.0.0.1:3000/api/cocktails/';

final _versionPattern = RegExp(r'^[0-9a-f]{64}$');
final _idPattern = RegExp(r'^\d{1,20}$');

/// A fetch either found a new version, or confirmed the caller's version is
/// still current (a `304`, or a `200` whose version happens to match).
sealed class CatalogSnapshotFetch {
  const CatalogSnapshotFetch();
}

final class CatalogSnapshotAvailable extends CatalogSnapshotFetch {
  const CatalogSnapshotAvailable(this.snapshot);
  final CatalogSnapshot snapshot;
}

final class CatalogSnapshotUnchanged extends CatalogSnapshotFetch {
  const CatalogSnapshotUnchanged();
}

/// Conditional-GET client for the shared backend catalog (`GET /api/catalog`,
/// `docs/M11.md`). Validates the envelope and every drink record before
/// handing back a [CatalogSnapshot]; never partially applies an invalid
/// response. Provider credentials never pass through this client.
final class CatalogSnapshotClient {
  CatalogSnapshotClient({
    http.Client? client,
    String baseUrl = const String.fromEnvironment(
      'ZEST_API_BASE_URL',
      defaultValue: _defaultApiBaseUrl,
    ),
    this.requestTimeout = const Duration(seconds: 20),
    this.maxResponseBytes = 8 * 1024 * 1024,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _uri = resolveCatalogSnapshotUrl(validateApiBaseUrl(baseUrl)),
       _now = now ?? DateTime.now {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(requestTimeout, 'requestTimeout');
    }
    if (maxResponseBytes <= 0) {
      throw ArgumentError.value(maxResponseBytes, 'maxResponseBytes');
    }
  }

  final http.Client _client;
  final bool _ownsClient;
  final Uri _uri;
  final DateTime Function() _now;
  final Duration requestTimeout;
  final int maxResponseBytes;
  bool _closed = false;

  /// Conditionally fetches the catalog. [ifNoneMatchVersion] is the locally
  /// applied version (unquoted 64-hex); when the server's current version
  /// matches, a `304` (or an identical `200` body) yields
  /// [CatalogSnapshotUnchanged] without allocating drink records.
  Future<CatalogSnapshotFetch> fetch({String? ifNoneMatchVersion}) async {
    if (_closed) throw _closedError();
    final request = http.Request('GET', _uri)
      ..followRedirects = false
      ..maxRedirects = 0;
    if (ifNoneMatchVersion != null) {
      request.headers['If-None-Match'] = '"$ifNoneMatchVersion"';
    }
    request.headers['Accept-Encoding'] = 'gzip';

    http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(requestTimeout);
    } on TimeoutException {
      throw const CocktailApiException(CocktailApiErrorKind.timeout);
    } on http.ClientException {
      throw const CocktailApiException(CocktailApiErrorKind.network);
    } catch (_) {
      throw const CocktailApiException(CocktailApiErrorKind.network);
    }

    if (response.statusCode == 304) {
      await _discard(response.stream);
      return const CatalogSnapshotUnchanged();
    }
    if (response.statusCode == 429) {
      await _discard(response.stream);
      final retryAfter = _retryAfter(response.headers['retry-after']);
      throw CocktailApiException(
        CocktailApiErrorKind.rateLimited,
        statusCode: 429,
        retryAfter: retryAfter,
        retryAt: retryAfter == null ? null : _now().add(retryAfter),
      );
    }
    if (response.statusCode == 503) {
      await _discard(response.stream);
      throw const CocktailApiException(
        CocktailApiErrorKind.http,
        statusCode: 503,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await _discard(response.stream);
      throw CocktailApiException(
        CocktailApiErrorKind.http,
        statusCode: response.statusCode,
      );
    }

    final Uint8List bytes;
    try {
      bytes = await _readBounded(response.stream).timeout(requestTimeout);
    } on TimeoutException {
      throw const CocktailApiException(CocktailApiErrorKind.timeout);
    } on http.ClientException {
      throw const CocktailApiException(CocktailApiErrorKind.network);
    } on _ResponseTooLarge {
      throw const CocktailApiException(CocktailApiErrorKind.invalidResponse);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException catch (_) {
      throw const CocktailApiException(CocktailApiErrorKind.invalidResponse);
    }

    final snapshot = _parseEnvelope(decoded);
    if (ifNoneMatchVersion != null && snapshot.version == ifNoneMatchVersion) {
      return const CatalogSnapshotUnchanged();
    }
    return CatalogSnapshotAvailable(snapshot);
  }

  CatalogSnapshot _parseEnvelope(Object? decoded) {
    if (decoded is! Map) _invalid();
    final map = decoded;

    final version = map['version'];
    if (version is! String || !_versionPattern.hasMatch(version)) _invalid();

    final publishedAtRaw = map['publishedAt'];
    final publishedAt = publishedAtRaw is String
        ? DateTime.tryParse(publishedAtRaw)
        : null;
    if (publishedAt == null) _invalid();

    final recipeCount = map['recipeCount'];
    if (recipeCount is! int || recipeCount < 0) _invalid();

    final attribution = _parseAttribution(map['attribution']);

    final drinksRaw = map['drinks'];
    if (drinksRaw is! List) _invalid();
    if (drinksRaw.length != recipeCount) _invalid();

    final seenIds = <String>{};
    final drinks = <Recipe>[];
    for (final entry in drinksRaw) {
      if (entry is! Map) _invalid();
      final record = <String, dynamic>{};
      for (final key in entry.keys) {
        if (key is! String) _invalid();
        final value = entry[key];
        if (key.startsWith('str') && value != null && value is! String) {
          _invalid();
        }
        record[key] = value;
      }
      final id = record['idDrink'];
      if (id is! String || !_idPattern.hasMatch(id)) _invalid();
      final name = record['strDrink'];
      if (name is! String || name.trim().isEmpty) _invalid();
      if (!seenIds.add(id)) _invalid();
      try {
        drinks.add(Recipe.fromJson(record));
      } on FormatException {
        _invalid();
      }
    }

    return CatalogSnapshot(
      version: version,
      publishedAt: publishedAt,
      recipeCount: recipeCount,
      attribution: attribution,
      drinks: List.unmodifiable(drinks),
    );
  }

  CatalogAttribution _parseAttribution(Object? raw) {
    if (raw is! Map) _invalid();
    final name = raw['name'];
    final urlRaw = raw['url'];
    if (name is! String || name.trim().isEmpty) _invalid();
    if (urlRaw is! String) _invalid();
    final url = Uri.tryParse(urlRaw);
    if (url == null || !url.hasScheme) _invalid();
    return CatalogAttribution(name: name, url: url);
  }

  Future<Uint8List> _readBounded(Stream<List<int>> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (builder.length + chunk.length > maxResponseBytes) {
        throw const _ResponseTooLarge();
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<void> _discard(Stream<List<int>> stream) =>
      stream.listen((_) {}).cancel();

  Duration? _retryAfter(String? value) {
    final seconds = int.tryParse(value?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  Never _invalid() =>
      throw const CocktailApiException(CocktailApiErrorKind.invalidResponse);

  CocktailApiException _closedError() =>
      const CocktailApiException(CocktailApiErrorKind.closed);

  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsClient) _client.close();
  }
}

final class _ResponseTooLarge implements Exception {
  const _ResponseTooLarge();
}
