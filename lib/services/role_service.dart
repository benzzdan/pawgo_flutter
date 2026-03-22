import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Roles a user can have in the system.
enum UserRole { owner, walker, both }

/// The currently active role for navigation/UI purposes.
enum ActiveRole { owner, walker }

/// Detects whether the current user is an owner, walker, or both,
/// and exposes the active role for UI switching.
class RoleService {
  RoleService._();
  static final instance = RoleService._();

  SupabaseClient get _client => _testClient ?? Supabase.instance.client;

  /// Override for testing — set a mock SupabaseClient.
  set testClient(SupabaseClient? client) => _testClient = client;
  SupabaseClient? _testClient;

  final ValueNotifier<UserRole> role = ValueNotifier(UserRole.owner);
  final ValueNotifier<ActiveRole> activeRole = ValueNotifier(ActiveRole.owner);

  /// Whether a pending walker application exists.
  final ValueNotifier<bool> hasPendingApplication = ValueNotifier(false);

  bool _initialized = false;

  /// Query walkers and walker_applications tables to determine role.
  Future<void> initialize() async {
    if (_initialized) return;
    await refresh();
    _initialized = true;
  }

  /// Re-query the database and update role notifiers.
  Future<void> refresh() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      role.value = UserRole.owner;
      activeRole.value = ActiveRole.owner;
      hasPendingApplication.value = false;
      return;
    }

    // Check if user has a walker profile.
    final walkerRow = await _client
        .from('walkers')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    final isWalker = walkerRow != null;

    // Check for pending application.
    final appRow = await _client
        .from('walker_applications')
        .select('status')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    hasPendingApplication.value =
        appRow != null &&
        (appRow['status'] == 'pending' ||
            appRow['status'] == 'background_check_in_progress');

    // Determine role.
    if (isWalker) {
      // A walker row means the user is at least a walker.
      // All users are owners by default (they can book walks), so having a
      // walker profile means they are "both".
      role.value = UserRole.both;
    } else {
      role.value = UserRole.owner;
    }

    // If the user lost their walker profile somehow, reset active role.
    if (!isWalker && activeRole.value == ActiveRole.walker) {
      activeRole.value = ActiveRole.owner;
    }
  }

  /// Toggle between owner and walker active roles.
  void switchRole() {
    if (role.value != UserRole.both) return;
    activeRole.value = activeRole.value == ActiveRole.owner
        ? ActiveRole.walker
        : ActiveRole.owner;
  }

  /// Reset state on sign-out.
  void reset() {
    role.value = UserRole.owner;
    activeRole.value = ActiveRole.owner;
    hasPendingApplication.value = false;
    _initialized = false;
  }

  /// Reset all state for testing. Also clears testClient.
  void resetForTesting() {
    reset();
    _testClient = null;
  }
}
