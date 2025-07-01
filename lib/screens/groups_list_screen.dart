import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/groups_provider.dart';
import '../providers/auth_provider.dart';
import '../models/group.dart';
import 'group_chat_screen.dart';

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
    // Initialize groups provider
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('atTalk Groups'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
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
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Text('Clear All Groups'),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Consumer<GroupsProvider>(
        builder: (context, groupsProvider, child) {
          if (!groupsProvider.isConnected) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Waiting for messages...',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your groups will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final groups = groupsProvider.sortedGroups;

          if (groups.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start a new group or wait for messages to arrive',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
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
    // Mark group as read when opening
    Provider.of<GroupsProvider>(
      context,
      listen: false,
    ).markGroupAsRead(group.id);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GroupChatScreen(group: group)),
    );
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
                // Close the dialog first
                Navigator.pop(context);
                // Then create the group
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
            const Text('Enter the atSign to chat with:'),
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
                // Close the dialog first
                Navigator.pop(context);
                // Then start the chat
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
    // Normalize the atSign
    final normalizedAtSign = atSign.startsWith('@') ? atSign : '@$atSign';

    // Create a 1-on-1 chat as a 2-member group
    _createNewGroup(normalizedAtSign, null);
  }

  void _createNewGroup(String input, String? groupName) {
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentAtSign = authProvider.currentAtSign;

    if (currentAtSign == null) return;

    // Parse multiple atSigns from comma-separated input
    final inputAtSigns = input
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((atSign) => atSign.startsWith('@') ? atSign : '@$atSign')
        .toSet();

    // Add current user to the group
    final members = {currentAtSign, ...inputAtSigns};

    // Ensure we have at least 2 members (current user + at least 1 other)
    if (members.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one valid atSign'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Generate a unique instance ID for the new group to avoid overwriting existing groups
    // This ensures compatibility with TUI behavior where /new creates new group instances
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sortedMembers = members.toList()..sort();
    final baseId = sortedMembers.join('_');
    final uniqueInstanceId = '${baseId}_$timestamp';

    final group = groupsProvider.createOrUpdateGroup(
      members,
      instanceId: uniqueInstanceId,
      name: groupName?.isNotEmpty == true ? groupName : null,
    );

    print('🆕 Created new group: ID=$uniqueInstanceId, members=$members');

    if (group != null) {
      // Show success message
      final memberCount = members.length - 1; // Exclude current user from count
      final groupDisplayName = group.displayName;
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group.displayName),
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
            child: const Text('Close'),
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
          'Are you sure you want to delete "${group.displayName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<GroupsProvider>(
                context,
                listen: false,
              ).deleteGroup(group.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
          'Are you sure you want to delete all groups and messages?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<GroupsProvider>(
                context,
                listen: false,
              ).clearAllGroups();
              Navigator.pop(context);
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

  void _logout() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout();
    Navigator.pushReplacementNamed(context, '/onboarding');
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
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF2196F3),
        child: Text(
          group.displayName.substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        group.displayName,
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
