# Offline Messages Fix - TUI & GUI Storage Management

## Current Status: ✅ COMPLETED

The AtTalk TUI and GUI now have robust, user-friendly, and cross-platform storage handling including:
- ✅ Ephemeral (temp) and persistent storage modes  
- ✅ User-facing options for ephemeral mode and storage cleanup
- ✅ Improved error handling for storage/database corruption, locking, and multi-instance issues
- ✅ Reliable multi-instance detection and fallback to ephemeral storage for Hive errors
- ✅ Code quality improvements (removed unused imports, cleaned up analysis warnings)

## Storage Paths

### Normal Mode (Persistent)
#### TUI
- Primary: `~/.ai6bh/@atsign/storage` 
- Fallback: `~/.ai6bh/@atsign/{uuid}/storage`
- Files: `~/.ai6bh/@atsign/files`

#### GUI
- Primary: `{AppSupport}/.ai6bh/@atsign/storage`
- Fallback: `{AppSupport}/.ai6bh/@atsign/{uuid}/storage`
- Files: `{AppSupport}/.ai6bh/@atsign/files`

### Ephemeral Mode (Auto-cleanup)
#### Both TUI & GUI
- Storage: `{OS_TEMP_DIR}/at_talk_{tui|gui}/@atsign/{uuid}/storage`
- Files: `{OS_TEMP_DIR}/at_talk_{tui|gui}/@atsign/{uuid}/files`
- OS-specific temp directories:
  - macOS/Linux: `$TMPDIR` or `/tmp`
  - Windows: `%TEMP%` or `%TMP%` or `C:\Windows\Temp`
  - Android: `/data/local/tmp`ument describes the changes made to fix offline message delivery in both AtTalk TUI and GUI applications.

## Problem
Both applications were creating new UUID-based storage paths on each run, which meant:
1. Offline messages sent to the atSign while the app was not running could not be retrieved
2. The atClient couldn't access previously stored notification state
3. Each app session was effectively isolated from previous sessions

## Solution
Implemented a multi-tier storage strategy for both TUI and GUI:

### 1. Default Persistent Storage
- **TUI**: Uses fixed storage path: `~/.ai6bh/@atsign/storage`
- **GUI**: Uses application support directory with atSign-specific paths
- Allows offline messages to persist between app sessions
- Enables proper offline notification retrieval via `fetchOfflineNotifications: true`

### 2. Multi-Instance Support  
- If the primary storage is locked (another instance running), automatically falls back to UUID-based storage
- Allows multiple app instances to run simultaneously
- Provides user feedback about the fallback

### 3. Ephemeral Mode
- **TUI**: Added `--ephemeral` command-line flag
- **GUI**: Added settings toggle in Storage Settings
- Uses OS temp directories for automatic cleanup
- Useful for testing or when persistence is not desired

## Storage Paths

### Normal Mode (Persistent)
- Primary: `~/.ai6bh/@atsign/storage` 
- Fallback: `~/.ai6bh/@atsign/{uuid}/storage`
- Files: `~/.ai6bh/@atsign/files`

### Ephemeral Mode  
- Storage: `{OS_TEMP_DIR}/at_talk_tui/@atsign/{uuid}/storage`
- Files: `{OS_TEMP_DIR}/at_talk_tui/@atsign/{uuid}/files`
- OS-specific temp directories:
  - macOS/Linux: `$TMPDIR` or `/tmp`
  - Windows: `%TEMP%` or `%TMP%` or `C:\Windows\Temp`
  - Android: `/data/local/tmp`

## Usage

### TUI

#### Standard Usage (Persistent)
```bash
dart run bin/at_talk_tui.dart -a @alice -t @bob
```

#### Multiple Instances
```bash
# First instance uses persistent storage
dart run bin/at_talk_tui.dart -a @alice -t @bob

# Second instance automatically uses fallback storage  
dart run bin/at_talk_tui.dart -a @alice -t @charlie
```

#### Ephemeral Mode
```bash
dart run bin/at_talk_tui.dart -a @alice -t @bob --ephemeral
```

### GUI

#### Standard Usage
```bash
flutter run
```

#### Ephemeral Mode
1. Open the app
2. Go to Settings (gear icon)
3. Toggle "Ephemeral Storage Mode" under Storage Settings
4. Restart the app for changes to take effect

## Technical Details

### AtClient Configuration
- `fetchOfflineNotifications: true` - Retrieves missed notifications on startup
- `isLocalStoreRequired: true` - Enables local storage for persistence
- Notification subscription uses `shouldDecrypt: true` for automatic decryption

### Multi-Instance Detection & Handling

#### Reactive Hive Failure Detection (TUI)
For persistent storage, the TUI now uses a reactive approach to handle multi-instance conflicts:
- Starts with primary persistent storage by default
- If Hive database authentication fails due to locking or corruption:
  1. **First fallback**: Tries UUID-based persistent storage for multi-instance support
  2. **Second fallback**: Switches to ephemeral storage as last resort
- Provides clear feedback about which storage mode is being used
- Ensures the app can always start, even with persistent storage issues

#### Ephemeral Mode Benefits
- **Never conflicts**: Ephemeral mode always uses fresh, unique directories
- **Automatic cleanup**: OS handles cleanup of temporary files
- **Multi-instance safe**: Each instance gets its own UUID-based path
- **Fallback option**: Acts as last resort when persistent storage fails

#### Storage Failure Handling
- **Database locks**: Detects "database locked" or "database busy" errors during authentication
- **Hive corruption**: Handles various Hive database corruption scenarios:
  - "Box not found" errors
  - "FileSystemException: readinto failed"
  - Permission denied errors
  - Invalid database formats
- **Automatic recovery**: Attempts storage cleanup before falling back
- **Progressive fallback**: Primary → UUID fallback → Ephemeral storage

#### Error Detection Patterns
Detects and handles these common storage issues:
- "Database locked" or "database busy" (multi-instance conflicts)
- "Box not found" or "did you forget to call Hive.openBox()" (Hive initialization issues)
- "FileSystemException: readinto failed" (file corruption)
- "No such file or directory" (missing storage files)
- "Permission denied" (filesystem permissions)
- "Hive error", "corrupted", "invalid format" (database corruption)
  - Corrupted .hive files
  - Invalid database formats

### GUI Storage Error Handling
- Enhanced AtTalkService with robust storage error recovery
- Automatic detection and handling of database lock issues (multi-instance support)
- Storage corruption detection and automatic cleanup
- Fallback to UUID-based storage when primary storage fails
- User guidance suggesting ephemeral mode after persistent failures
- Same error pattern detection as TUI for consistency

### Compatibility
- Maintains full compatibility with the GUI client
- Uses the same message format and notification system
- Supports both individual and group conversations

## Testing

To test offline message delivery:

1. Start TUI with persistent storage
2. Send messages to the atSign from another client while TUI is not running
3. Restart TUI - offline messages should appear
4. Verify multiple instances can run simultaneously
5. Test ephemeral mode for non-persistent behavior

## Benefits

1. **✅ Offline messages now work**: Messages sent while TUI is offline will appear when it restarts
2. **✅ Multi-instance support**: Multiple TUI instances can run simultaneously  
3. **✅ User choice**: Ephemeral mode for when persistence isn't wanted
4. **✅ Automatic cleanup**: Ephemeral files stored in OS temp directories for automatic cleanup
5. **✅ Cross-platform**: Proper temp directory detection for all supported platforms
6. **✅ Automatic handling**: No manual intervention needed for common scenarios
7. **✅ Clear feedback**: Users understand which storage mode is active
8. **✅ Robust error recovery**: Both TUI and GUI automatically handle storage corruption and database locks
9. **✅ Consistent experience**: Same error handling and recovery patterns across TUI and GUI
10. **✅ User guidance**: Clear suggestions for troubleshooting persistent storage issues

## Files Modified
- `bin/at_talk_tui.dart` - TUI main logic, storage configuration, and authentication handling
- `lib/main.dart` - GUI initialization with storage-aware preferences
- `lib/core/services/at_talk_service.dart` - Added storage-aware preference creation methods
- `lib/core/utils/temp_directory_utils.dart` - Cross-platform temp directory utilities
- `lib/core/utils/storage_configuration.dart` - Storage path configuration management
- `lib/core/utils/storage_preferences.dart` - Persistent storage preferences using SharedPreferences
- `lib/gui/screens/settings_screen.dart` - Added ephemeral storage mode toggle

## Startup Logic Flow

### TUI Storage Path Decision Process

```
Start TUI
    │
    ├─ Ephemeral Mode? (--ephemeral flag)
    │   ├─ YES: Use temp directory with UUID
    │   │        └─ Path: {OS_TEMP}/at_talk_tui/@atsign/{uuid}/storage
    │   │        └─ Always succeeds (unique path)
    │   │
    │   └─ NO: Persistent Mode
    │        └─ Start with primary storage
    │             └─ Path: ~/.ai6bh/@atsign/storage
    │
    │
    ├─ Attempt Authentication with Current Storage
    │   │
    │   ├─ SUCCESS: Continue with current storage
    │   │
    │   └─ FAILURE: Check exception type
    │        │
    │        ├─ Database Lock/Busy Error?
    │        │   ├─ Using primary storage?
    │        │   │   └─ Switch to fallback UUID storage
    │        │   │        └─ Path: ~/.ai6bh/@atsign/{uuid}/storage
    │        │   │        └─ Retry authentication
    │        │   │
    │        │   └─ Using fallback storage? 
    │        │       └─ Switch to ephemeral storage
    │        │            └─ Path: {OS_TEMP}/at_talk_tui/@atsign/{uuid}/storage
    │        │            └─ Retry authentication
    │        │
    │        └─ Storage Corruption Error?
    │             ├─ Try to clean current storage and retry
    │             └─ If cleanup fails:
    │                  └─ Switch to ephemeral storage
    │                       └─ Path: {OS_TEMP}/at_talk_tui/@atsign/{uuid}/storage
    │                       └─ Retry authentication
```

### Key Improvements

1. **Reactive Approach**: No proactive lock checking - handles failures as they occur
2. **Progressive Fallback**: Primary → UUID fallback → Ephemeral storage
3. **Always Succeeds**: Ephemeral storage as final fallback ensures app always starts
4. **Clear User Feedback**: Shows exactly which storage mode succeeded
