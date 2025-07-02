import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_onboarding_flutter/services/onboarding_service.dart';
import 'package:at_onboarding_flutter/utils/at_onboarding_response_status.dart';
import 'package:file_picker/file_picker.dart';
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
                          'Welcome to AtTalk',
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
                                        : const Icon(Icons.rocket_launch),
                                    label: const Text(
                                      'Get Started',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                        const Text(
                          'Need an atSign? Visit atsign.com to get yours.\n\n'
                          'If you already have an atSign, you\'ll need:\n'
                          '• Your .atKeys file, or\n'
                          '• A QR code/activation key from atsign.com',
                          style: TextStyle(fontSize: 14, color: Colors.white60),
                          textAlign: TextAlign.center,
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
      }
    }

    // Refresh the available atSigns after any onboarding operation
    await _loadAvailableAtSigns();
  }

  // Start onboarding for a new atSign
  Future<void> _startOnboarding(String atSign, String domain) async {
    if (atSign.isEmpty) {
      print('No atSign provided, cannot start onboarding');
      return;
    }

    print('Starting onboarding for: $atSign with domain: $domain');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final atClientPreference = AtTalkService.instance.atClientPreference;
      if (atClientPreference == null) {
        throw Exception('AtClient not initialized. Please restart the app.');
      }

      print('AtClient preference found, proceeding with onboarding...');

      final result = await AtOnboarding.onboard(
        context: context,
        atsign: atSign,
        config: AtOnboardingConfig(
          atClientPreference: atClientPreference,
          domain: domain,
          rootEnvironment: AtTalkEnv.rootEnvironment,
          appAPIKey: AtTalkEnv.appApiKey,
        ),
      );

      print('Onboarding result: ${result.status}');

      switch (result.status) {
        case AtOnboardingResultStatus.success:
          print('Onboarding successful for: ${result.atsign}');

          // Save the atSign information for future use
          if (result.atsign != null) {
            await saveAtsignInformation(AtsignInformation(atSign: result.atsign!, rootDomain: domain));
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
                const SnackBar(content: Text('Authentication failed. Please try again.'), backgroundColor: Colors.red),
              );
            }
          }
          break;

        case AtOnboardingResultStatus.error:
          print('Onboarding error: ${result.message}');
          String errorMessage = result.message ?? 'Onboarding failed';

          // Check if this is a CRAM secret error (atSign already registered)
          if (errorMessage.contains('CRAM Secret cannot be null or empty')) {
            print('AtSign appears to be already registered, suggesting alternatives');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This atSign is already registered.', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('For already-registered atSigns, please use:'),
                      SizedBox(height: 2),
                      Text('• Upload .atKeys file option'),
                      Text('• QR code/Authenticator option'),
                    ],
                  ),
                  backgroundColor: Colors.orange[700],
                  duration: const Duration(seconds: 8),
                  action: SnackBarAction(
                    label: 'Got it',
                    textColor: Colors.white,
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                  ),
                ),
              );
            }
            return;
          }

          // Provide more helpful error messages for other common issues
          if (errorMessage.contains('Unknown error')) {
            errorMessage =
                'Onboarding failed. This might be because:\n'
                '• The atSign is already registered to someone else\n'
                '• Network connection issues\n\n'
                'Try getting a new atSign from atsign.com';
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Get atSign',
                  textColor: Colors.white,
                  onPressed: () {
                    // You could add a web launch to atsign.com here
                  },
                ),
              ),
            );
          }
          break;

        case AtOnboardingResultStatus.cancel:
          print('Onboarding cancelled by user');
          // User cancelled onboarding - no action needed
          break;
      }
    } catch (e) {
      print('Exception during onboarding: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
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

      // Get the atClient preference
      final atClientPreference = AtTalkService.instance.atClientPreference;
      if (atClientPreference == null) {
        throw Exception('AtClient not initialized. Please restart the app.');
      }

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
          print('Authentication successful, navigating to groups...');
          Navigator.pushReplacementNamed(context, '/groups');
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

  // Start onboarding using QR code or authenticator app
  Future<void> _startAuthenticatorOnboarding(String atSign, String domain) async {
    if (atSign.isEmpty) {
      print('No atSign provided, cannot start authenticator onboarding');
      return;
    }

    print('Starting authenticator onboarding for: $atSign with domain: $domain');

    try {
      final atClientPreference = AtTalkService.instance.atClientPreference;
      if (atClientPreference == null) {
        throw Exception('AtClient not initialized. Please restart the app.');
      }

      final config = AtOnboardingConfig(
        atClientPreference: atClientPreference,
        domain: domain,
        rootEnvironment: AtTalkEnv.rootEnvironment,
        appAPIKey: AtTalkEnv.appApiKey,
      );

      // Use the AtOnboarding.onboard method with QR code/authenticator flow
      final result = await AtOnboarding.onboard(
        context: context,
        atsign: atSign,
        config: config,
        // This should enable QR code scanning or authenticator-based onboarding
      );

      print('Authenticator onboarding result: ${result.status}');

      switch (result.status) {
        case AtOnboardingResultStatus.success:
          print('Authenticator onboarding successful for: ${result.atsign}');

          // Save the atSign information for future use
          if (result.atsign != null) {
            await saveAtsignInformation(AtsignInformation(atSign: result.atsign!, rootDomain: domain));
            print('Saved atSign information');
          }

          print('Authenticating with AuthProvider...');
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.authenticate(result.atsign);

          if (mounted && authProvider.isAuthenticated) {
            print('Authentication successful, navigating to groups...');
            Navigator.pushReplacementNamed(context, '/groups');
          } else {
            print('Authentication failed after authenticator onboarding');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Authentication failed after authenticator setup. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          break;

        case AtOnboardingResultStatus.error:
          print('Authenticator onboarding error: ${result.message}');
          String errorMessage = result.message ?? 'Authenticator onboarding failed';

          // Provide more specific error messages
          if (errorMessage.contains('QR code') || errorMessage.contains('scan')) {
            errorMessage = 'Failed to scan QR code. Please ensure the QR code is clear and try again.';
          } else if (errorMessage.contains('Invalid') || errorMessage.contains('format')) {
            errorMessage = 'Invalid QR code or activation key. Please get a new one from the atSign authenticator app.';
          } else if (errorMessage.contains('timeout') || errorMessage.contains('expired')) {
            errorMessage = 'The QR code or activation key has expired. Please generate a new one.';
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 8)),
            );
          }
          break;

        case AtOnboardingResultStatus.cancel:
          print('Authenticator onboarding cancelled by user');
          // User cancelled - no action needed
          break;
      }
    } catch (e) {
      print('Exception during authenticator onboarding: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error with authenticator onboarding: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
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
  String _selectedRootDomain = 'root.atsign.org'; // Default to production (non-nullable)

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
              decoration: const InputDecoration(labelText: 'Root Domain', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'root.atsign.org', child: Text('Production (root.atsign.org)')),
                DropdownMenuItem(value: 'vip.ve.atsign.zone', child: Text('VIP (vip.ve.atsign.zone)')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRootDomain = value ?? 'root.atsign.org';
                });
              },
            ),

            const SizedBox(height: 24),

            const Text(
              'How would you like to add this atSign?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose the method that matches your situation:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        const SizedBox(width: 8),
        // Method buttons in a row for better UX
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isFormValid
                        ? () {
                            final atSign = _atSignController.text.startsWith('@')
                                ? _atSignController.text
                                : '@${_atSignController.text}';
                            Navigator.of(context).pop('onboard:$_selectedRootDomain:$atSign');
                          }
                        : null,
                    icon: const Icon(Icons.add_circle, size: 16),
                    label: const Text('New atSign', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isFormValid
                        ? () {
                            final atSign = _atSignController.text.startsWith('@')
                                ? _atSignController.text
                                : '@${_atSignController.text}';
                            Navigator.of(context).pop('upload:$_selectedRootDomain:$atSign');
                          }
                        : null,
                    icon: const Icon(Icons.file_upload, size: 16),
                    label: const Text('.atKeys File', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isFormValid
                        ? () {
                            final atSign = _atSignController.text.startsWith('@')
                                ? _atSignController.text
                                : '@${_atSignController.text}';
                            Navigator.of(context).pop('authenticator:$_selectedRootDomain:$atSign');
                          }
                        : null,
                    icon: const Icon(Icons.qr_code_scanner, size: 16),
                    label: const Text('QR/Authenticator', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
