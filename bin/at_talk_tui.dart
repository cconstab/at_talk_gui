#!/usr/bin/env dart
// This is the TUI entry point for at_talk
// Usage: dart run bin/at_talk_tui.dart -a @your_atsign -t @other_atsign

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:at_talk_gui/tui/tui_chat.dart';

// external packages
import 'package:args/args.dart';
import 'package:logging/src/level.dart';
import 'package:chalkdart/chalk.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';

// atPlatform packages
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';

// Local Packages
import 'package:version/version.dart';

const String digits = '0123456789';

// Global cleanup state
AtClient? globalAtClient;
bool isCleaningUp = false;
Timer? _lockRefreshTimer;

// Start periodic lock file refresh to prove we're still alive
void startLockRefresh() {
  if (_currentLockFile != null) {
    _lockRefreshTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
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

// Stop the lock refresh timer
void stopLockRefresh() {
  _lockRefreshTimer?.cancel();
  _lockRefreshTimer = null;
}

// Cleanup function to properly close AtClient and Hive boxes
Future<void> cleanup() async {
  if (isCleaningUp) return; // Prevent multiple cleanup calls
  isCleaningUp = true;

  print('\n🧹 Cleaning up resources...');

  try {
    // Stop lock refresh timer
    stopLockRefresh();

    // Release storage lock first
    await releaseStorageLock();

    // Close AtClient if it exists
    if (globalAtClient != null) {
      print('  📡 Closing AtClient connections...');
      globalAtClient!.notificationService.stopAllSubscriptions();
      // Reset the AtClient manager to ensure proper cleanup
      AtClientManager.getInstance().reset();
      globalAtClient = null;
    }

    // Close all open Hive boxes
    print('  📦 Closing Hive boxes...');
    await Hive.close();

    print('✅ Cleanup completed');
  } catch (e) {
    print('⚠️  Cleanup error: $e');
  }
}

// Setup signal handlers for graceful shutdown
void setupSignalHandlers() {
  // Note: SIGINT (Ctrl+C) is handled by the TUI chat interface to avoid conflicts

  // Handle SIGTERM (graceful termination)
  ProcessSignal.sigterm.watch().listen((signal) async {
    print('\n⚠️  Received termination signal');
    await cleanup();
    exit(0);
  });
}

// Utility functions
String? getHomeDirectory() {
  switch (Platform.operatingSystem) {
    case 'linux':
    case 'macos':
      return Platform.environment['HOME'];
    case 'windows':
      return Platform.environment['USERPROFILE'];
    case 'android':
      return '/storage/sdcard0';
    case 'ios':
      return null;
    case 'fuchsia':
      return null;
    default:
      return null;
  }
}

String? getTempDirectory() {
  switch (Platform.operatingSystem) {
    case 'linux':
    case 'macos':
      return Platform.environment['TMPDIR'] ?? '/tmp';
    case 'windows':
      return Platform.environment['TEMP'] ?? Platform.environment['TMP'] ?? r'C:\Windows\Temp';
    case 'android':
      return '/data/local/tmp';
    case 'ios':
      return '/tmp';
    default:
      return '/tmp';
  }
}

Future<bool> fileExists(String file) async {
  bool f = await File(file).exists();
  return f;
}

// Global variable to track our own lock file
String? _currentLockFile;

// Check if storage is already in use and attempt to create our own lock
Future<bool> tryClaimStorage(String storagePath, String instanceId) async {
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
    final lockFileName = 'at_talk_tui_$instanceId.lock';
    final lockFile = File('$storagePath/$lockFileName');

    // Use atomic write to prevent race conditions
    final lockContent = jsonEncode({
      'instanceId': instanceId,
      'pid': pid,
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'at_talk_tui',
    });

    try {
      // Create lock file exclusively (fails if exists)
      final randomAccessFile = await lockFile.open(mode: FileMode.writeOnly);
      await randomAccessFile.writeString(lockContent);
      await randomAccessFile.close();

      // Double-check that we're still the only lock after a brief pause
      await Future.delayed(Duration(milliseconds: 100));
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

// Check for active lock files, optionally excluding our own
Future<bool> _hasActiveLocks(String storagePath, {String? excludeOurLock}) async {
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

// Check if a lock file is one of our app lock files (not a Hive internal lock file)
bool _isOurAppLockFile(String fileName) {
  return fileName.startsWith('at_talk_gui_') || fileName.startsWith('at_talk_tui_');
}

// Check if a specific lock file represents an active process
Future<bool> _isActiveLock(File lockFile) async {
  try {
    if (!await lockFile.exists()) {
      return false;
    }

    final lockContent = await lockFile.readAsString();
    final lockStat = await lockFile.stat();
    final isStale =
        DateTime.now().difference(lockStat.modified).inSeconds > 30; // 30 seconds should be plenty for normal shutdown

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

// Check if a process ID is still running
bool _isProcessRunning(int pid) {
  try {
    // On Unix-like systems, sending signal 0 checks if process exists
    Process.runSync('kill', ['-0', pid.toString()]);
    return true;
  } catch (e) {
    return false;
  }
}

// Release our storage lock
Future<void> releaseStorageLock() async {
  if (_currentLockFile != null) {
    try {
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

// Legacy function for backward compatibility (now just checks without claiming)
Future<bool> isStorageInUse(String storagePath) async {
  return await _hasActiveLocks(storagePath);
}

class ServiceFactoryWithNoOpSyncService extends DefaultAtServiceFactory {
  @override
  Future<SyncService> syncService(
    AtClient atClient,
    AtClientManager atClientManager,
    NotificationService notificationService,
  ) async {
    return NoOpSyncService();
  }
}

class NoOpSyncService implements SyncService {
  @override
  void addProgressListener(SyncProgressListener listener) {}

  @override
  Future<bool> isInSync() async => false;

  @override
  bool get isSyncInProgress => false;

  @override
  void removeAllProgressListeners() {}

  @override
  void removeProgressListener(SyncProgressListener listener) {}

  @override
  void setOnDone(Function onDone) {}

  @override
  void sync({Function? onDone, Function? onError}) {}
}

void main(List<String> args) async {
  //starting secondary in a zone
  var logger = AtSignLogger('atTalk sender ');
  logger.logger.level = Level.SHOUT;
  await runZonedGuarded(
    () async {
      await atTalk(args);
    },
    (error, stackTrace) {
      logger.severe('Uncaught error: $error');
      logger.severe(stackTrace.toString());
    },
  );
}

Future<void> atTalk(List<String> args) async {
  final AtSignLogger logger = AtSignLogger(' atTalk ');
  logger.hierarchicalLoggingEnabled = true;
  logger.logger.level = Level.SHOUT;

  // Setup signal handlers for graceful shutdown
  setupSignalHandlers();

  var parser = ArgParser();
  // Args
  parser.addOption(
    'key-file',
    abbr: 'k',
    mandatory: false,
    help: 'Your atSign\'s atKeys file if not in ~/.atsign/keys/',
  );
  parser.addOption('atsign', abbr: 'a', mandatory: true, help: 'Your atSign');
  parser.addOption('toatsign', abbr: 't', mandatory: true, help: 'Talk to this atSign');
  parser.addOption('root-domain', abbr: 'd', mandatory: false, help: 'Root Domain (defaults to root.atsign.org)');
  parser.addOption('namespace', abbr: 'n', mandatory: false, help: 'Namespace (defaults to attalk)');
  parser.addOption('message', abbr: 'm', mandatory: false, help: 'send a message then exit');
  parser.addFlag('verbose', abbr: 'v', help: 'More logging', negatable: false);
  parser.addFlag('never-sync', help: 'Completely disable sync', negatable: false);
  parser.addFlag('ephemeral', help: 'Use ephemeral storage (no offline message persistence)', negatable: false);
  parser.addFlag('help', abbr: 'h', help: 'Show this help message', negatable: false);

  // Check the arguments
  dynamic parsedArgs;
  String atsignFile;
  String fromAtsign = 'unknown';
  String toAtsign = 'unknown';
  String? homeDirectory = getHomeDirectory();
  String nameSpace = 'default.attalk';
  String rootDomain = 'root.atsign.org';
  String? message;
  bool hasTerminal = stdin.hasTerminal;

  try {
    // Arg check
    parsedArgs = parser.parse(args);

    // Check for help flag
    if (parsedArgs['help']) {
      print('atTalk TUI - Terminal-based chat for the atPlatform');
      print('');
      print(parser.usage);
      await cleanup();
      exit(0);
    }

    // Find atSign key file
    fromAtsign = parsedArgs['atsign'];
    toAtsign = parsedArgs['toatsign'];

    if (parsedArgs['root-domain'] != null) {
      rootDomain = parsedArgs['root-domain'];
    }

    if (parsedArgs['namespace'] != null) {
      nameSpace = parsedArgs['namespace'] + '.attalk';
    }
    if (parsedArgs['message'] != null) {
      message = parsedArgs['message'];
    }

    if (parsedArgs['key-file'] != null) {
      atsignFile = parsedArgs['key-file'];
    } else {
      atsignFile = '${fromAtsign}_key.atKeys';
      atsignFile = '$homeDirectory/.atsign/keys/$atsignFile';
    }
    // Check atKeyFile selected exists
    if (!await fileExists(atsignFile)) {
      throw ('\n Unable to find .atKeys file : $atsignFile');
    }
  } catch (e) {
    print(parser.usage);
    print(e);
    await cleanup();
    exit(1);
  }

  AtServiceFactory? atServiceFactory;
  if (parsedArgs['never-sync']) {
    stdout.writeln(chalk.brightBlue('Creating ServiceFactoryWithNoOpSyncService'));
    atServiceFactory = ServiceFactoryWithNoOpSyncService();
  }

  // Now on to the atPlatform startup
  AtSignLogger.root_level = 'SHOUT';
  if (parsedArgs['verbose']) {
    logger.logger.level = Level.INFO;
    AtSignLogger.root_level = 'INFO';
  }

  String uuid = Uuid().v4();
  String instanceId = Uuid().v4(); // Unique ID for this app instance

  // Determine storage paths based on ephemeral flag or message mode
  String storagePath;
  String downloadPath;
  bool forcedEphemeral = false;

  if (parsedArgs['ephemeral'] || message != null) {
    // Use temp directory for ephemeral storage with UUID for isolation
    // Automatically use ephemeral storage for message mode (-m flag) since we're just sending and exiting
    String? tempDir = getTempDirectory();
    storagePath = '$tempDir/at_talk_tui/$fromAtsign/$uuid/storage';
    downloadPath = '$tempDir/at_talk_tui/$fromAtsign/$uuid/files';

    if (message != null) {
      stdout.writeln(chalk.brightYellow('Using ephemeral storage for message mode (faster, no conflicts)'));
    } else {
      stdout.writeln(chalk.brightYellow('Using ephemeral storage (no offline message persistence)'));
    }

    if (parsedArgs['verbose']) {
      stdout.writeln(chalk.gray('Storage path: $storagePath'));
      stdout.writeln(chalk.gray('Commit log: $storagePath/commitLog'));
    }
  } else {
    // Try to claim persistent storage atomically
    String persistentStoragePath = '$homeDirectory/.$nameSpace/$fromAtsign/storage';

    if (parsedArgs['verbose']) {
      stdout.writeln(chalk.gray('Attempting to claim persistent storage: $persistentStoragePath'));
    }

    bool storageClaimed = await tryClaimStorage(persistentStoragePath, instanceId);

    if (!storageClaimed) {
      // Storage claim failed, fall back to ephemeral mode
      stdout.writeln(chalk.brightYellow('⚠️  Could not claim persistent storage (another instance may be using it)'));
      stdout.writeln(chalk.brightYellow('   Automatically using ephemeral storage instead...'));
      stdout.writeln(chalk.gray('   (Offline messages will not persist across sessions)'));

      String? tempDir = getTempDirectory();
      storagePath = '$tempDir/at_talk_tui/$fromAtsign/$uuid/storage';
      downloadPath = '$tempDir/at_talk_tui/$fromAtsign/$uuid/files';
      forcedEphemeral = true;

      if (parsedArgs['verbose']) {
        stdout.writeln(chalk.gray('Ephemeral storage path: $storagePath'));
        stdout.writeln(chalk.gray('Ephemeral commit log: $storagePath/commitLog'));
      }
    } else {
      // Successfully claimed persistent storage
      storagePath = persistentStoragePath;
      downloadPath = '$homeDirectory/.$nameSpace/$fromAtsign/files';
      stdout.writeln(chalk.brightBlue('✅ Claimed persistent storage for offline messages'));
      if (parsedArgs['verbose']) {
        stdout.writeln(chalk.gray('Storage path: $storagePath'));
        stdout.writeln(chalk.gray('Commit log: $storagePath/commitLog'));
      }
    }
  }

  //onboarding preference builder can be used to set onboardingService parameters
  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    ..hiveStoragePath = storagePath
    ..namespace = nameSpace
    ..downloadPath = downloadPath
    ..isLocalStoreRequired = true
    ..monitorHeartbeatInterval = Duration(seconds: 5)
    ..commitLogPath = '$storagePath/commitLog'
    ..rootDomain = rootDomain
    ..fetchOfflineNotifications = true
    ..atKeysFilePath = atsignFile
    ..atProtocolEmitted = Version(2, 0, 0);

  AtOnboardingService onboardingService = AtOnboardingServiceImpl(
    fromAtsign,
    atOnboardingConfig,
    atServiceFactory: atServiceFactory,
  );
  bool onboarded = false;
  bool hasTriedEphemeral = parsedArgs['ephemeral'] || forcedEphemeral; // Track if we've already tried ephemeral
  Duration retryDuration = Duration(seconds: 3);
  while (!onboarded) {
    try {
      stdout.write(chalk.brightBlue('\r\x1b[KConnecting ... '));
      await Future.delayed(Duration(milliseconds: 1000)); // Pause just long enough for the retry to be visible
      onboarded = await onboardingService.authenticate();
    } catch (exception) {
      String exceptionStr = exception.toString().toLowerCase();

      // Check if this is a Hive database issue that suggests storage conflicts
      bool isHiveError =
          exceptionStr.contains('hive') ||
          exceptionStr.contains('box not found') ||
          exceptionStr.contains('box') ||
          exceptionStr.contains('commit log') ||
          exceptionStr.contains('database') ||
          exceptionStr.contains('lock') ||
          exceptionStr.contains('busy') ||
          exceptionStr.contains('corrupted') ||
          exceptionStr.contains('invalid format') ||
          exceptionStr.contains('permission denied') ||
          exceptionStr.contains('openbox') ||
          exceptionStr.contains('did you forget') ||
          exceptionStr.contains('storage locked'); // Our own lock detection

      if (isHiveError && !hasTriedEphemeral) {
        stdout.writeln('');
        stdout.writeln(chalk.brightRed('💥 Storage conflict detected during onboarding!'));
        stdout.writeln(chalk.brightYellow('   Automatically falling back to ephemeral storage...'));

        if (parsedArgs['verbose']) {
          stdout.writeln(chalk.gray('   Original storage path: $storagePath'));
          stdout.writeln(chalk.gray('   Error details: $exception'));
        }

        try {
          // Reset the AtClient manager
          var atClientManager = AtClientManager.getInstance();
          atClientManager.reset();

          if (parsedArgs['verbose']) {
            stdout.writeln(chalk.gray('   Reset AtClient manager'));
          }
        } catch (e) {
          if (parsedArgs['verbose']) {
            stdout.writeln(chalk.gray('   AtClient cleanup: $e'));
          }
        }

        // Give the system a moment to clean up
        await Future.delayed(Duration(milliseconds: 200));

        // Generate new identifiers for complete isolation
        uuid = Uuid().v4();
        instanceId = Uuid().v4();

        // Use a simpler ephemeral namespace
        String ephemeralNamespace = '${nameSpace}_eph_${uuid.substring(0, 8)}';

        // Create simpler ephemeral storage paths
        String? tempDir = getTempDirectory();
        storagePath = '$tempDir/at_talk_eph/$fromAtsign/$uuid/storage';
        downloadPath = '$tempDir/at_talk_eph/$fromAtsign/$uuid/files';
        String commitLogPath = '$storagePath/commitLog';

        if (parsedArgs['verbose']) {
          stdout.writeln(chalk.gray('   Ephemeral storage: $storagePath'));
          stdout.writeln(chalk.gray('   Ephemeral namespace: $ephemeralNamespace'));
        }

        // Create ephemeral directories
        try {
          await Directory(storagePath).create(recursive: true);
          await Directory(downloadPath).create(recursive: true);

          if (parsedArgs['verbose']) {
            stdout.writeln(chalk.gray('   Created ephemeral directories'));
          }
        } catch (e) {
          if (parsedArgs['verbose']) {
            stdout.writeln(chalk.gray('   Directory creation error: $e'));
          }
        }

        // Recreate onboarding config
        atOnboardingConfig = AtOnboardingPreference()
          ..hiveStoragePath = storagePath
          ..namespace =
              nameSpace // Always use the original namespace, even for ephemeral
          ..downloadPath = downloadPath
          ..isLocalStoreRequired = true
          ..monitorHeartbeatInterval = Duration(seconds: 5)
          ..commitLogPath = commitLogPath
          ..rootDomain = rootDomain
          ..fetchOfflineNotifications = true
          ..atKeysFilePath = atsignFile
          ..atProtocolEmitted = Version(2, 0, 0);

        // Recreate onboarding service
        onboardingService = AtOnboardingServiceImpl(fromAtsign, atOnboardingConfig, atServiceFactory: atServiceFactory);

        hasTriedEphemeral = true;
        nameSpace = ephemeralNamespace;

        stdout.writeln(chalk.brightYellow('   Using ephemeral storage (no offline message persistence)'));
        if (parsedArgs['verbose']) {
          stdout.writeln(chalk.gray('   Retrying authentication...'));
        }
        stdout.writeln('');
        continue; // Try again with ephemeral storage
      }

      stdout.write(chalk.brightRed('$exception. Will retry in ${retryDuration.inSeconds} seconds'));
    }
    if (!onboarded) {
      await Future.delayed(retryDuration);
    }
  }
  stdout.writeln(chalk.brightGreen('Connected'));

  // Current atClient is the one which the onboardingService just authenticated
  AtClient atClient = AtClientManager.getInstance().atClient;

  // Store global reference for cleanup
  globalAtClient = atClient;

  // Inform user if we fell back to ephemeral storage
  if (hasTriedEphemeral && !parsedArgs['ephemeral']) {
    stdout.writeln(chalk.brightYellow('⚠️  Note: Using ephemeral storage due to storage conflict'));
    stdout.writeln(chalk.brightYellow('   Messages will not persist after this session ends'));
    stdout.writeln(chalk.brightYellow('   To avoid this, ensure only one AtTalk instance runs per atSign'));
    stdout.writeln('');
  }

  // If no terminal, read from stdin (pipe mode)
  if (!hasTerminal && message == null) {
    try {
      // Read all input from stdin
      List<String> lines = [];
      await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
        lines.add(line);
      }
      if (lines.isNotEmpty) {
        message = "file sent\n${lines.join('\n')}";
      }
    } catch (e) {
      stderr.writeln('Error reading from stdin: $e');
      await cleanup();
      exit(1);
    }
  }

  // If -m is used OR pipe input, send message(s) and exit cleanly
  if (message != null && message.isNotEmpty) {
    // Support comma-separated list for -t
    var recipients = toAtsign.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();

    final isGroupMessage = recipients.length > 1;
    // Group should include all participants: sender + recipients
    final group = [fromAtsign, ...recipients].toSet().toList()..sort();

    // For multi-instance support, we need to send to ourselves too
    final allRecipients = <String>{...recipients, fromAtsign}.toList();

    bool allSuccess = true;
    for (final atSign in allRecipients) {
      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true;
      var key = AtKey()
        ..key = 'message'
        ..sharedBy = fromAtsign
        ..sharedWith = atSign
        ..namespace = nameSpace
        ..metadata = metaData;
      var payload = jsonEncode({
        'group': group,
        'from': fromAtsign,
        'msg': message,
        'instanceId': instanceId,
        'isGroup': isGroupMessage,
      });
      var success = await sendNotification(atClient.notificationService, key, payload, logger);
      if (!success) {
        if (hasTerminal) {
          stdout.writeln(chalk.red('[Error: Unable to send to $atSign]'));
        } else {
          stderr.writeln('[Error: Unable to send to $atSign]');
        }
        allSuccess = false;
      } else {
        if (!hasTerminal) {
          stderr.writeln('Message sent to $atSign');
        }
      }
    }

    if (hasTerminal) {
      stdout.writeln(chalk.green('Message sent.'));
    } else {
      if (allSuccess) {
        stderr.writeln('All messages sent successfully.');
        await cleanup();
        exit(0);
      } else {
        stderr.writeln('Some messages failed to send.');
        await cleanup();
        exit(1);
      }
    }
    await cleanup();
    exit(allSuccess ? 0 : 1);
  }

  // Only start TUI if we have a terminal
  if (!hasTerminal) {
    stderr.writeln('No terminal available and no message to send');
    await cleanup();
    exit(1);
  }

  // Start TUI chat app
  final tui = TuiChatApp(fromAtsign);

  // Set cleanup callback for graceful exit
  tui.onCleanup = cleanup;

  // If -m is not used, support group chat creation from comma-separated -t
  List<String> participants = toAtsign.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();
  if (participants.length > 1) {
    // Group chat: include myself in the participants list for consistency
    participants.add(fromAtsign);
    final allParticipants = participants.toSet().toList()..sort();
    final groupKey = allParticipants.join(',');
    tui.addSession(groupKey, allParticipants);
    tui.switchSession(groupKey);
  } else {
    // Individual chat: use consistent comma-separated format like groups
    final individualParticipants = {fromAtsign, participants[0]}.toList()..sort();
    final sessionKey = individualParticipants.join(','); // Use consistent format!
    tui.addSession(sessionKey, individualParticipants);
    tui.switchSession(sessionKey);
  }

  // Listen for incoming messages
  // Each instance needs a unique subscription to avoid notification load balancing
  // Use instanceId to make subscription unique while still receiving all attalk messages
  atClient.notificationService
      .subscribe(regex: 'message.$nameSpace@', shouldDecrypt: true)
      .listen(
        ((notification) async {
          try {
            final value = notification.value;
            if (value == null) return;
            final data = jsonDecode(value);
            if (data is! Map) return;

            // Check if this is a group rename notification
            if (data['type'] == 'groupRename') {
              final group = (data['group'] as List).map((e) => e.toString()).toList();
              final newGroupName = data['groupName'] as String?;
              final fromAtSign = data['from'] as String?;
              final instanceId = data['instanceId'] as String?;
              
              // Skip processing our own rename notifications to prevent loops
              if (fromAtSign == fromAtsign) {
                print('🚫 TUI: Ignoring rename notification from ourselves ($fromAtSign)');
                return;
              }
              
              final sessionParticipants = group.toSet().toList()..sort();
              final sessionKey = sessionParticipants.join(',');

              print('🔄 TUI: Received group rename notification');
              print('   From: $fromAtSign');
              print('   New name: $newGroupName');
              print('   Members: $sessionParticipants');
              print('   InstanceId: $instanceId');
              print('   Computed session key: $sessionKey');
              print('   Current sessions:');
              for (final entry in tui.sessions.entries) {
                print('     - ${entry.key}: ${entry.value.participants} (name: "${entry.value.groupName}")');
              }

              // Strategy 1: Try to find by exact instanceId first
              String? targetSessionId;
              if (instanceId != null && tui.sessions.containsKey(instanceId)) {
                targetSessionId = instanceId;
                print('   ✅ Found session by exact instanceId: $instanceId');
              } else {
                // Strategy 2: Find existing session with matching participants
                for (final entry in tui.sessions.entries) {
                  final session = entry.value;
                  final sessionMembers = session.participants.toSet();
                  final incomingMembers = sessionParticipants.toSet();

                  print('   Comparing session ${entry.key}: $sessionMembers vs incoming: $incomingMembers');

                  if (sessionMembers.length == incomingMembers.length && 
                      sessionMembers.containsAll(incomingMembers)) {
                    targetSessionId = entry.key;
                    print('   ✅ Found matching session by participants: $targetSessionId');
                    break;
                  }
                }
                
                // Strategy 3: Check if we should use the base session key
                if (targetSessionId == null && instanceId != null) {
                  // If the instanceId looks like a base session key format, use it
                  if (instanceId == sessionKey) {
                    print('   🔧 InstanceId matches computed session key, will create session: $instanceId');
                    targetSessionId = instanceId;
                  }
                }
              }

              if (targetSessionId != null && tui.sessions.containsKey(targetSessionId)) {
                // Update existing session name
                final oldName = tui.sessions[targetSessionId]!.groupName;
                tui.sessions[targetSessionId]!.groupName = newGroupName;

                print('   ✅ Updated existing session $targetSessionId from "$oldName" to "$newGroupName"');

                final displayName = newGroupName?.isNotEmpty == true ? newGroupName! : 'Unnamed Group';
                tui.addMessage(targetSessionId, '[Group renamed to "$displayName"]', incoming: true);
              } else {
                // Create new session ONLY if no existing session was found and we have a valid instanceId
                if (instanceId != null) {
                  print('   🆕 No matching session found, creating new session with instanceId: $instanceId');
                  tui.addSession(instanceId, sessionParticipants, newGroupName);
                  final displayName = newGroupName?.isNotEmpty == true ? newGroupName! : 'Unnamed Group';
                  tui.addMessage(instanceId, '[Group renamed to "$displayName"]', incoming: true);
                } else {
                  print('   ❌ No instanceId provided and no matching session found - ignoring rename');
                }
              }

              tui.draw();
              return;
            }

            // Check if this is a group membership change notification
            if (data['type'] == 'groupMembershipChange') {
              final group = (data['group'] as List).map((e) => e.toString()).toList();
              final groupName = data['groupName'] as String?;
              final sessionParticipants = group.toSet().toList()..sort();

              // Try to find existing session with different participant set
              String? existingSessionKey = tui.findSessionWithParticipants(sessionParticipants);

              if (existingSessionKey == null) {
                // Look for a session that has some of the same participants but different membership
                // BUT only migrate existing sessions under specific conditions to avoid overwriting individual chats
                for (var entry in tui.sessions.entries) {
                  var entryParticipants = entry.value.participants.toSet();
                  var newParticipants = sessionParticipants.toSet();

                  // Only consider migrating if:
                  // 1. The existing session is already a group (3+ participants), OR
                  // 2. The existing session is an individual chat (2 participants) AND the new session is also individual with same participants
                  bool shouldMigrate = false;

                  if (entryParticipants.length >= 3) {
                    // Existing session is already a group - safe to migrate if there's significant overlap
                    shouldMigrate =
                        entryParticipants.intersection(newParticipants).length >= 2 &&
                        entryParticipants.contains(fromAtsign);
                  } else if (entryParticipants.length == 2 && newParticipants.length == 2) {
                    // Both are individual chats - only migrate if they have exactly the same participants
                    shouldMigrate =
                        entryParticipants.difference(newParticipants).isEmpty &&
                        newParticipants.difference(entryParticipants).isEmpty;
                  }
                  // Don't migrate individual chats (2 participants) to group chats (3+ participants)

                  if (shouldMigrate) {
                    existingSessionKey = entry.key;
                    break;
                  }
                }
              }

              if (existingSessionKey != null) {
                // Update existing session
                var session = tui.sessions[existingSessionKey]!;
                var oldParticipants = session.participants.toSet();
                var newParticipants = sessionParticipants.toSet();

                // Generate new session key
                var newSessionKey = tui.generateSessionKey(sessionParticipants);

                if (newSessionKey != existingSessionKey) {
                  // Need to migrate session
                  var messages = session.messages.toList();
                  tui.addSession(newSessionKey, sessionParticipants, groupName);
                  tui.sessions[newSessionKey]!.messages.addAll(messages);

                  // Remove old session
                  tui.sessions.remove(existingSessionKey);

                  // Update active session if it was the migrated one
                  if (tui.activeSession == existingSessionKey) {
                    tui.activeSession = newSessionKey;
                    tui.windowOffset = tui.sessionList.indexOf(newSessionKey);
                  }
                } else {
                  // Same key, just update participants and group name
                  session.participants.clear();
                  session.participants.addAll(sessionParticipants);
                  session.groupName = groupName;
                }

                // Show what changed
                var added = newParticipants.difference(oldParticipants);
                var removed = oldParticipants.difference(newParticipants);

                for (var participant in added) {
                  if (participant != fromAtsign) {
                    tui.addMessage(
                      tui.activeSession ?? newSessionKey,
                      '[$participant joined the group]',
                      incoming: true,
                    );
                  }
                }
                for (var participant in removed) {
                  if (participant != fromAtsign) {
                    tui.addMessage(tui.activeSession ?? newSessionKey, '[$participant left the group]', incoming: true);
                  }
                }
              } else {
                // Create new session
                var newSessionKey = tui.generateSessionKey(sessionParticipants);
                tui.addSession(newSessionKey, sessionParticipants, groupName);
              }

              tui.draw();
              return;
            }

            final group = (data['group'] as List).map((e) => e.toString()).toList();
            final from = data['from'] as String? ?? notification.from;
            final msg = data['msg'] as String? ?? value;
            final messageInstanceId = data['instanceId'] as String?;
            final isGroup = data['isGroup'] as bool? ?? false;
            final groupName = data['groupName'] as String?;

            // Skip messages from this same app instance to avoid duplicates
            // But allow messages to self from different instances
            if (from == fromAtsign && messageInstanceId == instanceId) return;

            // Use the isGroup flag to determine session handling
            String sessionKey;
            List<String> sessionParticipants;

            if (isGroup) {
              // Group chat: use all participants (including myself) for consistency
              sessionParticipants = group.toSet().toList()..sort();
              sessionKey = sessionParticipants.join(',');
            } else {
              // Individual chat: use consistent comma-separated format
              sessionParticipants = group.toSet().toList()..sort();
              // Always use comma-separated format for consistency with GUI
              sessionKey = sessionParticipants.join(',');
            }

            // Try to find existing session with same participants first
            // This helps avoid duplicate sessions when group membership changes
            String? existingSessionKey = tui.findSessionWithParticipants(sessionParticipants);
            if (existingSessionKey != null) {
              sessionKey = existingSessionKey;
            } else {
              // If no exact match, look for a session that could be an updated version
              // This handles cases where participant lists have changed
              // BUT only migrate existing sessions under specific conditions to avoid overwriting individual chats
              for (var entry in tui.sessions.entries) {
                var entryParticipants = entry.value.participants.toSet();
                var newParticipants = sessionParticipants.toSet();

                // Only consider migrating if:
                // 1. The existing session is already a group (3+ participants), OR
                // 2. The existing session is an individual chat (2 participants) AND the new session is also individual with same participants
                bool shouldMigrate = false;

                if (entryParticipants.length >= 3) {
                  // Existing session is already a group - safe to migrate if there's significant overlap
                  shouldMigrate =
                      entryParticipants.intersection(newParticipants).length >= 2 &&
                      entryParticipants.contains(fromAtsign) &&
                      newParticipants.contains(fromAtsign);
                } else if (entryParticipants.length == 2 && newParticipants.length == 2) {
                  // Both are individual chats - only migrate if they have exactly the same participants
                  shouldMigrate =
                      entryParticipants.difference(newParticipants).isEmpty &&
                      newParticipants.difference(entryParticipants).isEmpty;
                }
                // Don't migrate individual chats (2 participants) to group chats (3+ participants)

                if (shouldMigrate) {
                  // Update the existing session with new participant list
                  var session = entry.value;
                  session.participants.clear();
                  session.participants.addAll(sessionParticipants);

                  // Generate correct session key for the updated participant list
                  var correctKey = tui.generateSessionKey(sessionParticipants);
                  if (correctKey != entry.key) {
                    // Need to migrate to correct key
                    var messages = session.messages.toList();
                    var groupName = session.groupName;

                    tui.addSession(correctKey, sessionParticipants, groupName);
                    tui.sessions[correctKey]!.messages.addAll(messages);

                    // Remove old session
                    tui.sessions.remove(entry.key);

                    // Update active session if needed
                    if (tui.activeSession == entry.key) {
                      tui.activeSession = correctKey;
                      tui.windowOffset = tui.sessionList.indexOf(correctKey);
                    }

                    sessionKey = correctKey;
                  } else {
                    sessionKey = entry.key;
                  }
                  break;
                }
              }
            }

            tui.addSession(sessionKey, sessionParticipants, groupName);
            tui.addMessage(
              sessionKey,
              msg,
              incoming: true,
              sender: (from == fromAtsign) ? null : from, // Use null for own messages to show "me:"
            );
            tui.draw();
          } catch (e) {
            // Skip messages from this same app instance in fallback case too
            if (notification.from == fromAtsign) return;

            // fallback: treat as plain message
            tui.addMessage(notification.from, notification.value ?? '', incoming: true);
            tui.draw();
          }
        }),
        onError: (e) => logger.severe('Notification Failed:$e'),
        onDone: () => logger.info('Notification listener stopped'),
      );

  // Outgoing message handler
  tui.onSend = (String sessionId, String message) async {
    final session = tui.sessions[sessionId];
    if (session == null) return;

    // Send messages to OTHER participants only (exclude self to prevent duplicate messages)
    final recipients = session.participants.where((atSign) => atSign != fromAtsign).toList();

    // Use all participants for the group field (for message organization)
    final groupForMessage = session.participants.toSet().toList()..sort();

    for (final atSign in recipients) {
      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true;
      var key = AtKey()
        ..key = 'message'
        ..sharedBy = fromAtsign
        ..sharedWith = atSign
        ..namespace = nameSpace
        ..metadata = metaData;
      var payload = jsonEncode({
        'group': groupForMessage,
        'from': fromAtsign,
        'msg': message,
        'instanceId': sessionId, // Use the session ID, not the global instance ID
        'isGroup': session.participants.length > 2, // Determine if group based on participant count
        'groupName': session.groupName,
      });
      var success = await sendNotification(atClient.notificationService, key, payload, logger);
      if (!success) {
        tui.addMessage(sessionId, '[Error: Unable to send to $atSign]', incoming: true);
        tui.draw();
      }
    }
  };

  // Group rename handler
  tui.onGroupRename = (String sessionId, String newGroupName) async {
    final session = tui.sessions[sessionId];
    if (session == null) return;

    // Send rename notifications to other participants only (exclude self)
    for (final atSign in session.participants) {
      if (atSign == fromAtsign) continue; // Skip sending to self

      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true;
      var key = AtKey()
        ..key = 'message'
        ..sharedBy = fromAtsign
        ..sharedWith = atSign
        ..namespace = nameSpace
        ..metadata = metaData;
      var payload = jsonEncode({
        'type': 'groupRename',
        'group': session.participants,
        'from': fromAtsign,
        'groupName': newGroupName,
        'instanceId': sessionId, // Use the session ID, not the global instance ID
      });
      await sendNotification(atClient.notificationService, key, payload, logger);
    }
  };

  // Group membership change handler
  tui.onGroupMembershipChange = (String sessionId, List<String> participants, String? groupName) async {
    final session = tui.sessions[sessionId];
    if (session == null) return;

    // Send membership change notifications to other participants only (exclude self)
    for (final atSign in participants) {
      if (atSign == fromAtsign) continue; // Skip sending to self
      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true;
      var key = AtKey()
        ..key = 'message'
        ..sharedBy = fromAtsign
        ..sharedWith = atSign
        ..namespace = nameSpace
        ..metadata = metaData;
      var payload = jsonEncode({
        'type': 'groupMembershipChange',
        'group': participants,
        'from': fromAtsign,
        'groupName': groupName,
        'instanceId': sessionId, // Use the session ID, not the global instance ID
      });
      await sendNotification(atClient.notificationService, key, payload, logger);
    }
  };

  // Run the TUI
  await tui.run();

  // Cleanup when TUI exits normally
  await cleanup();
  exit(0);
}

Future<bool> sendNotification(
  NotificationService notificationService,
  AtKey key,
  String input,
  AtSignLogger logger,
) async {
  bool success = false;

  // back off retries (max 3)
  for (int retry = 0; retry < 3; retry++) {
    try {
      NotificationResult result = await notificationService.notify(
        NotificationParams.forUpdate(key, value: input, notificationExpiry: Duration(days: 1)),
        waitForFinalDeliveryStatus: false,
        checkForFinalDeliveryStatus: false,
      );
      if (result.atClientException != null) {
        logger.warning(result.atClientException);
        retry++;
        await Future.delayed(Duration(milliseconds: (500 * (retry))));
      } else {
        success = true;
        break;
      }
    } catch (e) {
      logger.warning(e);
    }
  }
  return (success);
}
