import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_utils/at_logger.dart';

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

      final key = AtKey()
        ..key = 'attalk'
        ..sharedBy = currentAtSign
        ..sharedWith = toAtSign
        ..namespace = _atClientPreference!.namespace
        ..metadata = (Metadata()
          ..isPublic = false
          ..isEncrypted = true
          ..namespaceAware = true);

      final result = await client.notificationService.notify(
        NotificationParams.forUpdate(key, value: message),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      return result.atClientException == null;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  Stream<String> getMessageStream({required String fromAtSign}) {
    final client = atClient;
    if (client == null) {
      throw Exception('AtClient not initialized');
    }

    return client.notificationService
        .subscribe(
          regex: 'attalk.${_atClientPreference!.namespace}@',
          shouldDecrypt: true,
        )
        .where((notification) => notification.from == fromAtSign)
        .map((notification) => notification.value ?? '');
  }
}
