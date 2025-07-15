import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import '../models/group.dart';
import '../models/chat_message.dart';
import '../services/at_talk_service.dart';
import '../services/file_transfer_service.dart';

class GroupsProvider extends ChangeNotifier {
  final Map<String, Group> _groups = {};
  final Map<String, List<ChatMessage>> _groupMessages = {};
  bool _isConnected = false;
  StreamSubscription? _messageSubscription;

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

  /// Get total unread count across all groups, excluding the specified group
  int getTotalUnreadCount([String? excludeGroupId]) {
    return _groups.values
        .where((group) => excludeGroupId == null || group.id != excludeGroupId)
        .fold(0, (total, group) => total + group.unreadCount);
  }

  List<ChatMessage> getGroupMessages(String groupId) {
    return _groupMessages[groupId] ?? [];
  }

  void initialize() {
    print('🚀 GroupsProvider initializing...');
    print('🚀 Current atSign: ${AtTalkService.instance.currentAtSign}');
    _subscribeToMessages();
  }

  /// Reinitialize after namespace change - clears data and restarts subscriptions
  void reinitialize() {
    print('🔄 GroupsProvider reinitializing after namespace change...');

    // Cancel existing subscription first
    _messageSubscription?.cancel();

    // Clear all existing data
    clearAllGroups();

    // Restart message subscriptions with new namespace
    initialize();
  }

  /// Clean up resources
  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  Group? createOrUpdateGroup(Set<String> members, {String? name, String? instanceId}) {
    // Use TUI-compatible group ID generation
    final groupId = instanceId ?? _generateTUICompatibleGroupId(members);

    final existingGroup = _groups[groupId];

    // Critical safeguard: implement TUI-compatible migration rules to prevent overwriting
    // individual chats with group chats and vice versa
    if (existingGroup != null) {
      final existingMembers = existingGroup.members;
      final newMembers = members;

      // Apply TUI's migration rules:
      // 1. Individual chats (2 participants) should NOT be migrated to group chats (3+ participants)
      // 2. Group chats (3+ participants) should NOT be migrated to individual chats (2 participants)
      // 3. Only migrate if the participant count and membership are compatible

      bool shouldMigrate = false;

      if (existingMembers.length >= 3 && newMembers.length >= 3) {
        // Both are group chats - safe to migrate if there's significant overlap
        final currentAtSign = AtTalkService.instance.currentAtSign;
        shouldMigrate =
            existingMembers.intersection(newMembers).length >= 2 &&
            existingMembers.contains(currentAtSign) &&
            newMembers.contains(currentAtSign);
        print('🔄 Group-to-group migration check: shouldMigrate=$shouldMigrate');
      } else if (existingMembers.length == 2 && newMembers.length == 2) {
        // Both are individual chats - only migrate if they have exactly the same participants
        shouldMigrate =
            existingMembers.difference(newMembers).isEmpty && newMembers.difference(existingMembers).isEmpty;
        print('🔄 Individual-to-individual migration check: shouldMigrate=$shouldMigrate');
      } else {
        // Different participant counts - DON'T migrate to prevent overwriting
        shouldMigrate = false;
        print('🚫 Preventing migration: existing(${existingMembers.length}) vs new(${newMembers.length}) participants');
        print('   Existing: $existingMembers');
        print('   New: $newMembers');
        print('   This prevents individual chats from being overwritten by group chats and vice versa');
      }

      if (!shouldMigrate) {
        print('⚠️ MIGRATION BLOCKED: Cannot migrate group $groupId');
        print('   Existing members (${existingMembers.length}): $existingMembers');
        print('   New members (${newMembers.length}): $newMembers');
        print('   Generating unique ID to preserve both conversations');

        // Force a unique ID to prevent overwriting
        final uniqueGroupId = _generateUniqueGroupId(groupId);

        final newGroup = Group(id: uniqueGroupId, members: members, name: name, unreadCount: 0);

        _groups[uniqueGroupId] = newGroup;
        _groupMessages[uniqueGroupId] ??= [];

        print('✅ Created separate group with unique ID: $uniqueGroupId to preserve original conversation');
        notifyListeners();
        return newGroup;
      } else {
        print('✅ Migration allowed: compatible participant counts and membership');
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

      // Generate TUI-compatible session key for consistent message routing
      final sortedMembers = group.members.toList()..sort();
      final sessionKey = sortedMembers.join(',');

      // Add our own message to the chat BEFORE sending to prevent race conditions
      // This ensures our immediate message is always added before any notifications arrive
      final ourMessage = ChatMessage(
        text: message,
        fromAtSign: currentAtSign,
        timestamp: DateTime.now(),
        isFromMe: true,
      );

      // Use canonical group to ensure consistency with notification handling
      final canonicalGroupId = _getOrCreateCanonicalGroup(groupId, currentAtSign, currentAtSign);
      if (canonicalGroupId != groupId) {
        print('🔀 Using canonical group for immediate GROUP message: $canonicalGroupId (was: $groupId)');
        groupId = canonicalGroupId;
      }

      print(
        '➕ Adding our own GROUP message immediately (BEFORE sending): ID=${ourMessage.id}, text="$message", timestamp=${ourMessage.timestamp}',
      );
      print('   Target groupId: $groupId');
      print('   Group members: ${group.members}');
      print('   Current message count before adding: ${_groupMessages[groupId]?.length ?? 0}');
      addMessageToGroup(groupId, ourMessage);
      print('Added our own GROUP message to chat immediately for instant feedback');

      for (String recipient in recipients) {
        final success = await AtTalkService.instance.sendGroupMessage(
          toAtSign: recipient,
          message: message,
          groupMembers: groupMembersList,
          groupInstanceId: sessionKey, // Use consistent session key, not internal group ID
          groupName: group.name,
        );
        if (!success) allSuccess = false;
      }
      print('Sent as GROUP message to ${recipients.length} recipients');
    } else {
      // Send as JSON message with isGroup:false (for 1-on-1 conversations)
      // Send to ALL recipients including ourselves for proper TUI multi-instance support
      final groupMembersList = group.members.toList()..sort(); // Consistent group member list

      // Add our own message to the chat BEFORE sending to prevent race conditions
      // This ensures our immediate message is always added before any notifications arrive
      final ourMessage = ChatMessage(
        text: message,
        fromAtSign: currentAtSign,
        timestamp: DateTime.now(),
        isFromMe: true,
      );

      // Use canonical group to ensure consistency with notification handling
      final canonicalGroupId = _getOrCreateCanonicalGroup(groupId, currentAtSign, currentAtSign);
      if (canonicalGroupId != groupId) {
        print('🔀 Using canonical group for immediate message: $canonicalGroupId (was: $groupId)');
        groupId = canonicalGroupId;
      }

      print(
        '➕ Adding our own 1-on-1 message immediately (BEFORE sending): ID=${ourMessage.id}, text="$message", timestamp=${ourMessage.timestamp}',
      );
      print('   Target groupId: $groupId');
      print('   Group members: ${group.members}');
      print('   Current message count before adding: ${_groupMessages[groupId]?.length ?? 0}');
      addMessageToGroup(groupId, ourMessage);
      print('Added our own message to chat immediately for instant feedback');

      for (String recipient in recipients) {
        final success = await AtTalkService.instance.sendMessage(
          toAtSign: recipient,
          message: message,
          groupMembers: groupMembersList, // Pass the consistent group members
        );
        if (!success) allSuccess = false;
      }
      print(
        'Sent as 1-ON-1 JSON message to ${recipients.length} recipients (including self for TUI multi-instance support)',
      );
    }

    if (allSuccess) {
      // Wait for message to arrive via subscription stream
      print('Message sent successfully, waiting for subscription confirmation');
    }

    return allSuccess;
  }

  /// Send a file message to a group
  Future<bool> sendFileMessage(String groupId, String filePath, String? caption) async {
    final group = _groups[groupId];
    if (group == null) {
      print('❌ Group not found: $groupId');
      return false;
    }

    final currentAtSign = AtTalkService.instance.currentAtSign;
    if (currentAtSign == null) {
      print('❌ No current atSign available');
      return false;
    }

    try {
      print('📤 Starting file upload: $filePath');

      // Upload file and get the attachment
      final attachment = await FileTransferService.instance.uploadFile(filePath);
      if (attachment == null) {
        print('❌ Failed to upload file: $filePath');
        return false;
      }

      print('✅ File uploaded, sending to ${group.members.length} recipients');

      // Send file message to all group members
      final recipients = group.members.toList();
      bool allSuccess = true;

      for (String recipient in recipients) {
        try {
          final success = await FileTransferService.instance.sendFileMessage(
            toAtSign: recipient,
            attachment: attachment,
            caption: caption,
            groupMembers: group.members.toList(),
          );
          if (!success) {
            print('❌ Failed to send to recipient: $recipient');
            allSuccess = false;
          } else {
            print('✅ Sent successfully to: $recipient');
          }
        } catch (e) {
          print('❌ Error sending to $recipient: $e');
          allSuccess = false;
        }
      }

      if (allSuccess) {
        print('✅ File message sent successfully to group $groupId');
      } else {
        print('⚠️ Some file message deliveries failed for group $groupId');
      }

      return allSuccess;
    } catch (e) {
      print('❌ Error sending file message: $e');

      // Log the specific error for debugging
      if (e.toString().contains('File too large')) {
        print('❌ File size exceeded limit');
      } else if (e.toString().contains('AtClient not initialized')) {
        print('❌ AtClient connection issue');
      }

      return false;
    }
  }

  void _subscribeToMessages() {
    print('🔄 GroupsProvider subscribing to messages...');

    // Cancel any existing subscription first
    _messageSubscription?.cancel();

    try {
      _messageSubscription = AtTalkService.instance.getAllMessageStream().listen((messageData) async {
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

            // Get current atSign for filtering
            final currentAtSign = AtTalkService.instance.currentAtSign;

            // Handle special message types first
            if (messageType == 'groupRename') {
              // Skip processing our own rename notifications to prevent duplicate groups
              if (fromAtSign == currentAtSign) {
                print('🚫 Ignoring rename notification from ourselves');
                return;
              }
              _handleGroupRename(jsonData);
              return;
            } else if (messageType == 'groupMembershipChange') {
              // Skip processing our own membership change notifications
              if (fromAtSign == currentAtSign) {
                print('🚫 Ignoring membership change notification from ourselves');
                return;
              }
              _handleGroupMembershipChange(jsonData);
              return;
            } else if (messageType == 'file') {
              // Handle file message - download if needed
              await _handleFileMessage(jsonData, fromAtSign);
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
            final ourInstanceId = AtTalkService.instance.instanceId;

            // Legacy check: filter out messages using old instanceId matching
            if (fromAtSign == currentAtSign && instanceId == ourInstanceId) {
              print('🚫 Ignoring message from our own instance (legacy check): $instanceId');
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
              if (currentAtSign == null) {
                print('❌ No current atSign - cannot process message');
                return;
              }

              // Use TUI logic to determine session key
              String sessionKey;
              if (groupMembers.length == 1 && groupMembers.first == currentAtSign) {
                // Self-chat session
                sessionKey = currentAtSign;
                print('📱 Self-chat session key: $sessionKey');
              } else {
                // All groups: use comma-separated sorted list (consistent format)
                final sortedParticipants = groupMembers.toList()..sort();
                sessionKey = sortedParticipants.join(',');
                print('📱 Group session key: $sessionKey (consistent format)');
              }

              // Try to find existing session with same participants first (TUI approach)
              // CRITICAL: Apply TUI's safeguard to prevent individual chats from being overwritten by group chats
              Group? existingGroupWithParticipants;

              // First check if there's a group with exactly matching participants
              final candidateGroup = _findGroupByMembers(groupMembers);

              if (candidateGroup != null) {
                // Apply TUI's migration rules before using this group
                final existingMembers = candidateGroup.members;
                final newMembers = groupMembers;

                bool shouldUseExisting = false;

                if (existingMembers.length >= 3 && newMembers.length >= 3) {
                  // Both are group chats - safe to use existing
                  shouldUseExisting = true;
                  print('✅ Both are group chats - safe to use existing group: ${candidateGroup.id}');
                } else if (existingMembers.length == 2 && newMembers.length == 2) {
                  // Both are individual chats with same participants - safe to use existing
                  shouldUseExisting = true;
                  print(
                    '✅ Both are individual chats with same participants - safe to use existing: ${candidateGroup.id}',
                  );
                } else {
                  // Different participant counts - TUI safeguard: don't overwrite
                  shouldUseExisting = false;
                  print(
                    '🚫 TUI SAFEGUARD: Preventing overwrite of ${existingMembers.length}-person chat with ${newMembers.length}-person chat',
                  );
                  print(
                    '   Existing group: ${candidateGroup.id} (${existingMembers.length} members): $existingMembers',
                  );
                  print('   New message: (${newMembers.length} members): $newMembers');
                  print('   Will create separate conversation to preserve both');
                }

                if (shouldUseExisting) {
                  existingGroupWithParticipants = candidateGroup;
                }
              }

              if (existingGroupWithParticipants != null) {
                groupId = existingGroupWithParticipants.id;
                print('✅ GUI: Found existing group by members: $groupId');

                // Update group name if provided and different
                if (groupName != null && groupName.isNotEmpty && existingGroupWithParticipants.name != groupName) {
                  _groups[groupId] = existingGroupWithParticipants.copyWith(name: groupName);
                  notifyListeners();
                  print('📝 GUI: Updated group name to: $groupName');
                }
              } else {
                // No exact match found - create new group with TUI-compatible ID
                print('❌ GUI: No existing group found with members: $groupMembers');
                print('🆕 GUI: Creating new group for incoming message');
                print('   InstanceId from message: $instanceId');
                print('   Session key: $sessionKey');
                print('   Group name: $groupName');

                // CRITICAL FIX: For incoming messages, prefer the instanceId if it matches our session key format
                // This ensures GUI and TUI use the same group ID for the same conversation
                String newGroupId;

                if (instanceId != null && instanceId == sessionKey) {
                  // The instanceId matches our computed session key - use it for perfect TUI compatibility
                  newGroupId = instanceId;
                  print('✅ GUI: Using TUI-provided instanceId for perfect compatibility: $newGroupId');
                } else if (instanceId != null && !_groups.containsKey(instanceId)) {
                  // The instanceId is different but available - use it to maintain TUI compatibility
                  newGroupId = instanceId;
                  print('🔧 GUI: Using TUI-provided instanceId for compatibility: $newGroupId');
                } else {
                  // Fall back to our session key format
                  if (!_groups.containsKey(sessionKey)) {
                    newGroupId = sessionKey;
                    print('✅ GUI: Using computed session key: $newGroupId');
                  } else {
                    // Session key exists, create unique ID
                    newGroupId = _generateTUICompatibleGroupId(groupMembers, forceUniqueForGroup: true);
                    print('🔧 GUI: Session key conflict, using unique ID: $newGroupId');
                  }
                }

                createOrUpdateGroup(groupMembers, instanceId: newGroupId, name: groupName);
                groupId = newGroupId;
                print('🆕 Created new group: $groupId (TUI-compatible, members=${groupMembers.length})');
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
              // Message from someone else - use consistent group ID format
              groupMembers = {fromAtSign, currentAtSign};
              print('📱 1-on-1 members for incoming message: $groupMembers');

              // Use consistent session key generation (comma-separated sorted list)
              final sortedParticipants = groupMembers.toList()..sort();
              final sessionKey = sortedParticipants.join(',');
              print('📱 Consistent session key: $sessionKey');

              // Check if a group already exists for these members
              final existingGroup = _findGroupByMembers(groupMembers);
              if (existingGroup != null) {
                groupId = existingGroup.id;
                print('✅ Using existing 1-on-1 chat: ${existingGroup.id} for members: ${existingGroup.members}');
              } else {
                groupId = sessionKey; // Use consistent key format
                createOrUpdateGroup(groupMembers, instanceId: groupId);
                print('🆕 Created new 1-on-1 chat: $groupId for members: $groupMembers (consistent format)');
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

          // Create the ChatMessage with a unique ID first
          final chatMessage = ChatMessage(
            text: message,
            fromAtSign: fromAtSign,
            timestamp: DateTime.now(),
            isFromMe: isFromCurrentUser,
          );
          print(
            '📨 Created ChatMessage from notification: ID=${chatMessage.id}, text="$message", fromAtSign=$fromAtSign, isFromMe=$isFromCurrentUser, timestamp=${chatMessage.timestamp}',
          );

          // Check if we already have a message with this exact ID to avoid duplicates
          // For messages from current user, also check for content-based duplicates
          bool isDuplicate = false;

          // Check the target group first
          final existingMessages = _groupMessages[groupId] ?? [];

          print('🔍 Duplicate check for groupId: $groupId');
          print('   Current groups with same members:');
          if (currentAtSign != null) {
            final messageGroupMembers = {fromAtSign, currentAtSign};
            for (final entry in _groups.entries) {
              final group = entry.value;
              if (group.members.length == messageGroupMembers.length &&
                  group.members.containsAll(messageGroupMembers)) {
                print(
                  '     - Group ${entry.key}: ${group.members} (${_groupMessages[entry.key]?.length ?? 0} messages)',
                );
              }
            }
          }

          // First check for exact ID match (for messages from other users)
          isDuplicate = existingMessages.any((existingMsg) => existingMsg.id == chatMessage.id);

          // For messages from current user, also check for content-based duplicates
          // (since we add our own messages immediately and they get different IDs when received back)
          if (!isDuplicate && isFromCurrentUser) {
            final now = DateTime.now();
            print('🔍 Checking for content-based duplicates in ${existingMessages.length} messages for: "$message"');

            for (final existingMsg in existingMessages) {
              if (existingMsg.text == message && existingMsg.fromAtSign == fromAtSign && existingMsg.isFromMe == true) {
                final timeDiff = now.difference(existingMsg.timestamp).inSeconds;
                print('🕐 Found matching message with time diff: ${timeDiff}s');
                if (timeDiff < 30) {
                  isDuplicate = true;
                  print('🚫 Content-based duplicate detected: "$message" from $fromAtSign (time diff: ${timeDiff}s)');
                  break;
                }
              }
            }
          }

          // If from current user, also check all other groups in case of misrouting
          if (!isDuplicate && isFromCurrentUser) {
            for (final existingGroupId in _groupMessages.keys) {
              if (existingGroupId != groupId) {
                final otherGroupMessages = _groupMessages[existingGroupId] ?? [];
                isDuplicate = otherGroupMessages.any((existingMsg) => existingMsg.id == chatMessage.id);
                if (isDuplicate) {
                  print(
                    '⚠️ Duplicate message ID detected: ${chatMessage.id} from $fromAtSign (already exists in group $existingGroupId)',
                  );
                  break;
                }
              }
            }
          }

          if (!isDuplicate) {
            // Before adding the message, check if we need to consolidate groups
            // If there are multiple groups with the same members, consolidate to the canonical one
            final canonicalGroupId = _getOrCreateCanonicalGroup(groupId, fromAtSign, currentAtSign);

            if (canonicalGroupId != groupId) {
              print('🔀 Consolidating message to canonical group: $canonicalGroupId (was: $groupId)');
              groupId = canonicalGroupId;
            }

            addMessageToGroup(groupId, chatMessage);
            print('✅ Message added successfully to UI (group: $groupId)');
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
      } else {
        bestMatch ??= group;
      }
    }

    if (bestMatch != null) {
      print('   Selected group: ${bestMatch.id}');
    }

    return bestMatch;
  }

  /// Generates group ID using consistent logic for all group sizes:
  /// - Use comma-separated sorted participant list for all groups
  /// - For 1-on-1 and 2-person groups: use simple session key format (no timestamp)
  /// - For 3+ person groups: add timestamp suffix for disambiguation if needed
  String _generateTUICompatibleGroupId(Set<String> members, {bool forceUniqueForGroup = false}) {
    final sortedMembers = members.toList()..sort();

    // Use comma-separated sorted list for all groups (consistent approach)
    String groupId = sortedMembers.join(',');
    print('🔑 Generated base group ID: $groupId (${members.length} members)');

    // CRITICAL FIX: For 1-on-1 and 2-person conversations, prefer the base session key
    // This ensures TUI and GUI use the same session ID for the same conversation
    if (members.length <= 2 && !forceUniqueForGroup) {
      // Check if this base ID would conflict with an existing group with different members
      final existingGroup = _groups[groupId];
      if (existingGroup != null) {
        // Check if the members are exactly the same
        final sameMembers =
            existingGroup.members.length == members.length && existingGroup.members.containsAll(members);

        if (sameMembers) {
          print('✅ Using existing session key for same participants: $groupId');
          return groupId; // Same participants, safe to reuse
        } else {
          print('⚠️ Session key conflict for different participants, adding timestamp');
          // Different participants, need unique ID
          groupId = _generateUniqueGroupId(groupId);
        }
      } else {
        print('✅ Using base session key for new conversation: $groupId');
        return groupId; // No conflict, use base session key
      }
    } else {
      // For 3+ person groups or when forcing uniqueness, add timestamp if there's a conflict
      if (forceUniqueForGroup || _groups.containsKey(groupId)) {
        groupId = _generateUniqueGroupId(groupId);
        print('🔧 Added unique suffix for multi-person group: $groupId');
      }
    }

    // Final conflict check regardless of group size
    final existingGroup = _groups[groupId];
    if (existingGroup != null) {
      // Check if the members are exactly the same
      final sameMembers = existingGroup.members.length == members.length && existingGroup.members.containsAll(members);

      if (!sameMembers) {
        print('⚠️ Group ID conflict detected for $groupId');
        print('   Existing members: ${existingGroup.members}');
        print('   New members: $members');
        // In case of conflict, add a unique suffix
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
      uniqueId = counter == 0 ? '$baseId#$timestamp' : '$baseId#${timestamp}_$counter';
      counter++;
    } while (_groups.containsKey(uniqueId) && counter < 100); // Safety limit

    return uniqueId;
  }

  /// Legacy method for backwards compatibility - delegates to TUI-compatible version
  String _generateGroupId(Set<String> members) {
    return _generateTUICompatibleGroupId(members);
  }

  /// Create a new group with a unique ID (used when explicitly creating groups to avoid overwrites)
  Future<String> createNewGroupWithUniqueId(Set<String> members, {String? name}) async {
    // Force unique ID generation for new groups to prevent overwrites
    final baseId = _generateTUICompatibleGroupId(members);
    final groupId = _generateUniqueGroupId(baseId);

    final newGroup = Group(id: groupId, members: members, name: name, unreadCount: 0);

    _groups[groupId] = newGroup;
    _groupMessages[groupId] ??= [];

    print('🆕 Created new group with guaranteed unique ID: $groupId (${members.length} members)');
    notifyListeners();

    // Notify all other participants about the new group
    final currentAtSign = AtTalkService.instance.currentAtSign;
    if (currentAtSign != null) {
      final otherMembers = members.where((member) => member != currentAtSign);
      for (String recipient in otherMembers) {
        await AtTalkService.instance.sendGroupMembershipChange(
          toAtSign: recipient,
          groupMembers: members.toList(),
          groupName: name,
          groupInstanceId: groupId,
        );
        print('📤 Notified $recipient about new group: $groupId');
      }
    }

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

  Future<String?> renameGroup(String groupId, String newName) async {
    final group = _groups[groupId];
    if (group == null) return null;

    try {
      // Simply update the group name - no special handling needed
      _groups[groupId] = group.copyWith(name: newName);
      notifyListeners();

      // Notify other group members about the rename (exclude self)
      final currentAtSign = AtTalkService.instance.currentAtSign;
      if (currentAtSign == null) return null;

      final recipients = group.members.where((member) => member != currentAtSign).toList();

      print('📝 Renaming group $groupId to "$newName"');
      print('   Recipients: $recipients');

      // CRITICAL FIX: Send the TUI-compatible session key as instanceId
      // The TUI expects the base session key format for consistent routing
      final sortedMembers = group.members.toList()..sort();
      final tuiSessionKey = sortedMembers.join(',');

      print('   GUI internal groupId: $groupId');
      print('   TUI-compatible instanceId: $tuiSessionKey');

      bool allSuccess = true;
      for (String recipient in recipients) {
        final success = await AtTalkService.instance.sendGroupRename(
          toAtSign: recipient,
          groupMembers: group.members.toList(),
          groupName: newName,
          groupInstanceId: tuiSessionKey, // Send TUI-compatible session key, not internal group ID
        );
        if (!success) allSuccess = false;
      }

      return allSuccess ? groupId : null;
    } catch (e) {
      print('Error renaming group: $e');
      return null;
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

      print('🔄 GUI: Received group rename notification');
      print('   From: $fromAtSign');
      print('   New name: $newGroupName');
      print('   Members: $groupMembers');
      print('   InstanceId: $instanceId');
      print('   Existing groups: ${_groups.keys.toList()}');

      if (groupMembers.isEmpty || instanceId == null) return;

      String? groupId;

      // CRITICAL FIX: Try to find group by exact instance ID first
      if (_groups.containsKey(instanceId)) {
        groupId = instanceId;
        print('✅ GUI: Found group by exact instanceId: $instanceId');
      } else {
        print('❌ GUI: No group found with exact instanceId: $instanceId');

        // Try to find group by members (this is where we'll consolidate)
        final existingGroup = _findGroupByMembers(groupMembers.toSet());
        if (existingGroup != null) {
          groupId = existingGroup.id;
          print('✅ GUI: Found group by members: $groupId for instanceId: $instanceId');

          // CRITICAL: If we found a group with different ID, we need to consolidate
          // This happens when GUI created a timestamped ID but TUI uses base session key
          if (groupId != instanceId) {
            print('🔧 GUI: Group ID mismatch detected - consolidating group IDs');
            print('   TUI expects: $instanceId');
            print('   GUI has: $groupId');

            // Create/update the group with the TUI's expected ID to ensure future messages route correctly
            final group = _groups[groupId]!;
            _groups[instanceId] = group.copyWith(name: newGroupName);
            _groupMessages[instanceId] = _groupMessages[groupId] ?? [];

            // Remove the old group to prevent confusion
            _groups.remove(groupId);
            _groupMessages.remove(groupId);

            groupId = instanceId; // Use TUI's ID going forward
            print('   ✅ Consolidated to TUI session ID: $instanceId');
          }
        } else {
          print('❌ GUI: No group found by members: $groupMembers');

          // LAST RESORT: Create new group with the provided instance ID
          // This shouldn't happen often but ensures rename notifications don't get lost
          print('🆕 GUI: Creating new group for rename with instanceId: $instanceId');
          createOrUpdateGroup(groupMembers.toSet(), instanceId: instanceId, name: newGroupName);
          groupId = instanceId;
        }
      }

      if (_groups.containsKey(groupId)) {
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
        print('✅ Group $groupId renamed to "$displayName" by $fromAtSign');

        // Debug: Verify no duplicate groups exist after rename
        final renamedGroupMembers = groupMembers.toSet();
        int groupsWithSameMembers = 0;
        for (final entry in _groups.entries) {
          final group = entry.value;
          if (group.members.length == renamedGroupMembers.length && group.members.containsAll(renamedGroupMembers)) {
            groupsWithSameMembers++;
            print('   - Group ${entry.key}: name="${group.name}", messages=${_groupMessages[entry.key]?.length ?? 0}');
          }
        }
        if (groupsWithSameMembers > 1) {
          print('⚠️ Multiple groups detected with same members after rename - this may cause confusion');
        }
      } else {
        print('⚠️ Could not find group for rename operation:');
        print('   Instance ID: $instanceId');
        print('   Group members: $groupMembers');
        print('   Available groups: ${_groups.keys.toList()}');
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

      print('🔄 Handling group membership change:');
      print('  - newMembers: $newMembers');
      print('  - groupName: $groupName');
      print('  - instanceId: $instanceId');
      print('  - fromAtSign: $fromAtSign');

      if (newMembers.isEmpty) return;

      String? groupId;
      Group? existingGroup;

      // Try to find group by instance ID first
      if (instanceId != null && _groups.containsKey(instanceId)) {
        groupId = instanceId;
        existingGroup = _groups[instanceId];
        print('✅ Found group by instanceId: $instanceId');
      } else {
        // Look for group with matching members
        final newMembersSet = newMembers.toSet();

        for (final entry in _groups.entries) {
          final group = entry.value;
          final groupMembersSet = group.members.toSet();

          // Check if this group contains all new members as a subset
          if (newMembersSet.every((member) => groupMembersSet.contains(member))) {
            existingGroup = group;
            groupId = entry.key;
            print('✅ Found group by member match: $groupId');
            break;
          }
        }
      }

      if (existingGroup != null && groupId != null) {
        // Update existing group
        final oldMembers = existingGroup.members.toSet();
        final newMembersSet = newMembers.toSet();

        // Update the group
        _groups[groupId] = existingGroup.copyWith(members: newMembersSet, name: groupName);

        // Add system messages for member changes
        final currentAtSign = AtTalkService.instance.currentAtSign;
        final isFromCurrentUser = currentAtSign != null && fromAtSign == currentAtSign;

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
        print('✅ Updated group $groupId membership');
      } else {
        // Create new group
        final newGroupId = instanceId ?? _generateGroupId(newMembers.toSet());
        _groups[newGroupId] = Group(
          id: newGroupId,
          members: newMembers.toSet(),
          lastMessageTime: DateTime.now(),
          name: groupName,
        );
        notifyListeners();
        print('✅ Created new group $newGroupId');
      }
    } catch (e) {
      print('❌ Error handling group membership change: $e');
    }
  }

  /// Get or create the canonical group for a set of members
  /// This helps consolidate multiple groups with identical members into one
  String _getOrCreateCanonicalGroup(String suggestedGroupId, String fromAtSign, String? currentAtSign) {
    if (currentAtSign == null) return suggestedGroupId;

    // Determine the members for this conversation
    final members = {fromAtSign, currentAtSign};

    // Find all groups with these exact members
    final matchingGroups = <String, Group>{};
    for (final entry in _groups.entries) {
      final group = entry.value;
      if (group.members.length == members.length && group.members.containsAll(members)) {
        matchingGroups[entry.key] = group;
      }
    }

    if (matchingGroups.length <= 1) {
      // No consolidation needed
      return suggestedGroupId;
    }

    print('🔍 Found ${matchingGroups.length} groups with identical members: $members');

    // Choose the canonical group - prefer:
    // 1. The suggested group ID if it exists
    // 2. The base session key (no timestamp suffix)
    // 3. The group with the most messages
    // 4. The group with the most recent activity

    String? canonicalGroupId;

    // Strategy 1: Use suggested group if it's one of the matching groups
    if (matchingGroups.containsKey(suggestedGroupId)) {
      canonicalGroupId = suggestedGroupId;
      print('   Using suggested group as canonical: $canonicalGroupId');
    } else {
      // Strategy 2: Prefer base session key format (no timestamp suffix)
      final baseSessionKey = members.toList()..sort();
      final expectedBaseId = baseSessionKey.join(',');

      if (matchingGroups.containsKey(expectedBaseId)) {
        canonicalGroupId = expectedBaseId;
        print('   Using base session key as canonical: $canonicalGroupId');
      } else {
        // Strategy 3: Choose group with most messages, then most recent activity
        String? bestGroupId;
        int maxMessages = -1;
        DateTime? mostRecentActivity;

        for (final entry in matchingGroups.entries) {
          final groupId = entry.key;
          final group = entry.value;
          final messageCount = _groupMessages[groupId]?.length ?? 0;

          bool isBetter = false;

          if (messageCount > maxMessages) {
            isBetter = true;
          } else if (messageCount == maxMessages) {
            if (group.lastMessageTime != null) {
              if (mostRecentActivity == null || group.lastMessageTime!.isAfter(mostRecentActivity)) {
                isBetter = true;
              }
            }
          }

          if (isBetter) {
            bestGroupId = groupId;
            maxMessages = messageCount;
            mostRecentActivity = group.lastMessageTime;
          }
        }

        canonicalGroupId = bestGroupId ?? matchingGroups.keys.first;
        print('   Using group with most activity as canonical: $canonicalGroupId (${maxMessages} messages)');
      }
    }

    // If we chose a different group than suggested, consolidate messages
    if (canonicalGroupId != suggestedGroupId) {
      _consolidateGroupMessages(matchingGroups, canonicalGroupId);
    }

    return canonicalGroupId;
  }

  /// Consolidate messages from multiple groups with identical members into the canonical group
  void _consolidateGroupMessages(Map<String, Group> matchingGroups, String canonicalGroupId) {
    print('🔀 Consolidating ${matchingGroups.length} groups into canonical group: $canonicalGroupId');

    final canonicalGroup = matchingGroups[canonicalGroupId];
    if (canonicalGroup == null) return;

    // Collect all messages from non-canonical groups
    final allMessages = <ChatMessage>[];
    final canonicalMessages = _groupMessages[canonicalGroupId] ?? [];
    allMessages.addAll(canonicalMessages);

    for (final entry in matchingGroups.entries) {
      final groupId = entry.key;

      if (groupId != canonicalGroupId) {
        final messages = _groupMessages[groupId] ?? [];
        print('   Moving ${messages.length} messages from group $groupId');

        // Add messages that aren't already in the canonical group
        for (final message in messages) {
          // Check for duplicate by content and timestamp (more robust than ID)
          final isDuplicate = allMessages.any(
            (existing) =>
                existing.text == message.text &&
                existing.fromAtSign == message.fromAtSign &&
                existing.timestamp.difference(message.timestamp).abs().inSeconds < 5,
          );

          if (!isDuplicate) {
            allMessages.add(message);
          }
        }

        // Remove the non-canonical group
        _groups.remove(groupId);
        _groupMessages.remove(groupId);
        print('   Removed duplicate group: $groupId');
      }
    }

    // Sort all messages by timestamp
    allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Update the canonical group with all messages
    _groupMessages[canonicalGroupId] = allMessages;

    // Update group metadata based on the latest message
    if (allMessages.isNotEmpty) {
      final latestMessage = allMessages.last;
      _groups[canonicalGroupId] = canonicalGroup.copyWith(
        lastMessage: latestMessage.text,
        lastMessageTime: latestMessage.timestamp,
      );
    }

    print('   Consolidated to ${allMessages.length} total messages in $canonicalGroupId');
    notifyListeners();
  }

  /// Handle incoming file message notifications
  Future<void> _handleFileMessage(Map<String, dynamic> jsonData, String fromAtSign) async {
    try {
      print('📎 Processing file message from $fromAtSign');

      final fileId = jsonData['fileId'] as String?;
      final fileName = jsonData['fileName'] as String?;
      final fileSize = jsonData['fileSize'] as int?;
      final fileType = jsonData['attachmentType'] as String?;
      final fileMimeType = jsonData['mimeType'] as String?;
      final groupMembers = (jsonData['group'] as List<dynamic>?)?.cast<String>();
      final groupName = jsonData['groupName'] as String?;
      final messageText = jsonData['msg'] as String? ?? '';

      if (fileId == null || fileName == null) {
        print('⚠️ Invalid file message: missing fileId or fileName');
        return;
      }

      // Get current atSign for filtering
      final currentAtSign = AtTalkService.instance.currentAtSign;
      if (currentAtSign == null) {
        print('❌ No current atSign - cannot process file message');
        return;
      }

      // Determine group/session for this file message
      String groupId;
      Set<String> members = {};

      if (groupMembers != null) {
        members = groupMembers.toSet();
        // Use TUI-compatible session finding logic
        if (members.length == 1 && members.first == currentAtSign) {
          // Self-chat session
          groupId = currentAtSign;
        } else {
          // All groups: use comma-separated sorted list
          final sortedParticipants = members.toList()..sort();
          groupId = sortedParticipants.join(',');
        }
      } else {
        // Fallback to 1-on-1 conversation
        members = {fromAtSign, currentAtSign};
        final sortedParticipants = members.toList()..sort();
        groupId = sortedParticipants.join(',');
      }

      // Ensure group exists
      final canonicalGroupId = _getOrCreateCanonicalGroup(groupId, fromAtSign, currentAtSign);
      if (canonicalGroupId != groupId) {
        print('🔀 Using canonical group for file message: $canonicalGroupId (was: $groupId)');
        groupId = canonicalGroupId;
      }

      // Ensure the group exists in our groups map
      if (!_groups.containsKey(groupId)) {
        _groups[groupId] = Group(id: groupId, members: members, lastMessageTime: DateTime.now(), name: groupName);
      }

      // Determine attachment type
      AttachmentType attachmentType = AttachmentType.other;
      if (fileType != null) {
        switch (fileType.toLowerCase()) {
          case 'image':
            attachmentType = AttachmentType.image;
            break;
          case 'document':
            attachmentType = AttachmentType.document;
            break;
          case 'audio':
            attachmentType = AttachmentType.audio;
            break;
          case 'video':
            attachmentType = AttachmentType.video;
            break;
          default:
            attachmentType = AttachmentType.other;
        }
      } else if (fileMimeType != null) {
        attachmentType = _getAttachmentTypeFromMimeType(fileMimeType);
      }

      // Create attachment metadata
      final attachment = MessageAttachment(
        id: fileId,
        originalFileName: fileName,
        type: attachmentType,
        sizeInBytes: fileSize ?? 0,
        mimeType: fileMimeType,
        localPath: null, // Will be set after download
        thumbnailPath: null, // Will be set if thumbnail exists
        isDownloaded: false,
        downloadProgress: 0.0, // Start with 0% download progress
      );

      // Create chat message with attachment
      final chatMessage = ChatMessage(
        text: messageText.isNotEmpty ? messageText : 'Sent an attachment',
        fromAtSign: fromAtSign,
        timestamp: DateTime.now(),
        isFromMe: fromAtSign == currentAtSign,
        attachments: [attachment],
      );

      print('📨 Adding file message to group $groupId: ${attachment.originalFileName}');

      // Add message to group
      addMessageToGroup(groupId, chatMessage);

      // Start downloading the file in the background for preview/thumbnail generation
      autoDownloadFileAttachment(groupId, chatMessage.id, attachment, fromAtSign);
    } catch (e) {
      print('❌ Error handling file message: $e');
    }
  }

  /// Determine attachment type from MIME type
  AttachmentType _getAttachmentTypeFromMimeType(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return AttachmentType.image;
    } else if (mimeType.startsWith('audio/')) {
      return AttachmentType.audio;
    } else if (mimeType.startsWith('video/')) {
      return AttachmentType.video;
    } else if (mimeType.startsWith('application/pdf') ||
        mimeType.startsWith('application/msword') ||
        mimeType.startsWith('application/vnd.openxmlformats-officedocument') ||
        mimeType.startsWith('text/')) {
      return AttachmentType.document;
    } else {
      return AttachmentType.other;
    }
  }

  /// Download file attachment with user-selected save location
  Future<void> downloadFileAttachment(
    String groupId,
    String messageId,
    MessageAttachment attachment,
    String fromAtSign,
  ) async {
    try {
      print('📥 Starting user download for ${attachment.originalFileName}');

      // Set download progress to indicate download is starting
      _updateFileDownloadProgress(groupId, messageId, attachment.id, 0.1);

      // Download the file using the user-selected save dialog
      final filePath = await FileTransferService.instance.downloadFile(
        attachment.id,
        attachment.originalFileName,
        fromAtSign, // Pass the sender's atSign
      );

      if (filePath != null) {
        print('✅ Downloaded ${attachment.originalFileName} to $filePath');

        // Update the attachment with the downloaded file path
        _updateFileAttachmentPath(groupId, messageId, attachment.id, filePath);
      } else {
        print('❌ User cancelled download or failed to download ${attachment.originalFileName}');
        _updateFileDownloadProgress(groupId, messageId, attachment.id, 0.0); // Reset to show download button again
      }
    } catch (e) {
      print('❌ Error downloading file attachment: $e');
      _updateFileDownloadProgress(groupId, messageId, attachment.id, -1.0); // -1 indicates error
    }
  }

  /// Auto-download file attachment to app directory for previews/thumbnails
  Future<void> autoDownloadFileAttachment(
    String groupId,
    String messageId,
    MessageAttachment attachment,
    String fromAtSign,
  ) async {
    try {
      print('📥 Starting auto-download for ${attachment.originalFileName}');

      // Set download progress to indicate download is starting
      _updateFileDownloadProgress(groupId, messageId, attachment.id, 0.1);

      // Download the file automatically to app directory
      final filePath = await FileTransferService.instance.downloadFileToAppDirectory(
        attachment.id,
        attachment.originalFileName,
        fromAtSign, // Pass the sender's atSign
      );

      if (filePath != null) {
        print('✅ Auto-downloaded ${attachment.originalFileName} to $filePath');

        // Update the attachment with the downloaded file path
        _updateFileAttachmentPath(groupId, messageId, attachment.id, filePath);
      } else {
        print('❌ Failed to auto-download ${attachment.originalFileName}');
        _updateFileDownloadProgress(groupId, messageId, attachment.id, -1.0); // -1 indicates error
      }
    } catch (e) {
      print('❌ Error auto-downloading file attachment: $e');
      _updateFileDownloadProgress(groupId, messageId, attachment.id, -1.0); // -1 indicates error
    }
  }

  /// Update download progress for a file attachment
  void _updateFileDownloadProgress(String groupId, String messageId, String attachmentId, double progress) {
    final messages = _groupMessages[groupId];
    if (messages == null) return;

    final messageIndex = messages.indexWhere((msg) => msg.id == messageId);
    if (messageIndex == -1) return;

    final message = messages[messageIndex];
    final attachmentIndex = message.attachments.indexWhere((att) => att.id == attachmentId);
    if (attachmentIndex == -1) return;

    // Create updated attachment with new progress
    final attachment = message.attachments[attachmentIndex];
    final updatedAttachment = attachment.copyWith(downloadProgress: progress);

    // Create updated attachments list
    final updatedAttachments = List<MessageAttachment>.from(message.attachments);
    updatedAttachments[attachmentIndex] = updatedAttachment;

    // Create updated message
    final updatedMessage = ChatMessage(
      id: message.id,
      text: message.text,
      fromAtSign: message.fromAtSign,
      timestamp: message.timestamp,
      isFromMe: message.isFromMe,
      attachments: updatedAttachments,
    );

    // Replace the message
    messages[messageIndex] = updatedMessage;
    notifyListeners();
  }

  /// Update file path for a downloaded attachment
  void _updateFileAttachmentPath(String groupId, String messageId, String attachmentId, String filePath) {
    final messages = _groupMessages[groupId];
    if (messages == null) return;

    final messageIndex = messages.indexWhere((msg) => msg.id == messageId);
    if (messageIndex == -1) return;

    final message = messages[messageIndex];
    final attachmentIndex = message.attachments.indexWhere((att) => att.id == attachmentId);
    if (attachmentIndex == -1) return;

    // Create updated attachment with file path and thumbnail path
    final attachment = message.attachments[attachmentIndex];

    // Get thumbnail path if it exists
    final thumbnailPath = FileTransferService.instance.getThumbnailPath(attachmentId);

    final updatedAttachment = attachment.copyWith(
      localPath: filePath,
      thumbnailPath: thumbnailPath,
      isDownloaded: true,
      downloadProgress: 1.0,
    );

    // Create updated attachments list
    final updatedAttachments = List<MessageAttachment>.from(message.attachments);
    updatedAttachments[attachmentIndex] = updatedAttachment;

    // Create updated message
    final updatedMessage = ChatMessage(
      id: message.id,
      text: message.text,
      fromAtSign: message.fromAtSign,
      timestamp: message.timestamp,
      isFromMe: message.isFromMe,
      attachments: updatedAttachments,
    );

    // Replace the message
    messages[messageIndex] = updatedMessage;
    notifyListeners();
  }
}
