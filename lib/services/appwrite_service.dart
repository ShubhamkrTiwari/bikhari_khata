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

  static bool _ready = false;

  /// True once [init] has completed. Guards callers in tests / before startup.
  static bool get isReady => _ready;

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

    // IMPORTANT: the secret API key is intentionally NOT attached here. This
    // is a client-side app; auth (email/password) works with just the
    // endpoint + project ID and a session cookie. Sending the secret key
    // would make Appwrite treat every call as the "applications" role and
    // reject account operations with "missing scopes ([account])". Keep the
    // key in .env for trusted server-side use only.

    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
    functions = Functions(client);
    messaging = Messaging(client);
    realtime = Realtime(client);
    _ready = true;
  }
}
