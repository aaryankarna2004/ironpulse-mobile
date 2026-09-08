import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ironpulse/models/models.dart';
import 'package:ironpulse/screens/auth/login_screen.dart';
import 'package:ironpulse/services/local_database_service.dart';

class AdminHomeScreen extends StatefulWidget {
  final GymMember? gymMember;

  const AdminHomeScreen({
    super.key,
    this.gymMember,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _localDb = LocalDatabaseService.instance;

  Gym? _gym;
  List<GymMember> _members = [];
  List<MembershipPlan> _plans = [];
  List<GymClass> _classes = [];
  List<Trainer> _trainers = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String? _error;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isOffline = false;
    });

    final gymId = widget.gymMember?.gymId ?? '';

    // Step 1: Load instantly from Hive cache
    if (_localDb.hasCachedData) {
      _loadFromCache(gymId);
      setState(() {
        _isLoading = false;
        _lastSyncTime = _localDb.lastSyncTime;
      });
    }

    // Step 2: Background sync from Supabase
    try {
      await _localDb.syncFromSupabase(gymId);
      _loadFromCache(gymId);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = false;
          _lastSyncTime = _localDb.lastSyncTime;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
          if (!_localDb.hasCachedData) {
            _error = 'Failed to load data: $e';
          }
        });
      }
    }
  }

  /// Reads all data from Hive cache into state variables.
  void _loadFromCache(String gymId) {
    if (gymId.isNotEmpty) {
      _gym = _localDb.getGym(gymId);
    } else {
      final gyms = _localDb.getGyms();
      _gym = gyms.isNotEmpty ? gyms.first : null;
    }
    _members = _localDb.getGymMembers();
    _plans = _localDb.getMembershipPlans();
    _classes = _localDb.getGymClasses();
    _trainers = _localDb.getTrainers();
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

  @override
  Widget build(BuildContext context) {
    final user = widget.gymMember?.user;
    final displayName = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : user?.email.isNotEmpty == true
            ? user!.email
            : 'Admin';

    final gymName = _gym?.name ?? 'Ironpulse Gym';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: Color(0xFFFF6B00)),
            const SizedBox(width: 8),
            Text(
              gymName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: _loadAdminData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
            )
          : RefreshIndicator(
              onRefresh: _loadAdminData,
              color: const Color(0xFFFF6B00),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Admin Header Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF831843), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBE185D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'GYM ADMIN CONSOLE',
                                style: TextStyle(
                                  color: Colors.pink.shade200,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF43F5E),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  widget.gymMember?.role.toUpperCase() ?? 'ADMIN',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 13,
                            ),
                          ),
                          if (_gym != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Subdomain: ${_gym!.subdomain} • Rate: ${_gym!.billingCurrency} ${_gym!.pricePerMember.toStringAsFixed(0)}/member',
                              style: TextStyle(
                                color: Colors.pink.shade100,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Offline Mode Banner
                    if (_isOffline)
                      Container(
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

                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7F1D1D),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFEE2E2)),
                        ),
                      ),

                    // Metrics Grid
                    const Text(
                      'Live Metrics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Members',
                            value: '${_members.length}',
                            icon: Icons.people_alt,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Plans',
                            value: '${_plans.length}',
                            icon: Icons.card_membership,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Classes',
                            value: '${_classes.length}',
                            icon: Icons.fitness_center,
                            color: const Color(0xFFFF6B00),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Trainers',
                            value: '${_trainers.length}',
                            icon: Icons.sports,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Members List (Excluding Super Admin)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Gym Members',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_members.length} registered',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_members.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'No members registered in this gym yet.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _members.length,
                        separatorBuilder: (context, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final m = _members[index];
                          final memberUser = m.user;
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      const Color(0xFF3B82F6).withValues(alpha: 0.2),
                                  child: Text(
                                    (memberUser?.fullName.isNotEmpty == true
                                            ? memberUser!.fullName[0]
                                            : m.role[0])
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        memberUser?.fullName.isNotEmpty == true
                                            ? memberUser!.fullName
                                            : 'Gym Member',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        memberUser?.email ?? '',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: m.role == 'owner'
                                        ? const Color(0xFFF43F5E).withValues(alpha: 0.2)
                                        : const Color(0xFF10B981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    m.role.toUpperCase(),
                                    style: TextStyle(
                                      color: m.role == 'owner'
                                          ? const Color(0xFFF43F5E)
                                          : const Color(0xFF10B981),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeSince(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
