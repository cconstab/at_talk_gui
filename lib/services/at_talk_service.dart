import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_utils/at_logger.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

class AtTalkService {
  static AtTalkService? _instance;
  static AtTalkService get instance => _instance ??= AtTalkService._internal();

  AtTalkService._internal() {
    // Generate a unique instance ID for this app instance
    _instanceId = const Uuid().v4();
  }

  static AtClientPreference? _atClientPreference;
  bool _isInitialized = false;
  late final String _instanceId;

  String get instanceId => _instanceId;

  static void initialize(AtClientPreference preference) {
    _atClientPreference = preference;
    // Set up logging
    AtSignLogger.root_level = 'WARNING';
  }

  AtClientPreference? get atClientPreference => _atClientPreference;

  bool get isInitialized => _isInitialized;

  Future<void> onboard({
    required String? atSign,
    required Function(bool) onResult,
    Function(String)? onError,
  }) async {
    try {
      if (_atClientPreference == null) {
        throw Exception('AtClientPreference not initialized');
      }

      await AtClientManager.getInstance().setCurrentAtSign(
        atSign!,
        _atClientPreference!.namespace!,
        _atClientPreference!,
      );

      _isInitialized = true;
      onResult(true);
    } catch (e) {
      onError?.call(e.toString());
      onResult(false);
    }
  }

  AtClient? get atClient {
    if (_isInitialized) {
      return AtClientManager.getInstance().atClient;
    }
    return null;
  }

  String? get currentAtSign {
    return atClient?.getCurrentAtSign();
  }

  Future<bool> sendMessage({
    required String toAtSign,
    required String message,
  }) async {
    try {
      final client = atClient;
      if (client == null) return false;

      // Create 1-on-1 message JSON to match TUI format exactly
      // TUI expects JSON format even for 1-on-1 messages
      // Include group array with the two participants for consistency
      final messageData = {
        'msg': message,
        'isGroup': false,
        'group': [currentAtSign, toAtSign], // Always include both participants
        'instanceId': _instanceId,
        'from': currentAtSign,
      };

      final jsonMessage = jsonEncode(messageData);

      // Use exact same protocol as TUI app
      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true;

      var key = AtKey()
        ..key = 'attalk'
        ..sharedBy = currentAtSign
        ..sharedWith = toAtSign
        ..namespace = _atClientPreference!.namespace
        ..metadata = metaData;

      // Debug: Sending message
      print('📤 Sending 1-on-1 message to $toAtSign');
      print('📤 Key: ${key.toString()}');
      print('📤 JSON Message: $jsonMessage');
      print('📤 sharedBy (from): $currentAtSign');
      print('📤 sharedWith (to): $toAtSign');
      print('📤 Expected TUI display: "$currentAtSign: $message"');

      final result = await client.notificationService.notify(
        NotificationParams.forUpdate(key, value: jsonMessage),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      bool success = result.atClientException == null;
      if (!success) {
        print('Send failed: ${result.atClientException}');
      }

      return success;
    } catch (e) {
      print('Error sending message: $e'); // TODO: Replace with proper logging
      return false;
    }
  }

  Future<bool> sendGroupMessage({
    required String toAtSign,
    required String message,
    required List<String> groupMembers,
    required String groupInstanceId,
    String? groupName,
  }) async {
    try {
      final client = atClient;
      if (client == null) return false;

      // Create group message JSON to match TUI format exactly
      final groupMessageData = {
        'msg': message,
        'isGroup': true,
        'group': groupMembers,
        'instanceId': _instanceId, // Use this instance's ID
        'from': currentAtSign,
        if (groupName != null && groupName.isNotEmpty) 'groupName': groupName,
      };

      final jsonMessage = jsonEncode(groupMessageData);

      // Use exact same protocol as TUI app
      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true;

      var key = AtKey()
        ..key = 'attalk'
        ..sharedBy = currentAtSign
        ..sharedWith = toAtSign
        ..namespace = _atClientPreference!.namespace
        ..metadata = metaData;

      // Debug: Sending group message
      print(
        'Sending group message to $toAtSign: ${groupMembers.length} members',
      );

      final result = await client.notificationService.notify(
        NotificationParams.forUpdate(key, value: jsonMessage),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      bool success = result.atClientException == null;
      if (!success) {
        print('Group send failed: ${result.atClientException}');
      }

      return success;
    } catch (e) {
      print(
        'Error sending group message: $e',
      ); // TODO: Replace with proper logging
      return false;
    }
  }

  Future<bool> sendGroupRename({
    required String toAtSign,
    required List<String> groupMembers,
    required String groupName,
    required String groupInstanceId,
  }) async {
    try {
      final client = atClient;
      if (client == null) return false;

      // Create group rename notification JSON to match TUI format
      final renameData = {
        'type': 'groupRename',
        'group': groupMembers,
        'groupName': groupName,
        'instanceId': groupInstanceId,
        'from': currentAtSign,
      };

      final jsonMessage = jsonEncode(renameData);

      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true;

      var key = AtKey()
        ..key = 'attalk'
        ..sharedBy = currentAtSign
        ..sharedWith = toAtSign
        ..namespace = _atClientPreference!.namespace
        ..metadata = metaData;

      print(
        'DEBUG: Sending group rename - key: ${key.toString()}, JSON: $jsonMessage, to: $toAtSign',
      );

      final result = await client.notificationService.notify(
        NotificationParams.forUpdate(key, value: jsonMessage),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      bool success = result.atClientException == null;
      print(
        'DEBUG: Send group rename result - success: $success, exception: ${result.atClientException}',
      );

      return success;
    } catch (e) {
      print('Error sending group rename: $e');
      return false;
    }
  }

  Future<bool> sendGroupMembershipChange({
    required String toAtSign,
    required List<String> groupMembers,
    String? groupName,
    required String groupInstanceId,
  }) async {
    try {
      final client = atClient;
      if (client == null) return false;

      // Create group membership change notification JSON to match TUI format
      final membershipData = {
        'type': 'groupMembershipChange',
        'group': groupMembers,
        'instanceId': groupInstanceId,
        'from': currentAtSign,
        if (groupName != null && groupName.isNotEmpty) 'groupName': groupName,
      };

      final jsonMessage = jsonEncode(membershipData);

      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true;

      var key = AtKey()
        ..key = 'attalk'
        ..sharedBy = currentAtSign
        ..sharedWith = toAtSign
        ..namespace = _atClientPreference!.namespace
        ..metadata = metaData;

      print(
        'DEBUG: Sending group membership change - key: ${key.toString()}, JSON: $jsonMessage, to: $toAtSign',
      );

      final result = await client.notificationService.notify(
        NotificationParams.forUpdate(key, value: jsonMessage),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      bool success = result.atClientException == null;
      print(
        'DEBUG: Send group membership change result - success: $success, exception: ${result.atClientException}',
      );

      return success;
    } catch (e) {
      print('Error sending group membership change: $e');
      return false;
    }
  }

  Stream<Map<String, String>> getAllMessageStream() {
    final client = atClient;
    if (client == null) {
      throw Exception('AtClient not initialized');
    }

    // Use exact same subscription pattern as TUI app
    print(
      '🔄 Setting up message subscription with regex: attalk.${_atClientPreference!.namespace}@',
    );

    return client.notificationService
        .subscribe(
          regex: 'attalk.${_atClientPreference!.namespace}@',
          shouldDecrypt: true,
        )
        .where((notification) {
          // Filter like TUI app does - exact same logic
          String keyAtsign = notification.key;
          keyAtsign = keyAtsign.replaceAll('${notification.to}:', '');
          keyAtsign = keyAtsign.replaceAll(
            '.${_atClientPreference!.namespace}${notification.from}',
            '',
          );

          final isMatch = keyAtsign == 'attalk';

          // Only log when we get a message (regardless of match)
          if (notification.value != null && notification.value!.isNotEmpty) {
            print(
              '💬 Incoming notification: from=${notification.from}, to=${notification.to}',
            );
            print('💬 Full key: "${notification.key}"');
            print('💬 Filtered key: "$keyAtsign" (expected: "attalk")');
            print('💬 Key match: $isMatch');
            print('💬 Message content: "${notification.value}"');
            if (!isMatch) {
              print('❌ Message REJECTED by key filter');
            } else {
              print('✅ Message ACCEPTED by key filter');
            }
          }

          return isMatch;
        })
        .where((notification) {
          // For now, let all messages through and let the GroupsProvider handle duplicates
          // This ensures users see their own messages in group chats
          return true;
        })
        .map((notification) {
          // Parse and return message data
          String messageText = notification.value ?? '';

          // Debug: Show exactly what the TUI would receive
          print(
            '📨 Raw notification: from=${notification.from}, to=${notification.to}',
          );
          print('📨 Raw value: "${notification.value}"');
          print('📨 Key: "${notification.key}"');

          // Try to parse as JSON first (for group messages and TUI compatibility)
          try {
            final jsonData = jsonDecode(messageText);
            if (jsonData is Map<String, dynamic>) {
              // Extract message content from various possible field names
              String? extractedMessage;
              if (jsonData.containsKey('msg')) {
                extractedMessage = jsonData['msg'].toString();
              } else if (jsonData.containsKey('message')) {
                extractedMessage = jsonData['message'].toString();
              } else if (jsonData.containsKey('text')) {
                extractedMessage = jsonData['text'].toString();
              }

              if (extractedMessage != null && extractedMessage.isNotEmpty) {
                messageText = extractedMessage;
              }
            }
          } catch (e) {
            // If it's not JSON, use the original text
          }

          return {
            'from': notification.from,
            'message': messageText,
            'to': notification.to,
            'rawValue': notification.value ?? '',
          };
        });
  }

  Stream<String> getMessageStream({required String fromAtSign}) {
    return getAllMessageStream()
        .where((data) => data['from'] == fromAtSign)
        .map((data) => data['message'] ?? '');
  }
}
