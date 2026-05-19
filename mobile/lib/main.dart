import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/signup_page.dart';
import 'pages/analyst/analyst_home_page.dart';
import 'pages/pm/pm_dashboard_page.dart';
import 'pages/pm/prompt_responses_page.dart';
import 'widgets/protected_route.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();
  runApp(
    const ProviderScope(
      child: MindstreamApp(),
    ),
  );
}

// ── Router Setup ──────────────────────────────────────────────

final _routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    // Refresh listener for Riverpod auth state triggers route updates immediately
    refreshListenable: Listenable.merge([
      _NotifierListenable(ref.watch(authProvider.notifier)),
    ]),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.uri.toString();

      // If still loading session token from local storage, don't route anywhere
      if (auth.loading) return null;

      final isLoggedIn = auth.isAuthenticated;
      final isAuthPage = loc == '/login' || loc == '/signup';

      if (!isLoggedIn) {
        // Force redirect to login if not logged in and requesting inside pages
        return isAuthPage ? null : '/login';
      }

      if (isAuthPage) {
        // Logged in: redirect away from auth page to matching home
        return auth.profile?.role == 'pm' ? '/pm' : '/analyst';
      }

      if (loc == '/') {
        return auth.profile?.role == 'pm' ? '/pm' : '/analyst';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupPage(),
      ),
      GoRoute(
        path: '/analyst',
        builder: (_, __) => const ProtectedRoute(
          requiredRole: 'analyst',
          child: AnalystHomePage(),
        ),
      ),
      GoRoute(
        path: '/pm',
        builder: (_, __) => const ProtectedRoute(
          requiredRole: 'pm',
          child: PMDashboardPage(),
        ),
      ),
      GoRoute(
        path: '/pm/prompts/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return ProtectedRoute(
            requiredRole: 'pm',
            child: PromptResponsesPage(promptId: id),
          );
        },
      ),
    ],
  );
});

// Helper class to map StateNotifier to Listenable for GoRouter
class _NotifierListenable extends ChangeNotifier {
  _NotifierListenable(StateNotifier notifier) {
    notifier.addListener((_) => notifyListeners());
  }
}

// ── Main App Widget ───────────────────────────────────────────

class MindstreamApp extends ConsumerWidget {
  const MindstreamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'Shunya Mindstream',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
