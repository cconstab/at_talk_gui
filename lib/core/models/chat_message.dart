class ChatMessage {
  final String text;
  final String fromAtSign;
  final DateTime timestamp;
  final bool isFromMe;

  ChatMessage({
    required this.text,
    required this.fromAtSign,
    required this.timestamp,
    required this.isFromMe,
  });

  @override
  String toString() {
    return 'ChatMessage{text: $text, fromAtSign: $fromAtSign, timestamp: $timestamp, isFromMe: $isFromMe}';
  }
}
