# AtClient Multi-atSign Onboarding Fix

## Issue
When adding a second atSign to the GUI, the system would immediately look for APKAM instead of going through the proper onboarding flow (CRAM activation). This happened because the AtClient from the first atSign remained active.

## Root Cause
The AtClient was not being properly cleaned up when switching between atSigns during onboarding. The system would:

1. Configure storage for the new atSign
2. But keep the existing AtClient instance active
3. The onboarding library would detect an existing AtClient
4. Assume this was an existing, registered atSign
5. Look for APKAM instead of performing fresh CRAM onboarding

## Solution Applied

### 1. Enhanced `configureAtSignStorage()` Method
Added a `cleanupExisting` parameter that:
- Automatically detects when switching to a different atSign
- Cleans up the existing AtClient before configuring new storage
- Ensures each atSign gets a fresh environment

```dart
static Future<AtClientPreference> configureAtSignStorage(
  String atSign, {
  bool forceEphemeral = false,
  bool cleanupExisting = true,  // New parameter
}) async {
  // Clean up existing AtClient if switching to a different atSign
  if (cleanupExisting && _instance != null) {
    final currentAtSign = _instance!.currentAtSign;
    if (currentAtSign != null && currentAtSign != fullAtSign) {
      print('🧹 Cleaning up existing AtClient for $currentAtSign before configuring $fullAtSign');
      await _instance!.cleanup();
    }
  }
  // ... rest of method
}
```

### 2. Updated Authentication Flow
Modified `AuthProvider.authenticate()` and `AuthProvider.authenticateExisting()` to always enable cleanup when switching atSigns:

```dart
await AtTalkService.configureAtSignStorage(atSign!, cleanupExisting: true);
```

### 3. Enhanced Onboarding Screen
Updated the onboarding screen to ensure proper cleanup when starting onboarding for a new atSign:

```dart
final atClientPreference = await AtTalkService.configureAtSignStorage(
  atSign,
  cleanupExisting: true,  // Ensure clean state for onboarding
);
```

### 4. Namespace Change Protection
Ensured that namespace changes don't trigger unnecessary cleanup since that's handled separately by the `changeNamespace()` method:

```dart
final newPreference = await configureAtSignStorage(
  currentAtSign,
  cleanupExisting: false, // Don't cleanup here, we already did it above
);
```

## Expected Behavior After Fix

### Before:
1. Add first atSign ✅ (works)
2. Add second atSign ❌ (immediately looks for APKAM)

### After:
1. Add first atSign ✅ (works)
2. Add second atSign ✅ (proper CRAM onboarding flow)

## Benefits

1. **Proper Onboarding Flow**: Each new atSign goes through the correct CRAM activation process
2. **Clean State**: No residual data from previous atSigns interferes with onboarding
3. **Storage Isolation**: Each atSign gets its own clean storage environment
4. **Improved UX**: Users can successfully add multiple atSigns without confusion
5. **Debugging**: Clear logging shows when AtClient cleanup occurs

## Files Modified

- `lib/core/services/at_talk_service.dart`
  - Enhanced `configureAtSignStorage()` with cleanup detection
  - Added automatic AtClient cleanup when switching atSigns

- `lib/core/providers/auth_provider.dart` 
  - Updated `authenticate()` and `authenticateExisting()` to enable cleanup
  - Ensures fresh AtClient state for each authentication

- `lib/gui/screens/onboarding_screen.dart`
  - Updated `_startOnboarding()` to enable cleanup for new atSigns
  - Ensures proper onboarding flow for multiple atSigns

This fix ensures that the GUI can properly handle multiple atSigns with the correct onboarding flow for each one.
