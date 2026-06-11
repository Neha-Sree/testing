import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'chat_screen.dart';
import 'services/mom_api_service.dart';
import 'theme/mom_ui.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserType,
    this.embedded = false,
  });

  final String currentUserId;
  final String currentUserType; // 'mother' or 'doctor'
  /// When true, omits the outer [Scaffold] app bar (e.g. mother dashboard [IndexedStack]).
  final bool embedded;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final MomApiService _apiService = MomApiService();
  List<Map<String, dynamic>> _chatRooms = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  Future<void> _loadChatRooms() async {
    setState(() => _isLoading = true);

    try {
      final rooms = await _apiService.getUserChatRooms(
        widget.currentUserId,
        widget.currentUserType,
      );
      setState(() {
        _chatRooms = rooms;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load chat rooms: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadChatRooms,
        ),
      ),
    );
  }

  String _formatLastMessageTime(String? lastMessageAt) {
    if (lastMessageAt == null) return '';

    try {
      final dateTime = DateTime.parse(lastMessageAt);
      final now = DateTime.now();

      if (dateTime.day == now.day &&
          dateTime.month == now.month &&
          dateTime.year == now.year) {
        return DateFormat('HH:mm').format(dateTime);
      } else if (dateTime.year == now.year) {
        return DateFormat('MMM dd').format(dateTime);
      } else {
        return DateFormat('MM/dd/yy').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.currentUserType == 'doctor' ? 'Patient Chats' : 'Doctor Chats';
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _chatRooms.isEmpty
            ? _buildEmptyState()
            : _buildChatRoomsList();

    if (widget.embedded) {
      return ColoredBox(
        color: MomUi.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MomUi.embeddedHeader(
              icon: Icons.chat_rounded,
              title: title,
              onRefresh: _loadChatRooms,
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: _loadChatRooms,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.currentUserType == 'doctor'
                ? 'Start a conversation with your patients'
                : 'Your doctor will appear here when available',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildChatRoomsList() {
    return RefreshIndicator(
      onRefresh: _loadChatRooms,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _chatRooms.length,
        itemBuilder: (context, index) {
          final room = _chatRooms[index];
          return _buildChatRoomTile(room);
        },
      ),
    );
  }

  Widget _buildChatRoomTile(Map<String, dynamic> room) {
    final otherParticipantName = room['other_participant_name'] as String;
    final otherParticipantId = room['other_participant_id'] as String;
    final otherParticipantType = room['other_participant_type'] as String;
    final lastMessage = room['last_message'] as String?;
    final lastMessageTime = room['last_message_at'] as String?;
    final unreadCount = room['unread_count'] as int;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: otherParticipantType == 'doctor'
              ? Colors.blue.shade100
              : Colors.pink.shade100,
          child: Icon(
            otherParticipantType == 'doctor'
                ? Icons.local_hospital
                : Icons.pregnant_woman,
            color: otherParticipantType == 'doctor' ? Colors.blue : Colors.pink,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherParticipantName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              lastMessage ?? 'No messages yet',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontStyle: lastMessage != null
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatLastMessageTime(lastMessageTime),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    currentUserId: widget.currentUserId,
                    currentUserType: widget.currentUserType,
                    otherUserId: otherParticipantId,
                    otherUserName: otherParticipantName,
                    otherUserType: otherParticipantType,
                  ),
                ),
              )
              .then((_) {
                // Refresh chat rooms when returning from chat
                _loadChatRooms();
              });
        },
      ),
    );
  }
}
