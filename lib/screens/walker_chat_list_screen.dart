import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class WalkerChatListScreen extends StatefulWidget {
  const WalkerChatListScreen({super.key});

  @override
  State<WalkerChatListScreen> createState() => _WalkerChatListScreenState();
}

class _WalkerChatListScreenState extends State<WalkerChatListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _chatItems = [];
  bool _isLoading = true;
  String? _error;
  String? _walkerId;
  String? _currentUserId;
  RealtimeChannel? _messageChannel;

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id;
    _loadChats();
  }

  @override
  void dispose() {
    _messageChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = _currentUserId;
      if (userId == null) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }

      // Get walker profile
      final walkerRes = await withRetry(() => _supabase
          .from('walkers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle());

      if (walkerRes == null) {
        setState(() {
          _isLoading = false;
          _error = 'No walker profile found.';
        });
        return;
      }

      _walkerId = walkerRes['id'] as String;

      // Fetch bookings with confirmed or walk_started status
      final bookings = await withRetry(() => _supabase
          .from('bookings')
          .select(
              '*, dogs(name, breed), users!bookings_owner_id_fkey(full_name, avatar_url)')
          .eq('walker_id', _walkerId!)
          .inFilter('status', ['confirmed', 'walk_started'])
          .order('scheduled_at', ascending: true));

      final bookingList = List<Map<String, dynamic>>.from(bookings);

      // For each booking, fetch last message and unread count
      final chatItems = <Map<String, dynamic>>[];
      for (final booking in bookingList) {
        final bookingId = booking['id'] as String;

        // Get last message
        final lastMsgRes = await _supabase
            .from('messages')
            .select('content, media_type, created_at, sender_id')
            .eq('booking_id', bookingId)
            .order('created_at', ascending: false)
            .limit(1);

        Map<String, dynamic>? lastMessage;
        if (lastMsgRes.isNotEmpty) {
          lastMessage = Map<String, dynamic>.from(lastMsgRes.first);
        }

        // Get unread count (messages not sent by current user and not read)
        final unreadRes = await _supabase
            .from('messages')
            .select('id')
            .eq('booking_id', bookingId)
            .neq('sender_id', userId)
            .eq('is_read', false);

        final unreadCount = unreadRes.length;

        chatItems.add({
          'booking': booking,
          'last_message': lastMessage,
          'unread_count': unreadCount,
          'sort_key': lastMessage?['created_at'] ??
              booking['scheduled_at'] ??
              '',
        });
      }

      // Sort by most recent message first
      chatItems.sort((a, b) {
        final aKey = a['sort_key'] as String;
        final bKey = b['sort_key'] as String;
        return bKey.compareTo(aKey);
      });

      if (!mounted) return;
      setState(() {
        _chatItems = chatItems;
        _isLoading = false;
      });

      _subscribeToMessages();
    } catch (e) {
      if (!mounted) return;
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      setState(() {
        _isLoading = false;
        _error = appError.isNetworkError
            ? 'No internet connection. Please check your network.'
            : 'Failed to load chats';
      });
    }
  }

  void _subscribeToMessages() {
    _messageChannel?.unsubscribe();

    // Subscribe to all new messages in the messages table
    // We'll filter by our bookings client-side
    _messageChannel = _supabase
        .channel('walker-chat-list-messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            _handleNewMessage(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _handleNewMessage(Map<String, dynamic> newMessage) {
    if (!mounted) return;
    final bookingId = newMessage['booking_id']?.toString();
    if (bookingId == null) return;

    final idx =
        _chatItems.indexWhere((c) => c['booking']['id'] == bookingId);
    if (idx < 0) return; // Not one of our bookings

    setState(() {
      final item = Map<String, dynamic>.from(_chatItems[idx]);
      item['last_message'] = {
        'content': newMessage['content'],
        'media_type': newMessage['media_type'],
        'created_at': newMessage['created_at'],
        'sender_id': newMessage['sender_id'],
      };
      item['sort_key'] = newMessage['created_at'] ?? item['sort_key'];

      // Increment unread if not from current user
      if (newMessage['sender_id'] != _currentUserId) {
        item['unread_count'] = (item['unread_count'] as int) + 1;
      }

      _chatItems[idx] = item;

      // Re-sort by most recent message
      _chatItems.sort((a, b) {
        final aKey = a['sort_key'] as String;
        final bKey = b['sort_key'] as String;
        return bKey.compareTo(aKey);
      });
    });
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(local.year, local.month, local.day);

    if (messageDate == today) {
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = local.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[local.month - 1]} ${local.day}';
    }
  }

  String _messagePreview(Map<String, dynamic>? lastMessage) {
    if (lastMessage == null) return 'No messages yet';
    final mediaType = lastMessage['media_type'] as String?;
    if (mediaType == 'status_update') {
      return lastMessage['content']?.toString() ?? 'Status update';
    }
    if (mediaType == 'image') return '📷 Photo';
    if (mediaType == 'video') return '🎥 Video';
    final content = lastMessage['content']?.toString();
    if (content != null && content.isNotEmpty) return content;
    return 'Media message';
  }

  void _openChat(Map<String, dynamic> chatItem) {
    final booking = chatItem['booking'] as Map<String, dynamic>;
    final owner = booking['users'] as Map<String, dynamic>?;
    final ownerName = owner?['full_name'] ?? 'Owner';
    final bookingId = booking['id'] as String;

    // Clear unread count for this chat
    setState(() {
      final idx =
          _chatItems.indexWhere((c) => c['booking']['id'] == bookingId);
      if (idx >= 0) {
        _chatItems[idx] = {
          ..._chatItems[idx],
          'unread_count': 0,
        };
      }
    });

    // Mark messages as read
    _markMessagesAsRead(bookingId);

    Navigator.pushNamed(context, '/chat', arguments: {
      'booking_id': bookingId,
      'other_party_name': ownerName,
    });
  }

  Future<void> _markMessagesAsRead(String bookingId) async {
    if (_currentUserId == null) return;
    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('booking_id', bookingId)
          .neq('sender_id', _currentUserId!)
          .eq('is_read', false);
    } catch (_) {
      // Best-effort — don't block navigation
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Chats',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.cacaoBrown))
          : _error != null
              ? _buildErrorState()
              : _chatItems.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadChats,
                      color: AppColors.cacaoBrown,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                        itemCount: _chatItems.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) =>
                            _buildChatTile(_chatItems[index]),
                      ),
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.warningCircle(),
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _loadChats,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cacaoBrown),
              child: Text('Retry',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.cacaoBrown.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                PhosphorIcons.chatCircle(),
                size: 40,
                color: AppColors.cacaoBrown,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No active chats',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Chats appear when you have confirmed bookings.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chatItem) {
    final booking = chatItem['booking'] as Map<String, dynamic>;
    final owner = booking['users'] as Map<String, dynamic>?;
    final dog = booking['dogs'] as Map<String, dynamic>?;
    final lastMessage = chatItem['last_message'] as Map<String, dynamic>?;
    final unreadCount = chatItem['unread_count'] as int;
    final status = booking['status'] as String? ?? '';

    final ownerName = owner?['full_name'] ?? 'Dog Owner';
    final avatarUrl = owner?['avatar_url'] as String?;
    final dogName = dog?['name'] ?? 'Dog';
    final preview = _messagePreview(lastMessage);
    final timeStr = _formatTime(
        lastMessage?['created_at'] as String? ??
            booking['scheduled_at'] as String?);

    return InkWell(
      onTap: () => _openChat(chatItem),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.orange50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: avatarUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            ownerName.isNotEmpty
                                ? ownerName[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.nunito(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.orange500,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        ownerName.isNotEmpty
                            ? ownerName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.orange500,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Owner name + time
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ownerName,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w800
                                : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: unreadCount > 0
                              ? AppColors.cacaoBrown
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Dog name + status badge
                  Row(
                    children: [
                      Icon(PhosphorIcons.pawPrint(),
                          size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        dogName,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (status == 'walk_started') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.green50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Active',
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.green600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Message preview + unread badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: unreadCount > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.cacaoBrown,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
