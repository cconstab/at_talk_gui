import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
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
      // Handle the result from the dialog
      if (result.startsWith('onboard:')) {
        final atSign = result.substring(8);
        await _startOnboarding(atSign);
      } else if (result.startsWith('upload:')) {
        final atSign = result.substring(7);
        await _startAtKeysUpload(atSign);
      }
    }

    // Refresh the available atSigns after any onboarding operation
    await _loadAvailableAtSigns();
  }

  // Start onboarding for a new atSign
  Future<void> _startOnboarding(String atSign) async {
    if (atSign.isEmpty) {
      print('No atSign provided, cannot start onboarding');
      return;
    }

    print('Starting onboarding for: $atSign');

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
          domain: AtTalkEnv.rootDomain,
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
            await saveAtsignInformation(AtsignInformation(atSign: result.atsign!, rootDomain: AtTalkEnv.rootDomain));
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
            print('AtSign appears to be already registered, prompting for .atKeys file');
            _promptForAtKeysFile(atSign);
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

  Future<void> _promptForAtKeysFile(String atSign) async {
    if (!mounted) return;

    final shouldProceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('atSign Already Registered'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$atSign is already registered!', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              const Text(
                'This atSign has already been activated. To use it, you\'ll need to authenticate with your .atKeys file.',
              ),
              const SizedBox(height: 16),
              const Text('You can find your .atKeys file:', style: TextStyle(fontWeight: FontWeight.w500)),
              const Text('• Downloaded from my.atsign.com'),
              const Text('• In your previous atSign backup'),
              const Text('• Shared from another device'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.file_upload),
              label: const Text('Import .atKeys'),
            ),
          ],
        );
      },
    );

    if (shouldProceed == true) {
      _startAtKeysUpload(atSign);
    }
  }

  Future<void> _startAtKeysUpload(String atSign) async {
    if (atSign.isEmpty) {
      print('No atSign provided, cannot start .atKeys upload');
      return;
    }

    print('Starting .atKeys upload for: $atSign');

    try {
      final atClientPreference = AtTalkService.instance.atClientPreference;
      if (atClientPreference == null) {
        throw Exception('AtClient not initialized. Please restart the app.');
      }

      final config = AtOnboardingConfig(
        atClientPreference: atClientPreference,
        domain: AtTalkEnv.rootDomain,
        rootEnvironment: AtTalkEnv.rootEnvironment,
        appAPIKey: AtTalkEnv.appApiKey,
      );

      // Use the proper AtOnboarding.onboard method with isSwitchingAtsign
      final result = await AtOnboarding.onboard(
        context: context,
        atsign: atSign,
        isSwitchingAtsign: true, // This enables .atKeys file import
        config: config,
      );

      print('AtKeys upload result: ${result.status}');

      switch (result.status) {
        case AtOnboardingResultStatus.success:
          print('AtKeys upload successful for: ${result.atsign}');

          // Save the atSign information for future use
          if (result.atsign != null) {
            await saveAtsignInformation(AtsignInformation(atSign: result.atsign!, rootDomain: AtTalkEnv.rootDomain));
            print('Saved atSign information');
          }

          print('Authenticating with AuthProvider...');
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.authenticate(result.atsign);

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
          break;

        case AtOnboardingResultStatus.error:
          print('AtKeys upload error: ${result.message}');
          String errorMessage = result.message ?? 'Failed to upload .atKeys file';

          // Provide more specific error messages
          if (errorMessage.contains('key file not found') || errorMessage.contains('FileSystemException')) {
            errorMessage =
                'The selected .atKeys file could not be read. Please ensure the file exists and is accessible.';
          } else if (errorMessage.contains('Invalid key file') || errorMessage.contains('format')) {
            errorMessage =
                'The selected file is not a valid .atKeys file. Please select a valid .atKeys file for $atSign.';
          } else if (errorMessage.contains('AtSign mismatch')) {
            errorMessage =
                'The .atKeys file is for a different atSign. Please select the correct .atKeys file for $atSign.';
          } else if (errorMessage.contains('already activated') || errorMessage.contains('already exists')) {
            errorMessage =
                'This atSign has already been activated on this device. You can continue using it from the main screen.';
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 8)),
            );
          }
          break;

        case AtOnboardingResultStatus.cancel:
          print('AtKeys upload cancelled by user');
          // User cancelled - no action needed
          break;
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
}

// NoPorts-style onboarding dialog
class _OnboardingDialog extends StatefulWidget {
  const _OnboardingDialog();

  @override
  State<_OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<_OnboardingDialog> {
  final TextEditingController _atSignController = TextEditingController();
  String? _selectedRootDomain = AtTalkEnv.rootDomain;

  @override
  void dispose() {
    _atSignController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.rocket_launch, color: Colors.blue),
          SizedBox(width: 8),
          Text('Get Started with atSign'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your atSign to begin:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),

            TextFormField(
              controller: _atSignController,
              decoration: const InputDecoration(
                labelText: 'atSign',
                hintText: 'e.g. @alice',
                prefixIcon: Icon(Icons.alternate_email),
                border: OutlineInputBorder(),
              ),
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
                  _selectedRootDomain = value;
                });
              },
            ),

            const SizedBox(height: 16),

            const Text(
              'Choose your authentication method:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Activate new atSign - For first-time setup\n'
              '• Upload .atKeys file - If you have existing keys\n'
              '• Use authenticator/manager - From another device',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: _atSignController.text.isNotEmpty
              ? () {
                  final atSign = _atSignController.text.startsWith('@')
                      ? _atSignController.text
                      : '@${_atSignController.text}';
                  Navigator.of(context).pop('onboard:$atSign');
                }
              : null,
          icon: const Icon(Icons.add_circle),
          label: const Text('Activate'),
        ),
        ElevatedButton.icon(
          onPressed: _atSignController.text.isNotEmpty
              ? () {
                  final atSign = _atSignController.text.startsWith('@')
                      ? _atSignController.text
                      : '@${_atSignController.text}';
                  Navigator.of(context).pop('upload:$atSign');
                }
              : null,
          icon: const Icon(Icons.file_upload),
          label: const Text('Upload Keys'),
        ),
      ],
    );
  }
}
