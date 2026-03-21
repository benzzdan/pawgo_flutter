import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/error_handler.dart';

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
  String? _currentUserId;

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
      _fetchMessages();
      _subscribeToMessages();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    super.dispose();
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
            // Fetch full message with user join
            _fetchSingleMessage(newMessage['id'].toString());
          },
        )
        .subscribe();
  }

  Future<void> _fetchSingleMessage(String messageId) async {
    try {
      final data = await _supabase
          .from('messages')
          .select('*, users(full_name, avatar_url)')
          .eq('id', messageId)
          .single();

      if (mounted) {
        // Avoid duplicates
        final exists = _messages.any((m) => m['id'].toString() == messageId);
        if (!exists) {
          setState(() {
            _messages.add(Map<String, dynamic>.from(data));
          });
          _scrollToBottom();
        }
      }
    } catch (_) {}
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
      picked = await _imagePicker.pickImage(source: ImageSource.camera);
    } else {
      picked = await _imagePicker.pickMedia();
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
          'file_data': bytes.toList(),
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
        ErrorHandler.instance.showRecoverableError(context, 'Failed to upload media');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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

  void _showMediaSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _handleMediaUpload(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMessages(),
            ),
            _buildQuickActions(),
            _buildInput(),
          ],
        ),
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
              child: const Icon(Icons.arrow_back,
                  size: 20, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.orange400, AppColors.orange500],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.person, size: 24, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _otherPartyName ?? 'Chat',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
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
            Icon(Icons.chat_bubble_outline,
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _MessageBubble(
            message: msg,
            isCurrentUser: msg['sender_id'] == _currentUserId,
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.pets, 'label': 'Pee break', 'status': 'Pee break completed'},
      {'icon': Icons.eco, 'label': 'Poop', 'status': 'Poop pickup completed'},
      {'icon': Icons.water_drop, 'label': 'Water', 'status': 'Water break taken'},
      {'icon': Icons.camera_alt, 'label': 'Photo', 'action': 'photo'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: actions.map((a) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (a['action'] == 'photo') {
                  _showMediaSourcePicker();
                } else {
                  _sendStatusUpdate(a['status'] as String);
                }
              },
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
                  : const Icon(Icons.image,
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
                onChanged: (val) => setState(() => _message = val),
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
            onTap: _handleSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _message.trim().isNotEmpty
                    ? AppColors.orange500
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _message.trim().isNotEmpty
                    ? [
                        BoxShadow(
                          color: AppColors.orange500.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.send,
                size: 18,
                color: _message.trim().isNotEmpty
                    ? Colors.white
                    : const Color(0xFFCCCCCC),
              ),
            ),
          ),
        ],
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
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        Flexible(
          child: Column(
            crossAxisAlignment:
                isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (_hasMedia) _buildMediaContent(),
              if (message['content'] != null &&
                  message['content'].toString().isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        isCurrentUser ? AppColors.orange500 : AppColors.white,
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
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
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
              child: const Center(
                child: Icon(Icons.play_circle_outline,
                    size: 48, color: Colors.white),
              ),
            )
          else
            Image.network(
              mediaUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surface,
                child: const Center(
                  child: Icon(Icons.broken_image,
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
    IconData icon = Icons.info_outline;
    Color color = AppColors.blue500;

    if (content.toLowerCase().contains('pee')) {
      icon = Icons.pets;
      color = AppColors.orange500;
    } else if (content.toLowerCase().contains('poop')) {
      icon = Icons.eco;
      color = AppColors.green600;
    } else if (content.toLowerCase().contains('water')) {
      icon = Icons.water_drop;
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
