import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../account/data/account_repository.dart';
import '../../collection/sync/sync_exceptions.dart';
import 'home_bar_sync_contract.dart';

/// HTTP implementation of the independent home-bar sync stream.
final class HttpHomeBarSyncApi implements HomeBarSyncApi {
  HttpHomeBarSyncApi({
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
  Future<HomeBarSyncPage> pull({required int since, int limit = 200}) async {
    final response = await _send(
      'GET',
      'sync/bar-items',
      query: {'since': '$since', 'limit': '$limit'},
    );
    return HomeBarSyncPage.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<HomeBarRecord> putItem(HomeBarRecord record) async {
    final response = await _send(
      'PUT',
      'bar-items/${Uri.encodeComponent(record.ingredientId)}',
      jsonBody: record.toJson(),
    );
    return HomeBarRecord.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? jsonBody,
  }) async {
    final token = _account.sessionToken;
    var uri = _baseUrl.resolve(path);
    if (query != null) uri = uri.replace(queryParameters: query);
    final headers = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
      if (jsonBody != null) 'Content-Type': 'application/json',
    };
    final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(_timeout);
        case 'PUT':
          response = await _client
              .put(uri, headers: headers, body: jsonEncode(jsonBody))
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
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncApiException(response.statusCode, _errorCode(response));
    }
    return response;
  }

  String? _errorCode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      final error = decoded is Map ? decoded['error'] : null;
      return error is Map ? error['code'] as String? : null;
    } catch (_) {
      return null;
    }
  }
}
