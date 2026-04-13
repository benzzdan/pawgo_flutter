import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/error_handler.dart';

/// Abstraction over Supabase calls so the screen is testable without
/// a real Supabase client.
abstract class NotificationPrefsClient {
  Future<Map<String, dynamic>?> fetchPreferences();
  Future<void> upsertDefaults();
  Future<void> updatePreference(String column, bool value);
}

/// Production implementation that talks to Supabase.
class _SupabasePrefsClient implements NotificationPrefsClient {
  final SupabaseClient _client;

  _SupabasePrefsClient(this._client);

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<Map<String, dynamic>?> fetchPreferences() async {
    return await withRetry(() async {
      final row = await _client
          .from('notification_preferences')
          .select('booking_updates, walk_updates, chat_messages, marketing')
          .eq('user_id', _userId)
          .maybeSingle();
      return row;
    });
  }

  @override
  Future<void> upsertDefaults() async {
    await _client.from('notification_preferences').upsert({
      'user_id': _userId,
      'booking_updates': true,
      'walk_updates': true,
      'chat_messages': true,
      'marketing': false,
    });
  }

  @override
  Future<void> updatePreference(String column, bool value) async {
    await _client
        .from('notification_preferences')
        .update({column: value}).eq('user_id', _userId);
  }
}

class NotificationPreferencesScreen extends StatefulWidget {
  /// Accepts an optional [client] for testing. In production, the screen
  /// creates its own [_SupabasePrefsClient].
  final NotificationPrefsClient? client;

  const NotificationPreferencesScreen({super.key, this.client});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  late final NotificationPrefsClient _client;

  bool _loading = true;
  bool _error = false;

  bool _bookingUpdates = true;
  bool _walkUpdates = true;
  bool _chatMessages = true;
  bool _marketing = false;

  @override
  void initState() {
    super.initState();
    _client = widget.client ??
        _SupabasePrefsClient(Supabase.instance.client);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final row = await _client.fetchPreferences();

      if (row == null) {
        // First visit — upsert defaults
        await _client.upsertDefaults();
      }

      if (!mounted) return;
      setState(() {
        if (row != null) {
          _bookingUpdates = row['booking_updates'] as bool? ?? true;
          _walkUpdates = row['walk_updates'] as bool? ?? true;
          _chatMessages = row['chat_messages'] as bool? ?? true;
          _marketing = row['marketing'] as bool? ?? false;
        }
        // If row was null, defaults are already set in field initializers
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _updatePreference(String column, bool value) async {
    try {
      await _client.updatePreference(column, value);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.instance.showRecoverableError(
        context,
        'Failed to update preference. Please try again.',
      );
      // Revert the toggle on failure
      setState(() {
        switch (column) {
          case 'booking_updates':
            _bookingUpdates = !value;
          case 'walk_updates':
            _walkUpdates = !value;
          case 'chat_messages':
            _chatMessages = !value;
          case 'marketing':
            _marketing = !value;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIcons.warningCircle(),
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to load preferences',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Check your connection and try again.',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _loadPreferences,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              _buildToggle(
                title: 'Booking Updates',
                subtitle: 'New requests, confirmations, cancellations',
                value: _bookingUpdates,
                onChanged: (v) {
                  setState(() => _bookingUpdates = v);
                  _updatePreference('booking_updates', v);
                },
              ),
              const Divider(height: 1),
              _buildToggle(
                title: 'Walk Updates',
                subtitle: 'Walk started, completed, route updates',
                value: _walkUpdates,
                onChanged: (v) {
                  setState(() => _walkUpdates = v);
                  _updatePreference('walk_updates', v);
                },
              ),
              const Divider(height: 1),
              _buildToggle(
                title: 'Chat Messages',
                subtitle: 'New messages from walkers and owners',
                value: _chatMessages,
                onChanged: (v) {
                  setState(() => _chatMessages = v);
                  _updatePreference('chat_messages', v);
                },
              ),
              const Divider(height: 1),
              _buildToggle(
                title: 'Marketing',
                subtitle: 'Promotions, tips, and news',
                value: _marketing,
                onChanged: (v) {
                  setState(() => _marketing = v);
                  _updatePreference('marketing', v);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.orange500.withValues(alpha: 0.5),
      activeThumbColor: AppColors.orange500,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
    );
  }
}
