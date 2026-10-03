import 'package:appwrite/appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central Appwrite backend initialization for Split Khata.
///
/// Credentials live in the root `.env` file (git-ignored):
///   APPWRITE_ENDPOINT  - region URL, e.g. https://in01.cloud.appwrite.io/v1
///   APPWRITE_PROJECT_ID - project ID from the console
///   APPWRITE_API_KEY   - the Split_Khata API key (Auth/Databases/Functions/
///                        Storage/Messaging scopes)
///
/// Call [AppwriteService.init] once from `main()` before [runApp].
class AppwriteService {
  AppwriteService._();

  static late final Client client;
  static late final Account account;
  static late final Databases databases;
  static late final Storage storage;
  static late final Functions functions;
  static late final Messaging messaging;
  static late final Realtime realtime;

  static bool get isConfigured =>
      dotenv.env['APPWRITE_PROJECT_ID'] != null &&
      dotenv.env['APPWRITE_PROJECT_ID']!.isNotEmpty &&
      dotenv.env['APPWRITE_PROJECT_ID'] != 'YOUR_PROJECT_ID_HERE';

  static String get endpoint => dotenv.env['APPWRITE_ENDPOINT'] ?? '';
  static String get projectId => dotenv.env['APPWRITE_PROJECT_ID'] ?? '';

  /// Loads .env and builds the Appwrite client + service instances.
  static Future<void> init() async {
    await dotenv.load(fileName: '.env');

    client = Client()
      ..setEndpoint(dotenv.env['APPWRITE_ENDPOINT'] ?? '')
      ..setProject(projectId);

    // The secret API key (dev key) should ideally only be used server-side
    // (functions). It is attached here so direct calls work during development.
    final apiKey = dotenv.env['APPWRITE_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) client.setDevKey(apiKey);

    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
    functions = Functions(client);
    messaging = Messaging(client);
    realtime = Realtime(client);
  }
}
