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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Force AtClient reinitialization to ensure clean state for re-authentication
      // This ensures Hive boxes are properly closed and reopened for fresh message fetching
      print('🔄 Forcing AtClient reinitialization for re-authentication...');
      await AtTalkService.forceAtClientReinitialization();

      // Configure atSign-specific storage before authentication
      // For namespace changes, cleanup is already handled by changeNamespace()
      print('🔧 Configuring atSign-specific storage for existing atSign: $atSign (cleanup: $cleanupExisting)');
      if (rootDomain != null) {
        print('🌐 Using custom rootDomain: $rootDomain');
      }
      await AtTalkService.configureAtSignStorage(atSign, cleanupExisting: cleanupExisting, rootDomain: rootDomain);

      // Initialize the AtTalkService with the existing atSign
      // This will create a fresh AtClient that can fetch missed messages
      await AtTalkService.instance.onboard(
        atSign: atSign,
        onResult: (success) {
          _isAuthenticated = success;
          if (success) {
            _currentAtSign = atSign;
            _errorMessage = null;
            print('✅ Re-authentication successful - AtClient recreated for fresh message sync');
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
      _errorMessage = 'Failed to configure storage or authenticate: ${e.toString()}';
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    print('🔓 Starting logout process...');
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Clean up AtTalkService resources (this handles AtClient cleanup and storage locks)
      if (AtTalkService.instance.isInitialized) {
        print('  🧹 Cleaning up AtTalkService resources...');
        await AtTalkService.instance.cleanup();
      }

      // 2. Clean up AtClient databases more gracefully
      // Instead of closing all Hive, let AtClient handle its own cleanup
      // This prevents issues when re-authenticating with the same atSign
      try {
        print('  📦 Allowing AtClient to handle database cleanup...');
        // AtClient cleanup should handle Hive box management internally
        // We don't need to forcefully close all Hive databases
        print('  ✅ Database cleanup handled by AtClient');
      } catch (e) {
        print('  ⚠️ Error during database cleanup: $e');
      }

      // 3. Reset authentication state
      _isAuthenticated = false;
      _currentAtSign = null;
      _errorMessage = null;

      print('✅ Logout completed successfully');
    } catch (e) {
      print('⚠️ Error during logout: $e');
      _errorMessage = 'Logout error: ${e.toString()}';

      // Still clear authentication state even if cleanup fails
      _isAuthenticated = false;
      _currentAtSign = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
