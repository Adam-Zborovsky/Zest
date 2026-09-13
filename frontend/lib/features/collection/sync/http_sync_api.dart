import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../account/data/account_repository.dart';
import '../domain/memory_photo.dart';
import 'sync_contract.dart';
import 'sync_exceptions.dart';

/// [SyncApi] over the accounts/sync HTTP API. See `docs/ACCOUNTS.md`.
///
/// On a `401` it calls [AccountRepository.expireSession] and throws
/// [SyncUnauthorizedException]. Every transport failure (no network, DNS,
/// timeout) throws [SyncOfflineException], which `SyncEngine` maps to
/// `SyncPhase.offline`.
final class HttpSyncApi implements SyncApi {
  HttpSyncApi({
    required Uri baseUrl,
    required http.Client client,
    required AccountRepository account,
    Duration timeout = const Duration(seconds: 15),
  }) : _baseUrl = baseUrl,
       _client = client,
       _account = account,
       _timeout = timeout;

  final Uri _baseUrl;
  final http.Client _client;
  final AccountRepository _account;
  final Duration _timeout;

  @override
  Future<SyncPage> pull({required int since, int limit = 200}) async {
    final response = await _send(
      'GET',
      'sync/entries',
      query: {'since': '$since', 'limit': '$limit'},
    );
    return SyncPage.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<EntryRecord> putEntry(EntryRecord record) async {
    final response = await _send(
      'PUT',
      'entries/${record.id}',
      jsonBody: record.toJson(),
    );
    return EntryRecord.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<EntryRecord> putPhoto(
    String entryId,
    MemoryPhoto photo, {
    required DateTime updatedAt,
  }) async {
    final response = await _send(
      'PUT',
      'entries/$entryId/photo',
      query: {'updatedAt': updatedAt.toUtc().toIso8601String()},
      rawBody: photo.bytes,
      contentType: photo.mimeType,
    );
    return EntryRecord.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<EntryRecord> deletePhoto(
    String entryId, {
    required DateTime updatedAt,
  }) async {
    final response = await _send(
      'DELETE',
      'entries/$entryId/photo',
      query: {'updatedAt': updatedAt.toUtc().toIso8601String()},
    );
    return EntryRecord.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<MemoryPhoto?> getPhoto(String entryId) async {
    final response = await _send(
      'GET',
      'entries/$entryId/photo',
      allowNotFound: true,
    );
    if (response.statusCode == 404) return null;
    return MemoryPhoto.fromBytes(response.bodyBytes);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? jsonBody,
    List<int>? rawBody,
    String? contentType,
    bool allowNotFound = false,
  }) async {
    final token = _account.sessionToken;
    var uri = _baseUrl.resolve(path);
    if (query != null) uri = uri.replace(queryParameters: query);
    final headers = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
      if (jsonBody != null) 'Content-Type': 'application/json',
      if (contentType != null) 'Content-Type': contentType,
    };
    final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(_timeout);
        case 'PUT':
          response = await _client
              .put(
                uri,
                headers: headers,
                body: jsonBody != null ? jsonEncode(jsonBody) : rawBody,
              )
              .timeout(_timeout);
        case 'DELETE':
          response = await _client
              .delete(uri, headers: headers)
              .timeout(_timeout);
        default:
          throw UnsupportedError('Unsupported method $method');
      }
    } on TimeoutException {
      throw const SyncOfflineException();
    } on http.ClientException {
      throw const SyncOfflineException();
    } on SocketException {
      throw const SyncOfflineException();
    }
    if (response.statusCode == 401) {
      await _account.expireSession();
      throw const SyncUnauthorizedException();
    }
    if (allowNotFound && response.statusCode == 404) return response;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncApiException(response.statusCode, _errorCode(response));
    }
    return response;
  }

  String? _errorCode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) return error['code'] as String?;
      }
    } catch (_) {
      // Ignore a malformed error body; the status code is still reported.
    }
    return null;
  }
}
