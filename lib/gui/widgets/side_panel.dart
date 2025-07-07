import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/providers/groups_provider.dart';
import '../../core/services/at_talk_service.dart';
import '../../core/models/group.dart';

class SidePanel extends StatefulWidget {
  final Function(Group) onGroupSelected;
  final Group? selectedGroup;
  final bool isVisible;
  final VoidCallback onClose;

  const SidePanel({
    super.key,
    required this.onGroupSelected,
    this.selectedGroup,
    required this.isVisible,
    required this.onClose,
  });

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentAtSign = AtTalkService.instance.currentAtSign ?? 'Unknown';

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    currentAtSign,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: Icon(
                    widget.selectedGroup != null ? Icons.list : Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: widget.selectedGroup != null
                      ? 'Show all conversations'
                      : 'Close panel',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Search bar
          Container(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear, size: 20),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Groups list
          Expanded(
            child: Consumer<GroupsProvider>(
              builder: (context, groupsProvider, child) {
                final groups = groupsProvider.sortedGroups;
                final filteredGroups = _searchQuery.isEmpty
                    ? groups
                    : groups
                          .where(
                            (group) =>
                                group
                                    .getDisplayName(currentAtSign)
                                    .toLowerCase()
                                    .contains(_searchQuery) ||
                                (group.lastMessage?.toLowerCase().contains(
                                      _searchQuery,
                                    ) ??
                                    false),
                          )
                          .toList();

                if (filteredGroups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty ? Icons.chat : Icons.search_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No conversations yet'
                              : 'No matches found',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Start a new conversation',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredGroups.length,
                  itemBuilder: (context, index) {
                    final group = filteredGroups[index];
                    final isSelected = widget.selectedGroup?.id == group.id;

                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2196F3).withOpacity(0.1)
                            : null,
                        border: isSelected
                            ? const Border(
                                right: BorderSide(
                                  color: Color(0xFF2196F3),
                                  width: 3,
                                ),
                              )
                            : null,
                      ),
                      child: SidePanelGroupTile(
                        group: group,
                        isSelected: isSelected,
                        onTap: () => widget.onGroupSelected(group),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SidePanelGroupTile extends StatelessWidget {
  final Group group;
  final bool isSelected;
  final VoidCallback onTap;

  const SidePanelGroupTile({
    super.key,
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentAtSign = AtTalkService.instance.currentAtSign;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isSelected
            ? const Color(0xFF2196F3)
            : const Color(0xFF2196F3).withOpacity(0.7),
        child: Text(
          group.getDisplayName(currentAtSign).substring(0, 1).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      title: Text(
        group.getDisplayName(currentAtSign),
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 14,
          color: isSelected ? const Color(0xFF2196F3) : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
                fontSize: 12,
              ),
            )
          : const Text(
              'No messages yet',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
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
                fontSize: 10,
                fontWeight: group.unreadCount > 0
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
            ),
          if (group.unreadCount > 0) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                group.unreadCount > 99 ? '99+' : group.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      return DateFormat('M/d').format(time);
    } else if (difference.inDays > 0) {
      return DateFormat('EEE').format(time);
    } else {
      return DateFormat('HH:mm').format(time);
    }
  }
}
