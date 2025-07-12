import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/providers/groups_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/at_talk_service.dart';
import '../../core/models/group.dart';
import '../../core/utils/atsign_manager.dart';
import '../widgets/key_management_dialog.dart';
import 'group_chat_screen.dart';

/// Version of GroupsListScreen that integrates with side panel
class GroupsListScreenWithSidePanel extends StatefulWidget {
  final Function(Group)? onGroupSelected;
  final bool showMenuButton;
  final VoidCallback? onMenuPressed;

  const GroupsListScreenWithSidePanel({
    super.key,
    this.onGroupSelected,
    this.showMenuButton = false,
    this.onMenuPressed,
  });

  @override
  State<GroupsListScreenWithSidePanel> createState() =>
      _GroupsListScreenWithSidePanelState();
}

class _GroupsListScreenWithSidePanelState
    extends State<GroupsListScreenWithSidePanel> {
  final TextEditingController _newGroupController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();

  @override
  void dispose() {
    _newGroupController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final currentAtSign =
                authProvider.currentAtSign ??
                AtTalkService.instance.currentAtSign ??
                'Unknown';
            return GestureDetector(
              onTap: _showAtSignMenu,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currentAtSign,
                        style: const TextStyle(
                          fontSize: 20, // Base font size
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            );
          },
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        leading: widget.showMenuButton && widget.onMenuPressed != null
            ? IconButton(
                onPressed: widget.onMenuPressed,
                icon: const Icon(Icons.menu),
                tooltip: 'Show conversations',
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _showNewChatDialog,
            icon: const Icon(Icons.person_add),
            tooltip: 'Start 1-on-1 Chat',
          ),
          IconButton(
            onPressed: _showNewGroupDialog,
            icon: const Icon(Icons.group_add),
            tooltip: 'New Group',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'clear_all') {
                _clearAllGroups();
              } else if (value == 'key_management') {
                _showKeyManagement();
              } else if (value == 'switch_atsign') {
                _showAtSignSwitcher();
              } else if (value == 'settings') {
                Navigator.pushNamed(context, '/settings');
              } else if (value == 'exit_app') {
                _exitApp();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'switch_atsign',
                child: Row(
                  children: [
                    Icon(Icons.switch_account, size: 20),
                    SizedBox(width: 8),
                    Text('Switch atSign'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'key_management',
                child: Row(
                  children: [
                    Icon(Icons.key, size: 20),
                    SizedBox(width: 8),
                    Text('Key Management'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 20),
                    SizedBox(width: 8),
                    Text('Clear All Groups'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'exit_app',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Exit App', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<GroupsProvider>(
        builder: (context, groupsProvider, child) {
          final groups = groupsProvider.sortedGroups;

          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start a new conversation or create a group',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showNewChatDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Start Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _showNewGroupDialog,
                        icon: const Icon(Icons.group_add),
                        label: const Text('New Group'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return GroupListTile(
                group: group,
                onTap: () => _openGroupChat(group),
                onLongPress: () => _showGroupOptions(group),
              );
            },
          );
        },
      ),
    );
  }

  void _openGroupChat(Group group) {
    // If we have a callback for group selection (side panel mode), use it
    if (widget.onGroupSelected != null) {
      widget.onGroupSelected!(group);
    } else {
      // Otherwise, navigate to group chat screen normally
      Provider.of<GroupsProvider>(
        context,
        listen: false,
      ).markGroupAsRead(group.id);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GroupChatScreen(group: group)),
      );
    }
  }

  void _showAtSignMenu() {
    _showAtSignSwitcher();
  }

  void _showNewGroupDialog() {
    _newGroupController.clear();
    _groupNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Group Name (optional):'),
              const SizedBox(height: 8),
              TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  hintText: 'My awesome group',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              const Text('Members (comma-separated):'),
              const SizedBox(height: 8),
              const Text(
                'Example: @alice, @bob, @charlie',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newGroupController,
                decoration: const InputDecoration(
                  labelText: 'atSigns (e.g., @alice, @bob)',
                  hintText: '@alice, @bob',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                maxLines: 3,
                minLines: 1,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final members = _newGroupController.text.trim();
              final groupName = _groupNameController.text.trim();
              if (members.isNotEmpty) {
                Navigator.pop(context);
                _createNewGroup(members, groupName);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog() {
    final TextEditingController chatController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start 1-on-1 Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter atSign:'),
            const SizedBox(height: 8),
            const Text(
              'Example: @alice',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: chatController,
              decoration: const InputDecoration(
                labelText: 'atSign (e.g., @alice)',
                hintText: '@alice',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final atSign = chatController.text.trim();
              if (atSign.isNotEmpty) {
                Navigator.pop(context);
                _startOneOnOneChat(atSign);
              }
            },
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  void _startOneOnOneChat(String atSign) {
    final normalizedAtSign = atSign.startsWith('@') ? atSign : '@$atSign';
    // For 2-member groups, we can create them without an explicit name
    // The Group.getDisplayName() method will handle showing just the other person's name
    _createNewGroup(normalizedAtSign, null);
  }

  void _createNewGroup(String input, String? groupName) async {
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentAtSign = authProvider.currentAtSign;

    if (currentAtSign == null) return;

    final inputAtSigns = input
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((atSign) => atSign.startsWith('@') ? atSign : '@$atSign')
        .toSet();

    final members = {currentAtSign, ...inputAtSigns};

    if (members.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one valid atSign'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final groupId = await groupsProvider.createNewGroupWithUniqueId(
      members,
      name: groupName?.isNotEmpty == true ? groupName : null,
    );

    final group = groupsProvider.groups[groupId];
    if (group != null) {
      final memberCount = members.length - 1;
      final currentAtSign = AtTalkService.instance.currentAtSign;
      final groupDisplayName = group.getDisplayName(currentAtSign);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created group "$groupDisplayName" with $memberCount member${memberCount == 1 ? '' : 's'}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _openGroupChat(group);
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              authProvider.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/onboarding');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _clearAllGroups() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Groups'),
        content: const Text(
          'This will remove all groups and messages. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<GroupsProvider>(
                context,
                listen: false,
              ).clearAllGroups();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All groups cleared'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showKeyManagement() {
    final currentAtSign = AtTalkService.instance.currentAtSign;
    if (currentAtSign == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No atSign is currently active'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => KeyManagementDialog(atSign: currentAtSign),
    );
  }

  void _showAtSignSwitcher() {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<Map<String, AtsignInformation>>(
        future: getAtsignEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              title: Text('Switch atSign'),
              content: Center(child: CircularProgressIndicator()),
            );
          }

          final atSignsInfo = snapshot.data ?? {};
          final atSigns = atSignsInfo.keys.toList();
          final currentAtSign = AtTalkService.instance.currentAtSign;
          final availableAtSigns = atSigns
              .where((atSign) => atSign != currentAtSign)
              .toList();

          if (availableAtSigns.isEmpty) {
            return AlertDialog(
              title: const Text('Switch atSign'),
              content: Text(
                atSigns.isEmpty
                    ? 'No atSigns found in storage.'
                    : 'No other atSigns available. Current: $currentAtSign',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Switch atSign'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: availableAtSigns
                  .map(
                    (atSign) => ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(atSign),
                      subtitle: Text(atSignsInfo[atSign]?.rootDomain ?? ''),
                      onTap: () async {
                        Navigator.pop(context);
                        // Use AuthProvider to switch to existing atSign
                        final authProvider = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        final groupsProvider = Provider.of<GroupsProvider>(
                          context,
                          listen: false,
                        );

                        try {
                          // Show loading indicator
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Switching to $atSign...'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }

                          // Clear existing groups and reinitialize for new atSign
                          groupsProvider.clearAllGroups();

                          // Get the saved domain for this atSign
                          final savedDomain = atSignsInfo[atSign]?.rootDomain;
                          print(
                            '🔄 Switching to $atSign with domain: $savedDomain',
                          );

                          // Authenticate with the selected atSign and its saved domain
                          await authProvider.authenticateExisting(
                            atSign,
                            cleanupExisting: true,
                            rootDomain: savedDomain,
                          );

                          // Reinitialize groups provider for the new atSign
                          groupsProvider.reinitialize();

                          // Wait a moment for UI to update
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );

                          // Force widget rebuild
                          if (mounted) {
                            setState(() {});
                          }

                          // Show success message
                          if (mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Switched to $atSign'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          // Show error message
                          if (mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to switch atSign: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _exitApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showGroupOptions(Group group) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Group Info'),
            onTap: () {
              Navigator.pop(context);
              _showGroupInfo(group);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text(
              'Delete Group',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              _deleteGroup(group);
            },
          ),
        ],
      ),
    );
  }

  void _showGroupInfo(Group group) {
    final currentAtSign = AtTalkService.instance.currentAtSign;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group.getDisplayName(currentAtSign)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Members (${group.members.length}):'),
            const SizedBox(height: 8),
            ...group.members.map((member) => Text('• $member')),
            if (group.lastMessage != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Last Message:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(group.lastMessage!),
              if (group.lastMessageTime != null)
                Text(
                  DateFormat(
                    'MMM d, yyyy HH:mm',
                  ).format(group.lastMessageTime!),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _deleteGroup(Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
          'Are you sure you want to delete "${group.getDisplayName(AtTalkService.instance.currentAtSign)}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<GroupsProvider>(
                context,
                listen: false,
              ).deleteGroup(group.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Deleted group "${group.getDisplayName(AtTalkService.instance.currentAtSign)}"',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Keep the original GroupsListScreen for backward compatibility
class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({super.key});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  final TextEditingController _newGroupController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupsProvider>(context, listen: false).initialize();
    });
  }

  @override
  void dispose() {
    _newGroupController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Simply wrap the original implementation with the side panel version
    return const GroupsListScreenWithSidePanel();
  }
}

class GroupListTile extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const GroupListTile({
    super.key,
    required this.group,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final currentAtSign = AtTalkService.instance.currentAtSign;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF2196F3),
        child: Text(
          group.getDisplayName(currentAtSign).substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        group.getDisplayName(currentAtSign),
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: group.lastMessage != null
          ? Text(
              group.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: group.unreadCount > 0
                    ? Colors.black87
                    : Colors.grey[600],
                fontWeight: group.unreadCount > 0
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
            )
          : const Text('No messages yet', style: TextStyle(color: Colors.grey)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (group.lastMessageTime != null)
            Text(
              _formatTime(group.lastMessageTime!),
              style: TextStyle(
                color: group.unreadCount > 0
                    ? const Color(0xFF2196F3)
                    : Colors.grey,
                fontSize: 12,
                fontWeight: group.unreadCount > 0
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
            ),
          if (group.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                group.unreadCount > 99 ? '99+' : group.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return DateFormat('MMM d').format(time);
    } else {
      return DateFormat('HH:mm').format(time);
    }
  }
}
