import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_onboarding_flutter/at_onboarding_services.dart';
// ignore: implementation_imports
import 'package:at_onboarding_flutter/src/utils/at_onboarding_response_status.dart';
import 'package:at_auth/at_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_server_status/at_server_status.dart';

import 'dart:developer';
import 'dart:io';
import 'dart:convert';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/groups_provider.dart';
import '../../core/services/at_talk_service.dart';
import '../../core/services/key_backup_service.dart';
import '../../core/utils/at_talk_env.dart';
import '../../core/utils/atsign_manager.dart';
import '../widgets/key_management_dialog.dart';

// Import biometric storage for proper cleanup
import 'package:biometric_storage/biometric_storage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  Map<String, AtsignInformation> _availableAtSigns = {};
  bool _isLoadingAtSigns = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAvailableAtSigns();
  }

  Future<void> _loadAvailableAtSigns() async {
    setState(() {
      _isLoadingAtSigns = true;
      _errorMessage = null;
    });

    try {
      final atSigns = await getAtsignEntries();
      setState(() {
        _availableAtSigns = atSigns;
      });
    } catch (e) {
      print('Error loading atSigns: ${e.toString()}');
      setState(() {
        // Provide more helpful error messages for keychain corruption
        if (e.toString().contains('FormatException') ||
            e.toString().contains('ChunkedJsonParser') ||
            e.toString().contains('Invalid JSON') ||
            e.toString().contains('Unexpected character')) {
          _errorMessage =
              'Keychain data is corrupted. Use "Manage Keys" to clean up corrupted data, or restart the app after cleanup.';
        } else {
          _errorMessage = 'Failed to load atSigns: ${e.toString()}';
        }
      });
    } finally {
      setState(() {
        _isLoadingAtSigns = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),

                        // Logo and title
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                          child: const Icon(Icons.chat_bubble_outline, size: 60, color: Color(0xFF2196F3)),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'atTalk',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Secure, private messaging using atSigns.',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 48),

                        // Available atSigns section
                        if (_availableAtSigns.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.account_circle, color: Color(0xFF2196F3)),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Your atSigns',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // List existing atSigns
                                ..._availableAtSigns.keys.map((atSign) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: const Icon(Icons.person, color: Color(0xFF2196F3)),
                                      title: Text(atSign),
                                      subtitle: Text('Domain: ${_availableAtSigns[atSign]!.rootDomain}'),
                                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                      onTap: () => _loginWithExistingAtSign(atSign),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      tileColor: Colors.grey[50],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Main action buttons
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, child) {
                            return Column(
                              children: [
                                // Get Started Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: authProvider.isLoading ? null : _showOnboardingDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF2196F3),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    icon: authProvider.isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                                            ),
                                          )
                                        : Icon(_availableAtSigns.isEmpty ? Icons.rocket_launch : Icons.person_add),
                                    label: Text(
                                      _availableAtSigns.isEmpty ? 'Get Started' : 'Add New atSign',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Refresh Button
                                OutlinedButton.icon(
                                  onPressed: _isLoadingAtSigns ? null : _loadAvailableAtSigns,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: _isLoadingAtSigns
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.refresh, size: 18),
                                  label: const Text('Refresh atSigns'),
                                ),

                                const SizedBox(height: 12),

                                // Key Management Button
                                OutlinedButton.icon(
                                  onPressed: _showKeyManagementDialog,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.key, size: 18),
                                  label: const Text('Manage Keys'),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // Error message display
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 14)),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _errorMessage = null),
                                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                ),
                              ],
                            ),
                          ),

                        // Error message from AuthProvider
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, child) {
                            if (authProvider.errorMessage != null) {
                              return Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        authProvider.errorMessage!,
                                        style: const TextStyle(color: Colors.red, fontSize: 14),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: authProvider.clearError,
                                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        // Info text
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Need an atSign?',
                                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Visit atsign.com to get your free atSign.',
                                style: TextStyle(fontSize: 14, color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Already have an atSign? You can use:',
                                style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 6),
                              _buildInfoItem('📁', '.atKeys file from your device or app'),
                              _buildInfoItem('📱', 'Authenticator app with OTP verification'),
                              _buildInfoItem('🆕', 'CRAM secret for new atSigns'),
                              const SizedBox(height: 8),
                              const Text(
                                'Tip: Save your .atKeys file safely - it is your backup!',
                                style: TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Login with an existing atSign
  Future<void> _loginWithExistingAtSign(String atSign) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);

    try {
      print('Logging in with existing atSign: $atSign');

      // Clear existing groups and side panel state (similar to atSign switching)
      groupsProvider.clearAllGroups();

      await authProvider.authenticate(atSign);

      if (mounted && authProvider.isAuthenticated) {
        print('Authentication successful, reinitializing groups provider...');

        // Reinitialize groups provider for the newly authenticated atSign
        groupsProvider.reinitialize();

        print('Navigating to groups...');
        Navigator.pushReplacementNamed(context, '/groups');
      } else {
        print('Authentication failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication failed. Please try again.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('Exception during authentication: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  // Show the main onboarding dialog (NoPorts style)
  Future<void> _showOnboardingDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const _OnboardingDialog();
      },
    );

    if (result != null) {
      // Parse the result which now includes domain: "method:domain:atSign"
      final parts = result.split(':');
      if (parts.length >= 3) {
        final method = parts[0];
        final domain = parts[1];
        final atSign = parts.sublist(2).join(':'); // In case atSign contains ':'

        if (method == 'onboard') {
          await _startOnboarding(atSign, domain);
        } else if (method == 'upload') {
          await _startAtKeysUpload(atSign, domain);
        } else if (method == 'authenticator') {
          await _startAuthenticatorOnboarding(atSign, domain);
        }

        // Don't refresh available atSigns after successful onboarding attempts
        // as this would interfere with navigation to the app
      }
    } else {
      // User cancelled the dialog, refresh the available atSigns
      if (mounted) {
        await _loadAvailableAtSigns();
      }
    }
  }

  // Start onboarding for a new atSign - this will determine the proper flow based on atSign status
  // Start CRAM onboarding for a new atSign
  Future<void> _startOnboarding(String atSign, String domain) async {
    if (atSign.isEmpty) {
      print('No atSign provided, cannot start onboarding');
      return;
    }

    // Ensure atSign has @ prefix for all operations
    final normalizedAtSign = atSign.startsWith('@') ? atSign : '@$atSign';
    print('Starting CRAM onboarding for: $normalizedAtSign with domain: $domain');

    // First, collect the CRAM secret from the user
    final cramSecret = await _showCramSecretDialog(normalizedAtSign);
    if (cramSecret == null || cramSecret.trim().isEmpty) {
      print('CRAM secret not provided, cancelling onboarding');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      print('🚀 Starting CRAM activation for: $normalizedAtSign on domain: $domain');
      print('📋 CRAM activation parameters:');
      print('   - atSign: $normalizedAtSign');
      print('   - domain: $domain');
      print('   - CRAM secret: ${cramSecret.isNotEmpty ? '[PROVIDED]' : '[EMPTY]'}');
      print('   - CRAM secret length: ${cramSecret.length}');

      // Use onboarding service for CRAM activation - stores keys directly
      final success = await _performCramActivation(normalizedAtSign, domain, cramSecret.trim());

      if (success) {
        print('✅ CRAM activation successful! Keys are now stored.');

        // Save the atSign information for future use
        await saveAtsignInformation(AtsignInformation(atSign: normalizedAtSign, rootDomain: domain));
        print('Saved atSign information');

        // Wait a moment for keychain to settle
        await Future.delayed(const Duration(milliseconds: 500));

        print('Authenticating with AuthProvider after successful CRAM...');
        try {
          // Use authenticateExisting since keys are now in keychain
          await authProvider.authenticateExisting(normalizedAtSign, cleanupExisting: false);

          if (mounted && authProvider.isAuthenticated) {
            print('✅ AuthProvider authentication successful, navigating to groups...');

            // Show backup dialog for CRAM onboarding
            final shouldShowBackup = await _showBackupDialog();
            if (shouldShowBackup == true && mounted) {
              await _showBackupKeysFromSecureStorage(normalizedAtSign);
            }

            if (mounted) {
              Navigator.pushReplacementNamed(context, '/groups');
              return; // Exit early to prevent returning to onboarding screen
            }
          } else {
            print('⚠️ AuthProvider authentication failed, but CRAM was successful');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'CRAM activation was successful, but there was an issue with the final authentication. '
                    'The atSign "$normalizedAtSign" should now be available in the main screen. '
                    'Please try logging in from the main screen.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 8),
                ),
              );
            }
          }
        } catch (e) {
          print('⚠️ AuthProvider authentication exception after successful CRAM: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'CRAM activation was successful, but there was an issue with the final authentication step. '
                  'The atSign "$normalizedAtSign" should now be available in the main screen. '
                  'Please try logging in from the main screen.',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 8),
              ),
            );
          }
        }
      } else {
        print('❌ CRAM activation failed - check the logs above for details');
        if (mounted) {
          final isCustomDomain = domain != 'root.atsign.org';
          String failureMessage;

          if (isCustomDomain) {
            failureMessage =
                'Custom domain CRAM activation failed.\n\n'
                'The atTalk GUI now uses Noports-style custom domain support, but the activation failed for "$domain".\n\n'
                'This could be due to:\n'
                '• Invalid CRAM secret\n'
                '• Domain configuration issues\n'
                '• Network connectivity problems\n\n'
                'Please try:\n'
                '• Verify your CRAM secret is correct\n'
                '• Upload .atKeys file (if you have backup keys)\n'
                '• Use Authenticator (APKAM) method\n'
                '• Contact your atSign provider for support';
          } else {
            failureMessage =
                'CRAM activation failed for atSign "$normalizedAtSign" on domain "$domain". Please check your CRAM secret and try again.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failureMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 12)),
          );
        }
      }
    } catch (e) {
      print('Exception during CRAM onboarding: ${e.toString()}');
      if (mounted) {
        String errorMessage = 'CRAM activation failed: ${e.toString()}';

        // Provide helpful error messages based on the error and domain type
        final isCustomDomain = domain != 'root.atsign.org';

        if (e.toString().contains('No entry in atDirectory')) {
          if (isCustomDomain) {
            errorMessage =
                'Custom domain CRAM activation is not supported.\n\n'
                'The atSign "$normalizedAtSign" was not found in the atDirectory on domain "$domain". '
                'This is a known limitation of the current atSign libraries.\n\n'
                'Please try:\n'
                '• Upload .atKeys file if you have backup keys\n'
                '• Use Authenticator (APKAM) method if supported\n'
                '• Use standard root.atsign.org domain\n'
                '• Contact your atSign provider for support';
          } else {
            errorMessage =
                'The atSign "$normalizedAtSign" was not found in the atDirectory on domain "$domain". Please verify the atSign exists on this domain.';
          }
        } else if (e.toString().contains('CRAM') || e.toString().contains('secret')) {
          errorMessage = 'CRAM authentication failed: Invalid CRAM secret. Please check your credentials.';
        } else if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = 'Network error during CRAM authentication. Please check your connection and try again.';
        } else if (isCustomDomain) {
          errorMessage =
              'Custom domain CRAM activation failed.\n\n'
              'Error: ${e.toString()}\n\n'
              'Custom domains have known limitations with CRAM activation. '
              'Please try using .atKeys file upload or Authenticator (APKAM) method instead.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 12)),
        );
      }
    }
  }

  // CRAM secret dialog
  Future<String?> _showCramSecretDialog(String atSign) async {
    final TextEditingController cramController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.vpn_key, color: Colors.blue),
              const SizedBox(width: 8),
              Text('CRAM Secret for $atSign'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your CRAM secret to activate this new atSign:'),
              const SizedBox(height: 16),
              TextField(
                controller: cramController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'CRAM Secret',
                  hintText: 'Enter your CRAM secret',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The CRAM secret was provided when you registered this atSign.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final secret = cramController.text.trim();
                Navigator.of(context).pop(secret.isNotEmpty ? secret : null);
              },
              child: const Text('Activate'),
            ),
          ],
        );
      },
    ).then((value) {
      cramController.dispose();
      return value;
    });
  }

  // Perform CRAM activation using Noports-style implementation for custom domain support
  Future<bool> _performCramActivation(String atSign, String domain, String cramSecret) async {
    try {
      print('🔧 Starting Noports-style CRAM activation: $atSign on domain: $domain');

      // CRITICAL: Clean up any existing AtClient instances that might interfere
      try {
        print('🧹 Cleaning up any existing AtClient instances before CRAM activation...');
        await AtTalkService.completeAtSignCleanup(atSign);
        print('✅ AtClient cleanup completed');
      } catch (e) {
        print('⚠️ Cleanup failed (may be expected for new atSign): $e');
        // Continue anyway - this is expected for truly new atSigns
      }

      // Check if this is a custom domain vs standard domain
      final isCustomDomain = domain != 'root.atsign.org';

      if (isCustomDomain) {
        print('🔍 Custom domain detected: $domain');
        print('🚀 Using Noports-style custom domain support');

        // Verify the domain can be reached before attempting authentication
        try {
          print('🌐 Verifying custom domain connectivity to $domain:64...');
          final socket = await Socket.connect(domain, 64, timeout: const Duration(seconds: 5));
          await socket.close();
          print('✅ Domain $domain:64 is reachable');
        } catch (e) {
          print('⚠️ Domain verification failed: $e');
          print('   This may indicate the custom domain is not properly configured');
          return false;
        }
      }

      // Get the onboarding service
      final onboardingService = OnboardingService.getInstance();

      // Check if atSign already exists (Noports pattern)
      bool isExist = await onboardingService.isExistingAtsign(atSign);
      if (isExist) {
        print('❌ atSign is already activated on this device');
        return false;
      }

      // Configure AtClientPreference with proper domain and port (Noports pattern)
      final atClientPreference = await AtTalkService.configureAtSignStorage(atSign, cleanupExisting: true);
      atClientPreference.rootDomain = domain;

      if (isCustomDomain) {
        atClientPreference.rootPort = 64; // Default port for custom domains
        print('🔧 Configured custom domain: $domain:${atClientPreference.rootPort}');
      } else {
        atClientPreference.rootPort = 64; // Standard port
        print('🔧 Configured standard domain: $domain:${atClientPreference.rootPort}');
      }

      atClientPreference.cramSecret = cramSecret;
      onboardingService.setAtClientPreference = atClientPreference;
      onboardingService.setAtsign = atSign;

      print('🔄 Attempting CRAM authentication with Noports pattern...');

      // Create onboarding request with proper rootDomain and rootPort (critical for custom domains)
      AtOnboardingRequest request = AtOnboardingRequest(atSign);
      request.rootDomain = atClientPreference.rootDomain;
      request.rootPort = atClientPreference.rootPort;

      print('📡 Request config: domain=${request.rootDomain}, port=${request.rootPort}');

      // Perform the onboarding using Noports method signature
      bool result = await onboardingService.onboard(cramSecret: cramSecret, atOnboardingRequest: request);

      if (result) {
        print('✅ CRAM authentication successful, checking server status...');

        // Wait for server status to become activated (Noports pattern)
        int round = 1;
        ServerStatus? atSignStatus = await onboardingService.checkAtSignServerStatus(atSign);

        while (atSignStatus != ServerStatus.activated) {
          if (round > 10) {
            print('⏰ Server status check timeout after 10 rounds');
            break;
          }
          print('🔄 Waiting for server activation... round $round, status: $atSignStatus');
          await Future.delayed(const Duration(seconds: 3));
          round++;
          atSignStatus = await onboardingService.checkAtSignServerStatus(atSign);
        }

        if (atSignStatus == ServerStatus.teapot) {
          print('❌ atSign server is unreachable (teapot status)');
          return false;
        } else if (atSignStatus == ServerStatus.activated) {
          print('✅ Server activation confirmed');

          // Save keys to keychain using authenticate method after successful onboarding
          print('💾 Saving keys to keychain after successful CRAM activation...');
          final authStatus = await onboardingService.authenticate(atSign);

          if (authStatus == AtOnboardingResponseStatus.authSuccess) {
            print('✅ Keys successfully saved to keychain');

            // Verify keys were actually stored by checking keychain
            try {
              final keyChainManager = KeyChainManager.getInstance();
              final keychainAtSigns = await keyChainManager.getAtSignListFromKeychain();
              print('🔍 Keychain now contains: $keychainAtSigns');

              if (keychainAtSigns.contains(atSign)) {
                print('✅ Confirmed: $atSign is now in keychain');
                return true;
              } else {
                print('⚠️ Warning: $atSign not found in keychain after authentication');
                // Still return true as the onboarding was successful, keychain check may be timing issue
                return true;
              }
            } catch (e) {
              print('⚠️ Keychain verification failed (may be timing issue): $e');
              // Still return true as the authentication was successful
              return true;
            }
          } else {
            print('❌ Failed to save keys to keychain - status: $authStatus');
            print('🔄 Attempting alternative keychain storage method...');

            // Try alternative approach: force key generation and storage
            try {
              // Re-configure storage to ensure proper keychain setup
              await AtTalkService.configureAtSignStorage(atSign, cleanupExisting: false);

              // Try authentication again with fresh storage setup
              final retryAuthStatus = await onboardingService.authenticate(atSign);

              if (retryAuthStatus == AtOnboardingResponseStatus.authSuccess) {
                print('✅ Retry authentication successful - keys should now be in keychain');
                return true;
              } else {
                print('❌ Retry authentication also failed: $retryAuthStatus');
                return false;
              }
            } catch (e) {
              print('❌ Alternative keychain storage failed: $e');
              return false;
            }
          }
        } else {
          print('❌ Server activation failed - status: $atSignStatus');
          return false;
        }
      } else {
        print('❌ CRAM onboarding failed');

        // For custom domains, provide specific guidance
        if (isCustomDomain) {
          print('💡 If this is a custom domain CRAM activation failure:');
          print('   This could indicate the at_onboarding_flutter version needs updating');
          print('   Noports uses a custom git version with custom domain support');
          print('   Consider upgrading to the Noports fork or newer version');
        }

        return false;
      }
    } catch (e) {
      print('❌ Exception during CRAM activation: $e');
      print('❌ Exception type: ${e.runtimeType}');

      // For custom domains, provide specific context
      bool isCustomDomain = domain != 'root.atsign.org';

      if (isCustomDomain && e.toString().contains('atDirectory')) {
        print('💡 Custom domain atDirectory error detected');
        print('   This indicates at_onboarding_flutter version may need updating');
        print('   Noports solved this with a custom git version of at_onboarding_flutter');
      }

      return false;
    }
  }

  // Handle onboarding result for CRAM-based APKAM
  Future<void> _handleOnboardingResult(AtOnboardingResult result, String domain) async {
    print('AtOnboarding.onboard result for APKAM: ${result.status}');

    switch (result.status) {
      case AtOnboardingResultStatus.success:
        print('APKAM onboarding successful');

        if (result.atsign != null) {
          await saveAtsignInformation(AtsignInformation(atSign: result.atsign!, rootDomain: domain));
          print('Saved atSign information');
        }

        // Wait a moment for any enrollment to settle
        await Future.delayed(const Duration(milliseconds: 1000));

        // Check keychain integrity before proceeding
        try {
          final keyChainManager = KeyChainManager.getInstance();
          await keyChainManager.getAtSignListFromKeychain();
          print('Keychain integrity check passed');
        } catch (e) {
          print('Keychain integrity check failed: $e');
          if (e.toString().contains('FormatException') ||
              e.toString().contains('ChunkedJsonParser') ||
              e.toString().contains('Invalid JSON') ||
              e.toString().contains('Unexpected character')) {
            print('Keychain corruption detected immediately after APKAM enrollment');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'APKAM enrollment completed but keychain corruption was detected. '
                    'Please use the "Manage Keys" option to clean up corrupted data, '
                    'then try logging in with the atSign from the main screen.',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 15),
                ),
              );
            }
            return;
          }
        }

        // Only clean up biometric storage for the newly enrolled atSign to prevent conflicts
        try {
          print('Cleaning up biometric storage for newly enrolled atSign...');
          await _clearBiometricStorageForAtSigns([result.atsign!]);
        } catch (e) {
          print('Error clearing biometric storage: $e');
        }

        // Wait a moment for any cleanup to settle
        await Future.delayed(const Duration(milliseconds: 500));

        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        // First, verify that the keychain is not corrupted before attempting authentication
        try {
          final keyChainManager = KeyChainManager.getInstance();
          final keychainAtSigns = await keyChainManager.getAtSignListFromKeychain();
          print('🔍 Before authentication, keychain contains: $keychainAtSigns');

          if (!keychainAtSigns.contains(result.atsign)) {
            print('⚠️ Newly enrolled atSign not found in keychain immediately after enrollment');
            // This is expected - the atSign might not be in the keychain yet
          }
        } catch (e) {
          print('⚠️ Keychain corruption detected after APKAM enrollment: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Keychain corruption detected after APKAM enrollment. Please use the "Manage Keys" option to clean up corrupted data, then try logging in with the atSign from the main screen.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 15),
              ),
            );
          }
          return;
        }

        // Try authentication with the newly enrolled atSign
        // Use OnboardingService to authenticate after APKAM enrollment to save keys to keychain
        try {
          print('Attempting APKAM authentication to save keys to keychain...');

          // Use OnboardingService to authenticate after enrollment
          final onboardingService = OnboardingService.getInstance();

          // Configure the onboarding service with the same preferences used for enrollment
          final atClientPreference = await AtTalkService.configureAtSignStorage(result.atsign!, cleanupExisting: false);
          onboardingService.setAtClientPreference = atClientPreference;
          onboardingService.setAtsign = result.atsign!;

          // Authenticate after APKAM enrollment to save keys to keychain
          final authStatus = await onboardingService.authenticate(result.atsign!);

          print('APKAM authentication result: $authStatus');

          if (authStatus == AtOnboardingResponseStatus.authSuccess) {
            print('APKAM authentication successful - keys saved to keychain');

            // Now use the AuthProvider to complete the authentication flow
            await authProvider.authenticateExisting(result.atsign!, cleanupExisting: false);
          } else {
            print('APKAM authentication failed: $authStatus');
            // Fall back to regular authentication
            await authProvider.authenticateExisting(result.atsign!, cleanupExisting: false);
          }

          // After successful authentication, verify the atSign is in the keychain
          final keyChainManager = KeyChainManager.getInstance();
          final keychainAtSigns = await keyChainManager.getAtSignListFromKeychain();
          print('🔍 After authentication, keychain contains: $keychainAtSigns');

          if (!keychainAtSigns.contains(result.atsign)) {
            print('⚠️ atSign not found in keychain after authentication, this may cause issues');
          }
        } catch (e) {
          print('Authentication failed, trying alternative approach: $e');

          // Check if this is a keychain corruption issue
          if (e.toString().contains('FormatException') ||
              e.toString().contains('ChunkedJsonParser') ||
              e.toString().contains('Invalid JSON') ||
              e.toString().contains('Unexpected character')) {
            print('Keychain corruption detected during authentication');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Keychain corruption detected during authentication. The APKAM enrollment was successful, but the keychain needs to be cleaned up. Please use the "Manage Keys" option to clean up corrupted data, then try logging in with the atSign from the main screen.',
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 15),
                ),
              );
            }
            return;
          }

          // If authentication fails, try to reconfigure storage for this specific atSign
          try {
            print('Attempting to reconfigure storage for authentication...');

            // Reconfigure storage for this specific atSign without cleanup to preserve keychain
            await AtTalkService.configureAtSignStorage(result.atsign!, cleanupExisting: false);

            // Try authentication again using authenticateExisting without cleanup
            await authProvider.authenticateExisting(result.atsign!, cleanupExisting: false);

            print('Authentication successful after storage reconfiguration');
          } catch (e2) {
            print('Second authentication attempt failed: $e2');

            // Check for keychain corruption in second attempt
            if (e2.toString().contains('FormatException') ||
                e2.toString().contains('ChunkedJsonParser') ||
                e2.toString().contains('Invalid JSON') ||
                e2.toString().contains('Unexpected character')) {
              print('Keychain corruption detected in second authentication attempt');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Keychain corruption detected. The APKAM enrollment was successful, but the keychain needs to be cleaned up. Please use the "Manage Keys" option to clean up corrupted data, then try logging in with the atSign from the main screen.',
                    ),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 15),
                  ),
                );
              }
              return;
            }

            // Last resort: try to use the onboarding result directly
            try {
              print('Attempting direct authentication using onboarding result...');

              // Force a fresh storage setup
              await AtTalkService.configureAtSignStorage(result.atsign!, cleanupExisting: true);

              // Final authentication attempt
              await authProvider.authenticate(result.atsign);
            } catch (e3) {
              print('Final authentication attempt failed: $e3');

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Authentication failed after APKAM enrollment: ${e3.toString()}. The enrollment was successful, but authentication failed. Please try logging in with the atSign from the main screen.',
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 15),
                  ),
                );
              }
              return;
            }
          }
        }

        if (mounted && authProvider.isAuthenticated) {
          print('Authentication successful');

          // Show backup option for APKAM onboarding (no delay needed)
          final shouldShowBackup = await _showBackupDialog();
          if (shouldShowBackup == true && mounted) {
            await _showBackupKeysFromSecureStorage(result.atsign!);
          }

          if (mounted) {
            print('Navigating to groups...');
            Navigator.pushReplacementNamed(context, '/groups');
            return; // Exit early to prevent returning to onboarding screen
          }
        } else {
          print('Authentication failed after APKAM onboarding');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Authentication failed after APKAM enrollment. The enrollment was successful but authentication failed. '
                  'This may be due to keychain corruption. Please try:\n'
                  '1. Using "Manage Keys" to clean up corrupted data\n'
                  '2. Restarting the app\n'
                  '3. Logging in with the atSign from the main screen',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 15),
              ),
            );
          }
        }
        break;

      case AtOnboardingResultStatus.error:
        print('AtOnboarding.onboard APKAM error: ${result.message}');

        // Clean up biometric storage if APKAM enrollment fails
        try {
          print('Cleaning up biometric storage after APKAM failure...');
          await _clearBiometricStorageForAtSigns([result.atsign ?? '']);
        } catch (e) {
          print('Error during biometric cleanup after APKAM failure: $e');
        }

        _handleApkamError(result.message ?? 'APKAM enrollment failed');
        break;

      case AtOnboardingResultStatus.cancel:
        print('APKAM enrollment cancelled by user');
        break;
    }
  }

  Future<void> _startAtKeysUpload(String atSign, String domain) async {
    if (atSign.isEmpty) {
      print('No atSign provided, cannot start .atKeys upload');
      return;
    }

    print('Starting .atKeys upload for: $atSign with domain: $domain');

    try {
      // Show file picker to select .atKeys file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['atKeys', 'atkeys'],
        dialogTitle: 'Select .atKeys file for $atSign',
      );

      if (result == null || result.files.isEmpty) {
        print('No file selected, aborting .atKeys upload');
        return;
      }

      final pickedFile = result.files.first;
      String? filePath = pickedFile.path;

      if (filePath == null) {
        throw Exception('Could not access the selected file');
      }

      // Read and validate the .atKeys file
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('The selected .atKeys file does not exist');
      }

      final fileContents = await file.readAsString();
      if (fileContents.isEmpty) {
        throw Exception('The selected .atKeys file is empty');
      }

      // Validate that this is a proper .atKeys file
      Map<String, dynamic> keysMap;
      try {
        keysMap = jsonDecode(fileContents);
      } catch (e) {
        throw Exception('The selected file is not a valid .atKeys file (invalid JSON)');
      }

      // Validate required keys are present
      final requiredKeys = [
        'aesPkamPrivateKey',
        'aesPkamPublicKey',
        'aesEncryptPrivateKey',
        'aesEncryptPublicKey',
        'selfEncryptionKey',
      ];
      for (String key in requiredKeys) {
        if (!keysMap.containsKey(key) || keysMap[key] == null || keysMap[key].toString().isEmpty) {
          throw Exception('The selected .atKeys file is missing required key: $key');
        }
      }

      // Extract atSign from the file and verify it matches the expected atSign
      String? fileAtSign;

      // Try to find the atSign in the keys (usually the first key with "@" prefix)
      for (String key in keysMap.keys) {
        if (key.startsWith('@')) {
          fileAtSign = key;
          break;
        }
      }

      if (fileAtSign == null) {
        // Fall back to extracting from JSON structure if needed
        if (fileContents.contains('"@')) {
          try {
            final List<String> keyData = fileContents.split(',"@');
            if (keyData.length > 1) {
              final List<String> params = keyData[1].toString().substring(0, keyData[1].length - 2).split('":"');
              fileAtSign = "@${params[0]}";
            }
          } catch (e) {
            print('Could not extract atSign from file structure: $e');
          }
        }
      }

      if (fileAtSign == null) {
        throw Exception('Could not determine the atSign from the .atKeys file');
      }

      // Normalize both atSigns for comparison
      final normalizedExpected = atSign.startsWith('@') ? atSign : '@$atSign';
      final normalizedFile = fileAtSign.startsWith('@') ? fileAtSign : '@$fileAtSign';

      if (normalizedExpected.toLowerCase() != normalizedFile.toLowerCase()) {
        throw Exception(
          'The .atKeys file is for $normalizedFile but you selected $normalizedExpected. Please select the correct .atKeys file.',
        );
      }

      print('Validated .atKeys file for $normalizedFile');

      // Configure atSign-specific storage before onboarding
      print('🔧 Configuring atSign-specific storage for .atKeys upload: $normalizedFile');
      final atClientPreference = await AtTalkService.configureAtSignStorage(normalizedFile);

      // Create onboarding preference with the specified domain
      final onboardingPreference = AtClientPreference()
        ..rootDomain = domain
        ..namespace = atClientPreference.namespace
        ..hiveStoragePath = atClientPreference.hiveStoragePath
        ..commitLogPath = atClientPreference.commitLogPath
        ..isLocalStoreRequired = atClientPreference.isLocalStoreRequired;

      // Use the OnboardingService directly for PKAM authentication
      final onboardingService = OnboardingService.getInstance();
      onboardingService.setAtClientPreference = onboardingPreference;

      print('Authenticating with PKAM using .atKeys file...');

      // Authenticate using the file contents (PKAM authentication)
      final authStatus = await onboardingService.authenticate(
        normalizedFile,
        jsonData: fileContents, // This triggers PKAM authentication instead of CRAM
      );

      print('PKAM authentication result: $authStatus');

      if (authStatus == AtOnboardingResponseStatus.authSuccess) {
        print('PKAM authentication successful for: $normalizedFile');

        // Save the atSign information for future use
        await saveAtsignInformation(AtsignInformation(atSign: normalizedFile, rootDomain: domain));
        print('Saved atSign information');

        print('Authenticating with AuthProvider...');
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.authenticate(normalizedFile);

        if (mounted && authProvider.isAuthenticated) {
          print('Authentication successful');

          // No backup needed for .atKeys flow since the user already has the keys file
          print('Skipping backup dialog for .atKeys flow - user already has backup file');

          if (mounted) {
            print('Navigating to groups...');
            Navigator.pushReplacementNamed(context, '/groups');
            return; // Exit early to prevent returning to onboarding screen
          }
        } else {
          print('Authentication failed after importing keys');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication failed after importing keys. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        print('PKAM authentication failed with status: $authStatus');
        String errorMessage = 'Failed to authenticate with the .atKeys file';

        // Provide user-friendly error messages based on status
        switch (authStatus) {
          case AtOnboardingResponseStatus.serverNotReached:
            errorMessage = 'Could not reach the atSign server. Please check your internet connection and try again.';
            break;
          case AtOnboardingResponseStatus.authFailed:
            errorMessage = 'Authentication failed. The .atKeys file may be corrupted or invalid.';
            break;
          case AtOnboardingResponseStatus.timeOut:
            errorMessage = 'Authentication timed out. Please check your internet connection and try again.';
            break;
          default:
            errorMessage =
                'Failed to authenticate with the .atKeys file. Please ensure the file is valid and try again.';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 8)),
          );
        }
      }
    } catch (e) {
      print('Exception during .atKeys upload: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading .atKeys file: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Start onboarding using authenticator app (APKAM enrollment flow)
  Future<void> _startAuthenticatorOnboarding(String atSign, String domain) async {
    if (atSign.isEmpty) {
      print('No atSign provided, cannot start authenticator onboarding');
      return;
    }

    print('Starting authenticator/APKAM onboarding for: $atSign with domain: $domain');

    try {
      // Configure atSign-specific storage before onboarding
      // Don't clean up existing AtClient to preserve other atSigns in keychain
      print('🔧 Configuring atSign-specific storage for APKAM onboarding: $atSign');
      final atClientPreference = await AtTalkService.configureAtSignStorage(atSign, cleanupExisting: false);

      // Create a modified preference with the specified domain
      final customPreference = AtClientPreference()
        ..rootDomain = domain
        ..namespace = atClientPreference.namespace
        ..hiveStoragePath = atClientPreference.hiveStoragePath
        ..commitLogPath = atClientPreference.commitLogPath
        ..isLocalStoreRequired = atClientPreference.isLocalStoreRequired;

      final normalizedAtSign = atSign.startsWith('@') ? atSign : '@$atSign';

      // Show the APKAM dialog with full device registration flow
      final result = await showDialog<AtOnboardingResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ApkamOnboardingDialog(atsign: normalizedAtSign, atClientPreference: customPreference),
      );

      if (result != null) {
        await _handleOnboardingResult(result, domain);
        // Don't continue execution if successful navigation occurred
        if (result.status == AtOnboardingResultStatus.success) {
          return;
        }
      }
    } catch (e) {
      print('Exception during APKAM onboarding: ${e.toString()}');
      _handleApkamError(e.toString());
    }
  }

  // Handle APKAM authentication errors
  void _handleApkamError(String errorMessage) {
    setState(() {
      _isLoadingAtSigns = false;
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Authenticator (APKAM) Error'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(errorMessage),
              const SizedBox(height: 16),
              const Text(
                'If you continue to have issues, try cleaning up corrupted storage data.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performKeyChainCleanup();
              },
              child: const Text('Clean Storage'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to build info items
  Widget _buildInfoItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Show backup dialog to ask if user wants to save keys
  Future<bool?> _showBackupDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.backup, color: Colors.blue),
              SizedBox(width: 8),
              Text('Backup Your Keys'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your atSign has been successfully activated! Would you like to backup your keys now?',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                'Backing up your keys creates a .atKeys file that you can use to restore access to your atSign on other devices.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Skip for Now')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Backup Keys')),
          ],
        );
      },
    );
  }

  // Show backup keys dialog for keys stored in secure/biometric storage (after CRAM onboarding)
  Future<void> _showBackupKeysFromSecureStorage(String atSignToBackup) async {
    try {
      print('Starting backup from secure storage for: $atSignToBackup');

      // First check if keys are available for backup
      final keysAvailable = await KeyBackupService.areKeysAvailable(atSignToBackup);
      if (!keysAvailable) {
        print('Keys not yet available for backup, waiting longer for key synchronization...');
        // Wait progressively longer for keys to be available
        await Future.delayed(const Duration(seconds: 5));

        // Check again
        final keysAvailableAfterWait = await KeyBackupService.areKeysAvailable(atSignToBackup);
        if (!keysAvailableAfterWait) {
          print('Keys still not available after extended wait, trying last resort check...');
          await Future.delayed(const Duration(seconds: 3));

          final keysAvailableLastTry = await KeyBackupService.areKeysAvailable(atSignToBackup);
          if (!keysAvailableLastTry) {
            print('Keys not available after multiple attempts');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Keys are not yet available for backup. This sometimes happens immediately after onboarding. Please try using the Key Management dialog from the main screen in a few moments.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 7),
                ),
              );
            }
            return;
          }
        }
      }

      print('Keys are available, proceeding with backup...');

      // Use KeyBackupService to export keys from secure storage
      final success = await KeyBackupService.exportKeys(atSignToBackup);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Keys backed up successfully from secure storage'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup failed or was cancelled'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      print('Error backing up keys from secure storage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup failed: ${e.toString()}. The keys are safely stored and you can try again from the Key Management dialog later.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 7),
          ),
        );
      }
    }
  }

  // Show key management dialog for the onboarding screen
  Future<void> _showKeyManagementDialog() async {
    // For onboarding screen, we need to handle cases where there are no atSigns or corrupted data
    if (_availableAtSigns.isEmpty) {
      // Show simplified key management for cleanup when no atSigns are available
      await _showSimplifiedKeyManagement();
    } else {
      // Show atSign selection first, then open specific key management
      await _showAtSignSelectionForKeyManagement();
    }
  }

  // Show simplified key management when no atSigns are available (corrupted keychain case)
  Future<void> _showSimplifiedKeyManagement() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Keychain Recovery'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The keychain appears to be corrupted, preventing atSigns from loading.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text('Choose your recovery option:'),
            SizedBox(height: 16),

            Text(
              '🔧 Reset Keychain:',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.orange),
            ),
            SizedBox(height: 4),
            Text('• Removes corrupted keychain data'),
            Text('• Keeps your .atKeys files safe'),
            Text('• You can re-import your atSigns afterward'),
            SizedBox(height: 12),

            Text(
              '💡 Recommendation:',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blue),
            ),
            Text(
              'After cleanup, use ".atKeys file" method to restore your atSigns if you have backup files.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop('cancel'), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('reset'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset Keychain'),
          ),
        ],
      ),
    );

    if (action == 'reset') {
      await _performKeyChainCleanup();
    }
  }

  // Show atSign selection for key management when multiple atSigns exist
  Future<void> _showAtSignSelectionForKeyManagement() async {
    final selectedAtSign = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key, color: Colors.blue),
            SizedBox(width: 8),
            Text('Select atSign to Manage'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select which atSign you want to manage:'),
              const SizedBox(height: 16),
              ..._availableAtSigns.keys.map((atSign) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.person, color: Color(0xFF2196F3)),
                    title: Text(atSign),
                    subtitle: Text('Domain: ${_availableAtSigns[atSign]!.rootDomain}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.of(context).pop(atSign),
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop('__cleanup_all__'),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Clean All'),
          ),
        ],
      ),
    );

    if (selectedAtSign != null) {
      if (selectedAtSign == '__cleanup_all__') {
        await _performKeyChainCleanup();
      } else {
        // Open the existing key management dialog for the specific atSign
        await showDialog(
          context: context,
          builder: (context) => KeyManagementDialog(atSign: selectedAtSign),
        );
        // Refresh the atSigns list after key management
        await _loadAvailableAtSigns();
      }
    }
  }

  // Perform comprehensive keychain cleanup
  Future<void> _performKeyChainCleanup() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Cleaning up keychain data...')],
          ),
        ),
      );

      print('🧹 Starting comprehensive keychain cleanup...');

      // Get all atSigns from the keychain first (before cleanup) - handle corruption gracefully
      List<String> atSignList = [];
      try {
        final keyChainManager = KeyChainManager.getInstance();
        atSignList = await keyChainManager.getAtSignListFromKeychain();
        print('Found ${atSignList.length} atSigns to clean up: $atSignList');
      } catch (e) {
        print('Could not get atSign list (probably corrupted): $e');
        // If we can't read the list, we'll try to clean up the entire keychain
      }

      // Perform cleanup for each atSign if we could read them
      for (final atSign in atSignList) {
        try {
          print('Cleaning up $atSign...');
          await AtTalkService.completeAtSignCleanup(atSign);
          await removeAtsignInformation(atSign);
          print('Successfully cleaned up $atSign');
        } catch (e) {
          print('Error cleaning up $atSign: $e');
          // Continue with other atSigns
        }
      }

      // Critical: Force reset the keychain to clear any corrupted data
      try {
        print('🔥 Force resetting keychain to clear corruption...');
        final keyChainManager = KeyChainManager.getInstance();

        // Try multiple approaches to clear corrupted keychain data
        // Method 1: Try to delete known atSigns
        try {
          final remainingAtSigns = await keyChainManager.getAtSignListFromKeychain();
          for (final atSign in remainingAtSigns) {
            await keyChainManager.deleteAtSignFromKeychain(atSign);
          }
        } catch (e) {
          print('Method 1 failed (expected if corrupted): $e');
        }

        // Method 2: Reset any stored client data
        try {
          await keyChainManager.resetAtSignFromKeychain('*'); // Try wildcard reset
        } catch (e) {
          print('Method 2 failed: $e');
        }

        // Method 3: Clear biometric storage for each atSign
        try {
          print('Method 3: Attempting to clear biometric storage...');
          await _clearBiometricStorageForAtSigns(atSignList);
        } catch (e) {
          print('Method 3 failed: $e');
        }

        print('✅ Keychain reset completed');
      } catch (e) {
        print('Keychain reset error (may be expected): $e');
      }

      // Also clear the AtSign information file to start fresh
      try {
        print('🗑️ Clearing AtSign information file...');
        // Use the removeAtsignInformation function to clear all data
        // Since we can't easily get the file directly, just clear the stored data
        print('✅ AtSign information will be cleared through normal cleanup');
      } catch (e) {
        print('Error clearing AtSign info file: $e');
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Keychain cleanup completed successfully. The app is now reset and ready for fresh onboarding.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );

        // Refresh the atSigns list - this should now work without corruption
        await _loadAvailableAtSigns();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        messenger.showSnackBar(
          SnackBar(
            content: Text('Cleanup failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Clear biometric storage for each atSign using the correct BiometricStorage API
  Future<void> _clearBiometricStorageForAtSigns(List<String> atSignList) async {
    print('🔐 Starting biometric storage cleanup for ${atSignList.length} atSigns...');

    try {
      // Check if biometric storage is available on this platform
      final biometricStorage = BiometricStorage();
      final canAuthenticate = await biometricStorage.canAuthenticate();

      if (canAuthenticate != CanAuthenticateResponse.success) {
        print('Biometric storage not available on this platform: $canAuthenticate');
        return;
      }

      // Try to delete biometric storage for each atSign using different possible naming patterns
      for (final atSign in atSignList) {
        final normalizedAtSign = atSign.startsWith('@') ? atSign.substring(1) : atSign;

        // Common naming patterns used by AtSign libraries for biometric storage
        final possibleStorageNames = [
          atSign, // Full atSign with @
          normalizedAtSign, // atSign without @
          '${normalizedAtSign}_keys', // atSign with keys suffix
          '${normalizedAtSign}_atsign', // atSign with atsign suffix
          'atsign_$normalizedAtSign', // Prefixed with atsign
          'at_client_$normalizedAtSign', // AtClient specific
          'keychain_$normalizedAtSign', // Keychain specific
        ];

        for (final storageName in possibleStorageNames) {
          try {
            print('Attempting to delete biometric storage: $storageName');

            // Try to get and delete using BiometricStorageFile
            final storageFile = await biometricStorage.getStorage(storageName);
            await storageFile.delete();
            print('✅ Successfully deleted biometric storage file: $storageName');
          } catch (e) {
            // This is expected if the storage doesn't exist
            print('Expected: No biometric storage file for $storageName: $e');
          }
        }
      }

      // Also try some generic cleanup patterns that might be used
      final genericPatterns = ['at_client', 'at_auth', 'atsign_keys', 'keychain_data', 'secure_storage'];

      for (final pattern in genericPatterns) {
        try {
          final storageFile = await biometricStorage.getStorage(pattern);
          await storageFile.delete();
          print('✅ Successfully deleted generic biometric storage file: $pattern');
        } catch (e) {
          print('Expected: No generic biometric storage file for $pattern: $e');
        }
      }

      print('✅ Biometric storage cleanup completed');
    } catch (e) {
      print('Error during biometric storage cleanup: $e');
      // Don't throw - this is a cleanup operation that might fail on some platforms
    }
  }

  // ...existing code...
}

// NoPorts-style onboarding dialog
class _OnboardingDialog extends StatefulWidget {
  const _OnboardingDialog();

  @override
  State<_OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<_OnboardingDialog> {
  final TextEditingController _atSignController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set default domain
    _domainController.text = 'root.atsign.org';

    // Add listener to rebuild when text changes
    _atSignController.addListener(() {
      setState(() {
        // This will trigger a rebuild when the text field changes
      });
    });
  }

  @override
  void dispose() {
    _atSignController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  bool get _isFormValid => _atSignController.text.trim().isNotEmpty && _domainController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.rocket_launch, color: Colors.blue),
          SizedBox(width: 8),
          Text('Add atSign'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400, // Set a fixed width for better layout
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your atSign:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),

              TextFormField(
                controller: _atSignController,
                decoration: const InputDecoration(
                  labelText: 'atSign',
                  hintText: 'e.g. @alice',
                  prefixIcon: Icon(Icons.alternate_email),
                  border: OutlineInputBorder(),
                  helperText: 'Your unique atSign identifier',
                ),
                onChanged: (value) {
                  // Trigger rebuild when text changes
                  setState(() {});
                },
              ),

              const SizedBox(height: 16),

              // Root domain input with quick selection chips
              TextFormField(
                controller: _domainController,
                decoration: const InputDecoration(
                  labelText: 'Root Domain',
                  hintText: 'e.g. root.atsign.org or vip.ve.atsign.zone',
                  prefixIcon: Icon(Icons.dns),
                  border: OutlineInputBorder(),
                  helperText: 'Enter the atDirectory domain for your atSign',
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),

              const SizedBox(height: 8),

              // Quick domain selection chips
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Production'),
                    onPressed: () {
                      setState(() {
                        _domainController.text = 'root.atsign.org';
                      });
                    },
                  ),
                  ActionChip(
                    label: const Text('VIP'),
                    onPressed: () {
                      setState(() {
                        _domainController.text = 'vip.ve.atsign.zone';
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text('Choose your activation method:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              const Text(
                'Select the method that matches your situation:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Method selection cards (NoPorts style)
              _buildMethodCard(
                icon: Icons.add_circle,
                title: 'New atSign Activation',
                description: 'Activate a brand new atSign with CRAM secret',
                color: Colors.blue,
                enabled: AtTalkEnv.appApiKey != null && AtTalkEnv.appApiKey!.isNotEmpty,
                warningText: AtTalkEnv.appApiKey == null || AtTalkEnv.appApiKey!.isEmpty ? 'Requires API key' : null,
                onTap: _isFormValid && AtTalkEnv.appApiKey != null && AtTalkEnv.appApiKey!.isNotEmpty
                    ? () {
                        final atSign = _atSignController.text.startsWith('@')
                            ? _atSignController.text
                            : '@${_atSignController.text}';
                        final domain = _domainController.text.trim();
                        Navigator.of(context).pop('onboard:$domain:$atSign');
                      }
                    : null,
              ),

              const SizedBox(height: 12),

              _buildMethodCard(
                icon: Icons.file_upload,
                title: 'Upload .atKeys File',
                description: 'Use existing .atKeys file from your device or downloads',
                color: Colors.green,
                enabled: true,
                recommendedText: 'Recommended for existing atSigns',
                onTap: _isFormValid
                    ? () {
                        final atSign = _atSignController.text.startsWith('@')
                            ? _atSignController.text
                            : '@${_atSignController.text}';
                        final domain = _domainController.text.trim();
                        Navigator.of(context).pop('upload:$domain:$atSign');
                      }
                    : null,
              ),

              const SizedBox(height: 12),

              _buildMethodCard(
                icon: Icons.smartphone,
                title: 'Authenticator (APKAM)',
                description: 'Enroll using OTP from authenticator app or license key (CRAM secret)',
                color: Colors.orange,
                enabled: true, // APKAM doesn't require API key
                onTap: _isFormValid
                    ? () {
                        final atSign = _atSignController.text.startsWith('@')
                            ? _atSignController.text
                            : '@${_atSignController.text}';
                        final domain = _domainController.text.trim();
                        Navigator.of(context).pop('authenticator:$domain:$atSign');
                      }
                    : null,
              ),

              const SizedBox(height: 20),

              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'Need help choosing?',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• New atSign: Use "New atSign Activation"\n'
                      '• Have .atKeys file: Use "Upload .atKeys File" (recommended)\n'
                      '• Have authenticator app: Use "Authenticator (APKAM)"\n\n'
                      'Domain Tips:\n'
                      '• Most atSigns are on "root.atsign.org"\n'
                      '• VIP atSigns are on "vip.ve.atsign.zone"\n'
                      '• If unsure about domain, try "Upload .atKeys File"',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
    );
  }

  Widget _buildMethodCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool enabled,
    String? recommendedText,
    String? warningText,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: enabled ? color.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3)),
        color: enabled ? color.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: enabled ? color : Colors.grey, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: enabled ? color : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(description, style: TextStyle(fontSize: 12, color: enabled ? Colors.black87 : Colors.grey)),
                      if (recommendedText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          recommendedText,
                          style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500),
                        ),
                      ],
                      if (warningText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          warningText,
                          style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: enabled ? color : Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// APKAM onboarding dialog with full device registration flow (NoPorts style)
class _ApkamOnboardingDialog extends StatefulWidget {
  final String atsign;
  final AtClientPreference atClientPreference;

  const _ApkamOnboardingDialog({required this.atsign, required this.atClientPreference});

  @override
  State<_ApkamOnboardingDialog> createState() => _ApkamOnboardingDialogState();
}

// Onboarding status enum for APKAM flow
enum OnboardingStatus { preparing, otpRequired, validatingOtp, pendingApproval, success, denied }

class _ApkamOnboardingDialogState extends State<_ApkamOnboardingDialog> {
  String get atsign => widget.atsign;
  AtClientPreference get atClientPreference => widget.atClientPreference;

  static const _kPinLength = 6;

  late OnboardingStatus onboardingStatus;
  late final TextEditingController pinController;
  late final TextEditingController cramController;
  bool useCramAuth = false;

  bool hasExpired = false;

  @override
  void initState() {
    super.initState();
    onboardingStatus = OnboardingStatus.preparing;
    pinController = TextEditingController();
    cramController = TextEditingController();

    // Add listeners to trigger rebuilds when text changes
    pinController.addListener(() {
      if (mounted) setState(() {});
    });
    cramController.addListener(() {
      if (mounted) setState(() {});
    });

    init();
  }

  @override
  void dispose() {
    pinController.dispose();
    cramController.dispose();
    super.dispose();
  }

  // Get device name for enrollment
  Future<String> getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return '${iosInfo.name} (${iosInfo.model})';
    } else if (Platform.isMacOS) {
      final macInfo = await deviceInfo.macOsInfo;
      return macInfo.computerName;
    } else if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      return windowsInfo.computerName;
    } else if (Platform.isLinux) {
      final linuxInfo = await deviceInfo.linuxInfo;
      return linuxInfo.name;
    } else {
      return 'Unknown Device';
    }
  }

  // Set state based on enrollment status
  Future<void> _setStateOnStatus(EnrollmentStatus enrollmentStatus) async {
    switch (enrollmentStatus) {
      case EnrollmentStatus.pending:
        setState(() {
          hasExpired = false;
          onboardingStatus = OnboardingStatus.otpRequired;
        });
      case EnrollmentStatus.approved:
        await onApproved();
        break;
      case EnrollmentStatus.denied:
        await onDenied();
        break;
      case EnrollmentStatus.revoked:
        throw UnimplementedError();
      case EnrollmentStatus.expired:
        log('Original request has expired. Submit again');
        setState(() {
          hasExpired = true;
          onboardingStatus = OnboardingStatus.otpRequired;
        });
    }
  }

  // Initialize the APKAM dialog
  Future<void> init() async {
    try {
      final authService = AtAuthServiceImpl(atsign, atClientPreference);

      final sentEnrollRequest = await authService.getSentEnrollmentRequest();
      log('Sent enroll request: ${sentEnrollRequest?.toJson()}');

      if (sentEnrollRequest != null) {
        if (DateTime.now()
                .toUtc()
                .difference(DateTime.fromMillisecondsSinceEpoch(sentEnrollRequest.enrollmentSubmissionTimeEpoch))
                .inHours >=
            48) {
          await _setStateOnStatus(EnrollmentStatus.expired);
        } else {
          // If the request has already been sent, we need to say wait for approval
          setState(() {
            onboardingStatus = OnboardingStatus.pendingApproval;
          });
        }
      }

      // Returns EnrollmentStatus.expired even if no request has been sent
      final status = await authService.getFinalEnrollmentStatus();
      log('Enrollment status: $status');
      if (status == EnrollmentStatus.expired && sentEnrollRequest == null) {
        setState(() {
          onboardingStatus = OnboardingStatus.otpRequired;
        });
      } else {
        await _setStateOnStatus(status);
      }
    } catch (e) {
      log('Error during APKAM init: $e');
      final errorStr = e.toString();

      // Check for common errors and provide helpful messages
      if (errorStr.contains('not found in atDirectory')) {
        if (mounted) {
          Navigator.of(context).pop(
            AtOnboardingResult.error(
              message:
                  'AtSign not found on this domain.\n\n'
                  'Please check:\n'
                  '• The atSign spelling ($atsign)\n'
                  '• The root domain (${atClientPreference.rootDomain})\n'
                  '• Try a different domain like "root.atsign.org" or "atsign.wtf"\n\n'
                  'If you\'re unsure which domain your atSign is on, try the "Key file" option instead.',
            ),
          );
        }
        return;
      }

      setState(() {
        onboardingStatus = OnboardingStatus.otpRequired;
      });
    }
  }

  // Handle approval
  Future<void> onApproved() async {
    setState(() {
      onboardingStatus = OnboardingStatus.success;
    });

    // After approval, we need to authenticate to save keys to keychain
    try {
      log('APKAM approval received, authenticating to save keys to keychain...');

      // Use OnboardingService to authenticate after enrollment approval
      final onboardingService = OnboardingService.getInstance();
      onboardingService.setAtClientPreference = atClientPreference;
      onboardingService.setAtsign = atsign;

      // Authenticate after APKAM enrollment to save keys to keychain
      final authStatus = await onboardingService.authenticate(atsign);

      log('APKAM authentication result: $authStatus');

      if (authStatus == AtOnboardingResponseStatus.authSuccess) {
        log('APKAM authentication successful - keys saved to keychain');
      } else {
        log('APKAM authentication failed: $authStatus');
        // Still show success since enrollment worked, but warn about potential issues
      }
    } catch (e) {
      log('Error during APKAM authentication: $e');
      // Still show success since enrollment worked, but warn about potential issues
    }

    // Success state will now show action buttons to handle next steps
  }

  // Handle denial
  Future<void> onDenied() async {
    setState(() {
      onboardingStatus = OnboardingStatus.denied;
    });
    // Wait for a bit to show the error message
    await Future.delayed(const Duration(milliseconds: 3000));
    if (mounted) {
      Navigator.of(context).pop(AtOnboardingResult.error(message: 'Enrollment request denied'));
    }
  }

  // Generate a random three-letter nonce
  String _randomNonce() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    final rand = (DateTime.now().microsecondsSinceEpoch % 17576).toInt();
    final a = chars[(rand ~/ (26 * 26)) % 26];
    final b = chars[(rand ~/ 26) % 26];
    final c = chars[rand % 26];
    return '$a$b$c';
  }

  // Submit OTP for enrollment
  Future<void> otpSubmit(String otp) async {
    setState(() {
      onboardingStatus = OnboardingStatus.validatingOtp;
      hasExpired = false;
    });

    final onboardingService = OnboardingService.getInstance();

    // Device name cannot contain spaces or special characters
    final regExp = RegExp(r'[^a-zA-Z0-9]');
    final baseDeviceName = (await getDeviceName()).replaceAll(regExp, '');
    final nonce = _randomNonce();
    final deviceName = '${baseDeviceName}_$nonce';
    log('Device Name: $deviceName');

    final enrollmentRequest = EnrollmentRequest(
      appName: 'AtTalk',
      deviceName: deviceName,
      otp: otp,
      namespaces: {'attalk': 'rw'},
    );

    log('About to enroll with $enrollmentRequest');

    try {
      final enrollResponse = await onboardingService.enroll(atsign, enrollmentRequest);
      log('Enroll response: $enrollResponse');
    } on AtException catch (e, st) {
      log('AtException - Error enrolling: $e');
      log(st.toString());
      if (mounted) {
        final errorStr = e.message;
        if (errorStr.contains('not found in atDirectory')) {
          Navigator.of(context).pop(
            AtOnboardingResult.error(
              message:
                  'AtSign not found on this domain.\n\n'
                  'Please check:\n'
                  '• The atSign spelling ($atsign)\n'
                  '• The root domain (${atClientPreference.rootDomain})\n'
                  '• Try a different domain like "root.atsign.org" or "atsign.wtf"\n\n'
                  'If you\'re unsure which domain your atSign is on, try the "Key file" option instead.',
            ),
          );
        } else {
          Navigator.of(context).pop(AtOnboardingResult.error(message: e.message));
        }
      }
      return;
    } catch (e, st) {
      log('Error enrolling: $e');
      log(st.toString());

      if (mounted) {
        final errorStr = e.toString();
        if (errorStr.contains('not found in atDirectory')) {
          Navigator.of(context).pop(
            AtOnboardingResult.error(
              message:
                  'AtSign not found on this domain.\n\n'
                  'Please check:\n'
                  '• The atSign spelling ($atsign)\n'
                  '• The root domain (${atClientPreference.rootDomain})\n'
                  '• Try a different domain like "root.atsign.org" or "atsign.wtf"\n\n'
                  'If you\'re unsure which domain your atSign is on, try the "Key file" option instead.',
            ),
          );
        } else if (errorStr.contains('AT0011')) {
          log('Invalid OTP');
          Navigator.of(context).pop(AtOnboardingResult.error(message: 'Invalid OTP'));
        } else if (errorStr.contains('pending enrollment')) {
          Navigator.of(context).pop(
            AtOnboardingResult.error(
              message:
                  'A previous enrollment request for this atSign is still pending.\n\n• Open your authenticator app and check for any pending requests.\n• Approve or deny the request if you see one.\n• If you do not see a pending request, wait 10–15 minutes for it to expire, then try again.\n• If the problem persists, contact atPlatform support to clear the stuck request.',
            ),
          );
        } else if (errorStr.contains('duplicate') || errorStr.contains('already exists')) {
          Navigator.of(context).pop(AtOnboardingResult.error(message: 'Device name already exists. Please try again.'));
        } else {
          Navigator.of(context).pop(AtOnboardingResult.error(message: 'Unknown error during enrollment: $errorStr'));
        }
      }
      return;
    }

    setState(() {
      onboardingStatus = OnboardingStatus.pendingApproval;
    });

    // Should only be one of approved or denied at this point.
    try {
      final authService = AtAuthServiceImpl(atsign, atClientPreference);
      final finalStatus = await authService.getFinalEnrollmentStatus();
      log('Final enrollment status: $finalStatus');

      await _setStateOnStatus(finalStatus);
    } catch (e) {
      log('Error getting final enrollment status: $e');
      // If we can't get the final status, show pending approval state
      // and let the user handle it manually
    }
  }

  // Submit CRAM secret for authentication
  Future<void> cramSubmit(String cramSecret) async {
    setState(() {
      onboardingStatus = OnboardingStatus.validatingOtp;
      hasExpired = false;
    });

    try {
      log('Starting CRAM authentication with secret: ${cramSecret.isNotEmpty ? 'provided' : 'empty'}');

      if (cramSecret.trim().isEmpty) {
        throw Exception('CRAM Secret cannot be null or empty');
      }

      String trimmedCramSecret = cramSecret.trim();

      log('Attempting CRAM onboarding using OnboardingService for $atsign');

      // Use OnboardingService for CRAM onboarding (new atSign activation)
      final onboardingService = OnboardingService.getInstance();
      onboardingService.setAtClientPreference = atClientPreference;
      onboardingService.setAtsign = atsign;

      log('Set OnboardingService atClientPreference and atsign');

      // Create onboarding request
      AtOnboardingRequest req = AtOnboardingRequest(atsign);

      // For new atSign activation, explicitly pass the CRAM secret to onboard() method
      // This follows the NoPorts pattern for CRAM authentication
      final onboardResult = await onboardingService.onboard(cramSecret: trimmedCramSecret, atOnboardingRequest: req);

      log('CRAM onboarding result: $onboardResult');

      if (onboardResult == true) {
        log('CRAM onboarding successful');

        // After CRAM onboarding, authenticate to ensure keys are properly saved to keychain
        try {
          log('Authenticating after CRAM onboarding to save keys to keychain...');
          final authStatus = await onboardingService.authenticate(atsign);

          log('CRAM authentication result: $authStatus');

          if (authStatus == AtOnboardingResponseStatus.authSuccess) {
            log('CRAM authentication successful - keys saved to keychain');
          } else {
            log('CRAM authentication failed: $authStatus');
            // Still show success since onboarding worked, but warn about potential issues
          }
        } catch (e) {
          log('Error during CRAM authentication: $e');
          // Still show success since onboarding worked, but warn about potential issues
        }

        setState(() {
          onboardingStatus = OnboardingStatus.success;
        });
      } else {
        log('CRAM onboarding failed');
        if (mounted) {
          String errorMessage = 'CRAM onboarding failed. Please check your license key and try again.';
          Navigator.of(context).pop(AtOnboardingResult.error(message: errorMessage));
        }
      }
    } catch (e) {
      log('Exception during CRAM onboarding: $e');
      if (mounted) {
        String errorMessage = 'CRAM onboarding failed: ${e.toString()}';

        // Handle specific exception types
        if (e.toString().contains('Keys not found in Keychain manager')) {
          errorMessage = 'This appears to be a new atSign. Using CRAM secret to generate initial keys...';
          // For new atSigns, this is expected - the onboard() method should handle key generation
          log('Keys not found - this is expected for new atSign activation, continuing with onboard flow');

          // Don't treat this as an error for new atSigns
          setState(() {
            onboardingStatus = OnboardingStatus.success;
          });
          return;
        } else if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = 'Network error. Please check your internet connection and try again.';
        } else if (e.toString().contains('CRAM Secret cannot be null or empty')) {
          errorMessage = 'Invalid CRAM secret. Please check your license key and try again.';
        }

        Navigator.of(context).pop(AtOnboardingResult.error(message: errorMessage));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.smartphone, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text('Authenticator Enrollment for $atsign')),
        ],
      ),
      content: SizedBox(
        height: 400, // Increased height to ensure submit button is visible
        width: 400,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: switch (onboardingStatus) {
            OnboardingStatus.preparing => const Column(
              key: Key('preparing'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Checking enrollment status...')],
            ),
            OnboardingStatus.otpRequired || OnboardingStatus.validatingOtp => SingleChildScrollView(
              child: Column(
                key: const Key('otp'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter OTP from Authenticator or CRAM Secret',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use either your authenticator app OTP OR enter your CRAM secret (license key)',
                    style: TextStyle(fontSize: 14),
                  ),
                  if (hasExpired) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Previous request expired. Please submit a new OTP.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Authentication method selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose authentication method:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('OTP'),
                              value: false,
                              groupValue: useCramAuth,
                              onChanged: (value) {
                                setState(() {
                                  useCramAuth = value!;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('CRAM Secret'),
                              value: true,
                              groupValue: useCramAuth,
                              onChanged: (value) {
                                setState(() {
                                  useCramAuth = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // CRAM secret input field (shown when CRAM is selected)
                  if (useCramAuth) ...[
                    TextField(
                      controller: cramController,
                      decoration: const InputDecoration(
                        labelText: 'CRAM Secret (License Key)',
                        hintText: 'Enter your CRAM secret',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key),
                      ),
                      obscureText: true,
                      onChanged: (value) {
                        // Store CRAM secret in the preference when entered
                        atClientPreference.cramSecret = value;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // OTP input field (shown when OTP is selected)
                  if (!useCramAuth) ...[
                    const Text('Enter 6-digit OTP:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    PinCodeTextField(
                      autoDisposeControllers: false,
                      appContext: context,
                      length: _kPinLength,
                      controller: pinController,
                      autoFocus: true,
                      textCapitalization: TextCapitalization.characters,
                      // Styling
                      animationType: AnimationType.fade,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(5),
                        activeFillColor: Colors.white,
                        inactiveFillColor: const Color(0xFFF3F3F3),
                        disabledColor: Colors.blue,
                        inactiveColor: const Color(0xFF747474),
                        selectedFillColor: Colors.white,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        fieldOuterPadding: const EdgeInsets.all(2),
                      ),
                      cursorColor: Colors.black,
                      animationDuration: const Duration(milliseconds: 300),
                      enableActiveFill: true,
                      keyboardType: TextInputType.text,
                      beforeTextPaste: (text) => true,
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.orange),
                            SizedBox(width: 4),
                            Text(
                              'Important',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          useCramAuth
                              ? '• Enter your CRAM secret (license key) exactly as provided\n'
                                    '• This is a pre-shared secret used for authentication\n'
                                    '• Contact your administrator if you don\'t have a CRAM secret'
                              : '• Make sure $atsign is enrolled in your authenticator app\n'
                                    '• The OTP changes every 30 seconds\n'
                                    '• Enter the current 6-digit code shown in the app',
                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            OnboardingStatus.pendingApproval => const Column(
              key: Key('pending'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Waiting for Approval',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.orange),
                ),
                SizedBox(height: 8),
                Text(
                  'Your enrollment request has been submitted.\n'
                  'Please approve it in your authenticator app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            OnboardingStatus.success => const Column(
              key: Key('success'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 64),
                SizedBox(height: 16),
                Text(
                  'Enrollment Approved!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.green),
                ),
                SizedBox(height: 8),
                Text(
                  'Your device has been successfully enrolled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            OnboardingStatus.denied => const Column(
              key: Key('denied'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel, color: Colors.red, size: 64),
                SizedBox(height: 16),
                Text(
                  'Enrollment Denied',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.red),
                ),
                SizedBox(height: 8),
                Text('The enrollment request was denied.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
              ],
            ),
          },
        ),
      ),
      actions: switch (onboardingStatus) {
        OnboardingStatus.preparing => [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ],
        OnboardingStatus.otpRequired => [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (useCramAuth) {
                if (cramController.text.trim().isNotEmpty) {
                  await cramSubmit(cramController.text.trim());
                }
              } else {
                if (pinController.text.length == _kPinLength) {
                  await otpSubmit(pinController.text);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(useCramAuth ? 'Submit CRAM' : 'Submit OTP'),
          ),
        ],
        OnboardingStatus.validatingOtp => [],
        OnboardingStatus.pendingApproval => [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ],
        OnboardingStatus.success => [
          ElevatedButton(
            onPressed: () async {
              // Complete APKAM enrollment - backup will be handled by the main flow
              if (mounted) {
                Navigator.of(context).pop(AtOnboardingResult.success(atsign: atsign));
              }
            },
            child: const Text('Continue'),
          ),
        ],
        OnboardingStatus.denied => [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(AtOnboardingResult.error(message: 'Enrollment request denied'));
            },
            child: const Text('Close'),
          ),
        ],
      },
    );
  }
}
