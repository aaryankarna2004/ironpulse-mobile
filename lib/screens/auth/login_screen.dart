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
  bool _isStaffSelected = true;
  bool _keepActive = true;
  List<Gym> _gyms = [];
  Gym? _selectedGym;
  bool _loadingGyms = true;

  // Tailwind mapped colors
  static const _bg = Color(0xFF111316);
  static const _surface = Color(0xFF111316);
  static const _surfaceLowest = Color(0xFF0C0E11);
  static const _surfaceLow = Color(0xFF1A1C1F);
  static const _surfaceContainer = Color(0xFF1E2023);
  static const _surfaceHigh = Color(0xFF282A2D);
  static const _primaryContainer = Color(0xFFC3F400);
  static const _onPrimary = Color(0xFF161E00);
  static const _onSurface = Color(0xFFE2E2E6);
  static const _onSurfaceVariant = Color(0xFFC4C9AC);
  static const _outline = Color(0xFF8E9379);
  static const _secondaryDim = Color(0xFF00DBE9);
  static const _onSecondary = Color(0xFF00363A);
  static const _errorBg = Color(0xFF93000A);

  @override
  void initState() {
    super.initState();
    _fetchGyms();
  }

  Future<void> _fetchGyms() async {
    setState(() => _loadingGyms = true);
    try {
      // Try Hive cache first (if prior sync happened)
      final cached = LocalDatabaseService.instance.getGyms();
      if (cached.isNotEmpty) {
        setState(() {
          _gyms = cached;
          _selectedGym = cached.first;
          _loadingGyms = false;
        });
        return;
      }
    } catch (_) {}
    try {
      final data = await _supabase.from('gyms').select('id, name, subdomain, status, subscription_status, price_per_member, billing_currency, created_at').order('name');
      final list = (data as List).map((m) => Gym.fromJson(Map<String, dynamic>.from(m as Map))).toList();
      if (mounted) {
        setState(() {
          _gyms = list;
          if (list.isNotEmpty) _selectedGym = list.first;
          _loadingGyms = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingGyms = false);
    }
  }

  void _showGymPicker() {
    if (_gyms.isEmpty && !_loadingGyms) {
      _fetchGyms();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No gyms found. Check Supabase connection.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: _surfaceContainer, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Select Active Hub', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 14, fontWeight: FontWeight.w700, color: _onSurface)),
            ),
            const SizedBox(height: 8),
            if (_loadingGyms)
              const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _primaryContainer, strokeWidth: 2))
            else if (_gyms.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Text('No gyms available in Supabase (gyms table empty)', style: TextStyle(color: _onSurfaceVariant, fontSize: 12)))
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _gyms.length,
                  separatorBuilder: (context, _) => Divider(color: _surfaceContainer, height: 1),
                  itemBuilder: (context, i) {
                    final g = _gyms[i];
                    final selected = _selectedGym?.id == g.id;
                    return ListTile(
                      leading: Icon(Icons.storefront_outlined, color: selected ? _primaryContainer : _onSurfaceVariant, size: 20),
                      title: Text(g.name, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600, color: selected ? _primaryContainer : _onSurface)),
                      subtitle: Text('${g.subdomain} • ${g.status}', style: const TextStyle(fontSize: 11, color: _onSurfaceVariant)),
                      trailing: selected ? const Icon(Icons.check_circle, color: _primaryContainer, size: 20) : null,
                      onTap: () {
                        setState(() => _selectedGym = g);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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

        String gymId = data['gymId'] as String? ??
            data['gym_id'] as String? ??
            jwtPayload?['gymId'] as String? ??
            '';
        // If API didn't return gym (e.g., fallback membership) use picker selection so gym data appears
        if (gymId.isEmpty && _selectedGym != null) gymId = _selectedGym!.id;

        final String userId = userMap?['id'] as String? ??
            jwtPayload?['userId'] as String? ??
            '';
        final String fullName = userMap?['full_name'] as String? ??
            userMap?['name'] as String? ??
            '';

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

        await _syncLocalData(gymId);

        _routeUserBasedOnRole(gymMember, role);
        return;
      } else {
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
          // Fallback to picker if membership has empty gym (orphan user)
          if (gymMember.gymId.isEmpty && _selectedGym != null) {
            gymMember = gymMember.copyWith(gymId: _selectedGym!.id);
          }
        } else {
          role = user.isSuperAdmin ? 'owner' : 'member';
          final fallbackGymId = _selectedGym?.id ?? '';
          gymMember = GymMember(
            id: user.id,
            gymId: fallbackGymId,
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
    } catch (_) {}
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
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildBackdropHeader(),
              _buildFormCanvas(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackdropHeader() {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuBpEHR-NmAI91G73sYTtz3Qnx1BpVpOBm0VPYSvjZwGnIVAWhfg5FFDC6wEIj-rfQzy1LYxQ4Nz2XFyecd9uV_3RDJ2_lgBu5m-GXsFHs--Hf4ghn1XioUcaUKE41mYvrzKZ6jgYfkW9Qfk4DLIMN7f3jYUBh_skPGGsdQsbthRyx1iykcjW6BR7n-cyuMJjGgUglPHQG7UnxpBC8990P9AGc7N63ZgsHLeclfGkrk-UNcaDa_JumkR',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(color: _surfaceLowest),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xB31A1C1F),
                  Colors.transparent,
                  _surface,
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  _surface,
                  Color(0xD91E2023),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 0.95],
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _surfaceHigh,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 16)
                      ],
                    ),
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuAMzP1uWP91aPYbD3oyefFLVLG8mZWCQZKG06NcOgVgeAdLedpDGPG3Tku9G0Kv1IWlg--nmBHFxeR8QoMdxdml3-cPs4Fpyekutw4ZjEM_mQdFR8j03uMms0zfhqRHUuvVnBsdK-UydWMnVj8_BvIZo-eZidMyuDETZLEkdQBsSfRwKi2ZC4IQVVt3Z5jFbVF71s5-N17dxgkdMyIkDVUkl8V4oR6iqy0OcyKcLxwMGHxycC0zY8HN',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.bolt,
                        color: _primaryContainer,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      children: [
                        TextSpan(text: 'IRON ', style: TextStyle(color: _onSurface)),
                        TextSpan(text: 'PULSE', style: TextStyle(color: _primaryContainer)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Empowering fitness operations & member performance',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: _onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCanvas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        children: [
          _buildRoleSelector(),
          const SizedBox(height: 16),
          _buildFacilityPill(),
          const SizedBox(height: 16),
          _buildLoginCard(),
          const SizedBox(height: 16),
          _buildBiometricButton(),
          const SizedBox(height: 16),
          _buildNfcCard(),
          const SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
        children: [
          _roleButton(
            selected: _isStaffSelected,
            icon: Icons.badge_outlined,
            label: 'Staff / Trainer',
            onTap: () => setState(() => _isStaffSelected = true),
          ),
          _roleButton(
            selected: !_isStaffSelected,
            icon: Icons.fitness_center_outlined,
            label: 'Gym Member',
            onTap: () => setState(() => _isStaffSelected = false),
          ),
        ],
      ),
    );
  }

  Widget _roleButton({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? _primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [BoxShadow(color: _primaryContainer.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: -2)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? _onPrimary : _onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.6,
                  color: selected ? _onPrimary : _onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacilityPill() {
    final gymLabel = _loadingGyms
        ? 'Loading gyms…'
        : _selectedGym != null
            ? '${_selectedGym!.name} • ${_selectedGym!.subdomain}'
            : _gyms.isEmpty
                ? 'No gyms found'
                : 'Select gym';
    final subLabel = _gyms.isEmpty && !_loadingGyms ? 'Tap to retry' : '${_gyms.length} gym(s) available';
    return InkWell(
      onTap: _showGymPicker,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _surfaceLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _primaryContainer.withValues(alpha: 0.0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.pin_drop_outlined, color: _secondaryDim, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'ACTIVE HUB',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: _onSurfaceVariant,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (_loadingGyms)
                        const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: _onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gymLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _onSurface,
                    ),
                  ),
                  Text(
                    subLabel,
                    style: const TextStyle(fontSize: 10, color: _onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more, color: _onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    final identifierLabel = _isStaffSelected ? 'Staff ID or Corporate Email' : 'Member Key ID or Registered Email';
    final identifierHint = _isStaffSelected ? 'e.g. STF-88492 or trainer@voltgym.com' : 'e.g. MEM-44019 or athlete@athlete.com';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _errorBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFB4AB).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFFFDAD6), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFFFDAD6), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            // Identifier Field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      identifierLabel.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: _onSurfaceVariant,
                      ),
                    ),
                    const Text(
                      'REQUIRED',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _primaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  autocorrect: false,
                  style: const TextStyle(color: _onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _surfaceLowest,
                    hintText: identifierHint,
                    hintStyle: TextStyle(color: _onSurfaceVariant.withValues(alpha: 0.55), fontSize: 13),
                    prefixIcon: const Icon(Icons.account_circle_outlined, color: _onSurfaceVariant, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _outline, width: 1)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter your ID or email';
                    if (val.contains('@') && (!val.contains('.') || val.length < 5)) return 'Please enter a valid email address';
                    if (val.trim().length < 3) return 'Too short';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Password Field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SECURITY PASSCODE',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: _onSurfaceVariant,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        'FORGOT KEY?',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _secondaryDim,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: _onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _surfaceLowest,
                    hintText: '••••••••••••',
                    hintStyle: TextStyle(color: _onSurfaceVariant.withValues(alpha: 0.55)),
                    prefixIcon: const Icon(Icons.lock_outline, color: _onSurfaceVariant, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _onSurfaceVariant, size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _outline, width: 1)),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Please enter your passcode';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _keepActive,
                    onChanged: (v) => setState(() => _keepActive = v ?? true),
                    activeColor: _primaryContainer,
                    checkColor: _onPrimary,
                    side: const BorderSide(color: _outline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Keep shift active', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: _onSurfaceVariant)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _onSecondary, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF00EEFC), shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      const Text('256-BIT ENCRYPTED', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: _secondaryDim)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryContainer,
                  foregroundColor: _onPrimary,
                  disabledBackgroundColor: _primaryContainer.withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  shadowColor: _primaryContainer.withValues(alpha: 0.4),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: _onPrimary))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('AUTHORIZE & ENTER', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: _surfaceHigh,
          foregroundColor: _onSurface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: _surfaceLowest, shape: BoxShape.circle),
              child: const Icon(Icons.face_outlined, color: _primaryContainer, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Biometric Log In', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 13, fontWeight: FontWeight.w700, color: _onSurface, height: 1.0)),
                  SizedBox(height: 2),
                  Text('FaceID or Touch Sensor Enabled', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: _onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNfcCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _surfaceLowest, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.contactless_outlined, color: _secondaryDim, size: 26),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tap Physical Access Card', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, fontWeight: FontWeight.w600, color: _onSurface)),
                Text('Hold gym key fob near device', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: _onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _surfaceContainer, borderRadius: BorderRadius.circular(6)),
            child: const Text('NFC Ready', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Text('Need terminal access or lost credentials?', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, color: _onSurfaceVariant)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {},
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contact_support_outlined, color: _primaryContainer, size: 16),
              SizedBox(width: 6),
              Text('Contact Club Administrator', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _primaryContainer)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('IRON PULSE OS v4.12.0', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 9, fontWeight: FontWeight.w500, color: _onSurfaceVariant.withValues(alpha: 0.6))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('•', style: TextStyle(color: _onSurfaceVariant.withValues(alpha: 0.6), fontSize: 9)),
            ),
            Text('SERVER: US-EAST-CLUSTER', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 9, fontWeight: FontWeight.w500, color: _onSurfaceVariant.withValues(alpha: 0.6))),
          ],
        ),
      ],
    );
  }
}
