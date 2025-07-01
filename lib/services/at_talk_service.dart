import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_utils/at_logger.dart';
import 'dart:convert';

class AtTalkService {
  static AtTalkService? _instance;
  static AtTalkService get instance => _instance ??= AtTalkService._internal();

  AtTalkService._internal();

  static AtClientPreference? _atClientPreference;
  bool _isInitialized = false;

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

      print(
        'DEBUG: Sending message - key: ${key.toString()}, value: $message, to: $toAtSign',
      );

      final result = await client.notificationService.notify(
        NotificationParams.forUpdate(key, value: message),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      bool success = result.atClientException == null;
      print(
        'DEBUG: Send result - success: $success, exception: ${result.atClientException}',
      );

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
        'instanceId': groupInstanceId,
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

      print(
        'DEBUG: Sending group message - key: ${key.toString()}, JSON: $jsonMessage, to: $toAtSign',
      );

      final result = await client.notificationService.notify(
        NotificationParams.forUpdate(key, value: jsonMessage),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      bool success = result.atClientException == null;
      print(
        'DEBUG: Send group result - success: $success, exception: ${result.atClientException}',
      );

      return success;
    } catch (e) {
      print(
        'Error sending group message: $e',
      ); // TODO: Replace with proper logging
      return false;
    }
  }

  Stream<Map<String, String>> getAllMessageStream() {
    final client = atClient;
    if (client == null) {
      throw Exception('AtClient not initialized');
    }

    // Use exact same subscription pattern as TUI app
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
          print(
            'DEBUG: Filtering notification key: ${notification.key} -> filtered: $keyAtsign, matches: ${keyAtsign == 'attalk'}',
          );
          return keyAtsign == 'attalk';
        })
        .map((notification) {
          print(
            'DEBUG: Received valid message from ${notification.from}: ${notification.value}',
          );
          print('DEBUG: Raw notification value: ${notification.value}');

          // Parse the message - could be plain text or JSON
          String messageText = notification.value ?? '';

          // Try to parse as JSON first (for group messages and TUI compatibility)
          try {
            final jsonData = jsonDecode(messageText);
            if (jsonData is Map<String, dynamic>) {
              // Try different possible field names for the message content
              String? extractedMessage;

              // Check for 'msg' field first (used by TUI)
              if (jsonData.containsKey('msg')) {
                extractedMessage = jsonData['msg'].toString();
              }
              // Check for 'message' field (backup)
              else if (jsonData.containsKey('message')) {
                extractedMessage = jsonData['message'].toString();
              }
              // Other common field names
              else if (jsonData.containsKey('text')) {
                extractedMessage = jsonData['text'].toString();
              } else if (jsonData.containsKey('content')) {
                extractedMessage = jsonData['content'].toString();
              } else if (jsonData.containsKey('body')) {
                extractedMessage = jsonData['body'].toString();
              }

              if (extractedMessage != null && extractedMessage.isNotEmpty) {
                messageText = extractedMessage;
                print(
                  'DEBUG: Extracted message from JSON: "$messageText" from: $jsonData',
                );
              } else {
                print(
                  'DEBUG: JSON found but no valid message field. Available fields: ${jsonData.keys.toList()}',
                );
                // Use the full JSON as fallback for debugging
                messageText = messageText;
              }
            }
          } catch (e) {
            // If it's not JSON, use the original text
            print('DEBUG: Using plain text message: "$messageText"');
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
