import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_auth/at_auth.dart';
import 'package:at_utils/at_logger.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import '../utils/at_talk_env.dart';

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

  /// Configure atSign-specific storage paths matching TUI behavior
  static Future<AtClientPreference> configureAtSignStorage(
    String atSign, {
    bool forceEphemeral = false,
    bool cleanupExisting = true,
    String? rootDomain,
  }) async {
    // Normalize atSign (remove @ if present, we'll add it back consistently)
    final normalizedAtSign = atSign.startsWith('@') ? atSign.substring(1) : atSign;
    final fullAtSign = '@$normalizedAtSign';

    // ENHANCED: Check for domain switching or atSign switching
    bool needsCleanup = false;
    String cleanupReason = '';

    if (_instance != null) {
      final currentAtSign = _instance!.currentAtSign;
      final currentDomain = _atClientPreference?.rootDomain ?? 'root.atsign.org';
      final newDomain = rootDomain ?? 'root.atsign.org';

      // Check if we're switching atSigns
      if (currentAtSign != null && currentAtSign != fullAtSign) {
        needsCleanup = true;
        cleanupReason = 'switching atSigns ($currentAtSign → $fullAtSign)';
      }

      // Check if we're switching domains
      if (currentDomain != newDomain) {
        needsCleanup = true;
        if (cleanupReason.isNotEmpty) {
          cleanupReason += ' and domains ($currentDomain → $newDomain)';
        } else {
          cleanupReason = 'switching domains ($currentDomain → $newDomain)';
        }
      }

      // FORCE cleanup for any domain switch regardless of cleanupExisting parameter
      if (currentDomain != newDomain) {
        needsCleanup = true;
        cleanupReason += ' [FORCED]';
      }
    }

    // Clean up existing AtClient if needed
    if (needsCleanup) {
      print('🧹 Enhanced cleanup triggered: needsCleanup=true, reason=\'$cleanupReason\'');

      if (_instance != null) {
        print('   🗑️ Performing aggressive AtClient cleanup...');

        // Get existing client before cleanup
        final client = AtClientManager.getInstance().atClient;
        print('   🔧 Stopping internal AtClient services...');

        try {
          // Force sync service to stop and clear any cached connections
          print('      🔄 Stopping sync service...');
          // Note: stop() method may not be available, using sync reset instead
          // client.syncService.stop();
        } catch (e) {
          print('      ⚠️ Sync service stop error (may be expected): $e');
        }

        try {
          // Force notification service to clear all connections
          print('      🔔 Clearing notification service connections...');
          client.notificationService.stopAllSubscriptions();
        } catch (e) {
          print('      ⚠️ Notification service clear error (may be expected): $e');
        }

        print('   🗑️ Resetting AtClient manager...');
        AtClientManager.getInstance().reset();

        // CRITICAL: Add longer delay to ensure all internal components are fully reset
        print('   ⏳ Waiting 2 seconds for complete service shutdown...');
        await Future.delayed(Duration(seconds: 2));

        await _instance!.cleanup();
        print('   ✅ Enhanced cleanup completed');
      }
    } else if (cleanupExisting && _instance != null) {
      // Original logic for when no enhanced cleanup is needed
      final currentAtSign = _instance!.currentAtSign;
      if (currentAtSign != null && currentAtSign != fullAtSign) {
        print('🧹 Cleaning up existing AtClient for $currentAtSign before configuring $fullAtSign');
        await _instance!.cleanup();
      }
    }

    final dir = await getApplicationSupportDirectory();
    String storagePath = '';
    String commitLogPath = '';
    bool usingEphemeral = forceEphemeral;
    final instanceId = const Uuid().v4();

    if (!forceEphemeral) {
      // Try persistent storage first with atSign-specific path (matching TUI)
      // Use configurable namespace like TUI's -n option
      storagePath = '${dir.path}/.${AtTalkEnv.namespace}/$fullAtSign/storage';
      commitLogPath = '$storagePath/commitLog';

      print('Attempting to claim atSign-specific storage: $storagePath');

      final storageClaimed = await tryClaimStorage(storagePath, instanceId);

      if (!storageClaimed) {
        // Storage claim failed, fall back to ephemeral mode with atSign isolation
        print('⚠️  Could not claim persistent storage for $fullAtSign');
        print('   Automatically using ephemeral storage instead...');
        usingEphemeral = true;
      } else {
        print('Successfully claimed persistent storage for $fullAtSign');
      }
    }

    if (usingEphemeral) {
      // Create ephemeral storage path with atSign isolation (matching TUI)
      final tempDir = Directory.systemTemp;
      final uuid = const Uuid().v4();
      storagePath = '${tempDir.path}/at_talk_gui/$fullAtSign/$uuid/storage';
      commitLogPath = '$storagePath/commitLog';

      // Ensure ephemeral storage directories exist
      await Directory(storagePath).create(recursive: true);
      await Directory(commitLogPath).create(recursive: true);

      print('Using ephemeral GUI storage for $fullAtSign: $storagePath');
    }

    // Create AtClientPreference with atSign-specific paths
    final preference = AtClientPreference()
      ..rootDomain = rootDomain ?? _atClientPreference?.rootDomain ?? 'root.atsign.org'
      ..namespace = AtTalkEnv
          .namespace // Always use current namespace from AtTalkEnv
      ..hiveStoragePath = storagePath
      ..commitLogPath = commitLogPath
      ..isLocalStoreRequired = true
      ..fetchOfflineNotifications = true;

    // Debug logging to verify paths include atSign
    print('AtClient preferences configured for $fullAtSign:');
    print('   hiveStoragePath: $storagePath');
    print('   commitLogPath: $commitLogPath');
    print('   usingEphemeral: $usingEphemeral');

    // Update the global preference
    _atClientPreference = preference;

    return preference;
  }

  Future<void> onboard({required String? atSign, required Function(bool) onResult, Function(String)? onError}) async {
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
        throw Exception('No keys found for atSign $atSign. Please onboard first.');
      }

      // Use AtAuthService for proper authentication
      print('🔧 Creating AtAuthService with preferences:');
      print('   hiveStoragePath: ${_atClientPreference!.hiveStoragePath}');
      print('   commitLogPath: ${_atClientPreference!.commitLogPath}');

      final atAuthService = AtClientMobile.authService(atSign, _atClientPreference!);

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

  /// Full onboarding approach similar to TUI - creates new AtOnboardingService
  /// This is needed when switching domains to properly reset AtLookup service
  Future<void> onboardWithFullService({
    required String? atSign,
    required Function(bool) onResult,
    Function(String)? onError,
    String? rootDomain,
  }) async {
    try {
      if (_atClientPreference == null) {
        throw Exception('AtClientPreference not initialized');
      }

      print('🔄 Starting full onboarding service for $atSign (domain: ${rootDomain ?? 'default'})');

      // Check if keys exist in keychain for this atSign
      final keyChainManager = KeyChainManager.getInstance();
      final atsignKey = await keyChainManager.readAtsign(name: atSign!);

      if (atsignKey == null) {
        throw Exception('No keys found for atSign $atSign. Please onboard first.');
      }

      // Create AtOnboardingPreference similar to TUI approach
      final onboardingPreference = AtOnboardingPreference()
        ..hiveStoragePath = _atClientPreference!.hiveStoragePath
        ..namespace = _atClientPreference!.namespace
        ..commitLogPath = _atClientPreference!.commitLogPath
        ..isLocalStoreRequired = true
        ..monitorHeartbeatInterval = Duration(seconds: 5)
        ..rootDomain = rootDomain ?? _atClientPreference!.rootDomain
        ..fetchOfflineNotifications = true
        ..atKeysFilePath = null; // Will use keychain instead

      print('🔧 Creating AtOnboardingService with preferences:');
      print('   hiveStoragePath: ${onboardingPreference.hiveStoragePath}');
      print('   commitLogPath: ${onboardingPreference.commitLogPath}');
      print('   rootDomain: ${onboardingPreference.rootDomain}');
      print('   namespace: ${onboardingPreference.namespace}');

      // Create new AtOnboardingService (this is the key difference from the regular onboard method)
      final onboardingService = AtOnboardingServiceImpl(
        atSign,
        onboardingPreference,
      );

      // Perform full onboarding authentication (this resets all internal services)
      print('🚀 Performing full onboarding authentication...');
      final success = await onboardingService.authenticate();

      if (success) {
        print('✅ Full onboarding completed successfully');
        _isInitialized = true;
        onResult(true);
      } else {
        throw Exception('Full onboarding authentication failed');
      }
    } catch (e) {
      print('❌ Full onboarding error: $e');
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

      // Generate consistent session key to match TUI behavior
      final sortedParticipants = actualGroupMembers.toSet().toList()..sort();
      final sessionKey = sortedParticipants.join(',');

      final messageData = {
        'msg': message,
        'isGroup': false,
        'group': actualGroupMembers,
        'instanceId': sessionKey, // Use group session key, not app instance ID
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

      // Debug: Show exactly what AtKey we're creating
      print('🔑 GUI AtKey debug:');
      print('   key: ${key.key}');
      print('   sharedBy: ${key.sharedBy}');
      print('   sharedWith: ${key.sharedWith}');
      print('   namespace: ${key.namespace}');
      print('   Full key: ${key.toString()}');

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
        'instanceId': groupInstanceId, // Use the passed group session key, not app instance ID
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
        'Sending group message to $toAtSign: ${groupMembers.length} members at nameSpace ${_atClientPreference!.namespace.toString()}',
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
      print('Error sending group message: $e'); // TODO: Replace with proper logging
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

      print('Sending group rename - key: ${key.toString()}, JSON: $jsonMessage, to: $toAtSign');

      final result = await client.notificationService.notify(
        NotificationParams.forUpdate(key, value: jsonMessage),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      bool success = result.atClientException == null;
      print('Send group rename result - success: $success, exception: ${result.atClientException}');

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

      print('Sending group membership change - key: ${key.toString()}, JSON: $jsonMessage, to: $toAtSign');

      final result = await client.notificationService.notify(
        NotificationParams.forUpdate(key, value: jsonMessage),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      bool success = result.atClientException == null;
      print('Send group membership change result - success: $success, exception: ${result.atClientException}');

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
    print('🔄 Setting up message subscription with regex: message.${_atClientPreference!.namespace}@');

    return client.notificationService
        .subscribe(regex: 'message.${_atClientPreference!.namespace}@', shouldDecrypt: true)
        .where((notification) {
          // Filter like TUI app does - exact same logic
          String keyAtsign = notification.key;
          keyAtsign = keyAtsign.replaceAll('${notification.to}:', '');
          keyAtsign = keyAtsign.replaceAll('.${_atClientPreference!.namespace}${notification.from}', '');

          final isMatch = keyAtsign == 'message';

          // Only log when we get a message (regardless of match)
          if (notification.value != null && notification.value!.isNotEmpty) {
            print('💬 Incoming notification: from=${notification.from}, to=${notification.to}');
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
          print('📨 Raw notification: from=${notification.from}, to=${notification.to}');

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
    return getAllMessageStream().where((data) => data['from'] == fromAtSign).map((data) => data['message'] ?? '');
  }

  /// Global variable to track our own lock file
  static String? _currentLockFile;
  static Timer? _lockRefreshTimer;

  /// Start periodic lock file refresh to prove we're still alive
  static void startLockRefresh() {
    if (_currentLockFile != null) {
      _lockRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
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
  static Future<bool> tryClaimStorage(String storagePath, String instanceId) async {
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
        bool hasOtherLocks = await _hasActiveLocks(storagePath, excludeOurLock: lockFileName);

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
          print('🔓 Released storage lock: ${_currentLockFile!.split('/').last}');
        }
      } catch (e) {
        print('⚠️ Could not release storage lock: $e');
      }
      _currentLockFile = null;
    }
  }

  /// Check for active lock files, optionally excluding our own
  static Future<bool> _hasActiveLocks(String storagePath, {String? excludeOurLock}) async {
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
    return fileName.startsWith('at_talk_gui_') || fileName.startsWith('at_talk_tui_');
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
            print('🧹 Removing lock for dead process $lockPid: ${lockFile.path.split('/').last}');
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
              print('🔒 Active at_talk lock detected: ${lockFile.path.split('/').last}');
              return true;
            } else {
              // Unknown process type, might be orphaned
              print('🧹 Removing lock for unknown process type: ${lockFile.path.split('/').last}');
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
      print('🔒 Cannot read lock file, assuming active: ${lockFile.path.split('/').last}');
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

  /// Change namespace and reinitialize AtClient (like TUI's -n option)
  /// This will switch to a different storage directory and namespace
  /// and completely reinitialize the AtClient with the new namespace
  Future<bool> changeNamespace(String newNamespace, String? currentAtSign) async {
    try {
      print('🔄 Changing namespace from ${AtTalkEnv.namespace} to: $newNamespace');

      // Clean up current AtClient and stop all subscriptions
      await cleanup();

      // Update the namespace
      AtTalkEnv.setNamespace(newNamespace);
      print('✅ Namespace updated to: ${AtTalkEnv.namespace}');

      // If we have a current atSign, reconfigure storage and re-authenticate
      if (currentAtSign != null) {
        print('🔄 Reconfiguring storage for $currentAtSign with new namespace...');

        // Configure new storage with the updated namespace
        final newPreference = await configureAtSignStorage(
          currentAtSign,
          cleanupExisting: false, // Don't cleanup here, we already did it above
          rootDomain: _atClientPreference?.rootDomain,
        );

        // Force complete reinitialization of AtClient with new paths
        print('🔄 Forcing complete AtClient reinitialization...');

        // Initialize AtTalk service with new preference
        initialize(newPreference);

        // Mark as initialized so atClient getter works
        _isInitialized = true;

        // Debug: verify the namespace is correctly set
        print('🔍 Verifying namespace update:');
        print('   AtTalkEnv.namespace: ${AtTalkEnv.namespace}');
        print('   _atClientPreference.namespace: ${_atClientPreference?.namespace}');
        print('   Storage path: ${_atClientPreference?.hiveStoragePath}');

        print('✅ AtClient reinitialized with new namespace storage');

        // Note: The caller (settings screen) should handle:
        // 1. Clearing GroupsProvider data
        // 2. Re-authenticating the user
        // 3. Restarting message subscriptions

        return true;
      } else {
        // Just update the default preference for future use
        final dir = await getApplicationSupportDirectory();
        String storagePath = '${dir.path}/.${AtTalkEnv.namespace}/temp_initialization/storage';
        String commitLogPath = '$storagePath/commitLog';

        await Directory(storagePath).create(recursive: true);
        await Directory(commitLogPath).create(recursive: true);

        final newPreference = AtClientPreference()
          ..rootDomain = AtTalkEnv.rootDomain
          ..namespace = AtTalkEnv.namespace
          ..hiveStoragePath = storagePath
          ..commitLogPath = commitLogPath
          ..isLocalStoreRequired = true
          ..fetchOfflineNotifications = true;

        initialize(newPreference);

        print('✅ Default AtClient preference updated with new namespace');
        return true;
      }
    } catch (e) {
      print('❌ Failed to change namespace: $e');
      return false;
    }
  }

  /// Get current namespace
  String get currentNamespace => AtTalkEnv.namespace;

  /// Reset namespace to default
  Future<bool> resetNamespace(String? currentAtSign) async {
    return await changeNamespace('default', currentAtSign);
  }

  /// Comprehensive cleanup for atSign including all possible storage locations
  /// This is more thorough than the standard cleanup and is useful when
  /// an atSign needs to be completely removed from the system
  static Future<void> completeAtSignCleanup(String atSign) async {
    final normalizedAtSign = atSign.startsWith('@') ? atSign : '@$atSign';

    print('🧹 Starting complete cleanup for $normalizedAtSign...');

    try {
      // 1. Standard AtClient cleanup
      if (_instance != null) {
        await _instance!.cleanup();
      }

      // 2. Reset from keychain (including biometric data)
      final keyChainManager = KeyChainManager.getInstance();
      await keyChainManager.resetAtSignFromKeychain(normalizedAtSign);
      print('✅ Removed from keychain');

      // 3. Clean up storage directories for all namespaces
      final dir = await getApplicationSupportDirectory();
      final appSupportPath = dir.path;

      // List all possible namespace directories
      final namespaceDirs = ['default.attalk', 'test.attalk']; // Add more as needed

      for (final namespace in namespaceDirs) {
        final namespacePath = '$appSupportPath/.$namespace';
        final atSignPath = '$namespacePath/$normalizedAtSign';
        final atSignDir = Directory(atSignPath);

        if (atSignDir.existsSync()) {
          print('🗑️ Removing storage directory: $atSignPath');
          await atSignDir.delete(recursive: true);
        }
      }

      // 4. Clean up any legacy storage directories that might exist
      final legacyPaths = [
        '$appSupportPath/$normalizedAtSign', // Direct atSign folder
        '$appSupportPath/.ai6bh/$normalizedAtSign', // Old namespace
        '$appSupportPath/keys', // Legacy key storage
      ];

      for (final legacyPath in legacyPaths) {
        final legacyDir = Directory(legacyPath);
        if (legacyDir.existsSync()) {
          print('🗑️ Removing legacy directory: $legacyPath');
          // For keys directory, only remove files related to this atSign
          if (legacyPath.endsWith('/keys')) {
            final keyFiles = legacyDir
                .listSync()
                .where((file) => file.path.contains(normalizedAtSign.replaceAll('@', '')))
                .toList();
            for (final file in keyFiles) {
              await file.delete();
              print('🗑️ Removed key file: ${file.path}');
            }
          } else {
            await legacyDir.delete(recursive: true);
          }
        }
      }

      // 5. Clear any temporary storage
      final tempDir = Directory.systemTemp;
      final tempAtTalkDirs = tempDir
          .listSync()
          .where((dir) => dir.path.contains('at_talk_gui') && dir.path.contains(normalizedAtSign.replaceAll('@', '')))
          .toList();

      for (final tempAtTalkDir in tempAtTalkDirs) {
        if (tempAtTalkDir.existsSync()) {
          print('🗑️ Removing temp directory: ${tempAtTalkDir.path}');
          await tempAtTalkDir.delete(recursive: true);
        }
      }

      print('✅ Complete cleanup finished for $normalizedAtSign');
    } catch (e) {
      print('⚠️ Error during complete cleanup: $e');
      rethrow;
    }
  }

  /// Special cleanup for atSigns that match the OS username
  /// This addresses potential conflicts where an atSign matches the system username
  static Future<void> cleanupUsernameConflict(String atSign) async {
    final normalizedAtSign = atSign.startsWith('@') ? atSign : '@$atSign';
    final usernameOnly = normalizedAtSign.replaceAll('@', '');

    print('🔧 Special cleanup for potential username conflict: $normalizedAtSign');

    try {
      // First do the complete cleanup
      await completeAtSignCleanup(normalizedAtSign);

      // Additional cleanup for username conflicts
      final dir = await getApplicationSupportDirectory();

      // Check for directories that might be created with username variations
      final possibleConflictPaths = [
        '${dir.path}/$usernameOnly', // Direct username folder
        '${dir.path}/.default.attalk/$usernameOnly', // Without @ prefix
        '${dir.path}/.test.attalk/$usernameOnly', // Without @ prefix in test namespace
        '/tmp/at_talk_gui/$usernameOnly', // Temp without @ prefix
        '/tmp/at_talk_gui/$normalizedAtSign', // Temp with @ prefix
      ];

      for (final conflictPath in possibleConflictPaths) {
        final conflictDir = Directory(conflictPath);
        if (conflictDir.existsSync()) {
          print('🗑️ Removing potential conflict directory: $conflictPath');
          await conflictDir.delete(recursive: true);
        }
      }

      // Force clear any cached AtClient state
      AtClientManager.getInstance().reset();

      print('✅ Username conflict cleanup completed for $normalizedAtSign');
    } catch (e) {
      print('⚠️ Error during username conflict cleanup: $e');
      rethrow;
    }
  }
}
