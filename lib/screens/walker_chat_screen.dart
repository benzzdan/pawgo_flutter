import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pawgo/services/chat_service.dart';
import 'package:pawgo/theme/app_theme.dart';

class WalkerChatScreen extends StatefulWidget {
  const WalkerChatScreen({super.key});

  @override
  State<WalkerChatScreen> createState() => _WalkerChatScreenState();
}

class _WalkerChatScreenState extends State<WalkerChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  String _message = '';

  late final ChatService _chatService;
  StreamSubscription<Message>? _messageSub;
  StreamSubscription<ChatConnectionState>? _connectionSub;

  String? _bookingId;
  String _otherPartyName = 'Chat';
  String _bookingStatus = '';

  final List<Message> _messages = [];
  bool _isLoading = true;
  String? _error;
  bool _isSending = false;
  ChatConnectionState _connectionState = ChatConnectionState.disconnected;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  /// Chat is only active when the booking walk has started.
  bool get _isChatActive => _bookingStatus == 'walk_started';

  @override
  void initState() {
    super.initState();
    _chatService = ChatService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bookingId != null) return; // already initialised

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _bookingId = args['booking_id'] as String?;
      _otherPartyName =
          args['other_party_name'] as String? ?? 'Chat';
    }

    if (_bookingId != null) {
      _loadMessages();
      _subscribeToMessages();
      _fetchBookingStatus();
    } else {
      setState(() {
        _isLoading = false;
        _error = 'No booking ID provided';
      });
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _connectionSub?.cancel();
    _chatService.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.fetchMessages(_bookingId!);
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(messages);
          _isLoading = false;
          _error = null;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load messages. Tap to retry.';
        });
      }
    }
  }

  void _subscribeToMessages() {
    _chatService.subscribe(_bookingId!);

    _messageSub = _chatService.messageStream.listen((message) {
      if (!mounted) return;
      // Avoid duplicates (the sender already adds optimistically)
      final exists = _messages.any((m) => m.id == message.id);
      if (!exists) {
        setState(() => _messages.add(message));
        _scrollToBottom();
      }
    });

    _connectionSub = _chatService.connectionStream.listen((state) {
      if (mounted) setState(() => _connectionState = state);
    });
  }

  Future<void> _fetchBookingStatus() async {
    try {
      final data = await Supabase.instance.client
          .from('bookings')
          .select('status')
          .eq('id', _bookingId!)
          .maybeSingle();
      if (mounted && data != null) {
        setState(() => _bookingStatus = data['status'] as String? ?? '');
      }
    } catch (_) {
      // Non-critical — chat input state defaults to disabled.
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _message.trim();
    if (text.isEmpty || _isSending || !_isChatActive) return;

    _textController.clear();
    setState(() {
      _message = '';
      _isSending = true;
    });

    try {
      final sent = await _chatService.sendMessage(_bookingId!, text);
      if (mounted) {
        final exists = _messages.any((m) => m.id == sent.id);
        if (!exists) {
          setState(() => _messages.add(sent));
        }
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _handleQuickAction(String text) {
    _textController.text = text;
    setState(() => _message = text);
    _handleSend();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_connectionState == ChatConnectionState.error ||
                _connectionState == ChatConnectionState.disconnected)
              _buildConnectionBanner(),
            Expanded(child: _buildBody()),
            if (!_isLoading && _error == null) _buildQuickActions(),
            if (!_isLoading && _error == null) _buildInput(),
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
          Icon(Icons.wifi_off, size: 16, color: AppColors.orange500),
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
              child: const Icon(Icons.arrow_back,
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
                    _otherPartyName.isNotEmpty
                        ? _otherPartyName[0].toUpperCase()
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
                  _otherPartyName,
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_isChatActive)
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.green500,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Active now',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.green600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on,
                  size: 18, color: AppColors.blue600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isLoading = true;
              _error = null;
            });
            _loadMessages();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to retry',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet.\nSay hello!',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];

        // Status update messages → centered pill badge
        if (msg.isStatusUpdate) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  msg.content ?? '',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _MessageBubble(
            message: msg,
            isCurrentUser: msg.senderId == _currentUserId,
            otherPartyInitial: _otherPartyName.isNotEmpty
                ? _otherPartyName[0].toUpperCase()
                : '?',
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    if (!_isChatActive) return const SizedBox.shrink();

    final actions = [
      {
        'emoji': '\u{1F44D}',
        'label': 'Thanks!',
      },
      {
        'emoji': '\u{2764}\u{FE0F}',
        'label': 'Great job!',
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: actions
            .map((a) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _handleQuickAction(a['label']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                          Text(a['emoji']!,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(
                            a['label']!,
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
                ))
            .toList(),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.image,
                size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: _isChatActive,
                      onChanged: (val) => setState(() => _message = val),
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: _isChatActive
                            ? 'Type a message...'
                            : 'Chat available during active walks',
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
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.emoji_emotions_outlined,
                        size: 20, color: AppColors.textTertiary),
                  ),
                ],
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
                Icons.send,
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
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;
  final String otherPartyInitial;

  const _MessageBubble({
    required this.message,
    required this.isCurrentUser,
    required this.otherPartyInitial,
  });

  String get _timeString {
    return DateFormat.jm().format(message.createdAt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia =
        message.mediaUrl != null && message.mediaType != 'status_update';

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
                otherPartyInitial,
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
            crossAxisAlignment: isCurrentUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (hasMedia)
                Container(
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
                  child: Image.network(
                    message.mediaUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, st) => Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: Icon(Icons.broken_image,
                            size: 32, color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                ),
              if (message.content != null && message.content!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
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
                    message.content!,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isCurrentUser
                          ? Colors.white
                          : AppColors.textPrimary,
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
                '\u{1F464}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }
}
