import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ironpulse/models/models.dart';
import 'package:ironpulse/screens/admin/admin_home_screen.dart';
import 'package:ironpulse/screens/auth/login_screen.dart';
import 'package:ironpulse/screens/member/member_home_screen.dart';
import 'package:ironpulse/services/local_database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge dark Volt theme for Android/iOS status & nav bars
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF111316),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Supabase.initialize(
    url: 'https://qtwacvzlaprhtuuehfsu.supabase.co',
    publishableKey: 'sb_publishable_bCjvGYMc7wYq1gK2Y03-Dg_o5c_csXE',
  );
  // Initialize Hive local cache (Hive.initFlutter uses path_provider – works on Android/iOS/Web)
  await LocalDatabaseService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Iron Pulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111316),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFC3F400),
          secondary: Color(0xFF00DBE9),
          surface: Color(0xFF1E2023),
          onSurface: Color(0xFFE2E2E6),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111316),
          surfaceTintColor: Colors.transparent,
          foregroundColor: Color(0xFFE2E2E6),
        ),
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
      },
      home: const SplashRouter(),
    );
  }
}

/// Checks for stored tokens and cached data to auto-login,
/// or shows the login screen if no session exists.
class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    const storage = FlutterSecureStorage();
    final userId = await storage.read(key: 'user_id');
    final role = await storage.read(key: 'user_role');
    final gymId = await storage.read(key: 'gym_id');

    if (userId == null || userId.isEmpty || role == null || role.isEmpty) {
      // No stored session — go to login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    // We have stored credentials — try to build a GymMember from cache
    final db = LocalDatabaseService.instance;
    GymMember? cachedMember;

    if (db.hasCachedData) {
      // Look up this user's gym_member record from Hive
      final members = db.getGymMembers();
      cachedMember = members.cast<GymMember?>().firstWhere(
            (m) => m?.userId == userId,
            orElse: () => null,
          );
    }

    // Fallback: construct a minimal GymMember from stored metadata
    cachedMember ??= GymMember(
      id: userId,
      gymId: gymId ?? '',
      userId: userId,
      role: role,
      status: 'active',
      createdAt: DateTime.now(),
      user: User(
        id: userId,
        email: '',
        fullName: '',
        createdAt: DateTime.now(),
      ),
    );

    if (!mounted) return;

    final normalizedRole = role.toLowerCase().trim();
    if (normalizedRole == 'admin' ||
        normalizedRole == 'owner' ||
        normalizedRole == 'super_admin') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AdminHomeScreen(gymMember: cachedMember),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MemberHomeScreen(gymMember: cachedMember),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Brief Iron Pulse splash while checking session (Android/iOS launch parity)
    return const Scaffold(
      backgroundColor: Color(0xFF111316),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bolt_rounded,
              size: 56,
              color: Color(0xFFC3F400),
            ),
            SizedBox(height: 16),
            Text(
              'IRON',
              style: TextStyle(
                color: Color(0xFFE2E2E6),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            Text(
              'PULSE',
              style: TextStyle(
                color: Color(0xFFC3F400),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFFC3F400), strokeWidth: 2.5),
          ],
        ),
      ),
    );
  }
}