import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:zest/features/discovery/data/cocktail_db_client.dart';

/// Runs the real Fastify routes against a synthetic upstream, without
/// listeners. `lookup.php` is the only client-facing recipe route left
/// (docs/GATEWAY.md "Gateway cleanup"): search/filter/list moved to the
/// server-owned shared catalog and its refresher.
Future<void> main() async {
  final transport = _GatewayContractTransport();
  final client = CocktailDbClient(client: transport);
  try {
    final detail = await client.lookupRecipe('990001');
    await client.lookupRecipe('990001');
    if (detail?.ingredients.single.measure.raw != '1 1/2 oz' ||
        transport.requests != 1) {
      throw StateError('Gateway contract mismatch.');
    }
    stdout.writeln(
      'Flutter → Fastify → synthetic upstream: lookup.php passed.',
    );
    stdout.writeln(
      'Source measure retained; repeated lookup uses the Flutter cache.',
    );
    stdout.writeln(
      'No listening server, real API request, private key or provider files.',
    );
  } finally {
    client.close();
    transport.close();
  }
}

final class _GatewayContractTransport extends http.BaseClient {
  int requests = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    final result = await Process.run('node', [
      '--import',
      'tsx',
      'tool/contract_fixture.ts',
      request.url.toString(),
    ], workingDirectory: '../backend');
    if (result.exitCode != 0)
      throw StateError(
        'Synthetic gateway process failed. Run npm ci in backend first.',
      );
    final response =
        jsonDecode(result.stdout as String) as Map<String, dynamic>;
    return http.StreamedResponse(
      Stream.value(utf8.encode(response['body'] as String)),
      response['status'] as int,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
