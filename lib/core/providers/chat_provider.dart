import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'dart:convert';
import '../models/chat_message.dart';
import '../services/at_talk_service.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final Set<String> _groupMembers = {};
  bool _isConnected = false;
  final bool _isGroupMode = true; // Enable group mode by default

  List<ChatMessage> get messages => _messages;
  Set<String> get groupMembers => _groupMembers;
  bool get isConnected => _isConnected;
  bool get isGroupMode => _isGroupMode;

  // For backwards compatibility
  String? get currentChatPartner =>
      _groupMembers.isEmpty ? null : _groupMembers.first;

  void setChatPartner(String atSign) {
    // For backwards compatibility - just add to group
    addToGroup(atSign);
  }

  void addToGroup(String atSign) {
    if (!_groupMembers.contains(atSign)) {
      _groupMembers.add(atSign);
      if (_groupMembers.length == 1) {
        // First member added, start subscription
        _subscribeToMessages();
      }
      notifyListeners();
    }
  }

  void removeFromGroup(String atSign) {
    if (_groupMembers.remove(atSign)) {
      notifyListeners();
    }
  }

  void clearGroup() {
    _groupMembers.clear();
    _messages.clear();
    notifyListeners();
  }

  void _subscribeToMessages() {
    try {
      // Add current user to the group if not already there
      final currentAtSign = AtTalkService.instance.currentAtSign;
      if (currentAtSign != null && !_groupMembers.contains(currentAtSign)) {
        _groupMembers.add(currentAtSign);
      }

      // Subscribe to ALL messages, not just from one partner
      AtTalkService.instance.getAllMessageStream().listen((messageData) {
        final fromAtSign = messageData['from'] ?? '';
        final message = messageData['message'] ?? '';
        final rawValue = messageData['rawValue'] ?? '';

        print(
          '📨 ChatProvider received: from=$fromAtSign, message=$message',
        ); // DEBUG
        print('📨 Raw JSON: $rawValue'); // DEBUG

        // Try to extract group information from the raw JSON
        try {
          final jsonData = jsonDecode(rawValue);
          if (jsonData is Map<String, dynamic>) {
            // Check if this is a group message
            final isGroupMessage = jsonData['isGroup'] == true;
            final groupMembers = jsonData['group'] as List<dynamic>?;
            final instanceId = jsonData['instanceId'] as String?;

            // Filter out messages from our own GUI instance to prevent duplicates
            final currentAtSign = AtTalkService.instance.currentAtSign;
            final ourInstanceId = AtTalkService.instance.instanceId;

            print(
              '🔍 Instance check: fromAtSign=$fromAtSign, currentAtSign=$currentAtSign',
            );
            print(
              '🔍 Instance check: messageInstanceId=$instanceId, ourInstanceId=$ourInstanceId',
            );
            print(
              '🔍 Instance check: fromSelf=${fromAtSign == currentAtSign}, sameInstance=${instanceId == ourInstanceId}',
            );

            if (fromAtSign == currentAtSign && instanceId == ourInstanceId) {
              print(
                '🚫 Skipping message from our own instance: $instanceId (already added locally)',
              );
              return;
            } else if (fromAtSign == currentAtSign &&
                instanceId != ourInstanceId) {
              print(
                '📨 Processing message from our own atSign but different instance: $instanceId',
              );
            }

            if (isGroupMessage && groupMembers != null) {
              // Auto-sync with TUI group
              final groupAtSigns = groupMembers.cast<String>().toSet();
              if (!const SetEquality().equals(_groupMembers, groupAtSigns)) {
                _groupMembers.clear();
                _groupMembers.addAll(groupAtSigns);
                print('Auto-synced with TUI group: $groupAtSigns'); // DEBUG
                notifyListeners();
              }
            }
          }
        } catch (e) {
          // If not JSON or parsing fails, continue with regular processing
        }

        // Add message to the group chat
        final currentAtSign = AtTalkService.instance.currentAtSign;
        _addMessage(
          ChatMessage(
            text: message,
            fromAtSign: fromAtSign,
            timestamp: DateTime.now(),
            isFromMe:
                fromAtSign ==
                currentAtSign, // 🔧 FIX: Correctly identify own messages
          ),
        );

        // Automatically add sender to group if not already there
        if (!_groupMembers.contains(fromAtSign)) {
          _groupMembers.add(fromAtSign);
          notifyListeners();
        }
      });
      _isConnected = true;
    } catch (e) {
      _isConnected = false;
      print(
        'Error subscribing to messages: $e',
      ); // TODO: Replace with proper logging
    }
  }

  Future<bool> sendMessage(String message, {String? toAtSign}) async {
    // If no specific recipient is provided, send to all group members
    List<String> recipients = [];

    if (toAtSign != null) {
      recipients.add(toAtSign);
    } else {
      // Send to all group members except the current user
      final currentAtSign = AtTalkService.instance.currentAtSign;
      recipients.addAll(
        _groupMembers.where((member) => member != currentAtSign),
      );
    }

    if (recipients.isEmpty) return false;

    print('Sending message to group members: $recipients'); // DEBUG

    bool allSuccess = true;

    // Send message to all recipients
    final groupMembersList = _groupMembers.toList()
      ..sort(); // Consistent group member list
    for (String recipient in recipients) {
      final success = await AtTalkService.instance.sendMessage(
        toAtSign: recipient,
        message: message,
        groupMembers: groupMembersList, // Pass the consistent group members
      );
      if (!success) allSuccess = false;
    }

    if (allSuccess) {
      _addMessage(
        ChatMessage(
          text: message,
          fromAtSign: AtTalkService.instance.currentAtSign ?? 'me',
          timestamp: DateTime.now(),
          isFromMe: true,
        ),
      );
    }

    return allSuccess;
  }

  void _addMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
