// Project Services — Flutter app (one app, two roles).
// Customer: browse categories/services, book with photos, track bookings.
// Provider: dashboard, jobs, earnings, availability.
// Admin is web-only (website /admin).
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/strings.dart';
import 'models.dart';
import 'repository.dart';
import 'screens/auth_screen.dart';
import 'screens/customer_shell.dart';
import 'screens/provider_shell.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await languageService.load();
  await initSupabase();
  NotificationService.messengerKey = scaffoldMessengerKey;
  await NotificationService.init();
  runApp(const ProjectServicesApp());
}

class ProjectServicesApp extends StatelessWidget {
  const ProjectServicesApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole app when the language changes, so every
    // tr('…') string on screen switches immediately.
    //
    // The ValueKey is essential, not cosmetic: without it, `home` is the
    // same `const AuthGate()` instance on every rebuild, and Flutter
    // short-circuits identical widgets — the AuthGate subtree is never
    // re-invoked, tr() is never re-evaluated, and the visible screen stays
    // in the old language even though the service value changed (20 Nov:
    // tapping Urdu changed nothing, not even the bottom tabs). Keying
    // MaterialApp on the language forces the whole subtree — Navigator,
    // routes and all — to be rebuilt in the new language.
    return ValueListenableBuilder<String>(
      valueListenable: languageService,
      builder: (context, lang, _) {
        return MaterialApp(
          key: ValueKey(lang),
          title: tr('appName'),
          locale: Locale(lang),
          theme: buildTheme(),
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: db.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? db.auth.currentSession;
        if (session == null) {
          return const AuthScreen();
        }
        return FutureBuilder<Profile?>(
          future: currentProfile(),
          builder: (context, profSnap) {
            if (profSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final profile = profSnap.data;
            if (profile == null) {
              // Signed in but no profiles row (e.g. phone conflict at sign-up).
              // Send back to sign-in rather than crashing.
              return const AuthScreen();
            }
            if (profile.role == 'provider') {
              return ProviderShell(profile: profile);
            }
            // customer + admin both use the customer shell (admin tools are web-only).
            return CustomerShell(profile: profile);
          },
        );
      },
    );
  }
}
