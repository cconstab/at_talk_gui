# Group Rename Synchronization Fix

**Issue**: When the TUI creates a conversation with `/new` and then the GUI renames it, the TUI shows both the original conversation with the atSign-based name and a new conversation with the renamed group name.

## Root Cause Analysis

### Two Different Scenarios

1. **GUI creates first, TUI renames**: ✅ **FIXED** - TUI now finds and updates existing session
2. **TUI creates first, GUI renames**: ❌ **REMAINING ISSUE** - GUI may create duplicate group

### Scenario 2: TUI Creates First

When the **TUI** creates a conversation first:

1. **TUI creates conversation**: Uses session ID like `@alice,@bob` (sorted members)
2. **TUI sends first message**: Includes `instanceId: "@alice,@bob"`  
3. **GUI receives message**: Should create group with ID `@alice,@bob`
4. **GUI renames group**: Sends rename notification with `instanceId` matching GUI's group ID
5. **TUI receives rename**: Should find existing session and update name

**Problem**: The GUI might create a group with a different ID than the TUI's session ID, causing a mismatch when the rename notification is processed.

## Debugging Added

### TUI Side (bin/at_talk_tui.dart)
```dart
print('🔄 TUI: Received group rename notification');
print('   New name: $newGroupName');
print('   Members: $sessionParticipants');
print('   Computed session key: $sessionKey');
// ... existing session search logic with logging
```

### GUI Side (lib/core/providers/groups_provider.dart)

#### Group Rename Handler
```dart
print('🔄 GUI: Received group rename notification');
print('   From: $fromAtSign');
print('   New name: $newGroupName');
print('   Members: $groupMembers');
print('   InstanceId: $instanceId');
print('   Existing groups: ${_groups.keys.toList()}');
```

#### Message Processing (Group Creation)
```dart
print('❌ GUI: No existing group found with members: $groupMembers');
print('🆕 GUI: Creating new group for incoming message');
print('   InstanceId from message: $instanceId');
print('   Session key: $sessionKey');
print('✅ GUI: Using TUI-compatible base ID for 1-on-1: $groupId');
```

## Expected Debug Flow

### When TUI Creates Conversation First:

```
# TUI creates conversation
TUI: /new @alice

# TUI sends first message
TUI: Sending message with instanceId: @alice,@bob

# GUI receives message
GUI: No existing group found with members: [@alice, @bob]
GUI: Creating new group for incoming message
GUI: InstanceId from message: @alice,@bob
GUI: Session key: @alice,@bob
GUI: Using TUI-compatible base ID for 1-on-1: @alice,@bob

# GUI renames conversation  
GUI: Sending rename notification for group: @alice,@bob

# TUI receives rename
TUI: Received group rename notification
TUI: Found existing session @alice,@bob, updating name
```

## Testing Procedure

1. **Start TUI**: `bin/at_talk_tui.exe`
2. **Create conversation**: `/new @alice`
3. **Send message**: Type and send a message
4. **Start GUI**: `flutter run`
5. **Verify conversation appears** in GUI
6. **Rename in GUI**: Right-click → Rename
7. **Check TUI**: Should show renamed conversation (not duplicate)

## Expected Fix

The improved debugging should reveal exactly where the ID mismatch occurs. Likely fixes:

1. **Ensure GUI uses TUI session IDs**: When GUI receives message from TUI, use the `instanceId` from the message as the group ID
2. **Improve group matching**: Enhanced `_findGroupByMembers` to handle edge cases
3. **Prevent duplicate creation**: Better conflict detection in `_handleGroupRename`
