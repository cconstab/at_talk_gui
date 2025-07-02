import 'dart:io';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:uuid/uuid.dart';

/// Core AtClient service that works for both GUI and TUI implementations
class CoreAtClientService {
  static CoreAtClientService? _instance;
  static CoreAtClientService get instance => _instance ??= CoreAtClientService._internal();

  CoreAtClientService._internal() {
    _instanceId = const Uuid().v4();
  }

  AtClientPreference? _atClientPreference;
  AtClient? _atClient;
  bool _isInitialized = false;
  late final String _instanceId;
  final _logger = AtSignLogger('CoreAtClientService');

  String get instanceId => _instanceId;
  bool get isInitialized => _isInitialized;
  AtClient? get atClient => _atClient;
  String? get currentAtSign => _atClient?.getCurrentAtSign();

  /// Initialize the service with preferences
  void initialize(AtClientPreference preference) {
    _atClientPreference = preference;
    AtSignLogger.root_level = 'WARNING';
  }

  /// Initialize AtClient for CLI/TUI environment with atKeys file
  Future<bool> initializeFromKeysFile({
    required String atSign,
    required String keysFilePath,
    String? namespace,
    String? rootDomain,
  }) async {
    try {
      if (!File(keysFilePath).existsSync()) {
        throw Exception('Keys file not found: $keysFilePath');
      }

      // Set up AtClientPreference for CLI environment
      _atClientPreference = AtClientPreference()
        ..rootDomain = rootDomain ?? 'root.atsign.org'
        ..namespace = namespace ?? 'ai6bh'
        ..hiveStoragePath = '${Platform.environment['HOME']}/.atsign/storage'
        ..commitLogPath = '${Platform.environment['HOME']}/.atsign/storage'
        ..isLocalStoreRequired = true
        ..syncRegex = '.*'
        ..syncBatchSize = 5
        ..syncPageLimit = 10;

      // Create AtClient
      final atClientManager = AtClientManager.getInstance();
      await atClientManager.setCurrentAtSign(atSign, _atClientPreference!.namespace!, _atClientPreference!);

      _atClient = atClientManager.atClient;

      _isInitialized = true;
      _logger.info('AtClient initialized successfully for $atSign');
      return true;
    } catch (e) {
      _logger.severe('Failed to initialize AtClient: $e');
      return false;
    }
  }

  /// Send a message to another atSign
  Future<bool> sendMessage({required String toAtSign, required String message, String? messageId}) async {
    try {
      if (!_isInitialized || _atClient == null) {
        _logger.warning('AtClient not initialized');
        return false;
      }

      final key = AtKey()
        ..key = 'attalk'
        ..sharedBy = currentAtSign
        ..sharedWith = toAtSign
        ..namespace = _atClientPreference!.namespace
        ..metadata = (Metadata()
          ..isPublic = false
          ..isEncrypted = true
          ..namespaceAware = true
          ..ttl = 86400000); // 24 hours

      final messageData = {
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'messageId': messageId ?? const Uuid().v4(),
        'from': currentAtSign,
      };

      final result = await _atClient!.notificationService.notify(
        NotificationParams.forUpdate(key, value: messageData.toString()),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      if (result.atClientException != null) {
        _logger.severe('Failed to send message: ${result.atClientException}');
        return false;
      }

      _logger.info('Message sent successfully to $toAtSign');
      return true;
    } catch (e) {
      _logger.severe('Error sending message: $e');
      return false;
    }
  }

  /// Get a stream of incoming messages
  Stream<Map<String, dynamic>> getMessageStream() {
    if (!_isInitialized || _atClient == null) {
      throw Exception('AtClient not initialized');
    }

    return _atClient!.notificationService
        .subscribe(regex: 'attalk.${_atClientPreference!.namespace}@', shouldDecrypt: true)
        .where((notification) => notification.value != null)
        .map((notification) {
          try {
            // Parse the notification value as message data
            final data = notification.value.toString();
            return {
              'message': data,
              'from': notification.from,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'id': notification.id,
            };
          } catch (e) {
            _logger.warning('Failed to parse notification: $e');
            return {
              'message': notification.value.toString(),
              'from': notification.from,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'id': notification.id,
            };
          }
        });
  }

  /// Get conversation history with another atSign
  Future<List<Map<String, dynamic>>> getConversationHistory({required String withAtSign, int limit = 50}) async {
    try {
      if (!_isInitialized || _atClient == null) {
        return [];
      }

      final messages = <Map<String, dynamic>>[];

      // Get messages sent to the other atSign
      final sentKeys = await _atClient!.getKeys(regex: 'attalk.${_atClientPreference!.namespace}@$withAtSign');

      for (final keyStr in sentKeys) {
        try {
          final key = AtKey.fromString(keyStr);
          final value = await _atClient!.get(key);
          if (value.value != null) {
            messages.add({
              'message': value.value.toString(),
              'from': currentAtSign,
              'to': withAtSign,
              'timestamp': key.metadata.createdAt?.millisecondsSinceEpoch ?? 0,
              'isSent': true,
            });
          }
        } catch (e) {
          _logger.warning('Failed to get message for key $keyStr: $e');
        }
      }

      // Get messages received from the other atSign
      final receivedKeys = await _atClient!.getKeys(
        regex: 'attalk.${_atClientPreference!.namespace}@${currentAtSign?.replaceAll('@', '')}',
      );

      for (final keyStr in receivedKeys) {
        try {
          final key = AtKey.fromString(keyStr);
          if (key.sharedBy == withAtSign) {
            final value = await _atClient!.get(key);
            if (value.value != null) {
              messages.add({
                'message': value.value.toString(),
                'from': withAtSign,
                'to': currentAtSign,
                'timestamp': key.metadata.createdAt?.millisecondsSinceEpoch ?? 0,
                'isSent': false,
              });
            }
          }
        } catch (e) {
          _logger.warning('Failed to get message for key $keyStr: $e');
        }
      }

      // Sort by timestamp and limit results
      messages.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
      return messages.take(limit).toList();
    } catch (e) {
      _logger.severe('Error getting conversation history: $e');
      return [];
    }
  }

  /// Stop the service and cleanup
  Future<void> stop() async {
    try {
      if (_atClient != null) {
        _atClient!.notificationService.stopAllSubscriptions();
      }
      _isInitialized = false;
      _logger.info('CoreAtClientService stopped');
    } catch (e) {
      _logger.warning('Error stopping service: $e');
    }
  }
}
