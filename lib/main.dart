import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/solid_service.dart';
import 'services/share_service.dart';
import 'theme/app_colors.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/ai_coach_screen.dart';
import 'screens/records_screen.dart';
import 'screens/pod_info_screen.dart';
import 'screens/pod_explorer_screen.dart';
import 'screens/share_screen.dart';
import 'screens/share_history_screen.dart';
import 'screens/recipient_view_screen.dart';

/// MediSync - Consent-Driven AI Health Coach
///
/// This app demonstrates how to build a privacy-first health application
/// using Solid Protocol. Your health data stays in YOUR Pod, and you control
/// who can access it and for how long.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Solid authentication service
  final solidService = SolidService();

  // Local-only service for the "Share with Doctor" feature (no network/AI).
  final shareService = ShareService();
  // Warm the in-memory cache so the share history is ready on first open.
  shareService.load();

  // Paint the first frame immediately. Session restore talks to the OIDC
  // layer, which on web can take a while (or stall) — blocking runApp() on it
  // leaves the user staring at a blank white screen. Instead we render right
  // away (the router shows /login until auth resolves) and restore the session
  // in the background. The router listens to [solidService], so a successfully
  // restored session redirects to home automatically.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SolidService>.value(value: solidService),
        ChangeNotifierProvider<ShareService>.value(value: shareService),
      ],
      child: const MediSyncApp(),
    ),
  );

  // Best-effort restore; a timeout guards against a stalled OIDC call so we
  // never get stuck in a perpetual loading state.
  solidService.initializeSession().timeout(
    const Duration(seconds: 8),
    onTimeout: () {},
  );
}

class MediSyncApp extends StatelessWidget {
  const MediSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MediSync Lab',
      theme: _buildTheme(context),
      routerConfig: _buildRouter(context),
      debugShowCheckedModeBanner: false,
    );
  }

  /// Build the app router with authentication-aware navigation
  GoRouter _buildRouter(BuildContext context) {
    return GoRouter(
      initialLocation: '/',
      // Re-run [redirect] whenever auth state changes (e.g. a background
      // session restore completes) so the user is moved to the right screen.
      refreshListenable: context.read<SolidService>(),
      redirect: (context, state) {
        // Check if user is authenticated
        final solidService = context.read<SolidService>();
        final isLoggedIn = solidService.isLoggedIn;

        // A recipient opening a shared link is, by definition, not the logged-in
        // user — so the recipient view is public and skips the auth redirect.
        // The share itself is a self-contained, read-only, time-limited snapshot.
        if (state.matchedLocation.startsWith('/shared/')) {
          return null;
        }

        // Redirect to login if not authenticated
        if (!isLoggedIn && state.matchedLocation != '/login') {
          return '/login';
        }

        // Redirect to home if already logged in and trying to access login
        if (isLoggedIn && state.matchedLocation == '/login') {
          return '/';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: 'coach',
              builder: (context, state) => const AiCoachScreen(),
            ),
            GoRoute(
              path: 'records',
              builder: (context, state) => const RecordsScreen(),
            ),
            GoRoute(
              path: 'pod-info',
              builder: (context, state) => const PodInfoScreen(),
            ),
            GoRoute(
              path: 'pod-explorer',
              builder: (context, state) => const PodExplorerScreen(),
            ),
            GoRoute(
              path: 'share',
              builder: (context, state) => const ShareScreen(),
            ),
            GoRoute(
              path: 'share-history',
              builder: (context, state) => const ShareHistoryScreen(),
            ),
          ],
        ),
        // Public, auth-exempt recipient view reached via a shared link.
        GoRoute(
          path: '/shared/:token',
          builder: (context, state) => RecipientViewScreen(
            token: state.pathParameters['token'] ?? '',
          ),
        ),
      ],
    );
  }

  /// Build the light "Medical teal + mint" theme for MediSync.
  ///
  /// Design Philosophy:
  /// - Clean, near-white background (clinical, HealthPod-inspired)
  /// - Teal primary with mint accents
  /// - White cards with soft borders + gentle shadows
  ThemeData _buildTheme(BuildContext context) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.accent,
        tertiary: AppColors.accent,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.danger,
      ),

      // Typography
      textTheme: GoogleFonts.spaceGroteskTextTheme(
        Theme.of(context).textTheme.apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        ),
      ).copyWith(
        // Display fonts use Syne for more personality
        displayLarge: GoogleFonts.syne(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        displayMedium: GoogleFonts.syne(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
        headlineSmall: GoogleFonts.syne(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
      ),

      // Component themes
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),

      // Button styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      // Input field styling
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintStyle: const TextStyle(color: AppColors.textFaint),
      ),

      // Card styling
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.primary.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      dividerColor: AppColors.border,
    );
  }
}
