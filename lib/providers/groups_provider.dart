import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/group.dart';
import '../models/chat_message.dart';
import '../services/at_talk_service.dart';

class GroupsProvider extends ChangeNotifier {
  final Map<String, Group> _groups = {};
  final Map<String, List<ChatMessage>> _groupMessages = {};
  bool _isConnected = false;

  Map<String, Group> get groups => _groups;
  bool get isConnected => _isConnected;

  List<Group> get sortedGroups {
    final groupsList = _groups.values.toList();
    groupsList.sort((a, b) {
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });
    return groupsList;
  }

  List<ChatMessage> getGroupMessages(String groupId) {
    return _groupMessages[groupId] ?? [];
  }

  void initialize() {
    _subscribeToMessages();
  }

  Group? createOrUpdateGroup(
    Set<String> members, {
    String? name,
    String? instanceId,
  }) {
    // Use instance ID if available, otherwise generate from members
    final groupId = instanceId ?? _generateGroupId(members);

    final existingGroup = _groups[groupId];
    final updatedGroup = Group(
      id: groupId,
      members: members,
      name: name ?? existingGroup?.name,
      lastMessage: existingGroup?.lastMessage,
      lastMessageTime: existingGroup?.lastMessageTime,
      unreadCount: existingGroup?.unreadCount ?? 0,
    );

    _groups[groupId] = updatedGroup;

    // Initialize message list if it doesn't exist
    _groupMessages[groupId] ??= [];

    notifyListeners();
    return updatedGroup;
  }

  void addMessageToGroup(String groupId, ChatMessage message) {
    _groupMessages[groupId] ??= [];
    _groupMessages[groupId]!.add(message);

    // Update group's last message info
    final group = _groups[groupId];
    if (group != null) {
      final updatedGroup = group.copyWith(
        lastMessage: message.text,
        lastMessageTime: message.timestamp,
        unreadCount: message.isFromMe
            ? group.unreadCount
            : group.unreadCount + 1,
      );
      _groups[groupId] = updatedGroup;
    }

    notifyListeners();
  }

  void markGroupAsRead(String groupId) {
    final group = _groups[groupId];
    if (group != null && group.unreadCount > 0) {
      _groups[groupId] = group.copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  Future<bool> sendMessageToGroup(String groupId, String message) async {
    final group = _groups[groupId];
    if (group == null) return false;

    final currentAtSign = AtTalkService.instance.currentAtSign;
    if (currentAtSign == null) return false;

    // Send to all group members (including current user to match TUI behavior)
    final recipients = group.members.toList();

    if (recipients.isEmpty) return false;

    print(
      'Sending message to group $groupId (${group.members.length} members) -> recipients: $recipients (including self)',
    ); // DEBUG

    bool allSuccess = true;

    // Decide whether to send as group message or individual messages
    final isActualGroup = group.members.length > 2;

    if (isActualGroup) {
      // Send as group message with JSON metadata (for 3+ person groups)
      final groupMembersList = group.members.toList();

      for (String recipient in recipients) {
        final success = await AtTalkService.instance.sendGroupMessage(
          toAtSign: recipient,
          message: message,
          groupMembers: groupMembersList,
          groupInstanceId: groupId,
          groupName: group.name,
        );
        if (!success) allSuccess = false;
      }
      print(
        'Sent as GROUP message to ${recipients.length} recipients',
      ); // DEBUG
    } else {
      // Send as plain text message (for 1-on-1 conversations)
      for (String recipient in recipients) {
        final success = await AtTalkService.instance.sendMessage(
          toAtSign: recipient,
          message: message,
        );
        if (!success) allSuccess = false;
      }
      print(
        'Sent as INDIVIDUAL message to ${recipients.length} recipients',
      ); // DEBUG
    }

    if (allSuccess) {
      // Don't add local message immediately - let it come back through the subscription
      // stream so it gets proper isFromMe detection when sent to self
      print(
        'Message sent successfully, waiting for it to arrive via subscription',
      ); // DEBUG
    }

    return allSuccess;
  }

  void _subscribeToMessages() {
    try {
      AtTalkService.instance.getAllMessageStream().listen((messageData) {
        final fromAtSign = messageData['from'] ?? '';
        final message = messageData['message'] ?? '';
        final rawValue = messageData['rawValue'] ?? '';

        print('Received message from $fromAtSign: $message'); // DEBUG
        print('Raw JSON data: $rawValue'); // DEBUG

        String? groupId;
        Set<String> groupMembers = {};

        // Try to extract group information from the raw JSON
        try {
          final jsonData = jsonDecode(rawValue);
          if (jsonData is Map<String, dynamic>) {
            final isGroupMessage = jsonData['isGroup'] == true;
            final jsonGroupMembers = jsonData['group'] as List<dynamic>?;
            final instanceId = jsonData['instanceId'] as String?;
            final groupName = jsonData['groupName'] as String?;

            if (isGroupMessage && jsonGroupMembers != null) {
              groupMembers = jsonGroupMembers.cast<String>().toSet();

              // If we have an instanceId, try to use it first
              if (instanceId != null && _groups.containsKey(instanceId)) {
                groupId = instanceId;
                // Update group name if provided and different
                final existingGroup = _groups[instanceId];
                if (existingGroup != null && groupName != null && groupName.isNotEmpty) {
                  if (existingGroup.name != groupName) {
                    _groups[instanceId] = existingGroup.copyWith(name: groupName);
                    notifyListeners();
                  }
                }
                print(
                  'Using existing group by instanceId: $instanceId for members: $groupMembers',
                ); // DEBUG
              } else {
                // Fall back to finding existing group by members
                final existingGroup = _findGroupByMembers(groupMembers);
                if (existingGroup != null) {
                  groupId = existingGroup.id;
                  // Update group name if provided and different
                  if (groupName != null && groupName.isNotEmpty && existingGroup.name != groupName) {
                    _groups[existingGroup.id] = existingGroup.copyWith(name: groupName);
                    notifyListeners();
                  }
                  print(
                    'Found existing group by members: ${existingGroup.id} for members: $groupMembers',
                  ); // DEBUG
                } else {
                  // Create new group with instanceId if provided, otherwise generate one
                  groupId = instanceId ?? _generateGroupId(groupMembers);
                  createOrUpdateGroup(
                    groupMembers,
                    instanceId: groupId,
                    name: groupName,
                  );
                  print(
                    'Created new group: $groupId for members: $groupMembers with name: $groupName',
                  ); // DEBUG
                }
              }
            }
          }
        } catch (e) {
          // If not JSON or parsing fails, treat as individual message
          final currentAtSign = AtTalkService.instance.currentAtSign;
          if (currentAtSign != null) {
            groupMembers = {fromAtSign, currentAtSign};

            // Check if a group already exists for these members
            final existingGroup = _findGroupByMembers(groupMembers);
            if (existingGroup != null) {
              groupId = existingGroup.id;
              print(
                'Found existing group: ${existingGroup.id} for individual message from $fromAtSign',
              ); // DEBUG
            } else {
              groupId = _generateGroupId(groupMembers);
              createOrUpdateGroup(groupMembers);
              print(
                'Created new individual group: $groupId for members: $groupMembers',
              ); // DEBUG
            }
          }
        }

        // Add message to the appropriate group
        if (groupId != null) {
          final currentAtSign = AtTalkService.instance.currentAtSign;
          final isFromCurrentUser =
              currentAtSign != null && fromAtSign == currentAtSign;

          print(
            'DEBUG: Message from $fromAtSign, current user: $currentAtSign, isFromMe: $isFromCurrentUser, message: "$message"',
          ); // DEBUG

          final chatMessage = ChatMessage(
            text: message,
            fromAtSign: fromAtSign,
            timestamp: DateTime.now(),
            isFromMe: isFromCurrentUser,
          );
          addMessageToGroup(groupId, chatMessage);
        }
      });
      _isConnected = true;
    } catch (e) {
      _isConnected = false;
      print('Error subscribing to messages: $e');
    }
  }

  // Find an existing group that has the same members
  // If multiple groups exist with the same members, return the most recent one
  Group? _findGroupByMembers(Set<String> members) {
    Group? foundGroup;
    DateTime? latestTime;
    
    for (final group in _groups.values) {
      if (group.members.length == members.length &&
          group.members.containsAll(members)) {
        // If this is the first match or it's more recent, use it
        if (foundGroup == null || 
            (group.lastMessageTime != null && 
             (latestTime == null || group.lastMessageTime!.isAfter(latestTime)))) {
          foundGroup = group;
          latestTime = group.lastMessageTime;
        }
      }
    }
    return foundGroup;
  }

  String _generateGroupId(Set<String> members) {
    final sortedMembers = members.toList()..sort();
    return sortedMembers.join('_');
  }

  void deleteGroup(String groupId) {
    _groups.remove(groupId);
    _groupMessages.remove(groupId);
    notifyListeners();
  }

  void clearAllGroups() {
    _groups.clear();
    _groupMessages.clear();
    notifyListeners();
  }
}
