import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/auth_controller.dart';
import 'controllers/expense_controller.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/appwrite_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppwriteService.init();
  runApp(const SplitKhataApp());
}

class SplitKhataApp extends StatelessWidget {
  const SplitKhataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExpenseController()..load()),
        ChangeNotifierProvider(create: (_) => AuthController()..restore()),
      ],
      child: MaterialApp(
        title: 'Split Khata',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const RootScreen(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00897B),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF8F9FA)
          : const Color(0xFF121212),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: scheme.onSurface,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        ),
        extendedTextStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: brightness == Brightness.light
            ? Colors.white
            : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? Colors.grey.shade100
            : scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

/// Routes the app entry: splash → onboarding (first launch) → auth gate.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  static const _onboardedKey = 'split_onboarded';

  bool _splashDone = false;
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool(_onboardedKey) ?? false;
    // Let the splash animation play out fully before switching.
    await Future<void>.delayed(const Duration(milliseconds: 2700));
    if (!mounted) return;
    setState(() {
      _splashDone = true;
      _onboarded = onboarded;
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
    if (!mounted) return;
    setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (!_splashDone) {
      child = const SplashScreen();
    } else if (_onboarded != true) {
      child = OnboardingScreen(onDone: _finishOnboarding);
    } else {
      child = const AuthGate();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: KeyedSubtree(key: ValueKey(child), child: child),
    );
  }
}

/// Routes between splash / auth / home based on [AuthController.status].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthController, AuthStatus>((a) => a.status);
    final child = switch (status) {
      AuthStatus.unknown => const SplashScreen(showMadeBy: false),
      AuthStatus.signedOut => const AuthScreen(),
      AuthStatus.signedIn => const HomeScreen(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: KeyedSubtree(key: ValueKey(status), child: child),
    );
  }
}
