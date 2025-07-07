# AtClient Namespace Reinitialization Fix

## Issue
After changing the namespace in the GUI settings, the AtClient and AtKey were still using the old namespace (`default.attalk` instead of the new one, e.g., `test.attalk`), and Hive errors occurred due to improper AtClient/Hive reinitialization.

## Root Cause
In `AtTalkService.configureAtSignStorage()`, the namespace was being set using:
```dart
..namespace = _atClientPreference?.namespace ?? AtTalkEnv.namespace
```

This meant that when the namespace was changed, the method would use the cached old namespace from `_atClientPreference` instead of the newly updated `AtTalkEnv.namespace`.

## Fix Applied
1. **Always use current namespace**: Changed the preference initialization to always use `AtTalkEnv.namespace`:
   ```dart
   ..namespace = AtTalkEnv.namespace  // Always use current namespace from AtTalkEnv
   ```

2. **Proper initialization flag**: Added `_isInitialized = true` after reinitializing in `changeNamespace()` so the `atClient` getter works properly.

3. **Enhanced debugging**: Added comprehensive logging to track namespace changes and verify the AtClient is using the correct namespace.

## Verification
- Fixed the namespace fallback logic in `configureAtSignStorage()`
- Ensured `_isInitialized` flag is properly set after namespace changes
- Added debug logging to verify namespace updates
- Confirmed `flutter analyze` passes with no compilation errors
- Successfully built the macOS app in debug mode

## Expected Behavior
After this fix:
1. When changing namespace in GUI settings, `AtTalkEnv.namespace` is updated
2. `AtTalkService.changeNamespace()` cleans up old AtClient and reinitializes with new namespace
3. All new AtKeys use the correct namespace from `_atClientPreference.namespace`
4. `GroupsProvider.reinitialize()` restarts message subscriptions with the new namespace
5. TUI-to-GUI messaging works correctly with custom namespaces
6. No Hive box errors occur during namespace changes

## Additional Fix - Message Subscription Restart
Added proper subscription management to ensure TUI messages are received after namespace changes:

1. **Subscription Management**: Added `StreamSubscription? _messageSubscription` to track the active subscription
2. **Reinitialize Method**: Added `GroupsProvider.reinitialize()` that cancels old subscriptions and restarts them with the new namespace
3. **Settings Integration**: Updated settings screen to call `groupsProvider.reinitialize()` after successful namespace change and re-authentication
4. **Cleanup**: Added proper `@override dispose()` method to cancel subscriptions when the provider is disposed

This ensures that after changing the namespace in the GUI:
- Old message subscriptions are properly cancelled
- New subscriptions are created with the correct namespace
- The GUI can receive messages from TUI with the custom namespace

## Additional Fix - AtClient Cleanup for Multiple atSigns
Fixed the issue where adding a second atSign would immediately look for APKAM instead of going through proper onboarding:

**Root Cause**: When adding a second atSign, the AtClient from the first atSign remained active and wasn't properly cleaned up, causing the onboarding process to expect APKAM instead of performing fresh onboarding.

**Solution**: 
1. **AtClient Cleanup**: Added `cleanupExisting` parameter to `configureAtSignStorage()` method
2. **Automatic Detection**: The method now detects when switching to a different atSign and automatically cleans up the existing AtClient
3. **Onboarding Integration**: Updated onboarding screen and AuthProvider to enable cleanup when authenticating new atSigns
4. **Namespace Preservation**: Ensured namespace changes don't trigger unnecessary cleanup

This ensures that:
- Each atSign gets a fresh, clean AtClient environment
- No residual state from previous atSigns interferes with onboarding
- Proper storage isolation between different atSigns
- Correct onboarding flow (CRAM activation) instead of APKAM lookup

## Files Modified
- `/Users/cconstab/Documents/GitHub/cconstab/at_talk_gui/lib/core/services/at_talk_service.dart`
  - Fixed `configureAtSignStorage()` namespace assignment
  - Enhanced `changeNamespace()` with proper initialization flag
  - Added comprehensive debug logging

- `/Users/cconstab/Documents/GitHub/cconstab/at_talk_gui/lib/core/providers/groups_provider.dart`
  - Added `StreamSubscription? _messageSubscription` for subscription management
  - Added `reinitialize()` method to restart subscriptions after namespace changes
  - Updated `_subscribeToMessages()` to cancel existing subscriptions before creating new ones
  - Added proper `@override dispose()` method for cleanup

- `/Users/cconstab/Documents/GitHub/cconstab/at_talk_gui/lib/gui/screens/settings_screen.dart`
  - Updated namespace change flow to call `groupsProvider.reinitialize()` after re-authentication
  - Improved error handling and user feedback during namespace changes
