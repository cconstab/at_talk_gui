import 'package:flutter/foundation.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import '../services/at_talk_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _currentAtSign;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get currentAtSign => _currentAtSign;
  String? get errorMessage => _errorMessage;

  Future<bool> checkExistingAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final keyChainManager = KeyChainManager.getInstance();
      final atSigns = await keyChainManager.getAtSignListFromKeychain();

      if (atSigns.isNotEmpty) {
        _currentAtSign = atSigns.first;
        _isAuthenticated = true;
        _errorMessage = null;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();
    return _isAuthenticated;
  }

  Future<void> authenticate(String? atSign) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await AtTalkService.instance.onboard(
      atSign: atSign,
      onResult: (success) {
        _isAuthenticated = success;
        if (success) {
          _currentAtSign = atSign;
          _errorMessage = null;
        }
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error;
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> authenticateExisting(String atSign) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Initialize the AtTalkService with the existing atSign
      await AtTalkService.instance.onboard(
        atSign: atSign,
        onResult: (success) {
          _isAuthenticated = success;
          if (success) {
            _currentAtSign = atSign;
            _errorMessage = null;
          }
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = error;
          _isAuthenticated = false;
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _isAuthenticated = false;
    _currentAtSign = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
