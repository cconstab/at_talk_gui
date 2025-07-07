import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/providers/groups_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/at_talk_service.dart';
import '../../core/models/group.dart';
import '../../core/models/chat_message.dart';

class GroupChatScreen extends StatefulWidget {
  final Group group;
  final VoidCallback? onBack;
  final bool showMenuButton;
  final VoidCallback? onMenuPressed;

  const GroupChatScreen({
    super.key,
    required this.group,
    this.onBack,
    this.showMenuButton = false,
    this.onMenuPressed,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _addMemberController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _shouldMaintainFocus = false;
  GroupsProvider?
  _groupsProvider; // Store reference to avoid context lookup in dispose

  @override
  void initState() {
    super.initState();
    // Request focus when the screen first loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageFocusNode.requestFocus();
      _shouldMaintainFocus = true;

      // Set up listener for message changes to auto-scroll
      _groupsProvider = Provider.of<GroupsProvider>(context, listen: false);
      _groupsProvider?.addListener(_scrollToBottom);

      // Mark this group as read when entering the chat
      _groupsProvider?.markGroupAsRead(widget.group.id);
    });
  }

  @override
  void dispose() {
    // Use stored reference instead of context lookup
    _groupsProvider?.removeListener(_scrollToBottom);
    _messageController.dispose();
    _scrollController.dispose();
    _addMemberController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentAtSign = AtTalkService.instance.currentAtSign;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Consumer<GroupsProvider>(
          builder: (context, groupsProvider, child) {
            // Get the updated group from the provider
            final updatedGroup =
                groupsProvider.groups[widget.group.id] ?? widget.group;

            return Row(
              children: [
                Hero(
                  tag: 'avatar_${updatedGroup.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        updatedGroup
                            .getDisplayName(currentAtSign)
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        updatedGroup.getDisplayName(currentAtSign),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${updatedGroup.members.length} members',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        leading: widget.onBack != null
            ? Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  tooltip: 'Back to conversations',
                  padding: EdgeInsets.zero,
                ),
              )
            : widget.showMenuButton && widget.onMenuPressed != null
            ? Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: widget.onMenuPressed,
                  icon: const Icon(Icons.menu_rounded, size: 20),
                  tooltip: 'Show conversations',
                  padding: EdgeInsets.zero,
                ),
              )
            : null,
        automaticallyImplyLeading:
            widget.onBack == null && !widget.showMenuButton,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: _showAddMemberDialog,
              icon: const Icon(Icons.person_add_rounded, size: 20),
              tooltip: 'Add member',
              padding: const EdgeInsets.all(8),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'rename') {
                  _showRenameGroupDialog();
                } else if (value == 'info') {
                  _showGroupInfo();
                } else if (value == 'leave') {
                  _showLeaveGroupDialog();
                }
              },
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Colors.white,
                size: 20,
              ),
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Theme.of(context).colorScheme.surface,
              elevation: 8,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Rename Group',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Group Info',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(
                        Icons.exit_to_app_rounded,
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Leave Group',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Consumer<GroupsProvider>(
              builder: (context, groupsProvider, child) {
                final messages = groupsProvider.getGroupMessages(
                  widget.group.id,
                );

                // Maintain focus after widget rebuilds due to new messages
                if (_shouldMaintainFocus && !_messageFocusNode.hasFocus) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _shouldMaintainFocus) {
                      _messageFocusNode.requestFocus();
                    }
                  });
                }

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                // Use reversed messages for reverse ListView (newest at bottom)
                final reversedMessages = messages.reversed.toList();

                return ListView.builder(
                  controller: _scrollController,
                  reverse:
                      true, // This makes the ListView start from the bottom
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 32, // Top padding since we're reversed
                    bottom: 16,
                  ),
                  itemCount: reversedMessages.length,
                  itemBuilder: (context, index) {
                    final message = reversedMessages[index];
                    return ChatBubble(message: message);
                  },
                );
              },
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface.withOpacity(0.95),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.1),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                            size: 20,
                          ),
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onSubmitted: (text) => _sendMessage(),
                      onTap: () {
                        // User intentionally tapped the text field, ensure focus maintenance is enabled
                        _shouldMaintainFocus = true;
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _sendMessage,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    // For reverse ListView, scroll to position 0 (which is the bottom)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Mark group as read when scrolling (indicating user activity)
        _groupsProvider?.markGroupAsRead(widget.group.id);

        // Add a small additional delay to ensure all widgets are rendered
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0, // For reverse ListView, 0 is the bottom
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);
    final success = await groupsProvider.sendMessageToGroup(
      widget.group.id,
      text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }

    // Ensure focus maintenance is enabled and refocus the input field
    _shouldMaintainFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _messageFocusNode.requestFocus();
      }
    });
    _scrollToBottom();
  }

  void _showRenameGroupDialog() {
    _shouldMaintainFocus = false; // Disable focus maintenance during dialog
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);

    // Get the updated group from the provider
    final updatedGroup = groupsProvider.groups[widget.group.id] ?? widget.group;
    final currentName = updatedGroup.name ?? '';
    final renameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
          controller: renameController,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            hintText: 'Enter group name',
          ),
          autofocus: true,
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              renameController.dispose();
              // Re-enable focus maintenance after dialog closes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _shouldMaintainFocus = true;
                _messageFocusNode.requestFocus();
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = renameController.text.trim();
              _renameGroup(newName);
              Navigator.pop(context);
              renameController.dispose();
              // Re-enable focus maintenance after dialog closes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _shouldMaintainFocus = true;
                _messageFocusNode.requestFocus();
              });
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _renameGroup(String newName) async {
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);

    final newGroupId = await groupsProvider.renameGroup(
      widget.group.id,
      newName,
    );

    if (newGroupId != null && mounted) {
      final displayText = newName.isNotEmpty ? newName : 'Unnamed Group';

      // In the current architecture, group ID never changes during rename
      // (only display name changes), so we just show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Group renamed to "$displayText"'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to rename group. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLeaveGroupDialog() {
    _shouldMaintainFocus = false; // Disable focus maintenance during dialog

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text(
          'Are you sure you want to leave this group? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Re-enable focus maintenance after dialog closes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _shouldMaintainFocus = true;
                _messageFocusNode.requestFocus();
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _leaveGroup();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _leaveGroup() async {
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentAtSign;

    if (currentUser == null) return;

    // Remove current user from group members
    final updatedMembers = Set<String>.from(widget.group.members)
      ..remove(currentUser);

    if (updatedMembers.isEmpty) {
      // If no members left, delete the group entirely
      groupsProvider.deleteGroup(widget.group.id);
    } else {
      // Update group membership and notify other members
      final success = await groupsProvider.updateGroupMembership(
        widget.group.id,
        updatedMembers.toList(),
        widget.group.name,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to leave group. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (mounted) {
      Navigator.pop(context); // Return to groups list
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Left the group')));
    }
  }

  void _showAddMemberDialog() {
    _shouldMaintainFocus = false; // Disable focus maintenance during dialog
    _addMemberController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: _addMemberController,
          decoration: const InputDecoration(
            labelText: 'Enter atSign (e.g., @alice)',
            hintText: '@alice',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Re-enable focus maintenance after dialog closes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _shouldMaintainFocus = true;
                _messageFocusNode.requestFocus();
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final atSign = _addMemberController.text.trim();
              if (atSign.isNotEmpty) {
                await _addMember(atSign);

                // Close dialog and re-enable focus maintenance
                if (mounted) {
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _shouldMaintainFocus = true;
                    _messageFocusNode.requestFocus();
                  });
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMember(String memberAtSign) async {
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);

    // Ensure atSign starts with @
    final formattedAtSign = memberAtSign.startsWith('@')
        ? memberAtSign
        : '@$memberAtSign';

    // Check if member is already in the group
    if (widget.group.members.contains(formattedAtSign)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$formattedAtSign is already in the group')),
        );
      }
      return;
    }

    final updatedMembers = Set<String>.from(widget.group.members)
      ..add(formattedAtSign);

    // Simply update the existing group with new members
    final success = await groupsProvider.updateGroupMembership(
      widget.group.id,
      updatedMembers.toList(),
      widget.group.name,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $formattedAtSign to the group')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add $formattedAtSign to the group'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGroupInfo() {
    _shouldMaintainFocus = false; // Disable focus maintenance during dialog
    final currentAtSign = AtTalkService.instance.currentAtSign;
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);

    // Get the updated group from the provider
    final updatedGroup = groupsProvider.groups[widget.group.id] ?? widget.group;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Group Info'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400, // Set a reasonable fixed height for the dialog content
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Members (${updatedGroup.members.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Make the members list flexible and scrollable
              Expanded(
                child: ListView.builder(
                  itemCount: updatedGroup.members.length,
                  itemBuilder: (context, index) {
                    final membersList = updatedGroup.members.toList();
                    final member = membersList[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.grey[300],
                            child: Text(
                              member.substring(1, 2).toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(member)),
                          if (member != currentAtSign &&
                              updatedGroup.members.length > 2)
                            IconButton(
                              onPressed: () =>
                                  _showRemoveMemberDialog(member, updatedGroup),
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.red,
                                size: 20,
                              ),
                              tooltip: 'Remove $member',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (updatedGroup.id.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Group ID:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  updatedGroup.id,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Re-enable focus maintenance after dialog closes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _shouldMaintainFocus = true;
                _messageFocusNode.requestFocus();
              });
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberDialog(String member, Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Remove $member from the group?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close the remove dialog
              Navigator.pop(context); // Close the group info dialog
              _removeMember(member, group);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _removeMember(String memberAtSign, Group group) async {
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);

    // Remove member from group
    final updatedMembers = Set<String>.from(group.members)
      ..remove(memberAtSign);

    if (updatedMembers.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot remove member - group must have at least 2 members',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final success = await groupsProvider.updateGroupMembership(
      group.id,
      updatedMembers.toList(),
      group.name,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $memberAtSign from the group')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove $memberAtSign from the group'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromMe;
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: Text(
                (message.fromAtSign.startsWith('@')
                        ? message.fromAtSign.substring(1, 2)
                        : message.fromAtSign.substring(0, 1))
                    .toUpperCase(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF2196F3) : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe) ...[
                    Text(
                      message.fromAtSign.startsWith('@')
                          ? message.fromAtSign.substring(1) // Remove @ symbol
                          : message.fromAtSign,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeFormat.format(message.timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF2196F3),
              child: Text(
                (message.fromAtSign.startsWith('@')
                        ? message.fromAtSign.substring(1, 2)
                        : message.fromAtSign.substring(0, 1))
                    .toUpperCase(),
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
