import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zest/core/network/cocktail_api_exception.dart';
import 'package:zest/features/discovery/data/cocktail_db_client.dart';

/// One-shot data-layer demo. Offline by default; --live makes one public lookup.
/// Neither mode writes files. Live mode prints no recipe content or request URL.
Future<void> main(List<String> args) async {
  if (args.isNotEmpty && (args.length != 1 || args.single != '--live')) {
    stderr.writeln('Usage: dart run tool/m2_demo.dart [--live]');
    exitCode = 64;
    return;
  }
  final live = args.contains('--live');
  final http.Client transport;
  if (live) {
    transport = http.Client();
  } else {
    final fixture = File(
      'test/fixtures/synthetic_drinks.json',
    ).readAsStringSync();
    transport = MockClient(
      (_) async => http.Response(
        fixture,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
  }
  final counted = _CountingClient(transport);
  final client = CocktailDbClient(client: counted);
  try {
    // Public documentation's example ID, not a vendored provider record.
    final id = live ? '11007' : '900001';
    final first = await client.lookupRecipe(id);
    final second = await client.lookupRecipe(id);
    if (first == null || !identical(first, second) || counted.requests != 1) {
      throw StateError('Lookup/cache demo did not meet its checks.');
    }
    stdout.writeln(
      '${live ? 'Live' : 'Synthetic'} lookup: full recipe decoded.',
    );
    stdout.writeln(
      'Two lookups; ${counted.requests} HTTP request; second served from cache.',
    );
    if (!live) {
      stdout.writeln(
        'Synthetic ingredient slots: ${first.ingredients.map((i) => i.sourceSlot).join(', ')}.',
      );
      stdout.writeln(
        'Original: ${jsonEncode(first.ingredients.first.rawName)}; normalized: ${first.ingredients.first.normalizedName}.',
      );
      stdout.writeln(
        'Measure: ${first.ingredients.first.measure.amount} ${first.ingredients.first.measure.unit}; source text retained.',
      );
    }
    stdout.writeln('No provider content or images written to disk.');
  } on CocktailApiException catch (error) {
    stderr.writeln('Demo failed: $error');
    exitCode = 1;
  } catch (_) {
    // Do not forward arbitrary transport errors: they can contain the key URI.
    stderr.writeln('Demo failed its local setup or result checks.');
    exitCode = 1;
  } finally {
    client.close();
    counted.close();
  }
}

final class _CountingClient extends http.BaseClient {
  _CountingClient(this.inner);
  final http.Client inner;
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests++;
    return inner.send(request);
  }

  @override
  void close() => inner.close();
}
