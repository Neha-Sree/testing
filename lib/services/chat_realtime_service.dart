import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'mom_api_base_url.dart';

/// Live-chat event types received over the WebSocket.
sealed class ChatRealtimeEvent {
  const ChatRealtimeEvent();
}

class ChatHelloEvent extends ChatRealtimeEvent {
  ChatHelloEvent({required this.roomId, required this.online});
  final String roomId;

  /// List of `{user_id, user_type}` entries currently connected.
  final List<({String userId, String userType})> online;
}

class ChatMessageEvent extends ChatRealtimeEvent {
  ChatMessageEvent(this.message);
  final Map<String, dynamic> message;
}

class ChatTypingEvent extends ChatRealtimeEvent {
  ChatTypingEvent({required this.userId, required this.userType, required this.isTyping});
  final String userId;
  final String userType;
  final bool isTyping;
}

class ChatPresenceEvent extends ChatRealtimeEvent {
  ChatPresenceEvent({required this.userId, required this.userType, required this.online});
  final String userId;
  final String userType;
  final bool online;
}

class ChatReadEvent extends ChatRealtimeEvent {
  ChatReadEvent({required this.userId, required this.messageIds});
  final String userId;
  final List<int> messageIds;
}

class ChatConnectionErrorEvent extends ChatRealtimeEvent {
  ChatConnectionErrorEvent(this.error);
  final Object error;
}

/// WebSocket client for the mother <-> doctor live chat.
///
/// Lifetime mirrors the chat screen: call [connect] in `initState`
/// and [dispose] in `dispose`. Auto-reconnects with exponential backoff
/// up to 30 seconds when the socket drops.
class ChatRealtimeService {
  ChatRealtimeService({
    required this.roomId,
    required this.userId,
    required this.userType,
  });

  final String roomId;
  final String userId;
  final String userType;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _events = StreamController<ChatRealtimeEvent>.broadcast();
  Timer? _reconnectTimer;
  Timer? _typingThrottle;
  int _reconnectAttempts = 0;
  bool _closed = false;

  Stream<ChatRealtimeEvent> get events => _events.stream;

  static String get _baseHttp => momApiBaseUrl();

  /// Converts http://host:port to ws://host:port for the WS endpoint.
  Uri _wsUri() {
    final base = Uri.parse(_baseHttp);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/ws/chat/$roomId',
      queryParameters: {
        'user_id': userId.trim().toUpperCase(),
        'user_type': userType.trim().toLowerCase(),
      },
    );
  }

  void connect() {
    if (_closed) return;
    _reconnectTimer?.cancel();
    try {
      _channel = WebSocketChannel.connect(_wsUri());
    } catch (e) {
      _events.add(ChatConnectionErrorEvent(e));
      _scheduleReconnect();
      return;
    }
    _subscription = _channel!.stream.listen(
      _onRaw,
      onError: (Object e, [StackTrace? s]) {
        _events.add(ChatConnectionErrorEvent(e));
        _scheduleReconnect();
      },
      onDone: _scheduleReconnect,
      cancelOnError: true,
    );
    _reconnectAttempts = 0;
  }

  void _onRaw(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = data['type'] as String?;
    switch (type) {
      case 'hello':
        final online = (data['online'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((m) => (
                  userId: (m['user_id'] as String? ?? '').toUpperCase(),
                  userType: (m['user_type'] as String? ?? '').toLowerCase(),
                ))
            .toList(growable: false);
        _events.add(ChatHelloEvent(
          roomId: data['room_id'] as String? ?? roomId,
          online: online,
        ));
      case 'message':
        final msg = data['message'];
        if (msg is Map<String, dynamic>) _events.add(ChatMessageEvent(msg));
      case 'typing':
        _events.add(ChatTypingEvent(
          userId: (data['user_id'] as String? ?? '').toUpperCase(),
          userType: (data['user_type'] as String? ?? '').toLowerCase(),
          isTyping: data['is_typing'] as bool? ?? false,
        ));
      case 'presence':
        _events.add(ChatPresenceEvent(
          userId: (data['user_id'] as String? ?? '').toUpperCase(),
          userType: (data['user_type'] as String? ?? '').toLowerCase(),
          online: data['online'] as bool? ?? false,
        ));
      case 'read':
        final ids = (data['message_ids'] as List<dynamic>? ?? const [])
            .map((e) => (e as num).toInt())
            .toList(growable: false);
        _events.add(ChatReadEvent(
          userId: (data['user_id'] as String? ?? '').toUpperCase(),
          messageIds: ids,
        ));
      case 'pong':
        // ignore
        break;
      default:
        if (kDebugMode) debugPrint('[ChatRealtime] unknown event: $raw');
    }
  }

  void _scheduleReconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (_closed) return;
    _reconnectAttempts++;
    final delaySeconds =
        (1 << (_reconnectAttempts.clamp(0, 5) - 1)).clamp(1, 30).toInt();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), connect);
  }

  /// Sends a typing indicator. Throttled to 1 send per 1.2 seconds.
  void sendTyping(bool isTyping) {
    _typingThrottle?.cancel();
    _typingThrottle = Timer(const Duration(milliseconds: 1200), () {
      _send({'type': 'typing', 'is_typing': isTyping});
    });
    if (isTyping) {
      _send({'type': 'typing', 'is_typing': true});
    }
  }

  void _send(Map<String, dynamic> payload) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(payload));
    } catch (_) {/* swallow per-message errors */}
  }

  Future<void> dispose() async {
    _closed = true;
    _reconnectTimer?.cancel();
    _typingThrottle?.cancel();
    await _subscription?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    await _events.close();
  }
}
