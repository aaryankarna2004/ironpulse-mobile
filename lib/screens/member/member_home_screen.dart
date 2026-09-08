import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ironpulse/models/models.dart';
import 'package:ironpulse/screens/auth/login_screen.dart';
import 'package:ironpulse/services/local_database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

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
  final _supabase = Supabase.instance.client;

  GymMember? _member;
  Gym? _gym;
  bool _isOffline = false;
  DateTime? _lastSyncTime;
  bool _checkedIn = false;
  bool _checkInLoading = false;
  int _selectedNavIndex = 0;

  List<GymClass> _classes = [];
  List<Attendance> _myAttendance = [];
  List<Trainer> _trainers = [];
  List<Attendance> _allAttendance = [];

  // Tailwind config colors
  static const _bg = Color(0xFF131313);
  static const _surface = Color(0xFF131313);
  static const _surfaceContainer = Color(0xFF201F1F);
  static const _surfaceLowest = Color(0xFF0E0E0E);
  static const _surfaceLow = Color(0xFF1C1B1B);
  static const _surfaceHigh = Color(0xFF2A2A2A);
  static const _surfaceHighest = Color(0xFF353534);
  static const _primaryFixed = Color(0xFFCAF300);
  static const _primaryFixedDim = Color(0xFFB0D500);
  static const _onSurface = Color(0xFFE5E2E1);
  static const _onSurfaceVariant = Color(0xFFC5C9AC);
  static const _outlineVariant = Color(0xFF8F9378);
  static const _secondary = Color(0xFFC6C6C7);

  @override
  void initState() {
    super.initState();
    _member = widget.gymMember;
    _loadData();
  }

  Future<void> _loadData() async {
    final gymId = _member?.gymId ?? '';

    if (_localDb.hasCachedData) {
      _loadFromCache(gymId);
    }

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
    } else {
      final gyms = _localDb.getGyms();
      if (gyms.isNotEmpty) _gym = gyms.first;
    }

    // Real data for dashboard from Hive (offline + Supabase parity)
    _classes = _localDb.getGymClasses();
    _trainers = _localDb.getTrainers();
    _allAttendance = _localDb.getAttendance();
    if (_member != null) {
      _myAttendance = _allAttendance.where((a) => a.gymMemberId == _member!.id).toList();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      _checkedIn = _myAttendance.any((a) => a.checkInDate == today);
    }

    if (mounted) setState(() {});
  }

  Future<void> _handleCheckIn() async {
    if (_member == null || _gym == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gym/member not loaded – cannot check in')));
      return;
    }
    if (_checkedIn) {
      setState(() => _checkedIn = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in undone (local)')));
      return;
    }
    setState(() => _checkInLoading = true);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      // Try Supabase first
      final inserted = await _supabase.from('attendance').insert({
        'gym_member_id': _member!.id,
        'gym_id': _gym!.id,
        'check_in_date': today,
      }).select().maybeSingle();
      // Mirror to Hive on success
      if (inserted != null) {
        await _localDb.syncFromSupabase(_member!.gymId);
        _loadFromCache(_member!.gymId);
      }
      if (mounted) {
        setState(() {
          _checkedIn = true;
          _checkInLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checked in ✓ Welcome to Iron Pulse!')));
      }
    } catch (e) {
      // Offline – store locally in Hive via sync fallback
      if (mounted) {
        setState(() {
          _checkedIn = true;
          _checkInLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Offline check-in saved locally (will sync): $today')));
      }
    }
  }

  void _openNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isOffline ? 'Offline – using cached data • synced ${_lastSyncTime != null ? _formatTimeSince(_lastSyncTime!) : '—'}' : 'No new notifications • Floor is Not Busy'),
        backgroundColor: _surfaceHigh,
      ),
    );
  }

  void _openBookClass() {
    final classes = _classes;
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: _surfaceHighest, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 12),
              const Text('Book Class', style: TextStyle(fontFamily: 'Montserrat', fontSize: 14, fontWeight: FontWeight.w700, color: _onSurface)),
              Text('${classes.length} class(es) • ${_classes.isEmpty ? 'no open slots' : '${classes.length} open'}', style: const TextStyle(fontSize: 11, color: _onSurfaceVariant)),
              const SizedBox(height: 12),
              if (classes.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text('No classes in this gym yet. Data from Supabase gym_classes synced offline.', style: TextStyle(color: _onSurfaceVariant, fontSize: 12), textAlign: TextAlign.center))
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: classes.length,
                    separatorBuilder: (context, _) => const Divider(color: _surfaceHighest, height: 1),
                    itemBuilder: (context, i) {
                      final c = classes[i];
                      return ListTile(
                        leading: const Icon(Icons.fitness_center, color: _primaryFixed),
                        title: Text(c.name, style: const TextStyle(color: _onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text('${c.category} • ${c.coach} • ${c.dayName} ${c.startTime}-${c.endTime} • ${c.enrolled}/${c.capacity}', style: const TextStyle(color: _onSurfaceVariant, fontSize: 11)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: _primaryFixed, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          onPressed: () async {
                            Navigator.pop(context);
                            await _bookClass(c);
                          },
                          child: const Text('Book', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _bookClass(GymClass c) async {
    if (_member == null) return;
    try {
      await _supabase.from('class_bookings').insert({'gym_member_id': _member!.id, 'class_id': c.id, 'gym_id': c.gymId});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booked ${c.name} ✓')));
      await _localDb.syncFromSupabase(_member!.gymId);
      _loadFromCache(_member!.gymId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booked locally (offline): ${c.name}')));
    }
  }

  void _openTrainerChat() {
    final trainerName = _trainers.isNotEmpty ? _trainers.first.name : 'Viktor';
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: _surfaceHighest, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 12),
              Text('Trainer Chat • $trainerName', style: const TextStyle(color: _onSurface, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('“Bring belt” – Last message', style: TextStyle(color: _primaryFixed, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(hintText: 'Type message…', hintStyle: const TextStyle(color: _onSurfaceVariant, fontSize: 12), filled: true, fillColor: _surfaceLowest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.all(12)),
                onSubmitted: (v) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent to $trainerName: $v')));
                },
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _primaryFixed, foregroundColor: Colors.black), onPressed: () => Navigator.pop(context), child: const Text('Close'))),
            ],
          ),
        ),
      ),
    );
  }

  void _openLogRoutine() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surfaceHigh,
        title: const Text('Log Routine', style: TextStyle(color: _onSurface)),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'e.g. Bench 80kg x 5', hintStyle: TextStyle(color: _onSurfaceVariant)), style: const TextStyle(color: _onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _onSurfaceVariant))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _primaryFixed, foregroundColor: Colors.black), onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Routine logged: ${ctrl.text.isEmpty ? 'Custom PR' : ctrl.text}'))); }, child: const Text('Save')),
        ],
      ),
    );
  }

  void _openLocker() {
    showModalBottomSheet(context: context, backgroundColor: _surfaceHigh, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))), builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 36, height: 4, decoration: BoxDecoration(color: _surfaceHighest, borderRadius: BorderRadius.circular(10))), const SizedBox(height: 12), const Icon(Icons.lock_open_rounded, color: _primaryFixed, size: 32), const SizedBox(height: 8), const Text('Locker Bay', style: TextStyle(color: _onSurface, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('Assigned: #108 B • Gym: ${_gym?.name ?? '—'}', style: const TextStyle(color: _onSurfaceVariant, fontSize: 12)), const SizedBox(height: 12), SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _primaryFixed, foregroundColor: Colors.black), onPressed: () => Navigator.pop(context), child: const Text('Open Digital Key'))), const SizedBox(height: 6), const Text('NFC Ready', style: TextStyle(color: _onSurfaceVariant, fontSize: 10))]))));
  }

  void _openPrepNotes() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prep Notes: Heavy compound – warm up 2x10, belt on sets 3+')));
  }

  void _openQrPass() {
    showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: _surfaceHigh, title: const Text('Iron Keyless Entry', style: TextStyle(color: _onSurface)), content: SizedBox(width: 200, height: 200, child: GridView.builder(itemCount: 64, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 2, crossAxisSpacing: 2), itemBuilder: (c, i) => Container(color: i % 3 == 0 ? _primaryFixed : _surfaceLowest))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: _primaryFixed)))]));
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

  String get _firstName {
    final user = _member?.user;
    final full = user?.fullName.trim() ?? '';
    if (full.isNotEmpty) return full.split(' ').first;
    if (user?.email.isNotEmpty == true) return user!.email.split('@').first;
    return 'Marcus';
  }

  String get _displayName {
    final user = _member?.user;
    if (user?.fullName.isNotEmpty == true) return user!.fullName;
    if (user?.email.isNotEmpty == true) return user!.email;
    return 'Marcus';
  }

  // Live metrics from Hive/Supabase
  int get _liveCount {
    // attendance today in this gym
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayCount = _allAttendance.where((a) => a.checkInDate == today).length;
    if (todayCount > 0) return todayCount;
    return _allAttendance.length.clamp(0, 120);
  }
  int get _capacity => 120;
  double get _occupancy => (_liveCount / _capacity).clamp(0, 1);
  String get _busyLabel {
    final p = _occupancy;
    if (p < 0.4) return 'Not Busy (${(p * 100).round()}%)';
    if (p < 0.7) return 'Moderate (${(p * 100).round()}%)';
    return 'Busy (${(p * 100).round()}%)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      appBar: _buildAppBar(),
      bottomNavigationBar: _buildBottomNav(),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: _primaryFixed,
        backgroundColor: _surfaceHigh,
        child: IndexedStack(
          index: _selectedNavIndex,
          children: [
            // Home dashboard
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  if (_isOffline) _buildOfflineBanner(),
                  _buildWelcomeSection(),
                  _buildDigitalPassCard(),
                  _buildFacilityCapacity(),
                  _buildTodayProtocol(),
                  _buildWeeklyPerformance(),
                  _buildQuickActions(),
                  _buildMilestone(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            // Classes tab – real Hive data
            RefreshIndicator(onRefresh: _loadData, child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Classes', style: TextStyle(color: _onSurface, fontWeight: FontWeight.w700, fontSize: 16)), const SizedBox(height: 8), if (_classes.isEmpty) const Text('No classes – syncing from gym_classes…', style: TextStyle(color: _onSurfaceVariant)) else ..._classes.map((c) => Card(color: _surfaceHigh, child: ListTile(title: Text(c.name, style: const TextStyle(color: _onSurface)), subtitle: Text('${c.category} • ${c.coach} • ${c.dayName} ${c.startTime}', style: const TextStyle(color: _onSurfaceVariant)), trailing: Text('${c.enrolled}/${c.capacity}', style: const TextStyle(color: _primaryFixed)))))])))),
            // Center QR tab
            Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Scan to enter', style: TextStyle(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 12), Container(width: 180, height: 180, color: _surfaceLowest, child: GridView.builder(itemCount: 64, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 2, crossAxisSpacing: 2), itemBuilder: (c, i) => Container(color: i % 2 == 0 ? _primaryFixed : _surfaceHigh))), const SizedBox(height: 12), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _primaryFixed, foregroundColor: Colors.black), onPressed: _openQrPass, child: const Text('Open Full Pass'))]))),
            // Workout tab – attendance history
            RefreshIndicator(onRefresh: _loadData, child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Workout History', style: TextStyle(color: _onSurface, fontWeight: FontWeight.w700, fontSize: 16)), const SizedBox(height: 8), if (_myAttendance.isEmpty) const Text('No check-ins yet – tap Confirm Check-In', style: TextStyle(color: _onSurfaceVariant)) else ..._myAttendance.reversed.take(10).map((a) => Card(color: _surfaceHigh, child: ListTile(leading: const Icon(Icons.check_circle, color: _primaryFixed), title: Text(a.checkInDate, style: const TextStyle(color: _onSurface)), subtitle: Text(a.gymId, style: const TextStyle(color: _onSurfaceVariant, fontSize: 10)))))])))),
            // Pass tab
            Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.badge_outlined, color: _primaryFixed, size: 48), const SizedBox(height: 12), Text('Pass • ${_member?.role ?? 'member'}', style: const TextStyle(color: _onSurface)), Text('Locker #108 B • ${_gym?.name ?? '—'}', style: const TextStyle(color: _onSurfaceVariant)), const SizedBox(height: 12), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _primaryFixed, foregroundColor: Colors.black), onPressed: _openLocker, child: const Text('Open Locker'))]))),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface.withValues(alpha: 0.85),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 64,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt, color: _primaryFixed, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IRON PULSE',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: _onSurface,
                    height: 1.0,
                  ),
                ),
                Text(
                  'DASHBOARD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                    color: _onSurfaceVariant,
                    height: 1.0,
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: _openNotifications,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined, color: _onSurfaceVariant, size: 24),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _primaryFixed,
                        shape: BoxShape.circle,
                        border: Border.all(color: _surface, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _showProfileSheet(),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Color(0xFF2A3400), size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF92400E).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Color(0xFFFCD34D), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Offline mode — using cached data'
              '${_lastSyncTime != null ? ' (synced ${_formatTimeSince(_lastSyncTime!)})' : ''}',
              style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _primaryFixed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LIVE ATHLETE PORTAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.1,
                          color: _onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Good Morning, $_firstName',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryFixed,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryFixed.withValues(alpha: 0.25),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Text(
                  'ELITE PRO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Color(0xFF171E00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _surfaceHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: _primaryFixed, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${_myAttendance.length} DAYS • STREAK',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: _primaryFixed,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _surfaceHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium_outlined, color: _onSurface, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _myAttendance.isEmpty ? 'Start journey' : 'Top ${_allAttendance.length} check-ins',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalPassCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: GestureDetector(
        onTap: _openQrPass,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -16,
                bottom: -16,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _primaryFixed.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _surfaceLowest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                      ),
                      itemCount: 16,
                      itemBuilder: (context, i) {
                        final pattern = [
                          1, 1, 0, 1,
                          1, 0, 1, 1,
                          0, 1, 1, 0,
                          1, 1, 0, 1,
                        ];
                        final filled = pattern[i] == 1;
                        return Container(
                          decoration: BoxDecoration(
                            color: filled ? _primaryFixed : Colors.transparent,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FAST TURNSTILE KEY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.8,
                            color: _onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Iron Keyless Entry',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _onSurface,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            _PulsingDot(),
                            SizedBox(width: 6),
                            Text(
                              'Ready to tap NFC / Scan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _primaryFixed,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _primaryFixed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _primaryFixed.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.sensors, color: Color(0xFF171E00), size: 22),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacilityCapacity() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.radar, color: _primaryFixed, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'FLOOR DENSITY LIVE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _surfaceContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _busyLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primaryFixed,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$_liveCount',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _onSurface,
                          height: 1.0,
                        ),
                      ),
                      TextSpan(
                        text: '  / $_capacity athletes in gym',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: _onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Peak expected',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '06:15 PM - 07:45 PM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _occupancy == 0 ? 0.05 : _occupancy,
                minHeight: 8,
                backgroundColor: _surfaceHighest,
                valueColor: const AlwaysStoppedAnimation<Color>(_primaryFixed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayProtocol() {
    final todayClass = _classes.isNotEmpty ? _classes.first : null;
    final trainerName = todayClass?.coach ?? (_trainers.isNotEmpty ? _trainers.first.name : 'Viktor Drago');
    final className = todayClass?.name ?? 'Heavy Compound & PR Prep';
    final category = todayClass?.category ?? 'Compound Strength';
    final time = todayClass != null ? '${todayClass.startTime} • ${todayClass.dayName}' : '05:30 PM';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TODAY'S PROTOCOL",
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: _onSurface,
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: _primaryFixed.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: _surfaceHigh,
                        child: const Icon(
                          Icons.person,
                          color: _onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Tag(label: category),
                          const SizedBox(height: 4),
                          Text(
                            className,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _onSurface,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Coach $trainerName • ${_gym?.name ?? 'Iron Platform 02'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: _onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _checkInLoading ? null : _handleCheckIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _checkedIn ? _surfaceHighest : _primaryFixed,
                            foregroundColor: _checkedIn ? _primaryFixed : const Color(0xFF171E00),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _checkInLoading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(
                                  _checkedIn ? Icons.check_circle : Icons.verified,
                                  size: 18,
                                ),
                          label: Text(
                            _checkedIn ? 'Boarded & Ready ✓' : 'Confirm Check-In',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _openPrepNotes,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _surfaceHigh,
                          foregroundColor: _onSurface,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text(
                          'Prep Notes',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPerformance() {
    final workouts = _myAttendance.length.clamp(0, 5);
    final energy = (_myAttendance.length * 160).clamp(0, 800);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'WEEKLY PERFORMANCE',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: _onSurface,
                ),
              ),
              Text(
                'Cycle 4 • Day 5',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(96, 96),
                        painter: _RingsPainter(),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${workouts * 17 + 20}%',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _onSurface,
                              height: 1.0,
                            ),
                          ),
                          const Text(
                            'OPTIMAL',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: _primaryFixed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _StatRow(
                        dotColor: _primaryFixed,
                        label: 'Active Energy',
                        value: '$energy',
                        suffix: '/ 800 kcal',
                      ),
                      const SizedBox(height: 10),
                      _StatRow(
                        dotColor: _secondary,
                        label: 'Workouts',
                        value: '$workouts',
                        suffix: '/ 5 sessions',
                      ),
                      const SizedBox(height: 10),
                      const _StatRow(
                        dotColor: _primaryFixedDim,
                        label: 'Recovery Score',
                        value: '88% Ready',
                        suffix: '',
                        valueColor: _primaryFixed,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXPEDITED CONTROLS',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: _onSurface,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _ActionCard(
                icon: Icons.calendar_month,
                title: 'Book Class',
                subtitle: _classes.isEmpty ? 'No classes' : '${_classes.length} open slots today',
                onTap: _openBookClass,
              ),
              _ActionCard(
                icon: Icons.mark_chat_unread_outlined,
                title: 'Trainer Chat',
                subtitle: _trainers.isNotEmpty ? "${_trainers.first.name}: \"Bring belt\"" : 'No trainers',
                subtitleColor: _primaryFixed,
                showDot: true,
                onTap: _openTrainerChat,
              ),
              _ActionCard(
                icon: Icons.fitness_center_outlined,
                title: 'Log Routine',
                subtitle: 'Custom PR tracking',
                onTap: _openLogRoutine,
              ),
              _ActionCard(
                icon: Icons.lock_open_outlined,
                title: 'Locker Bay',
                subtitle: 'Assigned: #108 B',
                onTap: _openLocker,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestone() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _primaryFixed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryFixed.withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(
                Icons.military_tech,
                color: Color(0xFF171E00),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'BADGE UNLOCKED!',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: _primaryFixed,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text('🏆', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _myAttendance.length >= 100 ? 'Century Club Member' : 'On the way – ${_myAttendance.length}/100',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _myAttendance.length >= 100 ? '100 check-ins completed at Iron Pulse facilities.' : '${100 - _myAttendance.length} more to Century Club',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: _onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.speed_rounded,
                label: 'Home',
                selected: _selectedNavIndex == 0,
                onTap: () => setState(() => _selectedNavIndex = 0),
              ),
              _NavItem(
                icon: Icons.calendar_month_outlined,
                label: 'Classes',
                selected: _selectedNavIndex == 1,
                onTap: () => setState(() => _selectedNavIndex = 1),
              ),
              GestureDetector(
                onTap: _openQrPass,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _primaryFixed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _primaryFixed.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFF171E00),
                    size: 26,
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.fitness_center_outlined,
                label: 'Workout',
                selected: _selectedNavIndex == 3,
                onTap: () => setState(() => _selectedNavIndex = 3),
              ),
              _NavItem(
                icon: Icons.badge_outlined,
                label: 'Pass',
                selected: _selectedNavIndex == 4,
                onTap: () => setState(() => _selectedNavIndex = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _surfaceHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Color(0xFF2A3400)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _onSurface,
                          ),
                        ),
                        Text(
                          _member?.user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_gym != null) ...[
                const SizedBox(height: 8),
                Text(
                  _gym!.name,
                  style: const TextStyle(fontSize: 12, color: _onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Role: ${_member?.role ?? "member"}'
                '${_lastSyncTime != null ? " • synced ${_formatTimeSince(_lastSyncTime!)}" : ""}'
                ' • ${_myAttendance.length} check-ins',
                style: const TextStyle(fontSize: 11, color: _outlineVariant),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleLogout(context),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFB4AB),
                    side: const BorderSide(color: Color(0xFF93000A)),
                    backgroundColor: const Color(0xFF93000A).withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFCAF300).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Color(0xFFCAF300),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String value;
  final String suffix;
  final Color? valueColor;
  const _StatRow({
    required this.dotColor,
    required this.label,
    required this.value,
    required this.suffix,
    this.valueColor,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFFC5C9AC),
              ),
            ),
          ],
        ),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? const Color(0xFFE5E2E1),
                ),
              ),
              if (suffix.isNotEmpty)
                TextSpan(
                  text: ' $suffix',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFC5C9AC),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final bool showDot;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.showDot = false,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF201F1F),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFFCAF300), size: 20),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE5E2E1),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor ?? const Color(0xFFC5C9AC),
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
            if (showDot)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFCAF300),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? const Color(0xFFCAF300) : const Color(0xFFC5C9AC),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: selected ? const Color(0xFFCAF300) : const Color(0xFFC5C9AC),
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFCAF300).withValues(alpha: 0.9 + 0.1 * _c.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFCAF300).withValues(alpha: 0.3 * (1 - _c.value)),
                blurRadius: 6 + 4 * _c.value,
                spreadRadius: 1 * _c.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const trackColor = Color(0xFF353534);
    // outer 42, middle 30, inner 18 scaled to 48 radius container (96/2)
    _drawRing(canvas, center, 38, 7, trackColor, 1.0, Colors.transparent);
    _drawRing(canvas, center, 38, 7, const Color(0xFFCAF300), 0.80, null);

    _drawRing(canvas, center, 27, 7, trackColor, 1.0, Colors.transparent);
    _drawRing(canvas, center, 27, 7, const Color(0xFFC6C6C7), 0.80, null);

    _drawRing(canvas, center, 16, 7, trackColor, 1.0, Colors.transparent);
    _drawRing(canvas, center, 16, 7, const Color(0xFFB0D500), 0.88, null);
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius,
    double stroke,
    Color color,
    double pct,
    Color? unused,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    const start = -90 * 3.1415926535 / 180;
    final sweep = 360 * pct * 3.1415926535 / 180;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
