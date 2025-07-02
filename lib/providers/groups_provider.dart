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

  Group? createOrUpdateGroup(Set<String> members, {String? name, String? instanceId}) {
    // Use TUI-compatible group ID generation
    final groupId = instanceId ?? _generateTUICompatibleGroupId(members);

    final existingGroup = _groups[groupId];

    // Critical safeguard: prevent overwriting groups with completely different membership
    // This helps prevent the bug where second group overwrites the first group
    if (existingGroup != null) {
      final existingMembers = existingGroup.members;
      final newMembers = members;

      // Check if the membership is compatible for updating
      final membershipChanged =
          existingMembers.length != newMembers.length ||
          !existingMembers.containsAll(newMembers) ||
          !newMembers.containsAll(existingMembers);

      if (membershipChanged) {
        print('⚠️ CRITICAL: Attempted to overwrite group $groupId with different membership!');
        print('   Existing members: $existingMembers');
        print('   New members: $newMembers');
        print('   This could be the "second group overwrites first" bug - generating unique ID instead');

        // Force a unique ID to prevent overwriting
        final uniqueGroupId = _generateUniqueGroupId(groupId);

        final newGroup = Group(id: uniqueGroupId, members: members, name: name, unreadCount: 0);

        _groups[uniqueGroupId] = newGroup;
        _groupMessages[uniqueGroupId] ??= [];

        print('🚨 Created separate group with unique ID: $uniqueGroupId to prevent overwrite');
        notifyListeners();
        return newGroup;
      }
    }

    // Preserve existing message history by not overriding the group if messages exist
    final existingMessages = _groupMessages[groupId];

    final updatedGroup =
        existingGroup?.copyWith(members: members, name: name ?? existingGroup.name) ??
        Group(id: groupId, members: members, name: name, unreadCount: 0);

    _groups[groupId] = updatedGroup;

    // Initialize message list if it doesn't exist, but preserve existing messages
    _groupMessages[groupId] ??= [];

    // Debug logging to track group creation/updates
    if (existingGroup == null) {
      print('🆕 Created new group (TUI-compatible): $groupId with ${members.length} members');
    } else {
      print('🔄 Updated existing group: $groupId (preserved ${existingMessages?.length ?? 0} messages)');
    }

    notifyListeners();
    return updatedGroup;
  }

  void addMessageToGroup(String groupId, ChatMessage message) {
    _groupMessages[groupId] ??= [];
    _groupMessages[groupId]!.add(message);

    // Update group's last message info
    final group = _groups[groupId];
    if (group != null) {
      print(
        '📩 Adding message to group $groupId (${group.members}) - Total messages: ${_groupMessages[groupId]!.length}',
      );

      final updatedGroup = group.copyWith(
        lastMessage: message.text,
        lastMessageTime: message.timestamp,
        unreadCount: message.isFromMe ? group.unreadCount : group.unreadCount + 1,
      );
      _groups[groupId] = updatedGroup;
    } else {
      print('⚠️ Attempted to add message to non-existent group: $groupId');
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

    print('Sending message to group $groupId (${group.members.length} members): ${group.members}');

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
      print('Added our own GROUP message to chat immediately for instant feedback');
    } else {
      // Send as JSON message with isGroup:false (for 1-on-1 conversations)
      // Send to ALL recipients including ourselves for proper TUI multi-instance support
      for (String recipient in recipients) {
        final success = await AtTalkService.instance.sendMessage(toAtSign: recipient, message: message);
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

        print('📨 GroupsProvider received: from=$fromAtSign, message="$message"');

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

              // Use TUI-compatible session finding and generation logic
              final currentAtSign = AtTalkService.instance.currentAtSign;
              if (currentAtSign == null) {
                print('❌ No current atSign - cannot process message');
                return;
              }

              // Use TUI logic to determine session key
              String sessionKey;
              if (!isGroupMessage && groupMembers.length == 2 && groupMembers.contains(currentAtSign)) {
                // Individual chat: use the other person's atSign as the key (TUI style)
                sessionKey = groupMembers.firstWhere((p) => p != currentAtSign);
                print('📱 Individual chat session key: $sessionKey (TUI-compatible)');
              } else if (groupMembers.length == 1 && groupMembers.first == currentAtSign) {
                // Self-chat session
                sessionKey = currentAtSign;
                print('📱 Self-chat session key: $sessionKey');
              } else {
                // Group chat: use comma-separated sorted list (TUI style)
                final sortedParticipants = groupMembers.toList()..sort();
                sessionKey = sortedParticipants.join(',');
                print('👥 Group chat session key: $sessionKey (TUI-compatible)');
              }

              // Try to find existing session with same participants first (TUI approach)
              final existingGroupWithParticipants = _findGroupByMembers(groupMembers);
              if (existingGroupWithParticipants != null) {
                groupId = existingGroupWithParticipants.id;
                print('✅ Found existing group by members: $groupId');

                // Update group name if provided and different
                if (groupName != null && groupName.isNotEmpty && existingGroupWithParticipants.name != groupName) {
                  _groups[groupId] = existingGroupWithParticipants.copyWith(name: groupName);
                  notifyListeners();
                  print('📝 Updated group name to: $groupName');
                }
              } else {
                // No exact match found - ALWAYS create a new group to prevent overwriting different groups
                // Migration is disabled for safety - each group should remain distinct
                print('🚫 No exact match found, creating new group instead of migrating (safety first)');

                // Create new session - ALWAYS use unique IDs to prevent overwriting existing groups
                // This ensures that if two different groups with identical membership try to create
                // sessions simultaneously, they won't overwrite each other

                // First, try to use the natural session key (TUI-compatible)
                String baseGroupId = sessionKey;

                // Check if this base ID already exists with different context
                // (e.g., different instanceId from the incoming message)
                final existingWithBaseId = _groups[baseGroupId];
                final incomingInstanceId = instanceId; // The instanceId from the incoming JSON message

                if (existingWithBaseId != null && incomingInstanceId != null) {
                  // If there's already a group with this base ID, and the incoming message
                  // has a different instanceId, create a unique timestamped group to avoid conflict
                  print(
                    '⚠️ Base group ID $baseGroupId already exists, creating unique group for different instanceId: $incomingInstanceId',
                  );
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  groupId = '${baseGroupId}#$timestamp';
                } else if (groupMembers.length > 2) {
                  // For multi-person groups, always create with unique timestamp to avoid overwrites
                  // This matches TUI behavior where /new or member additions create fresh sessions
                  groupId = _generateTUICompatibleGroupId(groupMembers, forceUniqueForGroup: true);
                } else {
                  // For individual chats, use standard session key (but double-check for conflicts)
                  if (_groups.containsKey(baseGroupId)) {
                    // Conflict detected even for 1-on-1 chat, create unique ID
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    groupId = '${baseGroupId}#$timestamp';
                    print('⚠️ Conflict detected for 1-on-1 chat $baseGroupId, creating unique ID: $groupId');
                  } else {
                    groupId = baseGroupId;
                  }
                }

                createOrUpdateGroup(groupMembers, instanceId: groupId, name: groupName);
                print('🆕 Created new group: $groupId (unique for safety, members=${groupMembers.length})');
              }
            }
          }
        } catch (e) {
          // If not JSON or parsing fails, treat as individual message (1-on-1 chat)
          print('📱 Processing plain text message from $fromAtSign (fallback)');
          print('📱 Parse error was: $e');
          final currentAtSign = AtTalkService.instance.currentAtSign;
          if (currentAtSign != null) {
            // Special case: if this is from ourselves, we need to find the existing 1-on-1 chat
            // we were just sending to, rather than trying to create a group with ourselves
            if (fromAtSign == currentAtSign) {
              print('📱 This is our own message - attempting to match to recent outgoing message');

              // Don't try to find "most recent" chat - this is prone to errors
              // Instead, only process if we can definitively match the message
              // Most of our own messages should already be added immediately when sent

              // Check if this exact message was already added recently to any group
              bool messageAlreadyExists = false;
              final now = DateTime.now();

              for (final groupId in _groupMessages.keys) {
                final messages = _groupMessages[groupId] ?? [];
                messageAlreadyExists = messages.any(
                  (existingMsg) =>
                      existingMsg.text == message &&
                      existingMsg.fromAtSign == fromAtSign &&
                      existingMsg.isFromMe == true &&
                      now.difference(existingMsg.timestamp).inSeconds < 30,
                );
                if (messageAlreadyExists) {
                  print('✅ Message already exists in group $groupId, skipping');
                  break;
                }
              }

              if (messageAlreadyExists) {
                return; // Skip this message as it's already been processed
              }

              print('⚠️ Our own message not found in any recent group - this might be from another instance');
              return; // Don't process ambiguous own messages
            } else {
              // Message from someone else - use TUI-compatible group creation
              groupMembers = {fromAtSign, currentAtSign};
              print('📱 1-on-1 members for incoming message: $groupMembers');

              // Use TUI-compatible session key generation
              final sortedParticipants = groupMembers.toList()..sort();
              final sessionKey = sortedParticipants.firstWhere((p) => p != currentAtSign);
              print('📱 TUI-compatible session key: $sessionKey');

              // Check if a group already exists for these members
              final existingGroup = _findGroupByMembers(groupMembers);
              if (existingGroup != null) {
                groupId = existingGroup.id;
                print('✅ Using existing 1-on-1 chat: ${existingGroup.id} for members: ${existingGroup.members}');
              } else {
                groupId = sessionKey; // Use TUI-compatible key
                createOrUpdateGroup(groupMembers, instanceId: groupId);
                print('🆕 Created new 1-on-1 chat: $groupId for members: $groupMembers (TUI-compatible)');
              }
            }
          } else {
            print('❌ No current atSign - cannot process 1-on-1 message');
          }
        }

        // Add message to the appropriate group
        if (groupId != null) {
          final currentAtSign = AtTalkService.instance.currentAtSign;
          final isFromCurrentUser = currentAtSign != null && fromAtSign == currentAtSign;

          print('📩 Adding message to group $groupId: from=$fromAtSign, isFromMe=$isFromCurrentUser');

          // For both 1-on-1 and group chats, check if we already have this exact message to avoid duplicates
          bool isDuplicate = false;
          if (isFromCurrentUser) {
            // Check if we already have this exact message from the same sender with a recent timestamp
            // Look for messages within the last 30 seconds across ALL groups to catch misrouted messages
            final now = DateTime.now();

            // Check across all groups, not just the current one
            for (final existingGroupId in _groupMessages.keys) {
              final existingMessages = _groupMessages[existingGroupId] ?? [];
              isDuplicate = existingMessages.any(
                (existingMsg) =>
                    existingMsg.text == message &&
                    existingMsg.fromAtSign == fromAtSign &&
                    existingMsg.isFromMe == true &&
                    now.difference(existingMsg.timestamp).inSeconds < 30,
              );

              if (isDuplicate) {
                print('⚠️ Duplicate detected: "$message" from $fromAtSign (already exists in group $existingGroupId)');
                break;
              }
            }
          } else {
            // For messages from others, only check the current group
            final existingMessages = _groupMessages[groupId] ?? [];
            final now = DateTime.now();
            isDuplicate = existingMessages.any(
              (existingMsg) =>
                  existingMsg.text == message &&
                  existingMsg.fromAtSign == fromAtSign &&
                  now.difference(existingMsg.timestamp).inSeconds < 10,
            );
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
  // For safety, avoid returning groups with identical members unless we're confident it's the right one
  // This helps prevent different logical groups from overwriting each other
  Group? _findGroupByMembers(Set<String> members) {
    final matchingGroups = <Group>[];

    for (final group in _groups.values) {
      if (group.members.length == members.length && group.members.containsAll(members)) {
        matchingGroups.add(group);
      }
    }

    // If no matches found, return null
    if (matchingGroups.isEmpty) {
      return null;
    }

    // If only one match found, return it
    if (matchingGroups.length == 1) {
      return matchingGroups.first;
    }

    // If multiple matches found, this is potentially problematic because it means
    // we have multiple groups with identical membership, which could lead to
    // message routing confusion. In this case, prefer the group with the most recent message.
    print('⚠️ Found ${matchingGroups.length} groups with identical members: $members');
    print('   This might indicate different logical groups that need to be kept separate');

    Group? bestMatch;
    DateTime? bestTime;

    for (final group in matchingGroups) {
      print(
        '   - Group ${group.id}: lastMessage=${group.lastMessageTime}, messages=${_groupMessages[group.id]?.length ?? 0}',
      );

      if (group.lastMessageTime != null) {
        if (bestTime == null || group.lastMessageTime!.isAfter(bestTime)) {
          bestMatch = group;
          bestTime = group.lastMessageTime;
        }
      } else if (bestMatch == null) {
        // If no group has messages yet, prefer the one with more total metadata or the first one
        bestMatch = group;
      }
    }

    if (bestMatch != null) {
      print('   Selected group: ${bestMatch.id}');
    }

    return bestMatch;
  }

  /// Generates group ID using TUI-compatible logic with UUID support:
  /// - For individual chats (2 participants): Use the other person's atSign as the key
  /// - For group chats (3+ participants): Use comma-separated sorted participant list
  /// - Add timestamp suffix for disambiguation if needed
  /// - Use UUIDs for new group creation to prevent overwrites
  String _generateTUICompatibleGroupId(Set<String> members, {bool forceUniqueForGroup = false}) {
    final sortedMembers = members.toList()..sort();
    final currentAtSign = AtTalkService.instance.currentAtSign;

    String groupId;

    if (sortedMembers.length == 2 && sortedMembers.contains(currentAtSign)) {
      // Individual chat: use the other person's atSign as the key (TUI style)
      groupId = sortedMembers.firstWhere((m) => m != currentAtSign);
      print('🔑 Generated individual chat ID: $groupId (TUI-compatible)');
    } else {
      // Group chat: use comma-separated sorted list (TUI style)
      groupId = sortedMembers.join(',');
      print('🔑 Generated group chat ID: $groupId (TUI-compatible)');

      // For group chats, if we're forcing uniqueness (like when creating a NEW group),
      // add timestamp suffix like TUI does
      if (forceUniqueForGroup || _groups.containsKey(groupId)) {
        groupId = _generateUniqueGroupId(groupId);
        print('🔧 Added unique suffix for group ID: $groupId (TUI-style)');
      }
    }

    // Check if this ID would conflict with an existing group with different members
    final existingGroup = _groups[groupId];
    if (existingGroup != null) {
      // Check if the members are exactly the same
      final sameMembers = existingGroup.members.length == members.length && existingGroup.members.containsAll(members);

      if (!sameMembers) {
        print('⚠️ Group ID conflict detected for $groupId');
        print('   Existing members: ${existingGroup.members}');
        print('   New members: $members');
        // In case of conflict, add a unique suffix (TUI style)
        groupId = _generateUniqueGroupId(groupId);
        print('🔧 Resolved conflict with unique suffix: $groupId');
      }
    }

    return groupId;
  }

  /// Generate a unique group ID by adding timestamp and counter to avoid collisions
  String _generateUniqueGroupId(String baseId) {
    String uniqueId;
    int counter = 0;
    do {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      uniqueId = counter == 0 ? '${baseId}#$timestamp' : '${baseId}#${timestamp}_$counter';
      counter++;
    } while (_groups.containsKey(uniqueId) && counter < 100); // Safety limit

    return uniqueId;
  }

  /// Legacy method for backwards compatibility - delegates to TUI-compatible version
  String _generateGroupId(Set<String> members) {
    return _generateTUICompatibleGroupId(members);
  }

  /// Create a new group with a unique ID (used when explicitly creating groups to avoid overwrites)
  String createNewGroupWithUniqueId(Set<String> members, {String? name}) {
    // Force unique ID generation for new groups to prevent overwrites
    final baseId = _generateTUICompatibleGroupId(members);
    final groupId = _generateUniqueGroupId(baseId);

    final newGroup = Group(id: groupId, members: members, name: name, unreadCount: 0);

    _groups[groupId] = newGroup;
    _groupMessages[groupId] ??= [];

    print('🆕 Created new group with guaranteed unique ID: $groupId (${members.length} members)');
    notifyListeners();
    return groupId;
  }

  Group? createNewGroupWithUniqueName(Set<String> members, {String? name}) {
    // Force unique ID generation for new groups to prevent overwrites (TUI behavior)
    final groupId = _generateTUICompatibleGroupId(members, forceUniqueForGroup: true);

    final newGroup = Group(id: groupId, members: members, name: name, unreadCount: 0, lastMessageTime: DateTime.now());

    _groups[groupId] = newGroup;
    _groupMessages[groupId] ??= [];

    print('🆕 Created new group with unique ID: $groupId with ${members.length} members');
    notifyListeners();
    return newGroup;
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

  Future<bool> updateGroupMembership(String groupId, List<String> newMembers, String? groupName) async {
    final group = _groups[groupId];
    if (group == null) return false;

    try {
      // Update local group membership
      _groups[groupId] = group.copyWith(members: newMembers.toSet(), name: groupName);
      notifyListeners();

      // Notify all participants (both old and new) about the membership change
      final allParticipants = Set<String>.from(group.members)..addAll(newMembers);
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
      final groupMembers = (jsonData['group'] as List<dynamic>?)?.cast<String>() ?? [];
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
        final displayName = newGroupName?.isNotEmpty == true ? newGroupName! : 'Unnamed Group';

        // Use the actual sender's atSign (like TUI format) instead of 'System'
        final currentAtSign = AtTalkService.instance.currentAtSign;
        final isFromCurrentUser = currentAtSign != null && fromAtSign == currentAtSign;

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
      final newMembers = (jsonData['group'] as List<dynamic>?)?.cast<String>() ?? [];
      final groupName = jsonData['groupName'] as String?;
      final instanceId = jsonData['instanceId'] as String?;
      final fromAtSign = jsonData['from'] as String?;

      print('DEBUG: Handling group membership change:');
      print('  - newMembers: $newMembers');
      print('  - groupName: $groupName');
      print('  - instanceId: $instanceId');
      print('  - fromAtSign: $fromAtSign');
      print('  - Current groups: ${_groups.keys.toList()}');
      print('  - Current group details:');
      for (final entry in _groups.entries) {
        print('    * ${entry.key}: members=${entry.value.members}');
      }

      if (newMembers.isEmpty) return;

      String? groupId;
      Group? existingGroup;

      // Try to find group by instance ID first (this is the most reliable)
      if (instanceId != null && _groups.containsKey(instanceId)) {
        groupId = instanceId;
        existingGroup = _groups[instanceId];
        print('DEBUG: Found group by instanceId: $instanceId');
      } else {
        // For TUI compatibility, we need more sophisticated group matching
        // The key insight: when members are removed, we need to find the group that
        // currently contains ALL the new members PLUS some additional members
        final newMembersSet = newMembers.toSet();

        print('DEBUG: Looking for group to update with new members: $newMembersSet');

        // Strategy 1: Find a group that contains all new members as a subset
        // and has MORE members (indicating we're removing some)
        Group? bestMatch;
        int smallestSizeDifference = 999;

        for (final group in _groups.values) {
          final groupMembers = group.members;
          print('DEBUG: Checking group ${group.id} with members: $groupMembers');

          // Check if this group contains all the new members (subset)
          final containsAllNewMembers = newMembersSet.every((member) => groupMembers.contains(member));

          if (containsAllNewMembers) {
            final sizeDifference = groupMembers.length - newMembersSet.length;
            print('DEBUG: Group ${group.id} contains all new members, size difference: $sizeDifference');

            // Prefer the group with the smallest positive size difference
            // (closest match for member removal)
            if (sizeDifference >= 0 && sizeDifference < smallestSizeDifference) {
              bestMatch = group;
              smallestSizeDifference = sizeDifference;
              print('DEBUG: New best match: ${group.id} (difference: $sizeDifference)');
            }
          }
        }

        if (bestMatch != null) {
          existingGroup = bestMatch;
          groupId = bestMatch.id;
          print('DEBUG: Found group to update by best subset match: ${bestMatch.id}');
        }
      }

      if (existingGroup != null && groupId != null) {
        final oldMembers = existingGroup.members;
        final newMembersSet = newMembers.toSet();

        print('DEBUG: Updating existing group:');
        print('  - Group ID: $groupId');
        print('  - Old members: $oldMembers');
        print('  - New members: $newMembersSet');

        // Update the group
        _groups[groupId] = existingGroup.copyWith(members: newMembersSet, name: groupName);

        // Use the actual sender's atSign (like TUI format) instead of 'System'
        final currentAtSign = AtTalkService.instance.currentAtSign;
        final isFromCurrentUser = currentAtSign != null && fromAtSign == currentAtSign;

        // Add system messages for member changes
        final added = newMembersSet.difference(oldMembers);
        final removed = oldMembers.difference(newMembersSet);

        print('DEBUG: Member changes - Added: $added, Removed: $removed');

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
        print('DEBUG: Group $groupId membership updated successfully: +${added.length}, -${removed.length}');
      } else {
        // Create new group if not found
        print('DEBUG: No existing group found! Creating new group...');
        print('  - Attempted instanceId: $instanceId');
        print('  - Attempted member matching failed');
        print('  - This might cause TUI to see a duplicate group!');

        final newGroupId = instanceId ?? _generateGroupId(newMembers.toSet());
        _groups[newGroupId] = Group(
          id: newGroupId,
          members: newMembers.toSet(),
          lastMessageTime: DateTime.now(),
          name: groupName,
        );
        notifyListeners();
        print('DEBUG: Created new group $newGroupId with ${newMembers.length} members (this may be a duplicate!)');
      }
    } catch (e) {
      print('Error handling group membership change: $e');
    }
  }
}
