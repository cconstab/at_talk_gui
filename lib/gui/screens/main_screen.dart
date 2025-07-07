import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/side_panel.dart';
import '../screens/groups_list_screen.dart';
import '../screens/group_chat_screen.dart';
import '../../core/providers/groups_provider.dart';
import '../../core/models/group.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  Group? _selectedGroup;
  bool _sidePanelVisible = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller for side panel slide
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Listen to animation status to update UI
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() {
          // Ensure overlay is hidden when animation completes
        });
      }
    });

    // Initialize groups provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupsProvider = Provider.of<GroupsProvider>(
        context,
        listen: false,
      );
      groupsProvider.initialize();

      // Listen for changes and mark current group as read
      groupsProvider.addListener(_onGroupsProviderChanged);
    });
  }

  void _onGroupsProviderChanged() {
    // Automatically mark the currently viewed group as read when messages arrive
    if (_selectedGroup != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<GroupsProvider>(
            context,
            listen: false,
          ).markGroupAsRead(_selectedGroup!.id);
        }
      });
    }
  }

  @override
  void dispose() {
    // Remove the groups provider listener
    final groupsProvider = Provider.of<GroupsProvider>(context, listen: false);
    groupsProvider.removeListener(_onGroupsProviderChanged);

    _animationController.dispose();
    super.dispose();
  }

  void _onGroupSelected(Group group) {
    setState(() {
      _selectedGroup = group;
    });

    // Mark group as read when selecting
    Provider.of<GroupsProvider>(
      context,
      listen: false,
    ).markGroupAsRead(group.id);

    // Hide side panel on mobile after selection
    if (MediaQuery.of(context).size.width < 768) {
      setState(() {
        _sidePanelVisible = false;
      });
      _animationController.reverse();
    }
  }

  void _toggleSidePanel() {
    setState(() {
      _sidePanelVisible = !_sidePanelVisible;
    });

    // Animate the side panel
    if (_sidePanelVisible) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _hideSidePanel() {
    setState(() {
      _sidePanelVisible = false;
    });
    _animationController.reverse();
  }

  void _showGroupsList() {
    setState(() {
      _selectedGroup = null;
      // Also hide side panel on narrow screens when going back to groups list
      if (MediaQuery.of(context).size.width < 768) {
        _sidePanelVisible = false;
      }
    });

    // Animate panel closed if on narrow screen
    if (MediaQuery.of(context).size.width < 768) {
      _animationController.reverse();
    }
  }

  Widget _buildUnreadIndicator() {
    return Consumer<GroupsProvider>(
      builder: (context, groupsProvider, child) {
        // Only show indicator when viewing a specific group and there are unread messages in other groups
        if (_selectedGroup == null) {
          return const SizedBox.shrink();
        }

        // Ensure current group is marked as read
        if (_selectedGroup!.unreadCount > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              groupsProvider.markGroupAsRead(_selectedGroup!.id);
            }
          });
        }

        final unreadCount = groupsProvider.getTotalUnreadCount(
          _selectedGroup?.id,
        );

        if (unreadCount == 0) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 20,
          right: 20,
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(28),
            shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
            child: InkWell(
              onTap: _toggleSidePanel,
              borderRadius: BorderRadius.circular(28),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 768;

    return Scaffold(
      key: _scaffoldKey,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // On wide screens, always show the side panel
          final showSidePanelFixed = isWideScreen;
          // On narrow screens, show as overlay when visible or animating
          final showSidePanelOverlay =
              !isWideScreen &&
              (_sidePanelVisible || _animationController.value > 0);

          return Stack(
            children: [
              // Main content area
              Row(
                children: [
                  // Fixed side panel for wide screens
                  if (showSidePanelFixed)
                    SidePanel(
                      onGroupSelected: _onGroupSelected,
                      selectedGroup: _selectedGroup,
                      isVisible: true,
                      onClose:
                          _showGroupsList, // Allow closing to show group list
                    ),

                  // Main content
                  Expanded(
                    child: _selectedGroup != null
                        ? GroupChatScreen(
                            group: _selectedGroup!,
                            onBack:
                                _showGroupsList, // Always allow going back to group list
                            showMenuButton: !isWideScreen,
                            onMenuPressed: _toggleSidePanel,
                          )
                        : MainGroupsListScreen(
                            onGroupSelected: _onGroupSelected,
                            showMenuButton: !isWideScreen,
                            onMenuPressed: _toggleSidePanel,
                          ),
                  ),
                ],
              ),

              // Overlay side panel for narrow screens
              if (showSidePanelOverlay) ...[
                // Dark overlay with fade animation
                GestureDetector(
                  onTap: _hideSidePanel,
                  child: Container(
                    color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
                  ),
                ),
                // Sliding side panel
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SidePanel(
                      onGroupSelected: _onGroupSelected,
                      selectedGroup: _selectedGroup,
                      isVisible: true,
                      onClose: _hideSidePanel,
                    ),
                  ),
                ),
              ],

              // Unread message indicator (only on narrow screens)
              if (!isWideScreen) _buildUnreadIndicator(),
            ],
          );
        },
      ),
    );
  }
}

/// Wrapper around GroupsListScreen to add menu button support
class MainGroupsListScreen extends StatelessWidget {
  final Function(Group) onGroupSelected;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;

  const MainGroupsListScreen({
    super.key,
    required this.onGroupSelected,
    required this.showMenuButton,
    required this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GroupsListScreenWithSidePanel(
      onGroupSelected: onGroupSelected,
      showMenuButton: showMenuButton,
      onMenuPressed: onMenuPressed,
    );
  }
}
