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
    print('🚀 GroupsProvider initializing...');
    print('🚀 Current atSign: ${AtTalkService.instance.currentAtSign}');
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
      'Sending message to group $groupId (${group.members.length} members): ${group.members}',
    );

    // Update the group's lastMessageTime immediately when sending
    // This ensures that when our own message comes back, this group will be the "most recent"
    _groups[groupId] = group.copyWith(lastMessageTime: DateTime.now());
    notifyListeners();

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
      print('Sent as GROUP message to ${recipients.length} recipients');

      // Add our own message to the chat immediately for instant feedback
      // Even though we send to ourselves, we want immediate UI feedback for groups too
      final ourMessage = ChatMessage(
        text: message,
        fromAtSign: currentAtSign,
        timestamp: DateTime.now(),
        isFromMe: true,
      );
      addMessageToGroup(groupId, ourMessage);
      print(
        'Added our own GROUP message to chat immediately for instant feedback',
      );
    } else {
      // Send as JSON message with isGroup:false (for 1-on-1 conversations)
      // Send to ALL recipients including ourselves for proper TUI multi-instance support
      for (String recipient in recipients) {
        final success = await AtTalkService.instance.sendMessage(
          toAtSign: recipient,
          message: message,
        );
        if (!success) allSuccess = false;
      }
      print(
        'Sent as 1-ON-1 JSON message to ${recipients.length} recipients (including self for TUI multi-instance support)',
      );

      // Add our own message to the chat immediately for instant feedback
      // Even though we send to ourselves, we want immediate UI feedback
      final ourMessage = ChatMessage(
        text: message,
        fromAtSign: currentAtSign,
        timestamp: DateTime.now(),
        isFromMe: true,
      );
      addMessageToGroup(groupId, ourMessage);
      print('Added our own message to chat immediately for instant feedback');
    }

    if (allSuccess) {
      // Wait for message to arrive via subscription stream
      print('Message sent successfully, waiting for subscription confirmation');
    }

    return allSuccess;
  }

  void _subscribeToMessages() {
    print('🔄 GroupsProvider subscribing to messages...');
    try {
      AtTalkService.instance.getAllMessageStream().listen((messageData) {
        final fromAtSign = messageData['from'] ?? '';
        final message = messageData['message'] ?? '';
        final rawValue = messageData['rawValue'] ?? '';

        print(
          '📨 GroupsProvider received: from=$fromAtSign, message="$message"',
        );

        // Quick check for empty messages
        if (message.isEmpty) {
          print('⚠️ Ignoring empty message from $fromAtSign');
          return;
        }

        String? groupId;
        Set<String> groupMembers = {};

        // Try to extract group information from the raw JSON
        try {
          final jsonData = jsonDecode(rawValue);
          if (jsonData is Map<String, dynamic>) {
            final messageType = jsonData['type'] as String?;

            // Handle special message types first
            if (messageType == 'groupRename') {
              _handleGroupRename(jsonData);
              return;
            } else if (messageType == 'groupMembershipChange') {
              _handleGroupMembershipChange(jsonData);
              return;
            }

            final isGroupMessage = jsonData['isGroup'] == true;
            final jsonGroupMembers = jsonData['group'] as List<dynamic>?;
            final instanceId = jsonData['instanceId'] as String?;
            final groupName = jsonData['groupName'] as String?;

            print(
              '📋 Message analysis: isGroup=$isGroupMessage, hasMembers=${jsonGroupMembers != null}, memberCount=${jsonGroupMembers?.length}',
            );

            // Filter out messages from our own GUI instance to prevent self-chat
            final currentAtSign = AtTalkService.instance.currentAtSign;
            final ourInstanceId = AtTalkService.instance.instanceId;
            if (fromAtSign == currentAtSign && instanceId == ourInstanceId) {
              print('🚫 Ignoring message from our own instance: $instanceId');
              return;
            }

            // Process if it's explicitly a group message OR if it has group member information
            // This handles both TUI group messages and GUI 1-on-1 messages with JSON format
            if (jsonGroupMembers != null) {
              groupMembers = jsonGroupMembers.cast<String>().toSet();

              print(
                '🎯 Processing message with group metadata: isGroup=$isGroupMessage, members=$groupMembers, instanceId=$instanceId',
              );
              print('Current groups: ${_groups.keys.toList()}');

              // For 1-on-1 messages (isGroup=false), handle them as 2-member groups
              if (!isGroupMessage && groupMembers.length == 2) {
                print('📱 Processing 1-on-1 JSON message');

                // Special case: if the message is from ourselves, we need to find the EXISTING 1-on-1 chat
                // we were just participating in, not create a new self-chat
                final currentAtSign = AtTalkService.instance.currentAtSign;
                if (fromAtSign == currentAtSign) {
                  print(
                    '📱 This is our own 1-on-1 message - finding existing chat',
                  );
                  // Find the most recently active 2-member group that includes us but isn't just us
                  Group? targetGroup;
                  DateTime? latestTime;

                  for (final group in _groups.values) {
                    if (group.members.length == 2 &&
                        group.members.contains(currentAtSign) &&
                        !group.members.every((m) => m == currentAtSign)) {
                      // Exclude self-only chats
                      // Check if this is the most recent group
                      if (targetGroup == null ||
                          (group.lastMessageTime != null &&
                              (latestTime == null ||
                                  group.lastMessageTime!.isAfter(
                                    latestTime,
                                  )))) {
                        targetGroup = group;
                        latestTime = group.lastMessageTime;
                      }
                    }
                  }

                  if (targetGroup != null) {
                    groupId = targetGroup.id;
                    print(
                      '✅ Found existing 1-on-1 chat for our own message: ${targetGroup.id}',
                    );
                  } else {
                    print(
                      '❌ No existing 1-on-1 chat found - this message will be ignored',
                    );
                    return; // Don't create a self-chat
                  }
                } else {
                  // Message from someone else - find or create group normally
                  final existingGroup = _findGroupByMembers(groupMembers);
                  if (existingGroup != null) {
                    groupId = existingGroup.id;
                    print('✅ Using existing 1-on-1 chat: ${existingGroup.id}');
                  } else {
                    groupId = _generateGroupId(groupMembers);
                    createOrUpdateGroup(groupMembers);
                    print('🆕 Created new 1-on-1 chat: $groupId');
                  }
                }
              } else {
                // Handle multi-member group messages
                // If we have an instanceId, try to use it first
                if (instanceId != null && _groups.containsKey(instanceId)) {
                  groupId = instanceId;
                  // Update group name if provided and different
                  final existingGroup = _groups[instanceId];
                  if (existingGroup != null &&
                      groupName != null &&
                      groupName.isNotEmpty) {
                    if (existingGroup.name != groupName) {
                      _groups[instanceId] = existingGroup.copyWith(
                        name: groupName,
                      );
                      notifyListeners();
                    }
                  }
                  print(
                    'Using existing group by instanceId: $instanceId for members: $groupMembers',
                  );
                } else {
                  // Try to find existing group by members first
                  final existingGroup = _findGroupByMembers(groupMembers);
                  if (existingGroup != null) {
                    groupId = existingGroup.id;
                    // Update group name if provided and different
                    if (groupName != null &&
                        groupName.isNotEmpty &&
                        existingGroup.name != groupName) {
                      _groups[existingGroup.id] = existingGroup.copyWith(
                        name: groupName,
                      );
                      notifyListeners();
                    }
                    print(
                      'Found existing group by members: ${existingGroup.id} for external instanceId: $instanceId',
                    );
                  } else {
                    // Only create new group if no existing group found
                    groupId = instanceId ?? _generateGroupId(groupMembers);
                    createOrUpdateGroup(
                      groupMembers,
                      instanceId: groupId,
                      name: groupName,
                    );
                    print(
                      'Created new group: $groupId for members: $groupMembers with name: $groupName',
                    );
                  }
                }
              }
            }
          }
        } catch (e) {
          // If not JSON or parsing fails, treat as individual message (1-on-1 chat)
          print(
            '📱 Processing plain text message from $fromAtSign (catch block)',
          );
          print('📱 Parse error was: $e');
          final currentAtSign = AtTalkService.instance.currentAtSign;
          if (currentAtSign != null) {
            // Special case: if this is from ourselves, we need to find the existing 1-on-1 chat
            // we were just sending to, rather than trying to create a group with ourselves
            if (fromAtSign == currentAtSign) {
              print(
                '📱 This is our own message - finding most recent 1-on-1 chat',
              );
              // Look for the most recently active 2-member group that includes us
              Group? targetGroup;
              DateTime? latestTime;

              for (final group in _groups.values) {
                if (group.members.length == 2 &&
                    group.members.contains(currentAtSign)) {
                  // Check if this is the most recent group
                  if (targetGroup == null ||
                      (group.lastMessageTime != null &&
                          (latestTime == null ||
                              group.lastMessageTime!.isAfter(latestTime)))) {
                    targetGroup = group;
                    latestTime = group.lastMessageTime;
                  }
                }
              }

              if (targetGroup != null) {
                groupId = targetGroup.id;
                print(
                  '✅ Found most recent 1-on-1 chat for our own message: ${targetGroup.id}',
                );
                print(
                  '   Other member: ${targetGroup.members.where((m) => m != currentAtSign).first}',
                );
              } else {
                print('❌ No existing 1-on-1 chat found for our own message');
              }
            } else {
              // Message from someone else - create/find group normally
              groupMembers = {fromAtSign, currentAtSign};
              print('📱 1-on-1 members: $groupMembers');

              // Check if a group already exists for these members
              final existingGroup = _findGroupByMembers(groupMembers);
              if (existingGroup != null) {
                groupId = existingGroup.id;
                print('✅ Using existing 1-on-1 chat: ${existingGroup.id}');
              } else {
                groupId = _generateGroupId(groupMembers);
                createOrUpdateGroup(groupMembers);
                print('🆕 Created new 1-on-1 chat: $groupId');
              }
            }
          } else {
            print('❌ No current atSign - cannot process 1-on-1 message');
          }
        }

        // Add message to the appropriate group
        if (groupId != null) {
          final currentAtSign = AtTalkService.instance.currentAtSign;
          final isFromCurrentUser =
              currentAtSign != null && fromAtSign == currentAtSign;

          print(
            '📩 Adding message to group $groupId: from=$fromAtSign, isFromMe=$isFromCurrentUser',
          );

          // For both 1-on-1 and group chats, check if we already have this exact message to avoid duplicates
          // This happens when we send to ourselves and receive our own message back
          final existingMessages = _groupMessages[groupId] ?? [];

          bool isDuplicate = false;
          if (isFromCurrentUser) {
            // Check if we already have this exact message from the same sender with a recent timestamp
            // Look for messages within the last 10 seconds to account for network delays
            final now = DateTime.now();
            isDuplicate = existingMessages.any(
              (existingMsg) =>
                  existingMsg.text == message &&
                  existingMsg.fromAtSign == fromAtSign &&
                  existingMsg.isFromMe == true &&
                  now.difference(existingMsg.timestamp).inSeconds < 10,
            );

            if (isDuplicate) {
              print(
                '⚠️ Duplicate detected: "$message" from $fromAtSign (already exists within 10 seconds)',
              );
            }
          }

          if (!isDuplicate) {
            final chatMessage = ChatMessage(
              text: message,
              fromAtSign: fromAtSign,
              timestamp: DateTime.now(),
              isFromMe: isFromCurrentUser,
            );
            addMessageToGroup(groupId, chatMessage);
            print('✅ Message added successfully to UI');
          } else {
            print('⚠️ Skipped duplicate message from ourselves');
          }
        } else {
          print('❌ No groupId determined - message will be lost!');
        }
      });
      _isConnected = true;
      print('✅ GroupsProvider connected and listening for messages');
    } catch (e) {
      _isConnected = false;
      print('❌ GroupsProvider connection failed: $e');
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
                (latestTime == null ||
                    group.lastMessageTime!.isAfter(latestTime)))) {
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

  Future<bool> renameGroup(String groupId, String newName) async {
    final group = _groups[groupId];
    if (group == null) return false;

    try {
      // Update local group name
      _groups[groupId] = group.copyWith(name: newName);
      notifyListeners();

      // Notify all group members about the rename
      final recipients = group.members.toList();
      bool allSuccess = true;

      for (String recipient in recipients) {
        final success = await AtTalkService.instance.sendGroupRename(
          toAtSign: recipient,
          groupMembers: group.members.toList(),
          groupName: newName,
          groupInstanceId: groupId,
        );
        if (!success) allSuccess = false;
      }

      return allSuccess;
    } catch (e) {
      print('Error renaming group: $e');
      return false;
    }
  }

  Future<bool> updateGroupMembership(
    String groupId,
    List<String> newMembers,
    String? groupName,
  ) async {
    final group = _groups[groupId];
    if (group == null) return false;

    try {
      // Update local group membership
      _groups[groupId] = group.copyWith(
        members: newMembers.toSet(),
        name: groupName,
      );
      notifyListeners();

      // Notify all participants (both old and new) about the membership change
      final allParticipants = Set<String>.from(group.members)
        ..addAll(newMembers);
      bool allSuccess = true;

      for (String recipient in allParticipants) {
        final success = await AtTalkService.instance.sendGroupMembershipChange(
          toAtSign: recipient,
          groupMembers: newMembers,
          groupName: groupName,
          groupInstanceId: groupId,
        );
        if (!success) allSuccess = false;
      }

      return allSuccess;
    } catch (e) {
      print('Error updating group membership: $e');
      return false;
    }
  }

  void clearAllGroups() {
    _groups.clear();
    _groupMessages.clear();
    notifyListeners();
  }

  void _handleGroupRename(Map<String, dynamic> jsonData) {
    try {
      final groupMembers =
          (jsonData['group'] as List<dynamic>?)?.cast<String>() ?? [];
      final newGroupName = jsonData['groupName'] as String?;
      final instanceId = jsonData['instanceId'] as String?;
      final fromAtSign = jsonData['from'] as String?;

      if (groupMembers.isEmpty) return;

      String? groupId;

      // Try to find group by instance ID first
      if (instanceId != null && _groups.containsKey(instanceId)) {
        groupId = instanceId;
      } else {
        // Fall back to finding by members
        final existingGroup = _findGroupByMembers(groupMembers.toSet());
        groupId = existingGroup?.id;
      }

      if (groupId != null && _groups.containsKey(groupId)) {
        final group = _groups[groupId]!;
        _groups[groupId] = group.copyWith(name: newGroupName);

        // Add a system message about the rename, showing who did it
        final displayName = newGroupName?.isNotEmpty == true
            ? newGroupName!
            : 'Unnamed Group';

        // Use the actual sender's atSign (like TUI format) instead of 'System'
        final currentAtSign = AtTalkService.instance.currentAtSign;
        final isFromCurrentUser =
            currentAtSign != null && fromAtSign == currentAtSign;

        final systemMessage = ChatMessage(
          text: 'Group renamed to "$displayName"',
          fromAtSign: fromAtSign ?? 'System',
          timestamp: DateTime.now(),
          isFromMe: isFromCurrentUser,
        );
        addMessageToGroup(groupId, systemMessage);

        notifyListeners();
        print('Group $groupId renamed to "$displayName" by $fromAtSign');
      }
    } catch (e) {
      print('Error handling group rename: $e');
    }
  }

  void _handleGroupMembershipChange(Map<String, dynamic> jsonData) {
    try {
      final newMembers =
          (jsonData['group'] as List<dynamic>?)?.cast<String>() ?? [];
      final groupName = jsonData['groupName'] as String?;
      final instanceId = jsonData['instanceId'] as String?;
      final fromAtSign = jsonData['from'] as String?;

      if (newMembers.isEmpty) return;

      String? groupId;
      Group? existingGroup;

      // Try to find group by instance ID first
      if (instanceId != null && _groups.containsKey(instanceId)) {
        groupId = instanceId;
        existingGroup = _groups[instanceId];
      } else {
        // Look for existing group with similar members
        for (final group in _groups.values) {
          final commonMembers = group.members.intersection(newMembers.toSet());
          if (commonMembers.isNotEmpty &&
              commonMembers.length >= group.members.length * 0.5) {
            existingGroup = group;
            groupId = group.id;
            break;
          }
        }
      }

      if (existingGroup != null && groupId != null) {
        final oldMembers = existingGroup.members;
        final newMembersSet = newMembers.toSet();

        // Update the group
        _groups[groupId] = existingGroup.copyWith(
          members: newMembersSet,
          name: groupName,
        );

        // Use the actual sender's atSign (like TUI format) instead of 'System'
        final currentAtSign = AtTalkService.instance.currentAtSign;
        final isFromCurrentUser =
            currentAtSign != null && fromAtSign == currentAtSign;

        // Add system messages for member changes
        final added = newMembersSet.difference(oldMembers);
        final removed = oldMembers.difference(newMembersSet);

        for (final member in added) {
          final systemMessage = ChatMessage(
            text: '$member joined the group',
            fromAtSign: fromAtSign ?? 'System',
            timestamp: DateTime.now(),
            isFromMe: isFromCurrentUser,
          );
          addMessageToGroup(groupId, systemMessage);
        }

        for (final member in removed) {
          final systemMessage = ChatMessage(
            text: '$member left the group',
            fromAtSign: fromAtSign ?? 'System',
            timestamp: DateTime.now(),
            isFromMe: isFromCurrentUser,
          );
          addMessageToGroup(groupId, systemMessage);
        }

        notifyListeners();
        print(
          'Group $groupId membership updated: +${added.length}, -${removed.length}',
        );
      } else {
        // Create new group if not found
        final newGroupId = instanceId ?? _generateGroupId(newMembers.toSet());
        _groups[newGroupId] = Group(
          id: newGroupId,
          members: newMembers.toSet(),
          lastMessageTime: DateTime.now(),
          name: groupName,
        );
        notifyListeners();
        print(
          'Created new group $newGroupId with ${newMembers.length} members',
        );
      }
    } catch (e) {
      print('Error handling group membership change: $e');
    }
  }
}
