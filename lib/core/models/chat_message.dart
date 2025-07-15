import 'package:uuid/uuid.dart';

enum AttachmentType {
  image,
  document,
  audio,
  video,
  other,
}

class MessageAttachment {
  final String id;
  final String originalFileName;
  final AttachmentType type;
  final int sizeInBytes;
  final String? mimeType;
  final String? localPath; // Path to downloaded file
  final String? thumbnailPath; // Path to thumbnail for images/videos
  final bool isDownloaded;
  final double? downloadProgress; // 0.0 to 1.0

  const MessageAttachment({
    required this.id,
    required this.originalFileName,
    required this.type,
    required this.sizeInBytes,
    this.mimeType,
    this.localPath,
    this.thumbnailPath,
    this.isDownloaded = false,
    this.downloadProgress,
  });

  MessageAttachment copyWith({
    String? id,
    String? originalFileName,
    AttachmentType? type,
    int? sizeInBytes,
    String? mimeType,
    String? localPath,
    String? thumbnailPath,
    bool? isDownloaded,
    double? downloadProgress,
  }) {
    return MessageAttachment(
      id: id ?? this.id,
      originalFileName: originalFileName ?? this.originalFileName,
      type: type ?? this.type,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      mimeType: mimeType ?? this.mimeType,
      localPath: localPath ?? this.localPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalFileName': originalFileName,
      'type': type.name,
      'sizeInBytes': sizeInBytes,
      'mimeType': mimeType,
      'localPath': localPath,
      'thumbnailPath': thumbnailPath,
      'isDownloaded': isDownloaded,
      'downloadProgress': downloadProgress,
    };
  }

  static MessageAttachment fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id'] as String,
      originalFileName: json['originalFileName'] as String,
      type: AttachmentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AttachmentType.other,
      ),
      sizeInBytes: json['sizeInBytes'] as int,
      mimeType: json['mimeType'] as String?,
      localPath: json['localPath'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      downloadProgress: json['downloadProgress'] as double?,
    );
  }
}

class ChatMessage {
  final String id;
  final String text;
  final String fromAtSign;
  final DateTime timestamp;
  final bool isFromMe;
  final List<MessageAttachment> attachments;

  ChatMessage({
    String? id,
    required this.text,
    required this.fromAtSign,
    required this.timestamp,
    required this.isFromMe,
    this.attachments = const [],
  }) : id = id ?? const Uuid().v4();

  @override
  String toString() {
    return 'ChatMessage{id: $id, text: $text, fromAtSign: $fromAtSign, timestamp: $timestamp, isFromMe: $isFromMe, attachments: ${attachments.length}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  bool get hasAttachments => attachments.isNotEmpty;
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'fromAtSign': fromAtSign,
      'timestamp': timestamp.toIso8601String(),
      'isFromMe': isFromMe,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      fromAtSign: json['fromAtSign'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isFromMe: json['isFromMe'] as bool,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((a) => MessageAttachment.fromJson(a as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
