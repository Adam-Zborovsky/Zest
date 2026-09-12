import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/network/cocktail_api_exception.dart';
import '../domain/recipe.dart';

/// A small, cache-backed client for the four discovery endpoints used by Zest.
final class CocktailDbClient {
  CocktailDbClient({
    http.Client? client,
    String apiKey = const String.fromEnvironment(
      'COCKTAIL_DB_API_KEY',
      defaultValue: '1',
    ),
    this.cacheTtl = const Duration(minutes: 10),
    this.maxCacheEntries = 64,
    this.requestTimeout = const Duration(seconds: 10),
    this.maxResponseBytes = 2 * 1024 * 1024,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _apiKey = apiKey,
       _now = now ?? DateTime.now {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(apiKey)) {
      throw ArgumentError('apiKey must be a non-empty safe path segment.');
    }
    if (cacheTtl.isNegative) throw ArgumentError.value(cacheTtl, 'cacheTtl');
    if (maxCacheEntries <= 0) {
      throw ArgumentError.value(maxCacheEntries, 'maxCacheEntries');
    }
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(requestTimeout, 'requestTimeout');
    }
    if (maxResponseBytes <= 0) {
      throw ArgumentError.value(maxResponseBytes, 'maxResponseBytes');
    }
  }

  final http.Client _client;
  final bool _ownsClient;
  final String _apiKey;
  final DateTime Function() _now;
  final Duration cacheTtl;
  final int maxCacheEntries;
  final Duration requestTimeout;
  final int maxResponseBytes;
  final _cache = LinkedHashMap<String, _CacheEntry<Object?>>();
  final _inFlight = <String, Future<Object?>>{};
  final _aborters = <Completer<void>>{};
  bool _closed = false;

  Future<List<Recipe>> searchByName(String name) {
    final query = _requiredText(name, 'name');
    return _cached('search:$query', () async {
      final drinks = await _drinks('search.php', {'s': query});
      return List<Recipe>.unmodifiable(drinks.map(_parseRecipe));
    });
  }

  Future<List<Recipe>> browseByFirstLetter(String letter) {
    final query = letter.trim();
    if (query.length != 1 || !RegExp(r'^[a-zA-Z]$').hasMatch(query)) {
      throw ArgumentError.value(letter, 'letter', 'Must be one ASCII letter.');
    }
    final normalized = query.toLowerCase();
    return _cached('letter:$normalized', () async {
      final drinks = await _drinks('search.php', {'f': normalized});
      return List<Recipe>.unmodifiable(drinks.map(_parseRecipe));
    });
  }

  Future<List<RecipeSummary>> filterByIngredient(String name) {
    final query = _requiredText(name, 'name');
    return _cached('ingredient:$query', () async {
      final drinks = await _drinks('filter.php', {'i': query});
      return List<RecipeSummary>.unmodifiable(drinks.map(_parseSummary));
    });
  }

  Future<Recipe?> lookupRecipe(String id) {
    final query = id.trim();
    if (query.isEmpty || !RegExp(r'^\d+$').hasMatch(query)) {
      throw ArgumentError.value(id, 'id', 'Must be a numeric ID.');
    }
    return _cached('lookup:$query', () async {
      final drinks = await _drinks('lookup.php', {'i': query});
      if (drinks.isEmpty) return null;
      if (drinks.length != 1) _invalid();
      final recipe = _parseRecipe(drinks.single);
      if (recipe.id != query) _invalid();
      return recipe;
    });
  }

  /// The provider's ingredient filter names via `list.php?i=list`. Names
  /// only — no availability or property claim. Sorted case-insensitively and
  /// deduplicated for stable selection UI.
  Future<List<String>> listIngredientNames() {
    return _cached('ingredient-list', () async {
      final drinks = await _drinks('list.php', {'i': 'list'});
      final names = <String, String>{};
      for (final record in drinks) {
        final value = record['strIngredient1'];
        if (value is! String || value.trim().isEmpty) _invalid();
        final trimmed = value.trim();
        names.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
      }
      final sorted = names.values.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return List.unmodifiable(sorted);
    });
  }

  Future<T> _cached<T>(String key, Future<T> Function() load) {
    if (_closed) return Future<T>.error(_closedError());
    final existing = _cache.remove(key);
    if (existing != null && !existing.isExpired(_now(), cacheTtl)) {
      _cache[key] = existing;
      return Future<T>.value(existing.value as T);
    }
    final pending = _inFlight[key];
    if (pending != null) return pending.then((value) => value as T);
    final future = load().then<Object?>((value) {
      if (!_closed) {
        _cache[key] = _CacheEntry<Object?>(value, _now());
        while (_cache.length > maxCacheEntries) {
          _cache.remove(_cache.keys.first);
        }
      }
      return value;
    });
    _inFlight[key] = future;
    future.then<void>(
      (_) {
        _inFlight.remove(key);
      },
      onError: (Object _, StackTrace __) {
        _inFlight.remove(key);
      },
    );
    return future.then((value) => value as T);
  }

  Future<List<Map<String, dynamic>>> _drinks(
    String endpoint,
    Map<String, String> parameters,
  ) async {
    final uri = Uri.https(
      'www.thecocktaildb.com',
      'api/json/v1/$_apiKey/$endpoint',
      parameters,
    );
    final aborter = Completer<void>();
    _aborters.add(aborter);
    Timer? timer;
    var timedOut = false;
    try {
      timer = Timer(requestTimeout, () {
        timedOut = true;
        if (!aborter.isCompleted) aborter.complete();
      });
      final request =
          http.AbortableRequest('GET', uri, abortTrigger: aborter.future)
            ..followRedirects = false
            ..maxRedirects = 0;
      final operation = _sendAndRead(request);
      operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
      final response = await Future.any<_DecodedResponse>([
        operation,
        aborter.future.then<_DecodedResponse>((_) {
          throw CocktailApiException(
            timedOut
                ? CocktailApiErrorKind.timeout
                : CocktailApiErrorKind.closed,
          );
        }),
      ]);
      if (_closed) throw _closedError();
      if (response.statusCode == 429) {
        throw CocktailApiException(
          CocktailApiErrorKind.rateLimited,
          statusCode: 429,
          retryAfter: _retryAfter(response.headers['retry-after']),
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CocktailApiException(
          CocktailApiErrorKind.http,
          statusCode: response.statusCode,
        );
      }
      if (timedOut)
        throw const CocktailApiException(CocktailApiErrorKind.timeout);
      final decoded = jsonDecode(utf8.decode(response.bytes));
      if (decoded is! Map || !decoded.containsKey('drinks')) _invalid();
      final drinks = decoded['drinks'];
      if (drinks == null) return const [];
      if (drinks is! List) _invalid();
      final records = <Map<String, dynamic>>[];
      for (final record in drinks) {
        if (record is! Map) _invalid();
        records.add(Map<String, dynamic>.from(record));
      }
      return List.unmodifiable(records);
    } on CocktailApiException {
      rethrow;
    } on FormatException {
      throw const CocktailApiException(CocktailApiErrorKind.invalidResponse);
    } on http.RequestAbortedException {
      throw CocktailApiException(
        timedOut ? CocktailApiErrorKind.timeout : CocktailApiErrorKind.closed,
      );
    } on http.ClientException {
      throw const CocktailApiException(CocktailApiErrorKind.network);
    } on TimeoutException {
      throw const CocktailApiException(CocktailApiErrorKind.timeout);
    } catch (_) {
      throw const CocktailApiException(CocktailApiErrorKind.network);
    } finally {
      timer?.cancel();
      _aborters.remove(aborter);
    }
  }

  Future<_DecodedResponse> _sendAndRead(http.BaseRequest request) async {
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await _discard(response.stream);
      return _DecodedResponse(
        response.statusCode,
        response.headers,
        Uint8List(0),
      );
    }
    return _DecodedResponse(
      response.statusCode,
      response.headers,
      await _readBounded(response.stream),
    );
  }

  Future<Uint8List> _readBounded(Stream<List<int>> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (builder.length + chunk.length > maxResponseBytes) _invalid();
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

  String _requiredText(String value, String name) {
    final trimmed = value.trim();
    if (trimmed.isEmpty)
      throw ArgumentError.value(value, name, 'Must not be blank.');
    return trimmed;
  }

  Never _invalid() =>
      throw const CocktailApiException(CocktailApiErrorKind.invalidResponse);

  Recipe _parseRecipe(Map<String, dynamic> json) {
    try {
      return Recipe.fromJson(json);
    } on FormatException {
      _invalid();
    }
  }

  RecipeSummary _parseSummary(Map<String, dynamic> json) {
    try {
      return RecipeSummary.fromJson(json);
    } on FormatException {
      _invalid();
    }
  }

  CocktailApiException _closedError() =>
      const CocktailApiException(CocktailApiErrorKind.closed);

  void close() {
    if (_closed) return;
    _closed = true;
    _cache.clear();
    for (final aborter in _aborters.toList()) {
      if (!aborter.isCompleted) aborter.complete();
    }
    if (_ownsClient) _client.close();
  }
}

final class _CacheEntry<T> {
  const _CacheEntry(this.value, this.createdAt);

  final T value;
  final DateTime createdAt;

  bool isExpired(DateTime now, Duration ttl) =>
      now.difference(createdAt) >= ttl;
}

final class _DecodedResponse {
  const _DecodedResponse(this.statusCode, this.headers, this.bytes);

  final int statusCode;
  final Map<String, String> headers;
  final Uint8List bytes;
}
