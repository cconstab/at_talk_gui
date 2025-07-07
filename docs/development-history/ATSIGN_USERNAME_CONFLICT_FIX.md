# AtSign Username Conflict Cleanup Fix

## Issue
When trying to register `@cconstab` (which matches the OS username `cconstab`) after removing all keys, the GUI still goes to the "waiting" state rather than asking for a PIN code for PKAM authentication. This only happens with `@cconstab` - other atSigns work fine.

## Root Cause Analysis

The issue is likely caused by **persistent storage** that survives standard keychain removal:

1. **Username Matching**: `@cconstab` matches the macOS username `cconstab`
2. **Multiple Storage Locations**: AtClient data may be stored in various directories
3. **System-Level Cache**: macOS Keychain or biometric storage may cache data based on username
4. **Hive Database Persistence**: Old Hive boxes may persist across "cleanup" operations
5. **Path Conflicts**: Directory structures might resolve differently when username matches atSign

## Potential Storage Locations

The comprehensive cleanup addresses these locations:

### Standard AtSign Storage
```
~/Library/Application Support/com.example.atTalkGui/
├── .default.attalk/@cconstab/storage/
├── .test.attalk/@cconstab/storage/
└── .ai6bh/@cconstab/storage/ (legacy)
```

### Username-Based Conflicts
```
~/Library/Application Support/com.example.atTalkGui/
├── cconstab/ (direct username folder)
├── .default.attalk/cconstab/ (without @ prefix)
└── .test.attalk/cconstab/ (without @ prefix)
```

### Temporary Storage
```
/tmp/
├── at_talk_gui/@cconstab/
└── at_talk_gui/cconstab/
```

### Legacy Storage
```
~/Library/Application Support/com.example.atTalkGui/
└── keys/cconstab* (legacy key files)
```

## Solution Implemented

### 1. Comprehensive Cleanup Method
Added `AtTalkService.completeAtSignCleanup()` that:
- Performs standard AtClient cleanup
- Removes from keychain (including biometric data)
- Cleans storage directories for ALL namespaces
- Removes legacy storage directories
- Clears temporary storage
- Provides detailed logging

### 2. Username Conflict Cleanup
Added `AtTalkService.cleanupUsernameConflict()` that:
- Performs complete cleanup first
- Addresses username-specific conflicts
- Removes directories that might be created without `@` prefix
- Forces AtClient manager reset
- Handles edge cases where username == atSign

### 3. Integration with UI
Updated both:
- Key Management Dialog: Uses comprehensive cleanup
- Settings Screen: Uses comprehensive cleanup

## Usage Instructions

### For @cconstab Specifically:
1. **Use the comprehensive cleanup** in the Key Management dialog
2. **Restart the app** completely after cleanup
3. **Try registering @cconstab again**

If issues persist:

### Manual Cleanup Steps:
```bash
# 1. Quit the app completely
# 2. Remove all application data
rm -rf ~/Library/Application\ Support/com.example.atTalkGui/

# 3. Clear temporary files
rm -rf /tmp/at_talk_gui*

# 4. Clear keychain entries (if needed)
# Open Keychain Access.app and search for "cconstab" or "atsign"
# Delete any related entries

# 5. Restart the app
```

### Alternative Solutions:
1. **Try a different atSign first** to confirm the system works
2. **Use ephemeral storage** temporarily: modify the code to force `forceEphemeral = true`
3. **Create a test user account** to isolate username conflicts

## Files Modified

- `lib/core/services/at_talk_service.dart`
  - Added `completeAtSignCleanup()` method
  - Added `cleanupUsernameConflict()` method
  - Comprehensive storage location cleanup

- `lib/gui/widgets/key_management_dialog.dart`
  - Updated to use comprehensive cleanup
  - Enhanced user feedback about complete removal

- `lib/gui/screens/settings_screen.dart`
  - Updated to use comprehensive cleanup
  - Improved atSign removal process

## Testing Recommendations

1. **Test with other atSigns** to confirm they still work
2. **Test @cconstab registration** after comprehensive cleanup
3. **Monitor logs** for any remaining storage locations
4. **Verify PKAM flow** works correctly after cleanup

This solution addresses the specific case where an atSign matches the OS username and provides comprehensive cleanup to resolve persistent storage conflicts.
