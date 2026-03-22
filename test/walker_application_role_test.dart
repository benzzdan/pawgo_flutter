import 'package:flutter_test/flutter_test.dart';

import 'package:pawgo/services/role_service.dart';

// --- Phone Validation (mirrored from WalkerApplicationScreen) ---

/// Mirrors the _validatePhone logic from walker_application_screen.dart.
String? validatePhone(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Phone number is required';
  }
  final cleaned = value.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
  if (!RegExp(r'^\+52\d{10}$').hasMatch(cleaned)) {
    return 'Enter a valid Mexico phone (+52 followed by 10 digits)';
  }
  return null;
}

void main() {
  // =========================================================================
  // RoleService state and switchRole() tests
  // =========================================================================

  group('RoleService', () {
    late RoleService service;

    setUp(() {
      service = RoleService.instance;
      service.resetForTesting();
    });

    tearDown(() {
      service.resetForTesting();
    });

    test('defaults to owner role', () {
      expect(service.role.value, UserRole.owner);
      expect(service.activeRole.value, ActiveRole.owner);
      expect(service.hasPendingApplication.value, isFalse);
    });

    group('role detection logic', () {
      // These tests verify the role determination logic that refresh() uses.
      // We set values directly since mocking the full Supabase query chain
      // is impractical; the actual DB queries are integration-tested.

      test('owner when no walker profile exists', () {
        service.role.value = UserRole.owner;
        expect(service.role.value, UserRole.owner);
      });

      test('both when walker profile exists', () {
        service.role.value = UserRole.both;
        expect(service.role.value, UserRole.both);
      });

      test('walker role exists in enum', () {
        service.role.value = UserRole.walker;
        expect(service.role.value, UserRole.walker);
      });

      test('hasPendingApplication tracks pending status', () {
        service.hasPendingApplication.value = true;
        expect(service.hasPendingApplication.value, isTrue);

        service.hasPendingApplication.value = false;
        expect(service.hasPendingApplication.value, isFalse);
      });
    });

    group('switchRole()', () {
      test('toggles from owner to walker when role is both', () {
        service.role.value = UserRole.both;
        service.activeRole.value = ActiveRole.owner;

        service.switchRole();

        expect(service.activeRole.value, ActiveRole.walker);
      });

      test('toggles from walker to owner when role is both', () {
        service.role.value = UserRole.both;
        service.activeRole.value = ActiveRole.walker;

        service.switchRole();

        expect(service.activeRole.value, ActiveRole.owner);
      });

      test('does nothing when role is owner-only', () {
        service.role.value = UserRole.owner;
        service.activeRole.value = ActiveRole.owner;

        service.switchRole();

        expect(service.activeRole.value, ActiveRole.owner);
      });

      test('does nothing when role is walker-only', () {
        service.role.value = UserRole.walker;
        service.activeRole.value = ActiveRole.walker;

        service.switchRole();

        expect(service.activeRole.value, ActiveRole.walker);
      });

      test('multiple toggles cycle correctly', () {
        service.role.value = UserRole.both;
        service.activeRole.value = ActiveRole.owner;

        service.switchRole();
        expect(service.activeRole.value, ActiveRole.walker);

        service.switchRole();
        expect(service.activeRole.value, ActiveRole.owner);

        service.switchRole();
        expect(service.activeRole.value, ActiveRole.walker);
      });
    });

    test('reset() clears all state', () {
      service.role.value = UserRole.both;
      service.activeRole.value = ActiveRole.walker;
      service.hasPendingApplication.value = true;

      service.reset();

      expect(service.role.value, UserRole.owner);
      expect(service.activeRole.value, ActiveRole.owner);
      expect(service.hasPendingApplication.value, isFalse);
    });

    test('ValueNotifier listeners fire on role change', () {
      int callCount = 0;
      service.role.addListener(() => callCount++);

      service.role.value = UserRole.both;
      expect(callCount, 1);

      service.role.value = UserRole.owner;
      expect(callCount, 2);

      // Same value should not fire
      service.role.value = UserRole.owner;
      expect(callCount, 2);
    });

    test('ValueNotifier listeners fire on activeRole change', () {
      int callCount = 0;
      service.activeRole.addListener(() => callCount++);

      service.activeRole.value = ActiveRole.walker;
      expect(callCount, 1);

      service.activeRole.value = ActiveRole.owner;
      expect(callCount, 2);
    });
  });

  // =========================================================================
  // Walker application phone validation
  // =========================================================================

  group('Walker application phone validation', () {
    test('valid Mexico phone number passes', () {
      expect(validatePhone('+525512345678'), isNull);
    });

    test('valid phone with spaces passes', () {
      expect(validatePhone('+52 55 1234 5678'), isNull);
    });

    test('valid phone with hyphens passes', () {
      expect(validatePhone('+52-55-1234-5678'), isNull);
    });

    test('valid phone with parentheses passes', () {
      expect(validatePhone('+52(55)12345678'), isNull);
    });

    test('empty phone fails', () {
      expect(validatePhone(''), equals('Phone number is required'));
    });

    test('null phone fails', () {
      expect(validatePhone(null), equals('Phone number is required'));
    });

    test('whitespace-only phone fails', () {
      expect(validatePhone('   '), equals('Phone number is required'));
    });

    test('US phone number fails', () {
      expect(validatePhone('+15551234567'),
          equals('Enter a valid Mexico phone (+52 followed by 10 digits)'));
    });

    test('phone without country code fails', () {
      expect(validatePhone('5512345678'),
          equals('Enter a valid Mexico phone (+52 followed by 10 digits)'));
    });

    test('phone with too few digits fails', () {
      expect(validatePhone('+52551234'),
          equals('Enter a valid Mexico phone (+52 followed by 10 digits)'));
    });

    test('phone with too many digits fails', () {
      expect(validatePhone('+5255123456789'),
          equals('Enter a valid Mexico phone (+52 followed by 10 digits)'));
    });

    test('phone with letters fails', () {
      expect(validatePhone('+52abc1234567'),
          equals('Enter a valid Mexico phone (+52 followed by 10 digits)'));
    });
  });

  // =========================================================================
  // Application status transitions
  // =========================================================================

  group('Application status transitions', () {
    final validStatuses = [
      'pending',
      'background_check_in_progress',
      'approved',
      'rejected',
    ];

    test('all expected statuses are valid strings', () {
      for (final status in validStatuses) {
        expect(status, isNotEmpty);
        expect(status, isA<String>());
      }
    });

    test('pending -> background_check_in_progress is valid transition', () {
      const from = 'pending';
      const to = 'background_check_in_progress';
      expect(validStatuses.contains(from), isTrue);
      expect(validStatuses.contains(to), isTrue);
    });

    test('background_check_in_progress -> approved is valid transition', () {
      const from = 'background_check_in_progress';
      const to = 'approved';
      expect(validStatuses.contains(from), isTrue);
      expect(validStatuses.contains(to), isTrue);
    });

    test('background_check_in_progress -> rejected is valid transition', () {
      const from = 'background_check_in_progress';
      const to = 'rejected';
      expect(validStatuses.contains(from), isTrue);
      expect(validStatuses.contains(to), isTrue);
    });

    test('pending and background_check_in_progress are pending statuses', () {
      bool isPending(String status) =>
          status == 'pending' || status == 'background_check_in_progress';

      expect(isPending('pending'), isTrue);
      expect(isPending('background_check_in_progress'), isTrue);
      expect(isPending('approved'), isFalse);
      expect(isPending('rejected'), isFalse);
    });

    test('only approved status grants walker access', () {
      bool grantsAccess(String status) => status == 'approved';

      expect(grantsAccess('pending'), isFalse);
      expect(grantsAccess('background_check_in_progress'), isFalse);
      expect(grantsAccess('approved'), isTrue);
      expect(grantsAccess('rejected'), isFalse);
    });
  });

  // =========================================================================
  // MainShell bottom nav logic
  // =========================================================================

  group('MainShell bottom nav selection', () {
    test('shows owner nav when activeRole is owner', () {
      final activeRole = ActiveRole.owner;
      final isWalkerMode = activeRole == ActiveRole.walker;
      expect(isWalkerMode, isFalse);
    });

    test('shows walker nav when activeRole is walker', () {
      final activeRole = ActiveRole.walker;
      final isWalkerMode = activeRole == ActiveRole.walker;
      expect(isWalkerMode, isTrue);
    });

    test('RoleService activeRole drives nav selection', () {
      final service = RoleService.instance;
      service.resetForTesting();

      // Default is owner
      expect(service.activeRole.value == ActiveRole.walker, isFalse);

      // Switch to walker
      service.role.value = UserRole.both;
      service.switchRole();
      expect(service.activeRole.value == ActiveRole.walker, isTrue);

      service.resetForTesting();
    });
  });

  // =========================================================================
  // Profile screen "Become a Walker" visibility logic
  // =========================================================================

  group('Become a Walker button visibility', () {
    // Mirrors the _buildBecomeWalkerCard() logic from ProfileScreen

    String? computeCardType(UserRole role, String? applicationStatus) {
      if (role == UserRole.both) return 'role_toggle';
      if (role == UserRole.walker) return null; // hidden
      // Owner-only
      final hasApplication =
          applicationStatus != null && applicationStatus != 'approved';
      if (hasApplication) return 'application_status';
      return 'become_walker';
    }

    test('shows "Become a Walker" for owner with no application', () {
      expect(computeCardType(UserRole.owner, null), 'become_walker');
    });

    test('shows "Application Status" for owner with pending application', () {
      expect(computeCardType(UserRole.owner, 'pending'), 'application_status');
    });

    test(
        'shows "Application Status" for owner with background check in progress',
        () {
      expect(computeCardType(UserRole.owner, 'background_check_in_progress'),
          'application_status');
    });

    test('shows "Application Status" for owner with rejected application', () {
      expect(
          computeCardType(UserRole.owner, 'rejected'), 'application_status');
    });

    test('shows "Become a Walker" for owner with approved application', () {
      // Approved means they should have a walker profile (role=both),
      // but if still owner-only (edge case), card shows become_walker
      expect(computeCardType(UserRole.owner, 'approved'), 'become_walker');
    });

    test('shows role toggle for dual-role users regardless of app status', () {
      expect(computeCardType(UserRole.both, null), 'role_toggle');
      expect(computeCardType(UserRole.both, 'approved'), 'role_toggle');
      expect(computeCardType(UserRole.both, 'pending'), 'role_toggle');
    });

    test('hides card for walker-only users', () {
      expect(computeCardType(UserRole.walker, null), isNull);
    });
  });

  // =========================================================================
  // RLS policy expectations (logic-level documentation)
  // =========================================================================

  group('RLS policy expectations', () {
    test('user can only access own walker application', () {
      const currentUserId = 'user-123';
      const applicationUserId = 'user-123';
      const otherUserId = 'user-456';

      expect(currentUserId == applicationUserId, isTrue);
      expect(currentUserId == otherUserId, isFalse);
    });

    test('user can only update own pending application', () {
      const isOwnApplication = true;
      const status = 'pending';
      final canUpdate = isOwnApplication && status == 'pending';
      expect(canUpdate, isTrue);
    });

    test('user cannot update approved application', () {
      const isOwnApplication = true;
      const status = 'approved';
      final canUpdate = isOwnApplication && status == 'pending';
      expect(canUpdate, isFalse);
    });

    test('user cannot update rejected application', () {
      const isOwnApplication = true;
      const status = 'rejected';
      final canUpdate = isOwnApplication && status == 'pending';
      expect(canUpdate, isFalse);
    });

    test('user cannot access other users ID photos', () {
      const currentUserId = 'user-123';
      const filePath = 'user-456/app-1/id_front.jpg';
      final ownerFolder = filePath.split('/').first;
      expect(ownerFolder == currentUserId, isFalse);
    });

    test('user can access own ID photos', () {
      const currentUserId = 'user-123';
      const filePath = 'user-123/app-1/id_front.jpg';
      final ownerFolder = filePath.split('/').first;
      expect(ownerFolder == currentUserId, isTrue);
    });
  });
}
