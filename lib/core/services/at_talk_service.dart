import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_auth/at_auth.dart';
import 'package:at_utils/at_logger.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';

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

      // Proactively check if storage is in use before attempting onboarding
      final storagePath = _atClientPreference!.hiveStoragePath;
      if (storagePath != null) {
        final storageInUse = await isStorageInUse(storagePath);
        if (storageInUse) {
          print(
            'Storage already in use, switching to ephemeral fallback storage...',
          );

          // Create fallback storage path using OS temp directory
          final tempDir = Directory.systemTemp;
          final fallbackUuid = const Uuid().v4();
          final fallbackStoragePath =
              '${tempDir.path}/at_talk_gui/$atSign/$fallbackUuid/storage';
          final fallbackCommitLogPath = '$fallbackStoragePath/commitLog';

          // Update preferences to use fallback storage
          _atClientPreference = AtClientPreference()
            ..rootDomain = _atClientPreference!.rootDomain
            ..namespace = _atClientPreference!.namespace
            ..hiveStoragePath = fallbackStoragePath
            ..commitLogPath = fallbackCommitLogPath
            ..isLocalStoreRequired = true
            ..fetchOfflineNotifications = true;

          print('Using ephemeral storage: $fallbackStoragePath');
        }
      }

      // Check if keys exist in keychain for this atSign
      final keyChainManager = KeyChainManager.getInstance();
      final atsignKey = await keyChainManager.readAtsign(name: atSign!);

      if (atsignKey == null) {
        throw Exception(
          'No keys found for atSign $atSign. Please onboard first.',
        );
      }

      // Use AtAuthService for proper authentication
      final atAuthService = AtClientMobile.authService(
        atSign,
        _atClientPreference!,
      );

      // Create authentication request
      final atAuthRequest = AtAuthRequest(atSign);

      // Perform authentication
      final atAuthResponse = await atAuthService.authenticate(atAuthRequest);

      if (!atAuthResponse.isSuccessful) {
        throw Exception('Authentication failed for $atSign');
      }

      _isInitialized = true;
      onResult(true);
    } catch (e) {
      // Check if this is a Hive/database error that suggests storage conflicts
      String exceptionStr = e.toString().toLowerCase();
      bool isHiveError =
          exceptionStr.contains('hive') ||
          exceptionStr.contains('box not found') ||
          exceptionStr.contains('box') ||
          exceptionStr.contains('commit log') ||
          exceptionStr.contains('database') ||
          exceptionStr.contains('lock') ||
          exceptionStr.contains('busy') ||
          exceptionStr.contains('corrupted');

      if (isHiveError) {
        print(
          'Hive storage error detected, attempting fallback to ephemeral storage...',
        );

        try {
          // Create ephemeral storage path
          final tempDir = Directory.systemTemp;
          final fallbackUuid = const Uuid().v4();
          final fallbackStoragePath =
              '${tempDir.path}/at_talk_gui/$atSign/$fallbackUuid/storage';
          final fallbackCommitLogPath = '$fallbackStoragePath/commitLog';

          // Update preferences to use ephemeral storage
          _atClientPreference = AtClientPreference()
            ..rootDomain = _atClientPreference!.rootDomain
            ..namespace = _atClientPreference!.namespace
            ..hiveStoragePath = fallbackStoragePath
            ..commitLogPath = fallbackCommitLogPath
            ..isLocalStoreRequired = true
            ..fetchOfflineNotifications = true;

          print('Fallback to ephemeral storage: $fallbackStoragePath');

          // Retry authentication with ephemeral storage
          final keyChainManager = KeyChainManager.getInstance();
          final atsignKey = await keyChainManager.readAtsign(name: atSign!);

          if (atsignKey != null) {
            final atAuthService = AtClientMobile.authService(
              atSign,
              _atClientPreference!,
            );
            final atAuthRequest = AtAuthRequest(atSign);
            final atAuthResponse = await atAuthService.authenticate(
              atAuthRequest,
            );

            if (atAuthResponse.isSuccessful) {
              _isInitialized = true;
              print('Connected using ephemeral storage (multi-instance mode)');
              onResult(true);
              return;
            }
          }
        } catch (fallbackError) {
          print('Fallback storage also failed: $fallbackError');
        }
      }

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

  /// Check if storage is already in use by checking for Hive lock files
  static Future<bool> isStorageInUse(String storagePath) async {
    try {
      final directory = Directory(storagePath);
      if (!await directory.exists()) {
        return false; // Storage doesn't exist, so it's not in use
      }

      // Check for .lock files (Hive creates these when boxes are in use)
      // This is more reliable than trying to open boxes which changes global state
      final files = await directory.list().toList();
      for (var file in files) {
        if (file is File && file.path.endsWith('.lock')) {
          final lockFile = File(file.path);
          if (await lockFile.exists()) {
            // Check if lock file has content (active process) or is empty (stale lock)
            try {
              final lockContent = await lockFile.readAsString();
              final lockStat = await lockFile.stat();
              final isStale =
                  DateTime.now().difference(lockStat.modified).inMinutes >
                  5; // 5 minute timeout

              if (lockContent.isNotEmpty && !isStale) {
                print(
                  '🔒 Active Hive lock detected: ${file.path.split('/').last}',
                );
                return true;
              } else {
                print(
                  '🧹 Removing stale lock file: ${file.path.split('/').last}',
                );
                try {
                  await lockFile.delete();
                } catch (e) {
                  print('⚠️ Could not remove stale lock: $e');
                }
              }
            } catch (e) {
              // If we can't read the lock file, assume it's in use
              print(
                '🔒 Cannot read lock file, assuming in use: ${file.path.split('/').last}',
              );
              return true;
            }
          }
        }
      }

      // Also check commit log directory for lock files
      final commitLogDir = Directory('$storagePath/commitLog');
      if (await commitLogDir.exists()) {
        final commitLogFiles = await commitLogDir.list().toList();
        for (var file in commitLogFiles) {
          if (file is File && file.path.endsWith('.lock')) {
            final lockFile = File(file.path);
            if (await lockFile.exists()) {
              try {
                final lockContent = await lockFile.readAsString();
                final lockStat = await lockFile.stat();
                final isStale =
                    DateTime.now().difference(lockStat.modified).inMinutes > 5;

                if (lockContent.isNotEmpty && !isStale) {
                  print(
                    '🔒 Active commit log lock detected: ${file.path.split('/').last}',
                  );
                  return true;
                } else {
                  print(
                    '🧹 Removing stale commit log lock: ${file.path.split('/').last}',
                  );
                  try {
                    await lockFile.delete();
                  } catch (e) {
                    print('⚠️ Could not remove stale commit log lock: $e');
                  }
                }
              } catch (e) {
                print(
                  '🔒 Cannot read commit log lock, assuming in use: ${file.path.split('/').last}',
                );
                return true;
              }
            }
          }
        }
      }

      return false; // No active locks found
    } catch (e) {
      print('⚠️  Storage check error: $e');
      // If we can't check properly, assume it's safe to proceed
      return false;
    }
  }

  /// Cleanup method to properly close AtClient and resources
  Future<void> cleanup() async {
    if (_isInitialized) {
      try {
        print('🧹 Cleaning up AtTalk GUI resources...');

        final client = atClient;
        if (client != null) {
          print('  📡 Stopping notification subscriptions...');
          client.notificationService.stopAllSubscriptions();
        }

        print('  📱 Resetting AtClient manager...');
        AtClientManager.getInstance().reset();

        _isInitialized = false;
        print('✅ GUI cleanup completed');
      } catch (e) {
        print('⚠️ GUI cleanup error: $e');
      }
    }
  }
}
