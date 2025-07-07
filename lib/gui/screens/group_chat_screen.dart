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
        title: Consumer<GroupsProvider>(
          builder: (context, groupsProvider, child) {
            // Get the updated group from the provider
            final updatedGroup =
                groupsProvider.groups[widget.group.id] ?? widget.group;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${updatedGroup.getDisplayName(currentAtSign)} - ${currentAtSign ?? 'Unknown'}',
                ),
                Text(
                  '${updatedGroup.members.length} members',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            );
          },
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        leading: widget.onBack != null
            ? IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to conversations',
              )
            : widget.showMenuButton && widget.onMenuPressed != null
            ? IconButton(
                onPressed: widget.onMenuPressed,
                icon: const Icon(Icons.menu),
                tooltip: 'Show conversations',
              )
            : null,
        automaticallyImplyLeading:
            widget.onBack == null && !widget.showMenuButton,
        actions: [
          IconButton(
            onPressed: _showAddMemberDialog,
            icon: const Icon(Icons.person_add),
            tooltip: 'Add member',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') {
                _showRenameGroupDialog();
              } else if (value == 'info') {
                _showGroupInfo();
              } else if (value == 'leave') {
                _showLeaveGroupDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Rename Group'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info),
                    SizedBox(width: 8),
                    Text('Group Info'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Leave Group', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (text) => _sendMessage(),
                    onTap: () {
                      // User intentionally tapped the text field, ensure focus maintenance is enabled
                      _shouldMaintainFocus = true;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF2196F3),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white),
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

    final success = await groupsProvider.renameGroup(widget.group.id, newName);

    if (success && mounted) {
      final displayText = newName.isNotEmpty ? newName : 'Unnamed Group';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group renamed to "$displayText"')),
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
                // Check if this will be a 1-on-1 to group conversion
                final willCreateNewGroup = widget.group.members.length == 2;

                await _addMember(atSign);

                // Only close the dialog if we're not navigating to a new group
                // (because Navigator.pushReplacement will handle the navigation)
                if (mounted && !willCreateNewGroup) {
                  Navigator.pop(context);
                  // Re-enable focus maintenance after dialog closes
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

    // Check if we're converting a 1-on-1 conversation to a group (TUI behavior)
    final isConvertingToGroup =
        widget.group.members.length == 2 && updatedMembers.length == 3;

    if (isConvertingToGroup) {
      // Show group name dialog first (TUI-compatible behavior)
      final groupName = await _showGroupNameDialog();

      if (groupName == null || groupName.isEmpty) {
        return; // User cancelled or entered empty name
      }

      // Create a new group with unique ID (preserves the original 1-on-1)
      final newGroup = groupsProvider.createNewGroupWithUniqueName(
        updatedMembers,
        name: groupName,
      );

      if (newGroup != null) {
        // Send membership change notifications to all members
        final success = await groupsProvider.updateGroupMembership(
          newGroup.id,
          updatedMembers.toList(),
          groupName,
        );

        if (mounted) {
          if (success) {
            // The add member dialog will be automatically closed by the navigation
            // Navigate to the new group (TUI behavior: focus moves to new group)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GroupChatScreen(group: newGroup),
              ),
            );

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Created new group "$groupName" with $formattedAtSign',
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to create group with $formattedAtSign'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create new group'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      // Normal add member to existing group
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
  }

  Future<String?> _showGroupNameDialog() async {
    _shouldMaintainFocus = false; // Disable focus maintenance during dialog
    final groupNameController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name Your Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You\'re creating a new group. Please give it a name:'),
            const SizedBox(height: 16),
            TextField(
              controller: groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'Enter group name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              maxLength: 50,
              onSubmitted: (value) {
                // Allow Enter key to submit
                final groupName = value.trim();
                if (groupName.isNotEmpty) {
                  Navigator.pop(context, groupName);
                  groupNameController.dispose();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Return null
              groupNameController.dispose();
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
              final groupName = groupNameController.text.trim();
              if (groupName.isNotEmpty) {
                Navigator.pop(context, groupName);
              } else {
                // Show error for empty name
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a group name'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              groupNameController.dispose();
              // Re-enable focus maintenance after dialog closes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _shouldMaintainFocus = true;
                _messageFocusNode.requestFocus();
              });
            },
            child: const Text('Create Group'),
          ),
        ],
      ),
    );
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
