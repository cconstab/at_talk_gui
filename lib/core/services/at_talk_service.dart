import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_auth/at_auth.dart';
import 'package:at_utils/at_logger.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

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

      // Storage claiming is now handled in main.dart during app initialization
      // No need to claim storage again here

      // Check if keys exist in keychain for this atSign
      final keyChainManager = KeyChainManager.getInstance();
      final atsignKey = await keyChainManager.readAtsign(name: atSign!);

      if (atsignKey == null) {
        throw Exception(
          'No keys found for atSign $atSign. Please onboard first.',
        );
      }

      // Use AtAuthService for proper authentication
      print('🔧 Creating AtAuthService with preferences:');
      print('   hiveStoragePath: ${_atClientPreference!.hiveStoragePath}');
      print('   commitLogPath: ${_atClientPreference!.commitLogPath}');

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
      // Storage determination is now handled in main.dart during app initialization
      // This catch block only handles authentication errors
      print('Authentication error: $e');
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
    List<String>? groupMembers, // Add optional group members parameter
  }) async {
    try {
      final client = atClient;
      if (client == null) return false;

      // Create 1-on-1 message JSON to match TUI format exactly
      // TUI expects JSON format even for 1-on-1 messages
      // Include group array with the actual group participants for consistency
      final currentUser = currentAtSign;
      if (currentUser == null) return false;

      final actualGroupMembers = groupMembers ?? [currentUser, toAtSign];
      final messageData = {
        'msg': message,
        'isGroup': false,
        'group':
            actualGroupMembers, // Use provided group members or default to sender+recipient
        'instanceId': _instanceId,
        'from': currentUser,
      };

      final jsonMessage = jsonEncode(messageData);

      // Use exact same protocol as TUI app
      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true;

      var key = AtKey()
        ..key = 'message'
        ..sharedBy = currentUser
        ..sharedWith = toAtSign
        ..namespace = _atClientPreference!.namespace
        ..metadata = metaData;

      // Debug: Sending message
      print('📤 Sending 1-on-1 message to $toAtSign');
      print('📤 JSON Message: $jsonMessage');
      print('📤 sharedBy (from): $currentUser');
      print('📤 sharedWith (to): $toAtSign');
      print('📤 Expected TUI display: "$currentUser: $message"');

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
        ..key = 'message'
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
        ..key = 'message'
        ..sharedBy = currentAtSign
        ..sharedWith = toAtSign
        ..namespace = _atClientPreference!.namespace
        ..metadata = metaData;

      print(
        'Sending group rename - key: ${key.toString()}, JSON: $jsonMessage, to: $toAtSign',
      );

      final result = await client.notificationService.notify(
        NotificationParams.forUpdate(key, value: jsonMessage),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      bool success = result.atClientException == null;
      print(
        'Send group rename result - success: $success, exception: ${result.atClientException}',
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
        ..key = 'message'
        ..sharedBy = currentAtSign
        ..sharedWith = toAtSign
        ..namespace = _atClientPreference!.namespace
        ..metadata = metaData;

      print(
        'Sending group membership change - key: ${key.toString()}, JSON: $jsonMessage, to: $toAtSign',
      );

      final result = await client.notificationService.notify(
        NotificationParams.forUpdate(key, value: jsonMessage),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      bool success = result.atClientException == null;
      print(
        'Send group membership change result - success: $success, exception: ${result.atClientException}',
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
      '🔄 Setting up message subscription with regex: message.${_atClientPreference!.namespace}@',
    );

    return client.notificationService
        .subscribe(
          regex: 'message.${_atClientPreference!.namespace}@',
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

          final isMatch = keyAtsign == 'message';

          // Only log when we get a message (regardless of match)
          if (notification.value != null && notification.value!.isNotEmpty) {
            print(
              '💬 Incoming notification: from=${notification.from}, to=${notification.to}',
            );
            if (!isMatch) {
            } else {}
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

  /// Global variable to track our own lock file
  static String? _currentLockFile;
  static Timer? _lockRefreshTimer;

  /// Start periodic lock file refresh to prove we're still alive
  static void startLockRefresh() {
    if (_currentLockFile != null) {
      _lockRefreshTimer = Timer.periodic(const Duration(seconds: 10), (
        timer,
      ) async {
        if (_currentLockFile != null) {
          try {
            final lockFile = File(_currentLockFile!);
            if (await lockFile.exists()) {
              // Touch the lock file to update its modification time
              await lockFile.setLastModified(DateTime.now());
            }
          } catch (e) {
            print('⚠️ Could not refresh lock file: $e');
          }
        } else {
          timer.cancel();
        }
      });
    }
  }

  /// Stop the lock refresh timer
  static void stopLockRefresh() {
    _lockRefreshTimer?.cancel();
    _lockRefreshTimer = null;
  }

  /// Try to claim storage atomically and create our own lock
  static Future<bool> tryClaimStorage(
    String storagePath,
    String instanceId,
  ) async {
    try {
      final directory = Directory(storagePath);

      // Create directories if they don't exist
      await directory.create(recursive: true);
      final commitLogDir = Directory('$storagePath/commitLog');
      await commitLogDir.create(recursive: true);

      // Check for existing locks first
      bool hasActiveLocks = await _hasActiveLocks(storagePath);
      if (hasActiveLocks) {
        return false; // Storage is already claimed
      }

      // Try to create our own lock file atomically
      final lockFileName = 'at_talk_gui_$instanceId.lock';
      final lockFile = File('$storagePath/$lockFileName');

      // Use atomic write to prevent race conditions
      final lockContent = jsonEncode({
        'instanceId': instanceId,
        'pid': pid,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'at_talk_gui',
      });

      try {
        // Create lock file exclusively (fails if exists)
        final randomAccessFile = await lockFile.open(mode: FileMode.writeOnly);
        await randomAccessFile.writeString(lockContent);
        await randomAccessFile.close();

        // Double-check that we're still the only lock after a brief pause
        await Future.delayed(const Duration(milliseconds: 100));
        bool hasOtherLocks = await _hasActiveLocks(
          storagePath,
          excludeOurLock: lockFileName,
        );

        if (hasOtherLocks) {
          // We lost the race - another process claimed storage
          try {
            await lockFile.delete();
          } catch (e) {
            print('⚠️ Could not clean up our lock file: $e');
          }
          return false;
        }

        // Success! We have exclusive access
        _currentLockFile = lockFile.path;
        print('🔐 Successfully claimed storage: $storagePath');

        // Start periodic lock file refresh to prove we're still alive
        startLockRefresh();

        return true;
      } catch (e) {
        // Lock file already exists or other error
        return false;
      }
    } catch (e) {
      print('⚠️ Storage claim error: $e');
      return false;
    }
  }

  /// Release our storage lock
  static Future<void> releaseStorageLock() async {
    if (_currentLockFile != null) {
      try {
        // Stop the refresh timer
        stopLockRefresh();

        final lockFile = File(_currentLockFile!);
        if (await lockFile.exists()) {
          await lockFile.delete();
          print(
            '🔓 Released storage lock: ${_currentLockFile!.split('/').last}',
          );
        }
      } catch (e) {
        print('⚠️ Could not release storage lock: $e');
      }
      _currentLockFile = null;
    }
  }

  /// Check for active lock files, optionally excluding our own
  static Future<bool> _hasActiveLocks(
    String storagePath, {
    String? excludeOurLock,
  }) async {
    try {
      final directory = Directory(storagePath);
      if (!await directory.exists()) {
        return false;
      }

      // Only check main storage directory for our app lock files
      // DO NOT check commit log directory - that contains Hive's internal lock files
      final files = await directory.list().toList();
      for (var file in files) {
        if (file is File && file.path.endsWith('.lock')) {
          final fileName = file.path.split('/').last;

          // Only check OUR app lock files, not Hive's internal lock files
          if (!_isOurAppLockFile(fileName)) {
            continue; // Skip Hive internal lock files
          }

          if (excludeOurLock != null && fileName == excludeOurLock) {
            continue; // Skip our own lock file
          }

          if (await _isActiveLock(File(file.path))) {
            return true;
          }
        }
      }

      // DO NOT check commit log directory - it contains Hive's lock files that we should never touch

      return false;
    } catch (e) {
      print('⚠️ Lock check error: $e');
      return true; // Assume locked on error
    }
  }

  /// Check if a lock file is one of our app lock files (not a Hive internal lock file)
  static bool _isOurAppLockFile(String fileName) {
    return fileName.startsWith('at_talk_gui_') ||
        fileName.startsWith('at_talk_tui_');
  }

  /// Check if a specific lock file represents an active process
  static Future<bool> _isActiveLock(File lockFile) async {
    try {
      if (!await lockFile.exists()) {
        return false;
      }

      final lockContent = await lockFile.readAsString();
      final lockStat = await lockFile.stat();
      final isStale =
          DateTime.now().difference(lockStat.modified).inSeconds >
          30; // 30 seconds should be plenty for normal shutdown

      if (lockContent.isEmpty || isStale) {
        // Clean up stale lock
        print(
          '🧹 Removing stale lock file: ${lockFile.path.split('/').last} (age: ${DateTime.now().difference(lockStat.modified).inSeconds}s)',
        );
        try {
          await lockFile.delete();
        } catch (e) {
          print('⚠️ Could not remove stale lock: $e');
        }
        return false;
      }

      // For JSON lock files, also check if the process is still running
      try {
        final lockData = jsonDecode(lockContent);
        if (lockData is Map && lockData.containsKey('pid')) {
          final lockPid = lockData['pid'] as int;
          if (!_isProcessRunning(lockPid)) {
            print(
              '🧹 Removing lock for dead process $lockPid: ${lockFile.path.split('/').last}',
            );
            try {
              await lockFile.delete();
            } catch (e) {
              print('⚠️ Could not remove dead process lock: $e');
            }
            return false;
          }

          // Extra check: if lock is more than 15 seconds old but process still exists,
          // check if it's really our type of process (at_talk)
          if (DateTime.now().difference(lockStat.modified).inSeconds > 15) {
            final processType = lockData['type'] as String?;
            if (processType != null && (processType.contains('at_talk'))) {
              // This is probably a real at_talk process, keep the lock
              print(
                '🔒 Active at_talk lock detected: ${lockFile.path.split('/').last}',
              );
              return true;
            } else {
              // Unknown process type, might be orphaned
              print(
                '🧹 Removing lock for unknown process type: ${lockFile.path.split('/').last}',
              );
              try {
                await lockFile.delete();
              } catch (e) {
                print('⚠️ Could not remove unknown process lock: $e');
              }
              return false;
            }
          }
        }
      } catch (e) {
        // Not JSON or other parsing error, treat as active for safety
      }

      print('🔒 Active lock detected: ${lockFile.path.split('/').last}');
      return true;
    } catch (e) {
      print(
        '🔒 Cannot read lock file, assuming active: ${lockFile.path.split('/').last}',
      );
      return true; // Assume active on error
    }
  }

  /// Check if a process ID is still running
  static bool _isProcessRunning(int pid) {
    try {
      // On Unix-like systems, sending signal 0 checks if process exists
      Process.runSync('kill', ['-0', pid.toString()]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if storage is already in use by checking for Hive lock files (legacy function for backward compatibility)
  /// Legacy method - now just calls _hasActiveLocks for backward compatibility
  static Future<bool> isStorageInUse(String storagePath) async {
    return await _hasActiveLocks(storagePath);
  }

  /// Cleanup method to properly close AtClient and resources
  Future<void> cleanup() async {
    if (_isInitialized) {
      try {
        print('🧹 Cleaning up AtTalk GUI resources...');

        // Release storage lock first
        await releaseStorageLock();

        final client = atClient;
        if (client != null) {
          print('  📡 Stopping notification subscriptions...');
          client.notificationService.stopAllSubscriptions();
        }

        print('  📱 Resetting AtClient manager...');
        AtClientManager.getInstance().reset();

        _isInitialized = false;
      } catch (e) {
        print('⚠️ GUI cleanup error: $e');
      }
    }
  }
}
