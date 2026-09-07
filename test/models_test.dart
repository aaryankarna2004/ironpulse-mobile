import 'package:flutter_test/flutter_test.dart';
import 'package:ironpulse/models/models.dart';

void main() {
  group('User Model Tests', () {
    final userJson = {
      'id': '22222222-2222-2222-2222-222222222222',
      'email': 'owner@titanfit.com',
      'password_hash': r'$2b$10$hbHYYkc9V0Opy1CFP7B1H.SPD8FyTF1mS7TUK7n2cQlV1f7CtizFa',
      'full_name': 'Ram Thapa',
      'is_super_admin': false,
      'created_at': '2026-06-29T10:59:05.620208+00:00',
    };

    test('fromJson & toJson roundtrip', () {
      final user = User.fromJson(userJson);
      expect(user.id, '22222222-2222-2222-2222-222222222222');
      expect(user.email, 'owner@titanfit.com');
      expect(user.fullName, 'Ram Thapa');
      expect(user.isSuperAdmin, false);
      expect(user.passwordHash, userJson['password_hash']);

      final convertedJson = user.toJson();
      expect(convertedJson['id'], userJson['id']);
      expect(convertedJson['email'], userJson['email']);
      expect(convertedJson['full_name'], userJson['full_name']);
    });
  });

  group('GymMember Model Tests', () {
    final gymMemberJson = {
      'id': 'a0000001-0000-0000-0000-000000000001',
      'gym_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'user_id': '11111111-1111-1111-1111-111111111111',
      'role': 'owner',
      'status': 'active',
      'created_at': '2026-06-29T10:59:05.620208+00:00',
      'users': {
        'id': '11111111-1111-1111-1111-111111111111',
        'email': 'admin@ironpulse.com',
        'full_name': 'Super Admin',
        'created_at': '2026-06-29T10:59:05.620208+00:00',
        'is_super_admin': true,
      }
    };

    test('fromJson with nested user & toJson', () {
      final member = GymMember.fromJson(gymMemberJson);
      expect(member.id, 'a0000001-0000-0000-0000-000000000001');
      expect(member.gymId, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      expect(member.userId, '11111111-1111-1111-1111-111111111111');
      expect(member.role, 'owner');
      expect(member.status, 'active');
      expect(member.user, isNotNull);
      expect(member.user?.email, 'admin@ironpulse.com');
      expect(member.user?.fullName, 'Super Admin');

      final memberJsonOutput = member.toJson();
      expect(memberJsonOutput['id'], gymMemberJson['id']);
      expect(memberJsonOutput['gym_id'], gymMemberJson['gym_id']);
    });
  });
}
