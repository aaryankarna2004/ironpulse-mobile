import 'package:hive_flutter/hive_flutter.dart';
import 'package:ironpulse/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

/// Singleton service that caches Supabase data locally in Hive boxes
/// for offline access. Excludes super_admin users from all caches.
class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService instance = LocalDatabaseService._();

  // Box names
  static const String _usersBox = 'users';
  static const String _gymMembersBox = 'gym_members';
  static const String _gymsBox = 'gyms';
  static const String _membershipPlansBox = 'membership_plans';
  static const String _gymClassesBox = 'gym_classes';
  static const String _attendanceBox = 'attendance';
  static const String _trainersBox = 'trainers';
  static const String _metaBox = 'sync_metadata';

  bool _initialized = false;

  /// Initialize Hive and open all boxes. Call once in main().
  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(_usersBox),
      Hive.openBox<Map>(_gymMembersBox),
      Hive.openBox<Map>(_gymsBox),
      Hive.openBox<Map>(_membershipPlansBox),
      Hive.openBox<Map>(_gymClassesBox),
      Hive.openBox<Map>(_attendanceBox),
      Hive.openBox<Map>(_trainersBox),
      Hive.openBox(_metaBox),
    ]);
    _initialized = true;
  }

  // ── Sync from Supabase ──────────────────────────────────────────

  /// Fetches all 7 tables from Supabase and stores them in Hive.
  /// Filters out super_admin users and their related gym_member records.
  /// Returns the number of total records synced.
  Future<int> syncFromSupabase(String gymId) async {
    final supabase = Supabase.instance.client;
    int totalRecords = 0;

    // 1. Users — exclude super_admin
    final usersData = await supabase
        .from('users')
        .select('id, email, full_name, is_super_admin, created_at')
        .eq('is_super_admin', false);

    final usersBox = Hive.box<Map>(_usersBox);
    await usersBox.clear();
    final nonSuperAdminUserIds = <String>{};
    for (final row in usersData as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final userId = map['id'] as String;
      nonSuperAdminUserIds.add(userId);
      await usersBox.put(userId, map);
      totalRecords++;
    }

    // 2. Gym Members — only for non-super-admin users
    final membersQuery = gymId.isNotEmpty
        ? await supabase
            .from('gym_members')
            .select('*, users(id, email, full_name, is_super_admin, created_at)')
            .eq('gym_id', gymId)
        : await supabase
            .from('gym_members')
            .select('*, users(id, email, full_name, is_super_admin, created_at)');

    final membersBox = Hive.box<Map>(_gymMembersBox);
    await membersBox.clear();
    for (final row in membersQuery as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final userId = map['user_id'] as String? ?? '';
      // Skip if the user is a super_admin
      if (!nonSuperAdminUserIds.contains(userId)) continue;
      // Deep-copy nested users map
      if (map['users'] is Map) {
        map['users'] = Map<String, dynamic>.from(map['users'] as Map);
      }
      await membersBox.put(map['id'] as String, map);
      totalRecords++;
    }

    // 3. Gyms
    final gymsQuery = gymId.isNotEmpty
        ? await supabase.from('gyms').select().eq('id', gymId)
        : await supabase.from('gyms').select();

    final gymsBox = Hive.box<Map>(_gymsBox);
    await gymsBox.clear();
    for (final row in gymsQuery as List) {
      final map = Map<String, dynamic>.from(row as Map);
      await gymsBox.put(map['id'] as String, map);
      totalRecords++;
    }

    // 4. Membership Plans
    final plansQuery = gymId.isNotEmpty
        ? await supabase.from('membership_plans').select().eq('gym_id', gymId)
        : await supabase.from('membership_plans').select();

    final plansBox = Hive.box<Map>(_membershipPlansBox);
    await plansBox.clear();
    for (final row in plansQuery as List) {
      final map = Map<String, dynamic>.from(row as Map);
      await plansBox.put(map['id'] as String, map);
      totalRecords++;
    }

    // 5. Gym Classes
    final classesQuery = gymId.isNotEmpty
        ? await supabase.from('gym_classes').select().eq('gym_id', gymId)
        : await supabase.from('gym_classes').select();

    final classesBox = Hive.box<Map>(_gymClassesBox);
    await classesBox.clear();
    for (final row in classesQuery as List) {
      final map = Map<String, dynamic>.from(row as Map);
      await classesBox.put(map['id'] as String, map);
      totalRecords++;
    }

    // 6. Attendance
    final attendanceQuery = gymId.isNotEmpty
        ? await supabase.from('attendance').select().eq('gym_id', gymId)
        : await supabase.from('attendance').select();

    final attendanceBox = Hive.box<Map>(_attendanceBox);
    await attendanceBox.clear();
    for (final row in attendanceQuery as List) {
      final map = Map<String, dynamic>.from(row as Map);
      // Skip attendance records for super_admin members
      final gmId = map['gym_member_id'] as String? ?? '';
      if (gmId.isNotEmpty && !membersBox.containsKey(gmId)) {
        continue;
      }
      await attendanceBox.put(map['id'] as String, map);
      totalRecords++;
    }

    // 7. Trainers
    final trainersQuery = gymId.isNotEmpty
        ? await supabase.from('trainers').select().eq('gym_id', gymId)
        : await supabase.from('trainers').select();

    final trainersBox = Hive.box<Map>(_trainersBox);
    await trainersBox.clear();
    for (final row in trainersQuery as List) {
      final map = Map<String, dynamic>.from(row as Map);
      await trainersBox.put(map['id'] as String, map);
      totalRecords++;
    }

    // Update last sync timestamp
    final metaBox = Hive.box(_metaBox);
    await metaBox.put('last_sync', DateTime.now().toIso8601String());
    await metaBox.put('gym_id', gymId);

    return totalRecords;
  }

  // ── Read from Cache ─────────────────────────────────────────────

  List<User> getUsers() {
    final box = Hive.box<Map>(_usersBox);
    return box.values
        .map((m) => User.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  List<GymMember> getGymMembers() {
    final box = Hive.box<Map>(_gymMembersBox);
    return box.values.map((m) {
      final map = Map<String, dynamic>.from(m);
      if (map['users'] is Map) {
        map['users'] = Map<String, dynamic>.from(map['users'] as Map);
      }
      return GymMember.fromJson(map);
    }).toList();
  }

  List<Gym> getGyms() {
    final box = Hive.box<Map>(_gymsBox);
    return box.values
        .map((m) => Gym.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Gym? getGym(String gymId) {
    final box = Hive.box<Map>(_gymsBox);
    final data = box.get(gymId);
    if (data == null) return null;
    return Gym.fromJson(Map<String, dynamic>.from(data));
  }

  List<MembershipPlan> getMembershipPlans() {
    final box = Hive.box<Map>(_membershipPlansBox);
    return box.values
        .map((m) => MembershipPlan.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  List<GymClass> getGymClasses() {
    final box = Hive.box<Map>(_gymClassesBox);
    return box.values
        .map((m) => GymClass.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  List<Attendance> getAttendance() {
    final box = Hive.box<Map>(_attendanceBox);
    return box.values
        .map((m) => Attendance.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  List<Trainer> getTrainers() {
    final box = Hive.box<Map>(_trainersBox);
    return box.values
        .map((m) => Trainer.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  // ── Cache Status ────────────────────────────────────────────────

  /// Returns the last sync timestamp, or null if never synced.
  DateTime? get lastSyncTime {
    final metaBox = Hive.box(_metaBox);
    final raw = metaBox.get('last_sync') as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Returns the gym ID from the last sync.
  String? get lastSyncGymId {
    final metaBox = Hive.box(_metaBox);
    return metaBox.get('gym_id') as String?;
  }

  /// Returns true if cached data exists.
  bool get hasCachedData {
    return Hive.box<Map>(_usersBox).isNotEmpty ||
        Hive.box<Map>(_gymMembersBox).isNotEmpty;
  }

  /// Returns true if last sync was more than [minutes] minutes ago.
  bool needsSync({int minutes = 30}) {
    final last = lastSyncTime;
    if (last == null) return true;
    return DateTime.now().difference(last).inMinutes > minutes;
  }

  // ── Cleanup ─────────────────────────────────────────────────────

  /// Wipes all cached data and metadata. Call on logout.
  Future<void> clearAll() async {
    await Future.wait([
      Hive.box<Map>(_usersBox).clear(),
      Hive.box<Map>(_gymMembersBox).clear(),
      Hive.box<Map>(_gymsBox).clear(),
      Hive.box<Map>(_membershipPlansBox).clear(),
      Hive.box<Map>(_gymClassesBox).clear(),
      Hive.box<Map>(_attendanceBox).clear(),
      Hive.box<Map>(_trainersBox).clear(),
      Hive.box(_metaBox).clear(),
    ]);
  }
}
