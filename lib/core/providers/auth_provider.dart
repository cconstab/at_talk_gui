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

  Future<void> authenticate(String? atSign, {String? rootDomain}) async {
    print('🎯 [AUTH_METHOD_1] authenticate() called with atSign: $atSign, rootDomain: $rootDomain');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Configure atSign-specific storage before authentication
      // KEYCHAIN PRESERVATION FIX: Don't clean up existing AtClient to preserve other atSigns
      print('🔧 Configuring atSign-specific storage for: $atSign');
      if (rootDomain != null) {
        print('🌐 Using custom rootDomain: $rootDomain');
      }
      await AtTalkService.configureAtSignStorage(atSign!, cleanupExisting: false, rootDomain: rootDomain);

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
      _errorMessage = 'Failed to configure storage: ${e.toString()}';
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> authenticateExisting(String atSign, {bool cleanupExisting = true, String? rootDomain}) async {
    print('🎯 [AUTH_METHOD_2] authenticateExisting() called with atSign: $atSign, cleanupExisting: $cleanupExisting, rootDomain: $rootDomain');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if we need full onboarding BEFORE calling configureAtSignStorage
      // (because configureAtSignStorage will reset the state)
      bool needsFullOnboarding = false;
      final currentAtSign = AtTalkService.instance.currentAtSign;
      final currentDomain = AtTalkService.instance.atClientPreference?.rootDomain ?? 'root.atsign.org';
      final newDomain = rootDomain ?? 'root.atsign.org';
      
      if (currentAtSign != null && currentAtSign != atSign) {
        needsFullOnboarding = true;
        print('🔄 Full onboarding required: switching atSigns ($currentAtSign → $atSign)');
      } else if (currentDomain != newDomain) {
        needsFullOnboarding = true;
        print('🔄 Full onboarding required: switching domains ($currentDomain → $newDomain)');
      }
      
      // Force full onboarding for custom domains to ensure AtLookup service reset
      if (rootDomain != null && rootDomain != 'root.atsign.org') {
        needsFullOnboarding = true;
        print('🔄 Full onboarding forced: custom domain detected ($newDomain)');
      }

      // Configure atSign-specific storage before authentication
      // For namespace changes, cleanup is already handled by changeNamespace()
      print('🔧 Configuring atSign-specific storage for existing atSign: $atSign (cleanup: $cleanupExisting)');
      if (rootDomain != null) {
        print('🌐 Using custom rootDomain: $rootDomain');
      }
      print('🔍 Pre-configure state: needsFullOnboarding=$needsFullOnboarding, currentAtSign=$currentAtSign, currentDomain=$currentDomain, newDomain=$newDomain');
      await AtTalkService.configureAtSignStorage(atSign, cleanupExisting: cleanupExisting, rootDomain: rootDomain);

      print('🔍 Post-configure state: needsFullOnboarding=$needsFullOnboarding');
      if (needsFullOnboarding) {
        print('🚀 Using full onboarding service to reset AtLookup and all internal components...');
        // Use full onboarding service like the TUI to properly reset everything
        await AtTalkService.instance.onboardWithFullService(
          atSign: atSign,
          rootDomain: rootDomain,
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
      } else {
        print('🔧 Using regular authentication (no domain/atSign switch detected)');
        // Use regular authentication for same atSign and domain
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
    } catch (e) {
      _errorMessage = 'Failed to configure storage or authenticate: ${e.toString()}';
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
