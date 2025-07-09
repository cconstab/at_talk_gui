# AtClient State Reset Fix for Keychain Preservation

## Problem Identified
The keychain wiping issue during APKAM onboarding appears to be caused by **AtClient state interference** between atSigns, not by our cleanup code. 

**Key Finding**: When switching between atSigns (e.g., from `@ssh_1` to `@llama` during APKAM onboarding), the AtClient retains state from the previous atSign, which may interfere with keychain operations for the new atSign.

## Root Cause Analysis
1. **AtClient State Persistence**: The AtClient maintains state for the currently authenticated atSign
2. **Keychain Interference**: When initializing AtClient for a new atSign, the existing state may cause keychain operations to interfere with other atSigns
3. **Incomplete Reset**: Previously, we only reset AtClient when `cleanupExisting: true`, but we need to reset the AtClient state even when preserving the keychain

## Solution Implemented
Added **lightweight AtClient state reset** in `AtTalkService.configureAtSignStorage()` that:

### When `cleanupExisting: true` (existing behavior):
- Performs full cleanup including keychain operations
- Resets AtClient manager
- Releases storage locks

### When `cleanupExisting: false` (new behavior):
- **Resets AtClient state** without affecting the keychain
- Stops notification subscriptions
- Resets AtClient manager (this clears client state but preserves keychain)
- Marks service as uninitialized

## Code Changes

### File: `lib/core/services/at_talk_service.dart`

```dart
// Clean up existing AtClient if switching to a different atSign
if (cleanupExisting && _instance != null) {
  final currentAtSign = _instance!.currentAtSign;
  if (currentAtSign != null && currentAtSign != fullAtSign) {
    print('🧹 Cleaning up existing AtClient for $currentAtSign before configuring $fullAtSign');
    await _instance!.cleanup();
  }
} else if (!cleanupExisting && _instance != null) {
  // Even when not cleaning up existing data, we need to reset the AtClient state
  // to prevent interference with the new atSign's operations
  final currentAtSign = _instance!.currentAtSign;
  if (currentAtSign != null && currentAtSign != fullAtSign) {
    print('🔄 Resetting AtClient state (without keychain cleanup) for atSign switch: $currentAtSign -> $fullAtSign');
    
    // Lightweight reset: just reset the AtClient manager without cleaning up keychain
    try {
      final client = _instance!.atClient;
      if (client != null) {
        print('  📡 Stopping notification subscriptions...');
        client.notificationService.stopAllSubscriptions();
      }
      
      print('  📱 Resetting AtClient manager (preserving keychain)...');
      AtClientManager.getInstance().reset();
      
      _instance!._isInitialized = false;
      print('✅ AtClient state reset completed - keychain preserved');
    } catch (e) {
      print('⚠️ AtClient state reset error: $e');
    }
  }
}
```

## Expected Behavior
1. **APKAM Onboarding**: When switching from `@ssh_1` to `@llama`, the AtClient state is reset but the keychain is preserved
2. **Keychain Preservation**: Both `@ssh_1` and `@llama` should remain in the keychain after APKAM onboarding
3. **No Interference**: The new atSign's operations won't be affected by the previous atSign's AtClient state

## Testing
- Test APKAM onboarding with an existing atSign in the keychain
- Verify that both the old and new atSigns appear in the atSign switcher
- Confirm that authentication works for both atSigns after onboarding

## Benefits
1. **Prevents Keychain Wiping**: Addresses the core issue where AtClient state interference was causing keychain manipulation
2. **Maintains Functionality**: Preserves all existing functionality while fixing the multi-atSign support
3. **Clean State**: Ensures each atSign gets a clean AtClient environment without affecting other atSigns
4. **Backward Compatible**: Doesn't change existing behavior for `cleanupExisting: true` scenarios

## Impact
This fix should resolve the primary issue where APKAM onboarding was removing existing atSigns from the keychain, enabling proper multi-atSign support in the application.

---

**Created**: December 2024  
**Status**: Under Testing  
**Files Modified**: `lib/core/services/at_talk_service.dart`
