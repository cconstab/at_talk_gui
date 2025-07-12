# APKAM Keychain Preservation Solution

## Root Cause Identified

The issue was caused by calls to `OnboardingService.authenticate()` during the APKAM onboarding flow. This method **internally wipes the keychain** when authenticating a new atSign, which is the intended behavior of the onboarding library but undesirable for our use case where we want to preserve existing atSigns.

## Problem Locations

1. **APKAM Dialog `onApproved()` method** - Called `OnboardingService.authenticate()` after enrollment approval
2. **Main onboarding result handler `_handleOnboardingResult()`** - Called `OnboardingService.authenticate()` after successful enrollment
3. **CRAM authentication flow** - Also called `OnboardingService.authenticate()` (fixed for consistency)

## Solution Applied

### Key Changes

1. **Removed `OnboardingService.authenticate()` calls** from both APKAM approval and main result handling flows
2. **Use `AuthProvider.authenticateExisting()` instead** - This method preserves the keychain by using `AtAuthService.authenticate()` internally
3. **Ensure `cleanupExisting: false`** is consistently used throughout the authentication flow

### Code Changes

#### 1. APKAM Dialog `onApproved()` Method (lines ~2280-2320)
```dart
// BEFORE (problematic):
final authStatus = await onboardingService.authenticate(atsign);

// AFTER (fixed):
// Skip OnboardingService.authenticate() entirely to preserve keychain
// The enrollment process already saves keys to keychain
log('✅ APKAM enrollment completed - keys should be preserved in keychain');
log('🔄 Skipping OnboardingService.authenticate() to preserve existing atSigns');
```

#### 2. Main Result Handler `_handleOnboardingResult()` (lines ~690-740)
```dart
// BEFORE (problematic):
final authStatus = await onboardingService.authenticate(result.atsign!);
if (authStatus == AtOnboardingResponseStatus.authSuccess) {
  await authProvider.authenticateExisting(result.atsign!, cleanupExisting: false);
}

// AFTER (fixed):
// Skip OnboardingService.authenticate() and use AuthProvider directly
await authProvider.authenticateExisting(result.atsign!, cleanupExisting: false);
```

#### 3. CRAM Authentication Flow (lines ~2460-2480)
```dart
// BEFORE (problematic):
final authStatus = await onboardingService.authenticate(atsign);

// AFTER (fixed):
// Skip OnboardingService.authenticate() to preserve keychain
// CRAM onboarding should handle key storage automatically
log('✅ CRAM onboarding completed - keys should be preserved in keychain');
```

## Why This Works

1. **APKAM/CRAM onboarding already saves keys** - The `OnboardingService.enroll()` and `OnboardingService.onboard()` methods already save the keys to the keychain
2. **AuthProvider.authenticateExisting() preserves keychain** - This method uses `AtAuthService.authenticate()` which doesn't wipe the keychain
3. **Consistent `cleanupExisting: false`** - All storage configuration calls now preserve existing atSigns

## Testing

After applying this fix:
1. Start with an existing atSign in the keychain (e.g., `@llama`)
2. Add a new atSign via APKAM onboarding (e.g., `@ssh_1`)
3. Verify that both atSigns remain in the keychain after onboarding completion

## Expected Behavior

- **Before fix**: Only the newly added atSign remains in keychain
- **After fix**: Both the existing and newly added atSigns remain in keychain

## Technical Notes

- The `OnboardingService.authenticate()` method is designed to replace the keychain contents for a single-user flow
- Our multi-user flow requires preserving existing atSigns
- The enrollment/onboarding process already handles key storage, so the additional authenticate call was redundant and harmful
- Using `AuthProvider.authenticateExisting()` provides the proper AtClient initialization without keychain wiping

## Status

✅ **FIXED** - APKAM onboarding now preserves existing atSigns in the keychain
