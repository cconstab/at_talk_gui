class Group {
  final String id;
  final Set<String> members;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String? name;

  Group({
    required this.id,
    required this.members,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.name,
  });

  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }

    // Generate a name from members
    if (members.isEmpty) return 'Empty Group';
    if (members.length == 1) return members.first;
    if (members.length == 2) return members.join(', ');

    final membersList = members.toList();
    return '${membersList.take(2).join(', ')} +${members.length - 2}';
  }

  Group copyWith({
    String? id,
    Set<String>? members,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    String? name,
  }) {
    return Group(
      id: id ?? this.id,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      name: name ?? this.name,
    );
  }
}
