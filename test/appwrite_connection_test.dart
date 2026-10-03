import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:flutter_test/flutter_test.dart';

/// Live connectivity check against the Appwrite cloud project.
/// Run with: flutter test test/appwrite_connection_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Appwrite project reachable and API key valid', () async {
    final env = <String, String>{};
    for (final line in File('.env').readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final i = trimmed.indexOf('=');
      if (i > 0) {
        env[trimmed.substring(0, i)] = trimmed.substring(i + 1);
      }
    }

    final client = Client()
      ..setEndpoint(env['APPWRITE_ENDPOINT']!)
      ..setProject(env['APPWRITE_PROJECT_ID']!)
      ..setDevKey(env['APPWRITE_API_KEY']!);

    final ping = await client.ping();
    expect(ping, 'OK');

    // Authenticated call - proves the API key works.
    final user = await Account(client).get();
    // ignore: avoid_print
    print('Connected! Project account: ${user.name} ${user.email ?? ""}');
  });
}
