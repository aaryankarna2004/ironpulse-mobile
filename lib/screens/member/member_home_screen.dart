import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ironpulse/models/models.dart';
import 'package:ironpulse/screens/auth/login_screen.dart';
import 'package:ironpulse/services/local_database_service.dart';

class MemberHomeScreen extends StatefulWidget {
  final GymMember? gymMember;

  const MemberHomeScreen({
    super.key,
    this.gymMember,
  });

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  final _localDb = LocalDatabaseService.instance;

  GymMember? _member;
  Gym? _gym;
  bool _isOffline = false;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _member = widget.gymMember;
    _loadData();
  }

  Future<void> _loadData() async {
    final gymId = _member?.gymId ?? '';

    // Load from cache first
    if (_localDb.hasCachedData) {
      _loadFromCache(gymId);
    }

    // Background sync
    try {
      await _localDb.syncFromSupabase(gymId);
      _loadFromCache(gymId);
      if (mounted) {
        setState(() {
          _isOffline = false;
          _lastSyncTime = _localDb.lastSyncTime;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _lastSyncTime = _localDb.lastSyncTime;
        });
      }
    }
  }

  void _loadFromCache(String gymId) {
    // Try to find a richer version of this member from cache
    final members = _localDb.getGymMembers();
    final cached = members.cast<GymMember?>().firstWhere(
          (m) => m?.userId == _member?.userId,
          orElse: () => null,
        );
    if (cached != null) {
      _member = cached;
    }

    if (gymId.isNotEmpty) {
      _gym = _localDb.getGym(gymId);
    }

    if (mounted) setState(() {});
  }

  Future<void> _handleLogout(BuildContext context) async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
    await _localDb.clearAll();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  String _formatTimeSince(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final user = _member?.user;
    final displayName = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : user?.email.isNotEmpty == true
            ? user!.email
            : 'Member';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          _gym?.name ?? 'Member Home',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFFFF6B00),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Offline banner
              if (_isOffline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF92400E).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off,
                          color: Color(0xFFFCD34D), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Offline mode — using cached data'
                          '${_lastSyncTime != null ? ' (synced ${_formatTimeSince(_lastSyncTime!)})' : ''}',
                          style: const TextStyle(
                            color: Color(0xFFFCD34D),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              const Icon(
                Icons.fitness_center_rounded,
                size: 64,
                color: Color(0xFFFF6B00),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome, $displayName!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFF6B00)),
                ),
                child: Text(
                  'Role: ${_member?.role ?? "member"}',
                  style: const TextStyle(
                    color: Color(0xFFFF6B00),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_gym != null) ...[
                const SizedBox(height: 8),
                Text(
                  _gym!.name,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
              if (_member?.gymId != null && _member!.gymId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Gym ID: ${_member!.gymId}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: () => _handleLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
