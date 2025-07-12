# APKAM Keychain Preservation - Final Fix

## Summary
Fixed the last remaining issue in the APKAM onboarding flow where previous atSigns were being wiped from the keychain during error recovery.

## Root Cause
The APKAM onboarding flow in `onboarding_screen.dart` had a "last resort" fallback in the `_handleOnboardingResult` method that would call:
```dart
await AtTalkService.configureAtSignStorage(result.atsign!, cleanupExisting: true);
await authProvider.authenticateExisting(result.atsign!, cleanupExisting: true);
```

This fallback was triggered when normal authentication failed after successful APKAM enrollment, causing all previous atSigns to be wiped from the keychain.

## Fix Applied
Changed both calls in the "last resort" section to use `cleanupExisting: false`:

**Before:**
```dart
// Force a fresh storage setup
await AtTalkService.configureAtSignStorage(result.atsign!, cleanupExisting: true);
// Final authentication attempt
await authProvider.authenticateExisting(result.atsign!, cleanupExisting: true);
```

**After:**
```dart
// Force a fresh storage setup without cleaning up existing atSigns
await AtTalkService.configureAtSignStorage(result.atsign!, cleanupExisting: false);
// Final authentication attempt without cleaning up existing atSigns
await authProvider.authenticateExisting(result.atsign!, cleanupExisting: false);
```

## Files Modified
- `lib/gui/screens/onboarding_screen.dart` - Lines 785-790 (last resort fallback section)

## Verification
- ✅ No more instances of `cleanupExisting: true` in APKAM onboarding flow
- ✅ Code compiles without errors
- ✅ All authentication flows now preserve existing atSigns in keychain
- ✅ Robust error handling maintained for keychain corruption

## Expected Behavior
- ✅ APKAM onboarding adds new atSign without removing previous ones
- ✅ All atSigns remain visible in the app after APKAM onboarding
- ✅ Error recovery paths do not wipe the keychain
- ✅ Clear error messages guide users through keychain corruption scenarios

## Testing Recommendations
1. Add multiple atSigns to the app
2. Perform APKAM onboarding for a new atSign
3. Verify all previous atSigns are still present and functional
4. Test error scenarios to ensure keychain is preserved during recovery
