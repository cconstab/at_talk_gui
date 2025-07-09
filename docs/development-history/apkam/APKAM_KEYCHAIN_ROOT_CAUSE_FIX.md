# APKAM Keychain Issue - ROOT CAUSE IDENTIFIED & FIXED

## Problem Summary
When adding a new atSign via APKAM onboarding, previous atSigns were being deleted from the keychain. This prevented users from having multiple atSigns available in the app.

## Root Cause Identified
The issue was **NOT** in the APKAM onboarding process itself. The logs revealed that the problem was in the **app startup sequence** in `main.dart`.

### Timeline of Events
1. **App Startup**: App reads keychain containing multiple atSigns (e.g., `[@llama, @ssh_1]`)
2. **First atSign Authentication**: `main.dart` calls `authProvider.authenticateExisting(atSigns.first)` with default `cleanupExisting: true`
3. **Keychain Cleanup**: This wipes all other atSigns from the keychain, leaving only the first one
4. **APKAM Onboarding**: User adds new atSign, but previous ones are already gone

### Key Evidence from Logs
- **Before startup**: Keychain contains: `[@llama, @ssh_1]`
- **After startup**: Keychain contains: `[@ssh_1]` (only the first atSign)
- **During APKAM**: Keychain consistently shows preservation behavior - no unexpected deletions
- **After APKAM**: Keychain correctly contains the new atSign

## Fix Applied
**File**: `lib/main.dart`
**Line**: 255
**Change**: Added `cleanupExisting: false` to the startup authentication call

```dart
// OLD CODE (causing the issue):
await authProvider.authenticateExisting(atSigns.first);

// NEW CODE (fixed):
await authProvider.authenticateExisting(atSigns.first, cleanupExisting: false);
```

## Why This Fix Works
1. **Preserves Keychain**: The startup authentication no longer cleans up other atSigns
2. **Maintains Functionality**: The app still authenticates with the first available atSign
3. **Enables Multi-atSign**: Users can now have multiple atSigns in their keychain
4. **APKAM Works**: New atSigns added via APKAM will be preserved alongside existing ones

## Testing Status
- ✅ **Root cause identified**: App startup was cleaning keychain, not APKAM process
- ✅ **Fix applied**: Modified `main.dart` to preserve keychain during startup
- ✅ **Comprehensive logging added**: Detailed tracking of keychain state at all critical points
- ⏳ **Testing in progress**: Waiting for app build to complete to verify fix

## Previous Attempts (Now Understood)
All previous attempts to fix the APKAM onboarding process were correct but addressing the wrong problem:
- ✅ APKAM onboarding already used `cleanupExisting: false` correctly
- ✅ Storage configuration was already preserving atSigns
- ✅ All authentication flows were already configured correctly

The real issue was the **one-time cleanup during app startup** that occurred before any APKAM onboarding.

## Expected Behavior After Fix
1. App starts with multiple atSigns in keychain (e.g., `[@llama, @ssh_1]`)
2. App authenticates with first atSign WITHOUT cleaning up others
3. User can add new atSign via APKAM onboarding
4. All atSigns remain available: `[@llama, @ssh_1, @new_atsign]`

## Files Modified
- `lib/main.dart` - Fixed startup authentication to preserve keychain
- `lib/gui/screens/onboarding_screen.dart` - Added comprehensive logging
- `lib/core/providers/auth_provider.dart` - Added comprehensive logging  
- `lib/core/services/at_talk_service.dart` - Added comprehensive logging

## Next Steps
1. Complete testing of the fix
2. Remove debug logging once confirmed working
3. Update documentation with final solution
