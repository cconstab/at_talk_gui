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
    return getDisplayName();
  }

  String getDisplayName([String? currentAtSign]) {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }

    // Generate a name from members - treat all groups consistently
    if (members.isEmpty) return 'Empty Group';
    if (members.length == 1) return members.first;

    // For any group, show meaningful member display
    if (currentAtSign != null && members.contains(currentAtSign)) {
      final otherMembers = members
          .where((member) => member != currentAtSign)
          .toList();
      if (otherMembers.isNotEmpty) {
        if (otherMembers.length == 1) {
          // Two members total: show the other person
          return otherMembers.first;
        } else {
          // Multiple other members: show list
          return otherMembers.length <= 2
              ? otherMembers.join(', ')
              : '${otherMembers.take(2).join(', ')} +${otherMembers.length - 2}';
        }
      }
    }

    // Fallback: show all members
    final membersList = members.toList();
    return membersList.length <= 3
        ? membersList.join(', ')
        : '${membersList.take(3).join(', ')} +${membersList.length - 3}';
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
