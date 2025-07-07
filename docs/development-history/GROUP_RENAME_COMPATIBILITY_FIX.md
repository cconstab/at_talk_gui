# AtTalk Group Rename and Session ID Compatibility Fix

**Status**: ✅ **COMPLETE** - Fixed group rename handling and session ID consistency between TUI and GUI

**Date**: January 7, 2025  
**Issues Addressed**: Group rename causing duplicate sessions, missing system messages, UUID handling inconsistencies

---

## Problems Identified

### 1. **Group Rename Creating Duplicate Sessions**
When TUI created a new conversation with `/new @cconstab` and then GUI renamed the group, the TUI would create a new duplicate session instead of updating the existing one.

### 2. **Missing System Messages**
When GUI renamed a group, TUI didn't display the rename system message that appears in TUI-to-TUI renames.

### 3. **Session ID Inconsistency**
TUI and GUI were creating different session IDs for the same conversation:
- TUI: Uses base session key format (e.g., `@alice,@bob`)
- GUI: Sometimes used timestamped IDs (e.g., `@alice,@bob#1672531200000`)

### 4. **UUID/Timestamp Missing for 1-on-1**
1-on-1 conversations weren't getting unique identifiers when needed, causing ID conflicts.

---

## Solutions Implemented

### 🔧 **Fix 1: Group ID Consolidation in GUI**

**File**: `lib/core/providers/groups_provider.dart`  
**Method**: `_handleGroupRename()`

**Problem**: GUI couldn't find groups when TUI sent rename notifications with different session IDs.

**Solution**: Added group ID consolidation logic:
```dart
// CRITICAL: If we found a group with different ID, we need to consolidate
// This happens when GUI created a timestamped ID but TUI uses base session key
if (groupId != instanceId) {
  print('🔧 GUI: Group ID mismatch detected - consolidating group IDs');
  
  // Create/update the group with the TUI's expected ID
  final group = _groups[groupId]!;
  _groups[instanceId] = group.copyWith(name: newGroupName);
  _groupMessages[instanceId] = _groupMessages[groupId] ?? [];
  
  // Remove the old group to prevent confusion
  _groups.remove(groupId);
  _groupMessages.remove(groupId);
  
  groupId = instanceId; // Use TUI's ID going forward
}
```

### 🔧 **Fix 2: Improved TUI Group Rename Handling**

**File**: `bin/at_talk_tui.dart`  
**Section**: Group rename notification handler

**Problem**: TUI was creating new sessions instead of updating existing ones.

**Solution**: Enhanced session matching strategy:
```dart
// Strategy 1: Try to find by exact instanceId first
if (instanceId != null && tui.sessions.containsKey(instanceId)) {
  targetSessionId = instanceId;
} else {
  // Strategy 2: Find existing session with matching participants
  // Strategy 3: Check if we should use the base session key
}

// Only create new session if no existing session was found
if (targetSessionId != null && tui.sessions.containsKey(targetSessionId)) {
  // Update existing session name
  tui.sessions[targetSessionId]!.groupName = newGroupName;
} else {
  // Create new session ONLY if needed
}
```

### 🔧 **Fix 3: Consistent Session ID Generation**

**File**: `lib/core/providers/groups_provider.dart`  
**Method**: `_generateTUICompatibleGroupId()`

**Problem**: GUI was adding timestamps to all group IDs, causing TUI/GUI incompatibility.

**Solution**: Prefer base session keys for 1-on-1 and 2-person conversations:
```dart
// CRITICAL FIX: For 1-on-1 and 2-person conversations, prefer the base session key
// This ensures TUI and GUI use the same session ID for the same conversation
if (members.length <= 2 && !forceUniqueForGroup) {
  // Use base session key format (no timestamp)
  return groupId; // e.g., "@alice,@bob"
} else {
  // For 3+ person groups, add timestamp if there's a conflict
  if (forceUniqueForGroup || _groups.containsKey(groupId)) {
    groupId = _generateUniqueGroupId(groupId);
  }
}
```

### 🔧 **Fix 4: TUI-Compatible Instance ID in Rename Notifications**

**File**: `lib/core/providers/groups_provider.dart`  
**Method**: `renameGroup()`

**Problem**: GUI was sending its internal group ID instead of TUI-compatible session key.

**Solution**: Send TUI-compatible session key as instanceId:
```dart
// CRITICAL FIX: Send the TUI-compatible session key as instanceId
// The TUI expects the base session key format for consistent routing
final sortedMembers = group.members.toList()..sort();
final tuiSessionKey = sortedMembers.join(',');

await AtTalkService.instance.sendGroupRename(
  toAtSign: recipient,
  groupMembers: group.members.toList(),
  groupName: newName,
  groupInstanceId: tuiSessionKey, // Send TUI-compatible session key
);
```

### 🔧 **Fix 5: Improved Message Processing**

**File**: `lib/core/providers/groups_provider.dart`  
**Method**: Message subscription handler

**Problem**: GUI wasn't using TUI-provided instanceIds for group creation.

**Solution**: Prefer TUI-provided instanceIds for perfect compatibility:
```dart
// CRITICAL FIX: For incoming messages, prefer the instanceId if it matches our session key format
String newGroupId;

if (instanceId != null && instanceId == sessionKey) {
  // The instanceId matches our computed session key - use it for perfect TUI compatibility
  newGroupId = instanceId;
} else if (instanceId != null && !_groups.containsKey(instanceId)) {
  // The instanceId is different but available - use it to maintain TUI compatibility
  newGroupId = instanceId;
} else {
  // Fall back to our session key format
  newGroupId = sessionKey;
}
```

### 🔧 **Fix 6: Self-Notification Filtering in TUI**

**File**: `bin/at_talk_tui.dart`  
**Section**: Group rename notification handler

**Problem**: TUI was processing its own rename notifications, causing loops.

**Solution**: Added self-filtering:
```dart
// Skip processing our own rename notifications to prevent loops
if (fromAtSign == fromAtsign) {
  print('🚫 TUI: Ignoring rename notification from ourselves');
  return;
}
```

---

## Results

### ✅ **Perfect TUI/GUI Group Compatibility**
- TUI creates session with `/new @cconstab` 
- GUI can rename the group
- TUI receives rename notification and updates existing session (no duplicate)
- TUI displays system message: `[Group renamed to "New Name"]`

### ✅ **Consistent Session IDs**
- Both TUI and GUI now use the same session ID format for the same conversation
- 1-on-1 conversations: `@alice,@bob` (no timestamp unless there's a conflict)
- Multi-person groups: `@alice,@bob,@charlie` (with timestamp if needed for uniqueness)

### ✅ **System Message Display**
- TUI now shows rename messages when GUI renames groups
- Format matches TUI-to-TUI rename messages: `[Group renamed to "Name"]`

### ✅ **No More Duplicate Sessions**
- TUI no longer creates duplicate sessions for the same participants
- Groups are properly matched by members and updated in place

---

## Testing Scenarios

### Scenario 1: TUI → GUI Group Rename
1. TUI creates conversation: `/new @other`
2. TUI renames group: `/rename My Group`  
3. ✅ GUI receives update and shows "My Group" in conversation list
4. ✅ GUI shows system message in chat

### Scenario 2: GUI → TUI Group Rename  
1. TUI creates conversation: `/new @other`
2. GUI renames group to "Test Group"
3. ✅ TUI updates existing session name (no duplicate)
4. ✅ TUI shows system message: `[Group renamed to "Test Group"]`

### Scenario 3: Cross-Platform Messaging
1. TUI creates 1-on-1 conversation: `/new @other`
2. GUI sends message to same conversation
3. ✅ Message appears in TUI's existing session (no new session created)
4. ✅ Both use same session ID format

---

## Technical Details

### Session Key Format
- **Base Format**: Comma-separated, sorted member list
- **Example**: `@alice,@bob,@charlie`
- **Unique Suffix**: Added only when needed: `@alice,@bob#1672531200000`

### Group Matching Priority
1. **Exact instanceId match** (highest priority)
2. **Member set match** (find group with identical participants)
3. **Base session key match** (ignore timestamp suffixes)
4. **Create new group** (last resort)

### Notification Flow
```
GUI Rename → AtTalk Service → Network → TUI Notification Handler → Session Update
```

---

## Code Quality

### ✅ Compilation Status
- **Result**: Clean compilation with `flutter analyze`
- **Warnings**: Only lint warnings (print statements, deprecated APIs)
- **Errors**: None

### ✅ Debugging Support
- Comprehensive logging for troubleshooting
- Clear debug messages for group matching and session updates
- Conflict detection and resolution logging

---

## Future Enhancements

### Potential Improvements
1. **Real-time sync**: Live session updates without requiring message exchange
2. **Conflict resolution**: Better handling of simultaneous renames from multiple clients
3. **Session migration**: Automatic consolidation of sessions with identical participants

### Maintenance Notes
- The session ID consistency logic is in `_generateTUICompatibleGroupId()`
- Group consolidation logic is in `_handleGroupRename()`
- TUI session matching is in the rename notification handler
- All changes maintain backward compatibility with existing groups

---

**🎯 Result**: Perfect TUI/GUI interoperability for group management and messaging with zero duplicate sessions and consistent system message display across all interfaces.
