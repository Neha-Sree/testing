import 'dart:async';
import 'package:flutter/material.dart';

import 'services/chat_realtime_service.dart';
import 'services/mom_api_service.dart';

/// Live mother <-> doctor chat.
///
/// Uses a WebSocket to receive new messages, typing indicators and
/// presence in real time. Sending and history-load still go through
/// the REST API so the database stays the source of truth.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserType,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserType = 'doctor',
  });

  final String currentUserId;
  final String currentUserType; // 'mother' or 'doctor'
  final String otherUserId;
  final String otherUserName;
  final String otherUserType;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MomApiService _apiService = MomApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Oldest first, newest last (typical chat order).
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _roomId;
  ChatRealtimeService? _realtime;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;

  bool _otherOnline = false;
  bool _otherTyping = false;
  Timer? _otherTypingClearTimer;

  String get _currentUserId => widget.currentUserId.trim().toUpperCase();
  String get _otherUserId => widget.otherUserId.trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _otherTypingClearTimer?.cancel();
    _realtimeSub?.cancel();
    _realtime?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _isLoading = true);
    try {
      final doctorId = widget.currentUserType == 'doctor' ? _currentUserId : _otherUserId;
      final patientId = widget.currentUserType == 'mother' ? _currentUserId : _otherUserId;
      final roomData = await _apiService.createOrGetChatRoom(
        doctorId: doctorId,
        patientId: patientId,
      );
      _roomId = roomData['room_id'] as String;
      await _loadHistory();
      _connectRealtime();
    } catch (e) {
      _showError('Failed to start chat: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    final roomId = _roomId;
    if (roomId == null) return;
    try {
      // API returns newest-first; reverse so newest is at bottom.
      final history = await _apiService.getChatMessages(roomId);
      final ordered = history.reversed.toList(growable: true);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(ordered);
      });
      _scrollToBottom(animated: false);
      try {
        await _apiService.markMessagesAsRead(
          roomId: roomId,
          userId: _currentUserId,
        );
      } catch (_) {
        // Read receipts are best-effort; do not block viewing messages.
      }
    } catch (e) {
      _showError('Failed to load messages: $e');
    }
  }

  void _connectRealtime() {
    final roomId = _roomId;
    if (roomId == null) return;
    _realtime = ChatRealtimeService(
      roomId: roomId,
      userId: _currentUserId,
      userType: widget.currentUserType,
    );
    _realtimeSub = _realtime!.events.listen(_onRealtimeEvent);
    _realtime!.connect();
  }

  void _onRealtimeEvent(ChatRealtimeEvent event) {
    if (!mounted) return;
    switch (event) {
      case ChatHelloEvent(:final online):
        final isOnline = online.any((p) => p.userId == _otherUserId);
        setState(() => _otherOnline = isOnline);
      case ChatPresenceEvent(:final userId, :final online):
        if (userId == _otherUserId) {
          setState(() => _otherOnline = online);
        }
      case ChatTypingEvent(:final userId, :final isTyping):
        if (userId == _otherUserId) {
          _otherTypingClearTimer?.cancel();
          setState(() => _otherTyping = isTyping);
          if (isTyping) {
            // Failsafe: auto-clear after 4s if no follow-up event arrives.
            _otherTypingClearTimer = Timer(const Duration(seconds: 4), () {
              if (mounted) setState(() => _otherTyping = false);
            });
          }
        }
      case ChatMessageEvent(:final message):
        final senderId = (message['sender_id'] as String? ?? '').toUpperCase();
        // Avoid duplicating a message we just optimistically appended.
        final id = message['id'];
        final exists = id != null && _messages.any((m) => m['id'] == id);
        if (exists) return;
        setState(() {
          _messages.add(message);
          if (senderId == _otherUserId) _otherTyping = false;
        });
        _scrollToBottom();
        if (senderId != _currentUserId && _roomId != null) {
          // Best-effort read receipt.
          unawaited(_apiService.markMessagesAsRead(
            roomId: _roomId!,
            userId: _currentUserId,
          ));
        }
      case ChatReadEvent(:final userId, :final messageIds):
        if (userId == _otherUserId) {
          setState(() {
            for (final m in _messages) {
              if (m['id'] is int && messageIds.contains(m['id'] as int)) {
                m['is_read'] = true;
              }
            }
          });
        }
      case ChatConnectionErrorEvent():
        // Soft fail — auto-reconnect handles recovery.
        break;
    }
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    _realtime?.sendTyping(hasText);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final roomId = _roomId;
    if (text.isEmpty || roomId == null || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();
    _realtime?.sendTyping(false);

    try {
      final sent = await _apiService.sendMessage(
        roomId: roomId,
        senderId: _currentUserId,
        senderType: widget.currentUserType,
        messageText: text,
      );
      if (!mounted) return;
      final id = sent['id'];
      final alreadyShown = id != null && _messages.any((m) => m['id'] == id);
      if (!alreadyShown) {
        setState(() => _messages.add(sent));
        _scrollToBottom();
      }
    } catch (e) {
      _showError('Failed to send: $e');
      _messageController.text = text;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Icon(
                    widget.otherUserType == 'doctor'
                        ? Icons.local_hospital
                        : Icons.pregnant_woman,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _otherOnline ? Colors.greenAccent.shade400 : Colors.grey.shade400,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE91E63), width: 2),
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
                    widget.otherUserName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _otherTyping
                        ? 'typing\u2026'
                        : (_otherOnline ? 'Online' : 'Offline'),
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: _otherTyping ? FontStyle.italic : FontStyle.normal,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty ? _buildEmptyState() : _buildMessagesList(),
                ),
                if (_otherTyping) _buildTypingBubble(),
                _buildInput(),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Start a conversation',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Send a message to ${widget.otherUserName}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = (message['sender_id'] as String? ?? '').toUpperCase() == _currentUserId;
        return _MessageBubble(
          message: message,
          isMe: isMe,
          otherUserType: widget.otherUserType,
          currentUserType: widget.currentUserType,
        );
      },
    );
  }

  Widget _buildTypingBubble() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const _AnimatedDots(),
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message\u2026',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: const Color(0xFFE91E63),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isSending ? null : _sendMessage,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white),
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
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.otherUserType,
    required this.currentUserType,
  });

  final Map<String, dynamic> message;
  final bool isMe;
  final String otherUserType;
  final String currentUserType;

  @override
  Widget build(BuildContext context) {
    final text = (message['message_text'] as String?) ?? '';
    final created = message['created_at'] as String?;
    final ts = created == null ? null : DateTime.tryParse(created);
    final time = ts == null
        ? ''
        : '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    final isRead = message['is_read'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _Avatar(userType: otherUserType),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFE91E63) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    border: isMe ? null : Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: isRead ? Colors.blue.shade300 : Colors.grey.shade400,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            _Avatar(userType: currentUserType),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.userType});
  final String userType;
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.grey.shade200,
      child: Icon(
        userType == 'doctor' ? Icons.local_hospital : Icons.pregnant_woman,
        size: 14,
        color: Colors.grey.shade600,
      ),
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((t * 3) - i).clamp(0.0, 1.0);
            final scale = 0.6 + 0.6 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
              child: Transform.scale(
                scale: scale,
                child: const _Dot(),
              ),
            );
          }),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey.shade500,
        shape: BoxShape.circle,
      ),
    );
  }
}
