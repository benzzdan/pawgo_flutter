import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/config/env.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:pawgo/services/role_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class WalkerChatScreen extends StatefulWidget {
  const WalkerChatScreen({super.key});

  @override
  State<WalkerChatScreen> createState() => _WalkerChatScreenState();
}

class _WalkerChatScreenState extends State<WalkerChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  String _message = '';
  String? _bookingId;
  String? _otherPartyName;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploading = false;
  RealtimeChannel? _channel;
  RealtimeChannel? _bookingChannel;
  RealtimeChannel? _typingChannel;
  String? _currentUserId;
  String? _bookingStatus;
  bool _isDisconnected = false;
  bool _otherPartyTyping = false;
  Timer? _typingDebounce;
  Timer? _typingTimeout;
  Timer? _disconnectDebounce;
  Timer? _pollTimer;

  /// Whether chat input is enabled (only during active walks).
  bool get _isChatActive => _bookingStatus == 'walk_started';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bookingId != null) return;
    _currentUserId = _supabase.auth.currentUser?.id;
    if (_currentUserId == null) {
      ErrorHandler.instance.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/', (route) => false);
      return;
    }
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _bookingId = args['booking_id'] as String?;
      _otherPartyName = args['other_party_name'] as String?;
    }
    if (_bookingId != null) {
      _fetchBookingStatus();
      _fetchMessages();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    _bookingChannel?.unsubscribe();
    _typingChannel?.unsubscribe();
    _typingDebounce?.cancel();
    _typingTimeout?.cancel();
    _disconnectDebounce?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchBookingStatus() async {
    if (_bookingId == null) return;

    // Always subscribe to messages immediately so they arrive in real-time
    _subscribeToMessages();

    try {
      final data = await withRetry(() => _supabase
          .from('bookings')
          .select('status')
          .eq('id', _bookingId!)
          .single());
      if (!mounted) return;
      setState(() {
        _bookingStatus = data['status'] as String?;
      });
      _subscribeToBookingStatus();
    } catch (e) {
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      if (mounted) {
        // Default to allowing chat on error (fail-open for UX)
        setState(() => _bookingStatus = 'walk_started');
      }
    }
  }

  void _subscribeToBookingStatus() {
    if (_bookingId == null) return;
    _bookingChannel?.unsubscribe();

    _bookingChannel = _supabase
        .channel('chat_booking_status_$_bookingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _bookingId!,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['status'] as String?;
            if (!mounted || newStatus == null) return;
            setState(() => _bookingStatus = newStatus);
          },
        )
        .subscribe();
  }

  Future<void> _fetchMessages() async {
    try {
      final data = await withRetry(() => _supabase
          .from('messages')
          .select('*, users(full_name, avatar_url)')
          .eq('booking_id', _bookingId!)
          .order('created_at', ascending: true));

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        if (appError.isAuthError) {
          ErrorHandler.instance.navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/', (route) => false);
          return;
        }
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToMessages() {
    _channel?.unsubscribe();
    _channel = _supabase
        .channel('messages:$_bookingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: _bookingId!,
          ),
          callback: (payload) {
            final newMessage = payload.newRecord;
            // Clear typing indicator when a message arrives from the other party
            final senderId = newMessage['sender_id']?.toString();
            if (senderId != _currentUserId && mounted) {
              setState(() => _otherPartyTyping = false);
              _typingTimeout?.cancel();
            }
            final messageId = newMessage['id']?.toString();
            if (messageId == null || !mounted) return;

            // Check for duplicate
            final exists = _messages.any((m) => m['id'].toString() == messageId);
            if (exists) return;

            // Use payload directly if it has content, then fetch user join in background
            if (newMessage['content'] != null || newMessage['media_url'] != null) {
              setState(() {
                _messages.add(Map<String, dynamic>.from(newMessage));
              });
              _scrollToBottom();
              // Fetch full message with user join to update sender name/avatar
              _fetchSingleMessage(messageId);
            } else {
              _fetchSingleMessage(messageId);
            }
          },
        )
        .subscribe((status, [error]) {
      if (_disposed) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        _disconnectDebounce?.cancel();
        if (_isDisconnected) setState(() => _isDisconnected = false);
      } else {
        // Only show banner after 5s of sustained disconnection
        _disconnectDebounce?.cancel();
        _disconnectDebounce = Timer(const Duration(seconds: 5), () {
          if (!_disposed) setState(() => _isDisconnected = true);
        });
      }
    });

    _subscribeToTyping();
    _startMessagePolling();
  }

  void _startMessagePolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _bookingId == null) return;
      _pollForNewMessages();
    });
  }

  Future<void> _pollForNewMessages() async {
    if (_bookingId == null) return;
    try {
      // Only fetch messages newer than the last one we have
      var query = _supabase
          .from('messages')
          .select('*, users(full_name, avatar_url)')
          .eq('booking_id', _bookingId!);

      if (_messages.isNotEmpty) {
        final lastCreatedAt = _messages.last['created_at']?.toString();
        if (lastCreatedAt != null) {
          query = query.gt('created_at', lastCreatedAt);
        }
      }

      final data = await query.order('created_at', ascending: true);
      if (!mounted || data.isEmpty) return;

      var added = false;
      for (final msg in data) {
        final msgId = msg['id'].toString();
        final exists = _messages.any((m) => m['id'].toString() == msgId);
        if (!exists) {
          _messages.add(Map<String, dynamic>.from(msg));
          added = true;
        }
      }

      if (added) {
        setState(() {});
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _subscribeToTyping() {
    _typingChannel?.unsubscribe();
    _typingChannel = _supabase
        .channel('typing:$_bookingId')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final senderId = payload['user_id']?.toString();
            if (senderId == _currentUserId || !mounted) return;

            setState(() => _otherPartyTyping = true);
            _scrollToBottom();

            // Auto-clear typing after 3s of no typing events
            _typingTimeout?.cancel();
            _typingTimeout = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _otherPartyTyping = false);
            });
          },
        )
        .subscribe();
  }

  void _broadcastTyping() {
    if (_typingChannel == null || _bookingId == null) return;

    // Debounce: only send typing event at most every 1s
    if (_typingDebounce?.isActive ?? false) return;
    _typingDebounce = Timer(const Duration(seconds: 1), () {});

    _typingChannel!.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': _currentUserId},
    );
  }

  Future<void> _fetchSingleMessage(String messageId) async {
    try {
      final data = await _supabase
          .from('messages')
          .select('*, users(full_name, avatar_url)')
          .eq('id', messageId)
          .single();

      if (!mounted) return;

      final idx = _messages.indexWhere((m) => m['id'].toString() == messageId);
      if (idx >= 0) {
        // Update existing message with full user join data
        setState(() {
          _messages[idx] = Map<String, dynamic>.from(data);
        });
      } else {
        // Add if not already present
        setState(() {
          _messages.add(Map<String, dynamic>.from(data));
        });
        _scrollToBottom();
      }
    } catch (_) {
      // Message was already added from payload — user join just won't show name
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _message.trim();
    if (text.isEmpty || _isSending || _bookingId == null) return;

    _messageController.clear();
    setState(() {
      _message = '';
      _isSending = true;
    });

    try {
      final inserted = await _supabase.from('messages').insert({
        'booking_id': _bookingId,
        'sender_id': _currentUserId,
        'content': text,
      }).select('*, users(full_name, avatar_url)').single();

      if (mounted) {
        final exists =
            _messages.any((m) => m['id'].toString() == inserted['id'].toString());
        if (!exists) {
          setState(() {
            _messages.add(Map<String, dynamic>.from(inserted));
          });
          _scrollToBottom();
        }
        _notifyOtherParty(text.length > 100 ? '${text.substring(0, 100)}\u2026' : text);
      }
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        if (appError.isAuthError) {
          ErrorHandler.instance.navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/', (route) => false);
          return;
        }
        ErrorHandler.instance.showRecoverableError(context, 'Failed to send message');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleMediaUpload({required ImageSource source}) async {
    if (_bookingId == null || _isUploading) return;

    final XFile? picked;
    if (source == ImageSource.camera) {
      picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 70,
      );
    } else {
      picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 70,
      );
    }
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      final fileName = picked.name;
      final mimeType = _getMimeType(fileName);

      final response = await _supabase.functions.invoke(
        'upload-walk-media',
        body: {
          'booking_id': _bookingId,
          'file_name': fileName,
          'file_data': base64Encode(bytes),
          'content_type': mimeType,
        },
      );

      if (response.status != 201) {
        throw Exception('Upload failed');
      }

      // The message is created server-side by the Edge Function,
      // it will arrive via the Realtime subscription
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        if (appError.isAuthError) {
          ErrorHandler.instance.navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/', (route) => false);
          return;
        }
        _showUploadRetrySnackBar(source);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showUploadRetrySnackBar(ImageSource source) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Failed to upload media'),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _handleMediaUpload(source: source),
        ),
      ),
    );
  }

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _sendStatusUpdate(String status) async {
    if (_bookingId == null || _isSending) return;

    setState(() => _isSending = true);

    try {
      final inserted = await _supabase.from('messages').insert({
        'booking_id': _bookingId,
        'sender_id': _currentUserId,
        'content': status,
        'media_type': 'status_update',
      }).select('*, users(full_name, avatar_url)').single();

      if (mounted) {
        final exists =
            _messages.any((m) => m['id'].toString() == inserted['id'].toString());
        if (!exists) {
          setState(() {
            _messages.add(Map<String, dynamic>.from(inserted));
          });
          _scrollToBottom();
        }
        _notifyOtherParty(status);
      }
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        if (appError.isAuthError) {
          ErrorHandler.instance.navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/', (route) => false);
          return;
        }
        ErrorHandler.instance.showRecoverableError(context, 'Failed to send status update');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Fire-and-forget push notification to the other party.
  void _notifyOtherParty(String previewText) {
    if (_bookingId == null) return;
    // Don't await — notification is best-effort
    _supabase.functions.invoke(
      'send-notification',
      body: {
        'booking_id': _bookingId,
        'sender_id': _currentUserId,
        'type': 'new_message',
        'title': _otherPartyName != null ? 'Message to $_otherPartyName' : 'New message',
        'body': previewText,
        'data': {'booking_id': _bookingId},
      },
    ).ignore();
  }

  void _showMediaSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(PhosphorIcons.camera()),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _handleMediaUpload(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(PhosphorIcons.images()),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _handleMediaUpload(source: ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_isDisconnected) _buildConnectionBanner(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMessages(),
            ),
            if (_isChatActive && RoleService.instance.activeRole.value == ActiveRole.walker) _buildQuickActions(),
            _isChatActive ? _buildInput() : _buildDisabledInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.orange100,
      child: Row(
        children: [
          Icon(PhosphorIcons.wifiSlash(), size: 16, color: AppColors.orange500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reconnecting\u2026 Messages may be delayed.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.orange500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(PhosphorIcons.arrowLeft(),
                  size: 20, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.orange400, AppColors.orange500],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    (_otherPartyName ?? '').isNotEmpty
                        ? _otherPartyName![0].toUpperCase()
                        : '?',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (_isChatActive)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.green500,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _otherPartyName ?? 'Chat',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_isChatActive)
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _otherPartyTyping
                              ? AppColors.orange500
                              : AppColors.green500,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _otherPartyTyping ? 'Typing\u2026' : 'Active now',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _otherPartyTyping
                              ? AppColors.orange500
                              : AppColors.green600,
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

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.chatCircle(),
                size: 48,
                color: AppColors.textTertiary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No messages yet',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Send a message to start chatting',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    final itemCount = _messages.length + (_otherPartyTyping ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Typing indicator as last item
        if (_otherPartyTyping && index == itemCount - 1) {
          return _buildTypingBubble();
        }

        final msg = _messages[index];
        final showDateSeparator = _shouldShowDateSeparator(index);
        return Column(
          children: [
            if (showDateSeparator)
              _DateSeparator(dateStr: _dateLabelFor(msg['created_at'])),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _MessageBubble(
                message: msg,
                isCurrentUser: msg['sender_id'] == _currentUserId,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.orange400, AppColors.orange500],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                (_otherPartyName ?? '').isNotEmpty
                    ? _otherPartyName![0].toUpperCase()
                    : '?',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Container(
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary
                            .withValues(alpha: 0.4 + 0.4 * value),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    final current = DateTime.tryParse(_messages[index]['created_at']?.toString() ?? '');
    final previous = DateTime.tryParse(_messages[index - 1]['created_at']?.toString() ?? '');
    if (current == null || previous == null) return false;
    final c = current.toLocal();
    final p = previous.toLocal();
    return c.year != p.year || c.month != p.month || c.day != p.day;
  }

  String _dateLabelFor(dynamic createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt.toString())?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(messageDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  Widget _buildQuickActions() {
    if (!_isChatActive) return const SizedBox.shrink();

    final actions = [
      {'icon': PhosphorIcons.pawPrint(), 'label': 'Pee break', 'status': 'Pee break completed'},
      {'icon': PhosphorIcons.leaf(), 'label': 'Poop', 'status': 'Poop pickup completed'},
      {'icon': PhosphorIcons.drop(), 'label': 'Water', 'status': 'Water break taken'},
      {'icon': PhosphorIcons.tennisBall(), 'label': 'Playing', 'status': 'Playing time!'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: actions.map((a) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _sendStatusUpdate(a['status'] as String),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(a['icon'] as IconData,
                        size: 16, color: AppColors.orange500),
                    const SizedBox(width: 8),
                    Text(
                      a['label'] as String,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          if (RoleService.instance.activeRole.value == ActiveRole.walker)
          GestureDetector(
            onTap: _isUploading ? null : _showMediaSourcePicker,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(PhosphorIcons.image(),
                      size: 18, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _messageController,
                onChanged: (val) {
                  setState(() => _message = val);
                  if (val.trim().isNotEmpty) _broadcastTyping();
                },
                onSubmitted: (_) => _handleSend(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16),
                ),
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isChatActive ? _handleSend : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _message.trim().isNotEmpty && _isChatActive
                    ? AppColors.orange500
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow:
                    _message.trim().isNotEmpty && _isChatActive
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.orange500.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
              ),
              child: Icon(
                PhosphorIcons.paperPlaneTilt(),
                size: 18,
                color: _message.trim().isNotEmpty && _isChatActive
                    ? Colors.white
                    : const Color(0xFFCCCCCC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledInput() {
    final statusText = _bookingStatus == 'walk_completed'
        ? 'This walk has ended. Chat is read-only.'
        : 'Chat is available during active walks.';

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              _bookingStatus == 'walk_completed'
                  ? PhosphorIcons.lock()
                  : PhosphorIcons.chatCircle(),
              size: 18,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isCurrentUser;

  const _MessageBubble({
    required this.message,
    required this.isCurrentUser,
  });

  bool get _isStatusUpdate => message['media_type'] == 'status_update';
  bool get _hasMedia =>
      message['media_url'] != null &&
      (message['media_type'] == 'image' || message['media_type'] == 'video');

  String get _senderName {
    final user = message['users'];
    if (user is Map) return user['full_name'] ?? 'Unknown';
    return 'Unknown';
  }

  String get _timeString {
    final created = message['created_at'];
    if (created == null) return '';
    try {
      final dt = DateTime.parse(created.toString()).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isStatusUpdate) {
      return _buildStatusUpdate();
    }

    return Row(
      mainAxisAlignment:
          isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isCurrentUser)
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.orange400, AppColors.orange500],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _senderName.isNotEmpty ? _senderName[0].toUpperCase() : '?',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        Flexible(
          child: Column(
            crossAxisAlignment:
                isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (_hasMedia) _buildTappableMedia(context),
              if (message['content'] != null &&
                  message['content'].toString().isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        isCurrentUser ? AppColors.orange500 : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                      bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
                    ),
                    boxShadow: isCurrentUser
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                            ),
                          ],
                  ),
                  child: Text(
                    message['content'].toString(),
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color:
                          isCurrentUser ? Colors.white : AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _timeString,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isCurrentUser)
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.blue400, AppColors.blue500],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _senderName.isNotEmpty ? _senderName[0].toUpperCase() : '?',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTappableMedia(BuildContext context) {
    final mediaUrl = message['media_url']?.toString();
    final isVideo = message['media_type'] == 'video';

    if (mediaUrl == null || isVideo) return _buildMediaContent();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenPhotoViewer(imageUrl: mediaUrl),
          ),
        );
      },
      child: _buildMediaContent(),
    );
  }

  Widget _buildMediaContent() {
    final mediaUrl = message['media_url'].toString();
    final isVideo = message['media_type'] == 'video';

    return Container(
      width: 220,
      height: 180,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isVideo)
            Container(
              color: Colors.black87,
              child: Center(
                child: Icon(PhosphorIcons.playCircle(),
                    size: 48, color: Colors.white),
              ),
            )
          else
            Image.network(
              mediaUrl,
              fit: BoxFit.cover,
              headers: {
                'apikey': Env.current.supabaseAnonKey,
              },
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surface,
                child: Center(
                  child: Icon(PhosphorIcons.imageBroken(),
                      size: 32, color: AppColors.textTertiary),
                ),
              ),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _timeString,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusUpdate() {
    final content = message['content']?.toString() ?? '';
    IconData icon = PhosphorIcons.info();
    Color color = AppColors.blue500;

    if (content.toLowerCase().contains('pee')) {
      icon = PhosphorIcons.pawPrint();
      color = AppColors.orange500;
    } else if (content.toLowerCase().contains('poop')) {
      icon = PhosphorIcons.leaf();
      color = AppColors.green600;
    } else if (content.toLowerCase().contains('water')) {
      icon = PhosphorIcons.drop();
      color = AppColors.blue500;
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              content,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _timeString,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final String dateStr;
  const _DateSeparator({required this.dateStr});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: AppColors.textTertiary.withValues(alpha: 0.3)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              dateStr,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Container(height: 1, color: AppColors.textTertiary.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}

class FullScreenPhotoViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenPhotoViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                headers: {
                  'apikey': Env.current.supabaseAnonKey,
                },
                errorBuilder: (_, __, ___) => Icon(
                  PhosphorIcons.imageBroken(),
                  size: 64,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              icon: Icon(PhosphorIcons.x(), color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
