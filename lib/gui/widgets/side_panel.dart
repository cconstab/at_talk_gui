import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/providers/groups_provider.dart';
import '../../core/providers/auth_provider.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final currentAtSign = authProvider.currentAtSign ?? AtTalkService.instance.currentAtSign ?? 'Unknown';

        return Container(
          width: 320,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colorScheme.surface, colorScheme.surface.withOpacity(0.98)],
            ),
            border: Border(right: BorderSide(color: colorScheme.outline.withOpacity(0.2), width: 1)),
            boxShadow: [
              BoxShadow(color: colorScheme.shadow.withOpacity(0.08), blurRadius: 12, offset: const Offset(3, 0)),
              BoxShadow(color: colorScheme.shadow.withOpacity(0.04), blurRadius: 6, offset: const Offset(1, 0)),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                height: 56, // Match standard AppBar height
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
                  ),
                  boxShadow: [
                    BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.alternate_email,
                        color: Colors.white,
                        size: 20, // Slightly smaller to fit better
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Signed in as',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 10, // Slightly smaller
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            currentAtSign,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14, // Adjusted for smaller header
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Removed the X button since it wasn't working properly
                    // Users can close the panel using other navigation methods
                  ],
                ),
              ),

              // Search bar
              Container(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline.withOpacity(0.1), width: 1),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 14),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: Material(
                                color: colorScheme.onSurfaceVariant.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(Icons.close_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
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
                                    group.getDisplayName(currentAtSign).toLowerCase().contains(_searchQuery) ||
                                    (group.lastMessage?.toLowerCase().contains(_searchQuery) ?? false),
                              )
                              .toList();

                    if (filteredGroups.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(
                                  _searchQuery.isEmpty ? Icons.chat_bubble_outline_rounded : Icons.search_off_rounded,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _searchQuery.isEmpty ? 'No conversations yet' : 'No matches found',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Start a new conversation to get started',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: filteredGroups.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final group = filteredGroups[index];
                        final isSelected = widget.selectedGroup?.id == group.id;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? colorScheme.primaryContainer.withOpacity(0.3) : null,
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(color: colorScheme.primary.withOpacity(0.3), width: 1.5)
                                : null,
                          ),
                          child: SidePanelGroupTile(
                            group: group,
                            isSelected: isSelected,
                            onTap: () => widget.onGroupSelected(group),
                            currentAtSign: currentAtSign,
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
      },
    );
  }
}

class SidePanelGroupTile extends StatelessWidget {
  final Group group;
  final bool isSelected;
  final VoidCallback onTap;
  final String currentAtSign;

  const SidePanelGroupTile({
    super.key,
    required this.group,
    required this.isSelected,
    required this.onTap,
    required this.currentAtSign,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar with enhanced styling
              Hero(
                tag: 'avatar_${group.id}',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (isSelected ? colorScheme.primary : colorScheme.primary.withOpacity(0.4)).withOpacity(
                          0.3,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: isSelected ? colorScheme.primary : colorScheme.primary.withOpacity(0.8),
                    child: Text(
                      group.getDisplayName(currentAtSign).substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.getDisplayName(currentAtSign),
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 15,
                              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (group.lastMessageTime != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(group.lastMessageTime!),
                            style: TextStyle(
                              color: group.unreadCount > 0
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant.withOpacity(0.7),
                              fontSize: 11,
                              fontWeight: group.unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: group.lastMessage != null
                              ? Text(
                                  group.lastMessage!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: group.unreadCount > 0
                                        ? colorScheme.onSurface.withOpacity(0.8)
                                        : colorScheme.onSurfaceVariant.withOpacity(0.7),
                                    fontWeight: group.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                    fontSize: 13,
                                    height: 1.2,
                                  ),
                                )
                              : Text(
                                  'No messages yet',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                        ),
                        if (group.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(minWidth: 20),
                            child: Text(
                              group.unreadCount > 99 ? '99+' : group.unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
