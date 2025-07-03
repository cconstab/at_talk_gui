import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id;
  final String text;
  final String fromAtSign;
  final DateTime timestamp;
  final bool isFromMe;

  ChatMessage({
    String? id,
    required this.text,
    required this.fromAtSign,
    required this.timestamp,
    required this.isFromMe,
  }) : id = id ?? const Uuid().v4();

  @override
  String toString() {
    return 'ChatMessage{id: $id, text: $text, fromAtSign: $fromAtSign, timestamp: $timestamp, isFromMe: $isFromMe}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
