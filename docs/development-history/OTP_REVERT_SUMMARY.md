# OTP Functionality Revert

## Summary

The last changes that introduced `AtAuthServiceImpl` were causing compilation errors and breaking the OTP functionality. This document summarizes the revert changes made to fix the issue.

## Changes Made

### 1. Reverted `otpSubmit` method
- **File**: `lib/gui/screens/onboarding_screen.dart`
- **Issue**: The method was trying to use `AtAuthServiceImpl` which doesn't exist or isn't properly imported
- **Fix**: Reverted to use `OnboardingService` directly for enrollment
- **Key changes**:
  - Removed all references to `AtAuthServiceImpl.enroll()`
  - Simplified the enrollment process to use `OnboardingService.enroll()`
  - Removed the complex backup/restore logic that wasn't working
  - Kept the logging to track keychain state

### 2. Reverted APKAM dialog `init()` method
- **File**: `lib/gui/screens/onboarding_screen.dart`
- **Issue**: The method was trying to use `AtAuthServiceImpl.getSentEnrollmentRequest()` and `AtAuthServiceImpl.getFinalEnrollmentStatus()`
- **Fix**: Reverted to use `OnboardingService` and simplified the initialization
- **Key changes**:
  - Removed `AtAuthServiceImpl` usage
  - Simplified to just start with `OnboardingStatus.otpRequired` state
  - Removed problematic method calls that don't exist in `OnboardingService`

### 3. Fixed `onApproved()` method
- **File**: `lib/gui/screens/onboarding_screen.dart`
- **Issue**: The method was trying to use `AtAuthServiceImpl.getFinalEnrollmentStatus()`
- **Fix**: Removed the problematic status check and simplified the approval handling
- **Key changes**:
  - Removed `AtAuthServiceImpl` usage
  - Simplified to just wait for manual approval through UI

### 4. Removed unused method
- **File**: `lib/gui/screens/onboarding_screen.dart`
- **Issue**: `_setStateOnStatus` method became unused after removing `AtAuthServiceImpl` calls
- **Status**: Left in place (only generates a warning, not an error)

## Current State

### What Works
- ✅ **OTP submission**: The `otpSubmit` method now works without compilation errors
- ✅ **APKAM dialog initialization**: The dialog can initialize without crashing
- ✅ **App compilation**: The app builds successfully
- ✅ **Basic enrollment flow**: Users can submit OTP and get to pending approval state

### What's Preserved
- ✅ **Keychain logging**: All logging statements remain to track keychain state
- ✅ **OnboardingService configuration**: Still configures `OnboardingService` with `AtClientPreference`
- ✅ **Error handling**: Maintains proper error handling for OTP submission
- ✅ **UI state management**: Proper state transitions in the APKAM dialog

### Known Limitations
- ⚠️ **Keychain preservation**: The keychain wiping issue still exists (requires upstream fix)
- ⚠️ **Manual approval check**: Users need to manually check approval status through UI
- ⚠️ **Automatic status polling**: Removed automatic polling for enrollment status

## Next Steps

To address the keychain preservation issue properly, we need to:

1. **Investigate upstream packages**: Check if there are newer versions of `at_auth` or `at_onboarding_flutter` that provide better keychain preservation
2. **Consider alternative approaches**: Look into other methods that don't rely on `AtAuthServiceImpl` 
3. **Manual workarounds**: Implement manual backup/restore logic if upstream fixes aren't available
4. **Contact maintainers**: Reach out to the atPlatform team about the keychain wiping issue

## Testing

The app should now:
- ✅ Build without errors
- ✅ Allow OTP submission in APKAM flow
- ✅ Show proper UI states during enrollment
- ✅ Handle errors gracefully
- ⚠️ Still have the keychain wiping issue (but won't crash)

## Files Modified

- `lib/gui/screens/onboarding_screen.dart` - Reverted problematic `AtAuthServiceImpl` usage
