# AtTalk GUI Storage Fix - AtSign-Specific Storage Paths

## Problem Identified
The GUI was using generic storage paths that didn't include the atSign, causing files to be overwritten when switching between atSigns or running multiple instances. This was inconsistent with the TUI's approach which always includes the atSign in storage paths.

## Root Cause
- **GUI Issue**: Storage paths were generic (e.g., `{AppSupport}/storage`) without atSign isolation
- **TUI (Correct)**: Storage paths included atSign (e.g., `~/.default.attalk/@atsign/storage`)

## Solution Implemented

### 1. Updated AtTalkService (`lib/core/services/at_talk_service.dart`)
- Added `configureAtSignStorage()` method that creates atSign-specific storage paths
- **Persistent Storage**: `{AppSupport}/.default.attalk/@atsign/storage` (matching TUI pattern)
- **Ephemeral Storage**: `{TempDir}/at_talk_gui/@atsign/{uuid}/storage` (with atSign isolation)
- Includes same storage claiming and lock file logic as TUI for multi-instance support

### 2. Updated AuthProvider (`lib/core/providers/auth_provider.dart`)
- Modified `authenticate()` and `authenticateExisting()` methods
- Now call `AtTalkService.configureAtSignStorage()` before authentication
- Ensures atSign-specific storage is configured before any AtClient operations

### 3. Updated Onboarding Screen (`lib/gui/screens/onboarding_screen.dart`)
- Modified all onboarding methods (CRAM, .atKeys upload, APKAM)
- Replace generic AtClientPreference usage with atSign-specific configuration
- Each onboarding method now calls `configureAtSignStorage()` first

### 4. Updated Main App Initialization (`lib/main.dart`)
- Simplified initialization to use temporary generic path during startup
- Actual atSign-specific storage configuration happens during authentication
- Removes premature storage claiming that occurred before atSign was known

## Storage Path Comparison

### Before (Problematic)
```
Persistent: {AppSupport}/storage               # No atSign isolation!
Ephemeral:  {TempDir}/at_talk_gui/ephemeral/{uuid}/storage  # No atSign isolation!
```

### After (Fixed - Matches TUI)
```
Persistent: {AppSupport}/.default.attalk/@atsign/storage             # atSign-specific ✓
Ephemeral:  {TempDir}/at_talk_gui/@atsign/{uuid}/storage    # atSign-specific ✓
```

## Benefits
- ✅ **No File Overwrites**: Each atSign uses isolated storage directory
- ✅ **Multi-Instance Safe**: Different atSigns can run simultaneously 
- ✅ **Consistent with TUI**: Same storage architecture across GUI and TUI
- ✅ **Multi-AtSign Support**: Switching atSigns doesn't conflict with storage
- ✅ **Backward Compatible**: Existing functionality unchanged

## Testing Verification Needed
1. **Single AtSign**: Verify normal operation continues to work
2. **Multiple AtSigns**: Test switching between atSigns doesn't cause conflicts
3. **Multi-Instance**: Run GUI with different atSigns simultaneously
4. **Storage Claiming**: Verify automatic fallback to ephemeral when storage busy
5. **Cross-Platform**: Test on different operating systems

## Files Modified
- `lib/core/services/at_talk_service.dart` - Added atSign-specific storage configuration
- `lib/core/providers/auth_provider.dart` - Updated authentication to use atSign storage
- `lib/gui/screens/onboarding_screen.dart` - Updated all onboarding methods
- `lib/main.dart` - Simplified initialization logic

The fix ensures the GUI now properly isolates storage by atSign, matching the TUI's robust approach and preventing the file overwrite issues you identified.
