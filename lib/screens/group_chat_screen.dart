import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/groups_provider.dart';
import '../providers/auth_provider.dart';
import '../services/at_talk_service.dart';
import '../models/group.dart';
import '../models/chat_message.dart';

class GroupChatScreen extends StatefulWidget {
  final Group group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _addMemberController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _shouldMaintainFocus = false;

  @override
  void initState() {
    super.initState();
    // Request focus when the screen first loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageFocusNode.requestFocus();
      _shouldMaintainFocus = true;

      // Set up listener for message changes to auto-scroll
      final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);
      groupsProvider.addListener(_scrollToBottom);
    });
  }

  @override
  void dispose() {
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);
    groupsProvider.removeListener(_scrollToBottom);
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
            final updatedGroup = groupsProvider.groups[widget.group.id] ?? widget.group;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${updatedGroup.getDisplayName(currentAtSign)} - ${currentAtSign ?? 'Unknown'}'),
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
        actions: [
          IconButton(onPressed: _showAddMemberDialog, icon: const Icon(Icons.person_add), tooltip: 'Add member'),
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
                child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Rename Group')]),
              ),
              const PopupMenuItem(
                value: 'info',
                child: Row(children: [Icon(Icons.info), SizedBox(width: 8), Text('Group Info')]),
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
                final messages = groupsProvider.getGroupMessages(widget.group.id);

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
                  reverse: true, // This makes the ListView start from the bottom
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
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
    final success = await groupsProvider.sendMessageToGroup(widget.group.id, text);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message. Please try again.'), backgroundColor: Colors.red),
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
          decoration: const InputDecoration(labelText: 'Group Name', hintText: 'Enter group name'),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Group renamed to "$displayText"')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to rename group. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }

  void _showLeaveGroupDialog() {
    _shouldMaintainFocus = false; // Disable focus maintenance during dialog

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group? This action cannot be undone.'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
    final updatedMembers = Set<String>.from(widget.group.members)..remove(currentUser);

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
          const SnackBar(content: Text('Failed to leave group. Please try again.'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    if (mounted) {
      Navigator.pop(context); // Return to groups list
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left the group')));
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
          decoration: const InputDecoration(labelText: 'Enter atSign (e.g., @alice)', hintText: '@alice'),
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
            onPressed: () {
              final atSign = _addMemberController.text.trim();
              if (atSign.isNotEmpty) {
                _addMember(atSign);
                Navigator.pop(context);
                // Re-enable focus maintenance after dialog closes
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _shouldMaintainFocus = true;
                  _messageFocusNode.requestFocus();
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addMember(String memberAtSign) async {
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);

    // Ensure atSign starts with @
    final formattedAtSign = memberAtSign.startsWith('@') ? memberAtSign : '@$memberAtSign';

    // Check if member is already in the group
    if (widget.group.members.contains(formattedAtSign)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$formattedAtSign is already in the group')));
      }
      return;
    }

    // Add member to group using the proper membership update method
    final updatedMembers = Set<String>.from(widget.group.members)..add(formattedAtSign);

    final success = await groupsProvider.updateGroupMembership(
      widget.group.id,
      updatedMembers.toList(),
      widget.group.name,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $formattedAtSign to the group')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add $formattedAtSign to the group'), backgroundColor: Colors.red),
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
        title: Text('${updatedGroup.getDisplayName(currentAtSign)} - ${currentAtSign ?? 'Unknown'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (updatedGroup.name != null && updatedGroup.name!.isNotEmpty) ...[
              const Text('Group Name:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(updatedGroup.name!),
              const SizedBox(height: 12),
            ],
            Text('Members (${updatedGroup.members.length}):', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...updatedGroup.members.map(
              (member) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: InkWell(
                  onLongPress: () {
                    // Only allow removing other members, not yourself
                    if (member != currentAtSign && updatedGroup.members.length > 2) {
                      _showRemoveMemberDialog(member, updatedGroup);
                    }
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.grey[300],
                        child: Text(member.substring(1, 2).toUpperCase(), style: const TextStyle(fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(member)),
                      if (member != currentAtSign && updatedGroup.members.length > 2)
                        const Icon(Icons.remove_circle_outline, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            if (updatedGroup.id.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Group ID:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(updatedGroup.id, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ],
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
        content: Text('Remove $member from the group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close the remove dialog
              Navigator.pop(context); // Close the group info dialog
              _removeMember(member, group);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _removeMember(String memberAtSign, Group group) async {
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);

    // Remove member from group
    final updatedMembers = Set<String>.from(group.members)..remove(memberAtSign);

    if (updatedMembers.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot remove member - group must have at least 2 members'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final success = await groupsProvider.updateGroupMembership(group.id, updatedMembers.toList(), group.name);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed $memberAtSign from the group')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove $memberAtSign from the group'), backgroundColor: Colors.red),
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
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
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
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2196F3)),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(message.text, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    timeFormat.format(message.timestamp),
                    style: TextStyle(color: isMe ? Colors.white70 : Colors.grey[600], fontSize: 12),
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
