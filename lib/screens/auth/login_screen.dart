import 'dart:convert';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:ironpulse/models/models.dart';
import 'package:ironpulse/screens/admin/admin_home_screen.dart';
import 'package:ironpulse/services/local_database_service.dart';
import 'package:ironpulse/screens/member/member_home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _primaryApiUrl =
      'https://ironpulse.aaryankarna78.workers.dev/api/auth/login';
  static const String _fallbackApiUrl =
      'https://ironpulse.aaryankarna78.workers.dev/login';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Decodes JWT payload to extract claims like userId, role, and gymId
  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(payloadString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    // Step 1: Attempt login via Next.js API endpoint
    try {
      final requestBody = jsonEncode({
        'email': email,
        'password': password,
      });

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      http.Response response = await http.post(
        Uri.parse(_primaryApiUrl),
        headers: headers,
        body: requestBody,
      );

      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await http.post(
          Uri.parse(_fallbackApiUrl),
          headers: headers,
          body: requestBody,
        );
      }

      final dynamic responseData = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = responseData is Map<String, dynamic>
            ? responseData
            : <String, dynamic>{};

        // Extract tokens
        String? accessToken =
            data['accessToken'] as String? ?? data['access_token'] as String?;
        String? refreshToken =
            data['refreshToken'] as String? ?? data['refresh_token'] as String?;

        final setCookieHeader = response.headers['set-cookie'];
        if (setCookieHeader != null) {
          if (accessToken == null && setCookieHeader.contains('access_token=')) {
            final match =
                RegExp(r'access_token=([^;]+)').firstMatch(setCookieHeader);
            if (match != null) accessToken = match.group(1);
          }
          if (refreshToken == null &&
              setCookieHeader.contains('refresh_token=')) {
            final match =
                RegExp(r'refresh_token=([^;]+)').firstMatch(setCookieHeader);
            if (match != null) refreshToken = match.group(1);
          }
        }

        Map<String, dynamic>? jwtPayload;
        if (accessToken != null) {
          jwtPayload = _decodeJwtPayload(accessToken);
        }

        final userMap = data['user'] as Map<String, dynamic>?;
        final String role = (data['role'] as String? ??
                userMap?['role'] as String? ??
                jwtPayload?['role'] as String? ??
                'member')
            .toLowerCase()
            .trim();

        final String gymId = data['gymId'] as String? ??
            data['gym_id'] as String? ??
            jwtPayload?['gymId'] as String? ??
            '';

        final String userId = userMap?['id'] as String? ??
            jwtPayload?['userId'] as String? ??
            '';
        final String fullName = userMap?['full_name'] as String? ??
            userMap?['name'] as String? ??
            '';

        // Store tokens securely
        if (accessToken != null) {
          await _storage.write(key: 'access_token', value: accessToken);
        }
        if (refreshToken != null) {
          await _storage.write(key: 'refresh_token', value: refreshToken);
        }
        await _storage.write(key: 'user_role', value: role);
        await _storage.write(key: 'gym_id', value: gymId);
        await _storage.write(key: 'user_id', value: userId);

        if (!mounted) return;

        final gymMember = GymMember(
          id: userId,
          gymId: gymId,
          userId: userId,
          role: role,
          status: 'active',
          createdAt: DateTime.now(),
          user: User(
            id: userId,
            email: userMap?['email'] as String? ?? email,
            fullName: fullName,
            isSuperAdmin: role == 'owner' || role == 'super_admin',
            createdAt: DateTime.now(),
          ),
        );

        // Sync all data to local Hive cache
        await _syncLocalData(gymId);

        _routeUserBasedOnRole(gymMember, role);
        return;
      } else {
        // Explicit 400/401 credential error from API
        String errorMsg = 'Invalid email or password.';
        if (responseData is Map<String, dynamic>) {
          errorMsg = responseData['error'] as String? ??
              responseData['message'] as String? ??
              errorMsg;
        }
        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {
      // Step 2: Fallback to direct database verification if network / CORS blocks API
      try {
        final userMap = await _supabase
            .from('users')
            .select('id, email, password_hash, full_name, is_super_admin, created_at')
            .eq('email', email)
            .maybeSingle();

        if (userMap == null) {
          setState(() {
            _errorMessage = 'Invalid email or password.';
            _isLoading = false;
          });
          return;
        }

        final passwordHash = userMap['password_hash'] as String?;
        if (passwordHash == null || !BCrypt.checkpw(password, passwordHash)) {
          setState(() {
            _errorMessage = 'Invalid email or password.';
            _isLoading = false;
          });
          return;
        }

        final user = User.fromJson(userMap);

        final memberMap = await _supabase
            .from('gym_members')
            .select('*, users(*)')
            .eq('user_id', user.id)
            .maybeSingle();

        if (!mounted) return;

        GymMember gymMember;
        String role = 'member';
        if (memberMap != null) {
          gymMember = GymMember.fromJson(memberMap);
          role = gymMember.role.toLowerCase().trim();
        } else {
          role = user.isSuperAdmin ? 'owner' : 'member';
          gymMember = GymMember(
            id: user.id,
            gymId: '',
            userId: user.id,
            role: role,
            status: 'active',
            createdAt: user.createdAt,
            user: user,
          );
        }

        await _storage.write(key: 'user_role', value: role);
        await _storage.write(key: 'gym_id', value: gymMember.gymId);
        await _storage.write(key: 'user_id', value: user.id);

        // Sync all data to local Hive cache
        await _syncLocalData(gymMember.gymId);

        _routeUserBasedOnRole(gymMember, role);
      } catch (dbError) {
        setState(() {
          _errorMessage = 'Login failed: Unable to authenticate ($dbError)';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncLocalData(String gymId) async {
    try {
      await LocalDatabaseService.instance.syncFromSupabase(gymId);
    } catch (_) {
      // Non-fatal — app can still work without cached data
    }
  }

  void _routeUserBasedOnRole(GymMember gymMember, String role) {
    if (!mounted) return;

    if (role == 'admin' || role == 'owner' || role == 'super_admin') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AdminHomeScreen(gymMember: gymMember),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MemberHomeScreen(gymMember: gymMember),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo & Heading
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF6B00),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          size: 42,
                          color: Color(0xFFFF6B00),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'IRONPULSE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to access your gym portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Error Alert Banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7F1D1D),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFFCA5A5), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFFEE2E2),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Email Field
                    Text(
                      'Email Address',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        hintText: 'user@example.com',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        prefixIcon: const Icon(Icons.email_outlined,
                            color: Color(0xFFFF6B00)),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF334155)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFFF6B00)),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!val.contains('@') || !val.contains('.')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Password Field
                    Text(
                      'Password',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        hintText: '••••••••',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Color(0xFFFF6B00)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey.shade400,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF334155)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF334155)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFFF6B00)),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B00),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFFFF6B00).withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
