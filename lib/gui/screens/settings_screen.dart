import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/groups_provider.dart';
import '../../core/services/at_talk_service.dart';
import '../../core/utils/atsign_manager.dart';
import '../widgets/key_management_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, AtsignInformation> _availableAtSigns = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAtSignsInfo();
  }

  Future<void> _loadAtSignsInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final atSigns = await getAtsignEntries();
      setState(() {
        _availableAtSigns = atSigns;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load atSigns: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAtSign = AtTalkService.instance.currentAtSign;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current AtSign Section
                  _buildSectionCard(
                    title: 'Current atSign',
                    icon: Icons.account_circle,
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF2196F3),
                          child: Text(
                            currentAtSign?.substring(1, 2).toUpperCase() ?? '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(currentAtSign ?? 'Unknown'),
                        subtitle:
                            currentAtSign != null &&
                                _availableAtSigns.containsKey(currentAtSign)
                            ? Text(
                                'Domain: ${_availableAtSigns[currentAtSign]!.rootDomain}',
                              )
                            : const Text('Domain: Unknown'),
                        trailing: IconButton(
                          onPressed: currentAtSign != null
                              ? () => _showKeyManagement(currentAtSign)
                              : null,
                          icon: const Icon(Icons.settings),
                          tooltip: 'Manage Keys',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // All AtSigns Section
                  _buildSectionCard(
                    title: 'All atSigns',
                    icon: Icons.people,
                    children: [
                      if (_availableAtSigns.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'No atSigns found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ..._availableAtSigns.entries.map((entry) {
                          final atSign = entry.key;
                          final info = entry.value;
                          final isCurrent = atSign == currentAtSign;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isCurrent
                                  ? const Color(0xFF2196F3)
                                  : Colors.grey,
                              child: Text(
                                atSign.substring(1, 2).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(atSign)),
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Active',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text('Domain: ${info.rootDomain}'),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'manage':
                                    _showKeyManagement(atSign);
                                    break;
                                  case 'switch':
                                    _switchToAtSign(atSign);
                                    break;
                                  case 'remove':
                                    _confirmRemoveAtSign(atSign);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'manage',
                                  child: Row(
                                    children: [
                                      Icon(Icons.vpn_key, size: 18),
                                      SizedBox(width: 8),
                                      Text('Manage Keys'),
                                    ],
                                  ),
                                ),
                                if (!isCurrent)
                                  const PopupMenuItem(
                                    value: 'switch',
                                    child: Row(
                                      children: [
                                        Icon(Icons.switch_account, size: 18),
                                        SizedBox(width: 8),
                                        Text('Switch To'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Remove',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                      const Divider(),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.add, color: Colors.white),
                        ),
                        title: const Text('Add New atSign'),
                        onTap: () {
                          Navigator.pushNamed(context, '/onboarding');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // App Configuration Section
                  _buildSectionCard(
                    title: 'App Configuration',
                    icon: Icons.tune,
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.folder_outlined,
                          color: Colors.purple,
                        ),
                        title: const Text('Namespace'),
                        subtitle: Text(
                          'Current: ${AtTalkService.instance.currentNamespace}',
                        ),
                        onTap: () => _showNamespaceDialog(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // App Actions Section
                  _buildSectionCard(
                    title: 'App Actions',
                    icon: Icons.settings,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.refresh, color: Colors.blue),
                        title: const Text('Refresh atSigns'),
                        subtitle: const Text('Reload atSign information'),
                        onTap: _loadAtSignsInfo,
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.orange),
                        title: const Text('Logout'),
                        subtitle: const Text('Sign out of current atSign'),
                        onTap: _logout,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // App Info
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'atTalk',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Secure messaging powered by atPlatform',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF2196F3)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2196F3),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  void _showKeyManagement(String atSign) {
    showDialog(
      context: context,
      builder: (context) => KeyManagementDialog(atSign: atSign),
    ).then((_) {
      // Refresh the atSigns list after key management
      _loadAtSignsInfo();
    });
  }

  void _switchToAtSign(String atSign) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Switching atSign...'),
          ],
        ),
      ),
    );

    try {
      // Clear current state first
      authProvider.logout();
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Give time for cleanup

      // Load the saved domain for this atSign
      String? savedDomain;
      try {
        final atSignInfo = _availableAtSigns[atSign];
        savedDomain = atSignInfo?.rootDomain;
        print('🔄 Switching to $atSign with saved domain: $savedDomain');
      } catch (e) {
        print('⚠️ Failed to load domain for $atSign, using default: $e');
      }

      // Authenticate directly with the known atSign and its domain
      print('🔑 Authenticating with $atSign...');
      await authProvider.authenticateExisting(atSign, rootDomain: savedDomain);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        if (authProvider.isAuthenticated) {
          // Switch successful - go to groups screen which will reinitialize providers
          Navigator.pushReplacementNamed(context, '/groups');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Switched to $atSign'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Authentication failed - show error and stay on settings
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to switch to $atSign: ${authProvider.errorMessage ?? "Unknown error"}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch atSign: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmRemoveAtSign(String atSign) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove atSign'),
        content: Text(
          'Are you sure you want to remove $atSign?\n\n'
          'This will delete all keys and data for this atSign from this device. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeAtSign(atSign);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _removeAtSign(String atSign) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Removing atSign...'),
          ],
        ),
      ),
    );

    try {
      // Use comprehensive cleanup for complete removal
      await AtTalkService.completeAtSignCleanup(atSign);

      // Remove from atsign information
      await removeAtsignInformation(atSign);

      // If we're removing the current atSign, logout
      final currentAtSign = AtTalkService.instance.currentAtSign;
      if (atSign == currentAtSign) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.logout();
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$atSign removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAtSignsInfo(); // Refresh the list

        // If we removed the current atSign, go to onboarding
        if (atSign == currentAtSign) {
          Navigator.pushReplacementNamed(context, '/onboarding');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove atSign: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              authProvider.logout();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/onboarding',
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showNamespaceDialog() {
    final currentNamespace = AtTalkService.instance.currentNamespace;
    final controller = TextEditingController();

    // Extract the base namespace (remove .attalk suffix if present)
    String baseNamespace = currentNamespace;
    if (baseNamespace.endsWith('.attalk')) {
      baseNamespace = baseNamespace.substring(0, baseNamespace.length - 7);
    }
    controller.text = baseNamespace;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder_outlined, color: Color(0xFF2196F3)),
            SizedBox(width: 8),
            Text('Change Namespace'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Namespace determines the storage directory and message isolation. '
              'Similar to TUI\'s -n option.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Namespace',
                hintText: 'e.g., default, work, personal',
                border: OutlineInputBorder(),
                helperText: 'Will automatically append .attalk',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Full namespace: ${controller.text.isEmpty ? 'default' : controller.text}.attalk',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newNamespace = controller.text.trim().isEmpty
                  ? 'default'
                  : controller.text.trim();
              Navigator.of(context).pop();
              await _changeNamespace(newNamespace);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeNamespace(String newNamespace) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);
    final currentAtSign = authProvider.currentAtSign;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Changing namespace...'),
          ],
        ),
      ),
    );

    try {
      // Step 1: Clear all groups data and stop subscriptions
      print('🧹 Clearing groups data for namespace change...');
      // Note: Don't clear here, let reinitialize handle it after AtClient is ready

      // Step 2: Change namespace and reinitialize AtClient
      final success = await AtTalkService.instance.changeNamespace(
        newNamespace,
        currentAtSign,
      );

      if (!success) {
        throw Exception('Failed to change namespace');
      }

      // Step 3: If user is authenticated, re-authenticate with new namespace
      if (currentAtSign != null) {
        print('🔄 Re-authenticating $currentAtSign with new namespace...');

        // Load the saved domain for this atSign
        String? savedDomain;
        try {
          final atSignInfo = _availableAtSigns[currentAtSign];
          savedDomain = atSignInfo?.rootDomain;
          print('Using saved domain for namespace change: $savedDomain');
        } catch (e) {
          print(
            '⚠️ Failed to load domain for $currentAtSign during namespace change, using default: $e',
          );
        }

        await authProvider.authenticateExisting(
          currentAtSign,
          cleanupExisting: false,
          rootDomain: savedDomain,
        );

        if (!authProvider.isAuthenticated) {
          throw Exception('Failed to re-authenticate with new namespace');
        }

        print('✅ Re-authentication successful with new namespace');

        // Step 4: Reinitialize GroupsProvider with new namespace
        print('🔄 Reinitializing GroupsProvider with new namespace...');
        groupsProvider.reinitialize();
        print('✅ GroupsProvider reinitialized with new namespace');
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Refresh the UI to show new namespace
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Namespace changed to: ${AtTalkService.instance.currentNamespace}',
            ),
            backgroundColor: Colors.green,
          ),
        );

        print('✅ Namespace change completed successfully');
      }
    } catch (e) {
      print('❌ Namespace change failed: $e');

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change namespace: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
