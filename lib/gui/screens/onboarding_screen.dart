import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_onboarding_flutter/services/onboarding_service.dart';
import 'package:at_onboarding_flutter/utils/at_onboarding_response_status.dart';
import 'package:at_auth/at_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer';
import 'dart:io';
import 'dart:convert';
import '../../core/providers/auth_provider.dart';
import '../../core/services/at_talk_service.dart';
import '../../core/utils/at_talk_env.dart';
import '../../core/utils/atsign_manager.dart';

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
      setState(() {
        _errorMessage = 'Failed to load atSigns: ${e.toString()}';
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),

                        // Logo and title
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            size: 60,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Welcome to AtTalk',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
                                    const Icon(
                                      Icons.account_circle,
                                      color: Color(0xFF2196F3),
                                    ),
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
                                      leading: const Icon(
                                        Icons.person,
                                        color: Color(0xFF2196F3),
                                      ),
                                      title: Text(atSign),
                                      subtitle: Text(
                                        'Domain: ${_availableAtSigns[atSign]!.rootDomain}',
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                      ),
                                      onTap: () =>
                                          _loginWithExistingAtSign(atSign),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
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
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : _showOnboardingDialog,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF2196F3),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: authProvider.isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Color(0xFF2196F3),
                                                  ),
                                            ),
                                          )
                                        : Icon(
                                            _availableAtSigns.isEmpty
                                                ? Icons.rocket_launch
                                                : Icons.person_add,
                                          ),
                                    label: Text(
                                      _availableAtSigns.isEmpty
                                          ? 'Get Started'
                                          : 'Add New atSign',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Refresh Button
                                OutlinedButton.icon(
                                  onPressed: _isLoadingAtSigns
                                      ? null
                                      : _loadAvailableAtSigns,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: _isLoadingAtSigns
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Icon(Icons.refresh, size: 18),
                                  label: const Text('Refresh atSigns'),
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
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _errorMessage = null),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                    size: 20,
                                  ),
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
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        authProvider.errorMessage!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: authProvider.clearError,
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                        size: 20,
                                      ),
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
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Need an atSign?',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Visit atsign.com to get your free atSign.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Already have an atSign? You can use:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildInfoItem(
                                '📁',
                                '.atKeys file from your device or app',
                              ),
                              _buildInfoItem(
                                '📱',
                                'Authenticator app with OTP verification',
                              ),
                              _buildInfoItem(
                                '🆕',
                                'CRAM secret for new atSigns',
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tip: Save your .atKeys file safely - it is your backup!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontStyle: FontStyle.italic,
                                ),
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

    try {
      print('Logging in with existing atSign: $atSign');
      await authProvider.authenticate(atSign);

      if (mounted && authProvider.isAuthenticated) {
        print('Authentication successful, navigating to groups...');
        Navigator.pushReplacementNamed(context, '/groups');
      } else {
        print('Authentication failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Exception during authentication: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
        final atSign = parts
            .sublist(2)
            .join(':'); // In case atSign contains ':'

        if (method == 'onboard') {
          await _startOnboarding(atSign, domain);
        } else if (method == 'upload') {
          await _startAtKeysUpload(atSign, domain);
        } else if (method == 'authenticator') {
          await _startAuthenticatorOnboarding(atSign, domain);
        }
      }
    }

    // Refresh the available atSigns after any onboarding operation
    await _loadAvailableAtSigns();
  }

  // Start onboarding for a new atSign - this will determine the proper flow based on atSign status
  Future<void> _startOnboarding(String atSign, String domain) async {
    if (atSign.isEmpty) {
      print('No atSign provided, cannot start onboarding');
      return;
    }

    print('Starting CRAM onboarding for: $atSign with domain: $domain');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Configure atSign-specific storage before onboarding
      print(
        '🔧 Configuring atSign-specific storage for CRAM onboarding: $atSign',
      );
      final atClientPreference = await AtTalkService.configureAtSignStorage(
        atSign,
      );

      print('AtClient preference found, proceeding with CRAM onboarding...');

      // Create a custom preference with the specified domain
      final customPreference = AtClientPreference()
        ..rootDomain = domain
        ..namespace = atClientPreference.namespace
        ..hiveStoragePath = atClientPreference.hiveStoragePath
        ..commitLogPath = atClientPreference.commitLogPath
        ..isLocalStoreRequired = atClientPreference.isLocalStoreRequired;

      final result = await AtOnboarding.onboard(
        context: context,
        atsign: atSign,
        config: AtOnboardingConfig(
          atClientPreference: customPreference,
          domain: domain,
          rootEnvironment: AtTalkEnv.rootEnvironment,
          // For CRAM activation, API key may be required depending on registrar
          appAPIKey: AtTalkEnv.appApiKey,
        ),
      );

      print('CRAM onboarding result: ${result.status}');

      switch (result.status) {
        case AtOnboardingResultStatus.success:
          print('CRAM onboarding successful for: ${result.atsign}');

          // Save the atSign information for future use
          if (result.atsign != null) {
            await saveAtsignInformation(
              AtsignInformation(atSign: result.atsign!, rootDomain: domain),
            );
            print('Saved atSign information');
          }

          print('Authenticating with AuthProvider...');
          await authProvider.authenticate(result.atsign);

          if (mounted && authProvider.isAuthenticated) {
            print('Authentication successful, navigating to groups...');
            Navigator.pushReplacementNamed(context, '/groups');
          } else {
            print('Authentication failed or widget unmounted');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Authentication failed. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          break;

        case AtOnboardingResultStatus.error:
          print('CRAM onboarding error: ${result.message}');
          String errorMessage = result.message ?? 'Onboarding failed';

          // Provide helpful error messages based on common CRAM scenarios
          if (errorMessage.contains('CRAM Secret cannot be null or empty') ||
              errorMessage.contains('CRAM') ||
              errorMessage.contains('already registered')) {
            print(
              'AtSign appears to be already registered, suggesting alternatives',
            );

            if (mounted) {
              _showAlreadyRegisteredDialog(atSign);
            }
            return;
          }

          if (errorMessage.contains('not found') ||
              errorMessage.contains('does not exist')) {
            errorMessage =
                'This atSign does not exist or is not available for activation.\n\n'
                'Please check:\n'
                '• The spelling of your atSign\n'
                '• That you own this atSign\n'
                '• Get a new atSign from atsign.com if needed';
          } else if (errorMessage.contains('network') ||
              errorMessage.contains('connection')) {
            errorMessage =
                'Network connection failed. Please check your internet connection and try again.';
          } else if (errorMessage.contains('timeout') ||
              errorMessage.contains('time out')) {
            errorMessage =
                'Request timed out. Please check your connection and try again.';
          } else if (errorMessage.contains('API key') ||
              errorMessage.contains('unauthorized')) {
            errorMessage =
                'API key issue. This may require registrar support for CRAM activation.';
          } else if (errorMessage.contains('Unknown error')) {
            errorMessage =
                'Activation failed. This might be because:\n'
                '• The atSign is already registered to someone else\n'
                '• Network connection issues\n'
                '• The atSign may need to be activated differently\n\n'
                'Try:\n'
                '• Using the .atKeys file if you already have one\n'
                '• Using Authenticator (APKAM) method\n'
                '• Getting a new atSign from atsign.com';
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 10),
                action: SnackBarAction(
                  label: 'Help',
                  textColor: Colors.white,
                  onPressed: () {
                    _showCramHelpDialog();
                  },
                ),
              ),
            );
          }
          break;

        case AtOnboardingResultStatus.cancel:
          print('CRAM onboarding cancelled by user');
          // User cancelled onboarding - no action needed
          break;
      }
    } catch (e) {
      print('Exception during CRAM onboarding: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Handle onboarding result for CRAM-based APKAM
  Future<void> _handleOnboardingResult(
    AtOnboardingResult result,
    String domain,
  ) async {
    print('AtOnboarding.onboard result for APKAM: ${result.status}');

    switch (result.status) {
      case AtOnboardingResultStatus.success:
        print('APKAM onboarding successful');

        if (result.atsign != null) {
          await saveAtsignInformation(
            AtsignInformation(atSign: result.atsign!, rootDomain: domain),
          );
          print('Saved atSign information');
        }

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.authenticate(result.atsign);

        if (mounted && authProvider.isAuthenticated) {
          print('Authentication successful, navigating to groups...');
          Navigator.pushReplacementNamed(context, '/groups');
        } else {
          print('Authentication failed after APKAM onboarding');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Authentication failed after APKAM enrollment. Please try again.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        break;

      case AtOnboardingResultStatus.error:
        print('AtOnboarding.onboard APKAM error: ${result.message}');
        _handleApkamError(result.message ?? 'APKAM enrollment failed');
        break;

      case AtOnboardingResultStatus.cancel:
        print('APKAM enrollment cancelled by user');
        break;
    }
  }

  // Show dialog when atSign is already registered
  void _showAlreadyRegisteredDialog(String atSign) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('atSign Already Registered'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The atSign "$atSign" is already registered.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'For already-registered atSigns, please use one of these methods:',
                ),
                const SizedBox(height: 8),
                const Text('📁 Upload .atKeys File (Recommended)'),
                const SizedBox(height: 4),
                const Text('   • Use the .atKeys file from your device'),
                const Text('   • Most reliable for existing atSigns'),
                const SizedBox(height: 8),
                const Text('📱 Authenticator (APKAM)'),
                const SizedBox(height: 4),
                const Text('   • Use if you have the authenticator app'),
                const Text('   • Requires enrollment approval'),
                const SizedBox(height: 12),
                const Text(
                  'New atSign activation is only for brand new atSigns that have never been used before.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Re-open the onboarding dialog
                _showOnboardingDialog();
              },
              child: const Text('Try Different Method'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  // Show help dialog for CRAM onboarding
  void _showCramHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('New atSign Activation Help'),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New atSign Activation:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'This method is for activating brand new atSigns that have never been used before.',
                ),
                SizedBox(height: 12),
                Text(
                  'Requirements:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('• A new, unregistered atSign'),
                Text('• CRAM secret (provided when you get the atSign)'),
                Text('• Valid API key (may be required)'),
                SizedBox(height: 12),
                Text(
                  'If this method fails:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('• The atSign might already be registered'),
                Text('• Try the ".atKeys File" method instead'),
                Text('• Try the "Authenticator (APKAM)" method'),
                Text('• Get a new atSign from atsign.com'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
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
        throw Exception(
          'The selected file is not a valid .atKeys file (invalid JSON)',
        );
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
        if (!keysMap.containsKey(key) ||
            keysMap[key] == null ||
            keysMap[key].toString().isEmpty) {
          throw Exception(
            'The selected .atKeys file is missing required key: $key',
          );
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
              final List<String> params = keyData[1]
                  .toString()
                  .substring(0, keyData[1].length - 2)
                  .split('":"');
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
      final normalizedFile = fileAtSign.startsWith('@')
          ? fileAtSign
          : '@$fileAtSign';

      if (normalizedExpected.toLowerCase() != normalizedFile.toLowerCase()) {
        throw Exception(
          'The .atKeys file is for $normalizedFile but you selected $normalizedExpected. Please select the correct .atKeys file.',
        );
      }

      print('Validated .atKeys file for $normalizedFile');

      // Configure atSign-specific storage before onboarding
      print(
        '🔧 Configuring atSign-specific storage for .atKeys upload: $normalizedFile',
      );
      final atClientPreference = await AtTalkService.configureAtSignStorage(
        normalizedFile,
      );

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
        jsonData:
            fileContents, // This triggers PKAM authentication instead of CRAM
      );

      print('PKAM authentication result: $authStatus');

      if (authStatus == AtOnboardingResponseStatus.authSuccess) {
        print('PKAM authentication successful for: $normalizedFile');

        // Save the atSign information for future use
        await saveAtsignInformation(
          AtsignInformation(atSign: normalizedFile, rootDomain: domain),
        );
        print('Saved atSign information');

        print('Authenticating with AuthProvider...');
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.authenticate(normalizedFile);

        if (mounted && authProvider.isAuthenticated) {
          print('Authentication successful, navigating to groups...');
          Navigator.pushReplacementNamed(context, '/groups');
        } else {
          print('Authentication failed after importing keys');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Authentication failed after importing keys. Please try again.',
                ),
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
            errorMessage =
                'Could not reach the atSign server. Please check your internet connection and try again.';
            break;
          case AtOnboardingResponseStatus.authFailed:
            errorMessage =
                'Authentication failed. The .atKeys file may be corrupted or invalid.';
            break;
          case AtOnboardingResponseStatus.timeOut:
            errorMessage =
                'Authentication timed out. Please check your internet connection and try again.';
            break;
          default:
            errorMessage =
                'Failed to authenticate with the .atKeys file. Please ensure the file is valid and try again.';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }
    } catch (e) {
      print('Exception during .atKeys upload: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading .atKeys file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Start onboarding using authenticator app (APKAM enrollment flow)
  Future<void> _startAuthenticatorOnboarding(
    String atSign,
    String domain,
  ) async {
    if (atSign.isEmpty) {
      print('No atSign provided, cannot start authenticator onboarding');
      return;
    }

    print(
      'Starting authenticator/APKAM onboarding for: $atSign with domain: $domain',
    );

    try {
      // Configure atSign-specific storage before onboarding
      print(
        '🔧 Configuring atSign-specific storage for APKAM onboarding: $atSign',
      );
      final atClientPreference = await AtTalkService.configureAtSignStorage(
        atSign,
      );

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
        builder: (context) => _ApkamOnboardingDialog(
          atsign: normalizedAtSign,
          atClientPreference: customPreference,
        ),
      );

      if (result != null) {
        await _handleOnboardingResult(result, domain);
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
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
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
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// NoPorts-style onboarding dialog
class _OnboardingDialog extends StatefulWidget {
  const _OnboardingDialog();

  @override
  State<_OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<_OnboardingDialog> {
  final TextEditingController _atSignController = TextEditingController();
  String _selectedRootDomain =
      'root.atsign.org'; // Default to production (non-nullable)

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  bool get _isFormValid => _atSignController.text.trim().isNotEmpty;

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
              const Text(
                'Enter your atSign:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
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

              // Root domain selection
              DropdownButtonFormField<String>(
                value: _selectedRootDomain,
                decoration: const InputDecoration(
                  labelText: 'Root Domain',
                  border: OutlineInputBorder(),
                  helperText: 'Choose your atSign network',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'root.atsign.org',
                    child: Text('Production (root.atsign.org)'),
                  ),
                  DropdownMenuItem(
                    value: 'vip.ve.atsign.zone',
                    child: Text('VIP (vip.ve.atsign.zone)'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRootDomain = value ?? 'root.atsign.org';
                  });
                },
              ),

              const SizedBox(height: 24),

              const Text(
                'Choose your activation method:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
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
                enabled:
                    AtTalkEnv.appApiKey != null &&
                    AtTalkEnv.appApiKey!.isNotEmpty,
                warningText:
                    AtTalkEnv.appApiKey == null || AtTalkEnv.appApiKey!.isEmpty
                    ? 'Requires API key'
                    : null,
                onTap:
                    _isFormValid &&
                        AtTalkEnv.appApiKey != null &&
                        AtTalkEnv.appApiKey!.isNotEmpty
                    ? () {
                        final atSign = _atSignController.text.startsWith('@')
                            ? _atSignController.text
                            : '@${_atSignController.text}';
                        Navigator.of(
                          context,
                        ).pop('onboard:$_selectedRootDomain:$atSign');
                      }
                    : null,
              ),

              const SizedBox(height: 12),

              _buildMethodCard(
                icon: Icons.file_upload,
                title: 'Upload .atKeys File',
                description:
                    'Use existing .atKeys file from your device or downloads',
                color: Colors.green,
                enabled: true,
                recommendedText: 'Recommended for existing atSigns',
                onTap: _isFormValid
                    ? () {
                        final atSign = _atSignController.text.startsWith('@')
                            ? _atSignController.text
                            : '@${_atSignController.text}';
                        Navigator.of(
                          context,
                        ).pop('upload:$_selectedRootDomain:$atSign');
                      }
                    : null,
              ),

              const SizedBox(height: 12),

              _buildMethodCard(
                icon: Icons.smartphone,
                title: 'Authenticator (APKAM)',
                description:
                    'Enroll using OTP from authenticator app or license key (CRAM secret)',
                color: Colors.orange,
                enabled: true, // APKAM doesn't require API key
                onTap: _isFormValid
                    ? () {
                        final atSign = _atSignController.text.startsWith('@')
                            ? _atSignController.text
                            : '@${_atSignController.text}';
                        Navigator.of(
                          context,
                        ).pop('authenticator:$_selectedRootDomain:$atSign');
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
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Need help choosing?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• New atSign: Use "New atSign Activation"\n'
                      '• Have .atKeys file: Use "Upload .atKeys File"\n'
                      '• Have authenticator app: Use "Authenticator (APKAM)"',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
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
        border: Border.all(
          color: enabled
              ? color.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
        ),
        color: enabled
            ? color.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
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
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: enabled ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      if (recommendedText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          recommendedText,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (warningText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          warningText,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: enabled ? color : Colors.grey,
                ),
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

  const _ApkamOnboardingDialog({
    required this.atsign,
    required this.atClientPreference,
  });

  @override
  State<_ApkamOnboardingDialog> createState() => _ApkamOnboardingDialogState();
}

// Onboarding status enum for APKAM flow
enum OnboardingStatus {
  preparing,
  otpRequired,
  validatingOtp,
  pendingApproval,
  success,
  denied,
}

class _ApkamOnboardingDialogState extends State<_ApkamOnboardingDialog> {
  String get atsign => widget.atsign;
  AtClientPreference get atClientPreference => widget.atClientPreference;

  static const _kPinLength = 6;

  late OnboardingStatus onboardingStatus;
  late final TextEditingController pinController;

  bool hasExpired = false;

  @override
  void initState() {
    super.initState();
    onboardingStatus = OnboardingStatus.preparing;
    pinController = TextEditingController();
    init();
  }

  @override
  void dispose() {
    pinController.dispose();
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
                .difference(
                  DateTime.fromMillisecondsSinceEpoch(
                    sentEnrollRequest.enrollmentSubmissionTimeEpoch,
                  ),
                )
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
      Navigator.of(
        context,
      ).pop(AtOnboardingResult.error(message: 'Enrollment request denied'));
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
      final enrollResponse = await onboardingService.enroll(
        atsign,
        enrollmentRequest,
      );
      log('Enroll response: $enrollResponse');
    } on AtException catch (e, st) {
      log('AtException - Error enrolling: $e');
      log(st.toString());
      if (mounted) {
        Navigator.of(context).pop(AtOnboardingResult.error(message: e.message));
      }
      return;
    } catch (e, st) {
      log('Error enrolling: $e');
      log(st.toString());

      if (mounted) {
        final errorStr = e.toString();
        if (errorStr.contains('AT0011')) {
          log('Invalid OTP');
          Navigator.of(
            context,
          ).pop(AtOnboardingResult.error(message: 'Invalid OTP'));
        } else if (errorStr.contains('pending enrollment')) {
          Navigator.of(context).pop(
            AtOnboardingResult.error(
              message:
                  'A previous enrollment request for this atSign is still pending.\n\n• Open your authenticator app and check for any pending requests.\n• Approve or deny the request if you see one.\n• If you do not see a pending request, wait 10–15 minutes for it to expire, then try again.\n• If the problem persists, contact atPlatform support to clear the stuck request.',
            ),
          );
        } else if (errorStr.contains('duplicate') ||
            errorStr.contains('already exists')) {
          Navigator.of(context).pop(
            AtOnboardingResult.error(
              message: 'Device name already exists. Please try again.',
            ),
          );
        } else {
          Navigator.of(context).pop(
            AtOnboardingResult.error(
              message: 'Unknown error during enrollment: $errorStr',
            ),
          );
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
                'Your atSign has been successfully enrolled!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text('Would you like to save a backup of your atKeys file now?'),
              SizedBox(height: 8),
              Text(
                'This backup file will allow you to restore access to your atSign on other devices.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save Backup'),
            ),
          ],
        );
      },
    );
  }

  // Show backup keys dialog - now with real implementation
  Future<void> _showBackupKeysDialog() async {
    try {
      // Get the directory where keys are stored
      final appSupportDir = await getApplicationSupportDirectory();
      final keysDir = Directory('${appSupportDir.path}/keys');

      if (!keysDir.existsSync()) {
        throw Exception('Keys directory not found');
      }

      // Find the key file for this atSign
      final keyFiles = keysDir
          .listSync()
          .where((file) => file.path.contains(atsign.replaceAll('@', '')))
          .toList();

      if (keyFiles.isEmpty) {
        throw Exception('No key files found for $atsign');
      }

      // Let user choose where to save the backup
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save atKeys backup',
        fileName: '${atsign.replaceAll('@', '')}_atkeys_backup.atKeys',
        type: FileType.any,
      );

      if (outputPath != null) {
        // Copy the key file to the selected location
        final keyFile = File(keyFiles.first.path);
        final backupFile = File(outputPath);

        await keyFile.copy(backupFile.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Keys backed up successfully to ${backupFile.path}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
        height: 300,
        width: 400,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: switch (onboardingStatus) {
            OnboardingStatus.preparing => const Column(
              key: Key('preparing'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Checking enrollment status...'),
              ],
            ),
            OnboardingStatus.otpRequired ||
            OnboardingStatus.validatingOtp => SingleChildScrollView(
              child: Column(
                key: const Key('otp'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter OTP from Authenticator',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Open your authenticator app and enter the current 6-digit OTP',
                    style: TextStyle(fontSize: 14),
                  ),
                  if (hasExpired) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Previous request expired. Please submit a new OTP.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 24),
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
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedBuilder(
                      animation: pinController,
                      builder: (context, _) {
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            textStyle: const TextStyle(fontSize: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed:
                              pinController.text.length == _kPinLength &&
                                  onboardingStatus !=
                                      OnboardingStatus.validatingOtp
                              ? () async {
                                  await otpSubmit(pinController.text);
                                }
                              : null,
                          child:
                              onboardingStatus == OnboardingStatus.validatingOtp
                              ? const CircularProgressIndicator()
                              : const Text('Submit OTP'),
                        );
                      },
                    ),
                  ),
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
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Important',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Make sure $atsign is enrolled in your authenticator app\n'
                          '• The OTP changes every 30 seconds\n'
                          '• Enter the current 6-digit code shown in the app',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                          ),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'The enrollment request was denied.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          },
        ),
      ),
      actions: switch (onboardingStatus) {
        OnboardingStatus.preparing => [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
        OnboardingStatus.otpRequired => [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
        OnboardingStatus.validatingOtp => [],
        OnboardingStatus.pendingApproval => [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
        OnboardingStatus.success => [
          TextButton(
            onPressed: () async {
              // Complete without backup
              if (mounted) {
                Navigator.of(
                  context,
                ).pop(AtOnboardingResult.success(atsign: atsign));
              }
            },
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Show backup option and then complete
              final shouldShowBackup = await _showBackupDialog();
              if (shouldShowBackup == true && mounted) {
                await _showBackupKeysDialog();
              }
              if (mounted) {
                Navigator.of(
                  context,
                ).pop(AtOnboardingResult.success(atsign: atsign));
              }
            },
            child: const Text('Backup & Continue'),
          ),
        ],
        OnboardingStatus.denied => [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(
                AtOnboardingResult.error(message: 'Enrollment request denied'),
              );
            },
            child: const Text('Close'),
          ),
        ],
      },
    );
  }
}
