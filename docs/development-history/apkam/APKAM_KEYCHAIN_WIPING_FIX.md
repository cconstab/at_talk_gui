# APKAM Keychain Wiping Fix

## Issue Description
During APKAM (Authenticator-based onboarding) enrollment, the keychain was being wiped, causing all previously stored atSigns to be lost. This was a critical bug that prevented users from maintaining multiple atSigns after using APKAM onboarding.

## Root Cause Analysis
The issue was in the `otpSubmit` method in `lib/gui/screens/onboarding_screen.dart`. When the user submitted their OTP for APKAM enrollment, the code was:

1. Creating an instance of `OnboardingService`
2. **NOT** configuring it with the correct `AtClientPreference`
3. Calling `OnboardingService.enroll()` with an unconfigured service

This caused the `OnboardingService` to use default or incorrect settings, which resulted in the keychain being wiped during the enrollment process.

## Evidence from Logs
The logs showed:
- **Before APKAM**: Keychain contained `[@llama]`
- **After APKAM**: Keychain only contained `[@ssh_1]` (the newly enrolled atSign)

The critical line in logs was:
```
🔍 Keychain BEFORE OnboardingService.enroll(): [@llama]
🔍 Keychain AFTER OnboardingService.enroll(): [@ssh_1]
```

This confirmed that `OnboardingService.enroll()` was the exact point where the keychain was wiped.

## Solution Applied
Modified the `otpSubmit` method in `lib/gui/screens/onboarding_screen.dart` to configure the `OnboardingService` with the correct `AtClientPreference` before calling `enroll()`:

```dart
// Before (problematic):
final onboardingService = OnboardingService.getInstance();
// Missing configuration step!
final enrollResponse = await onboardingService.enroll(atsign, enrollmentRequest);

// After (fixed):
final onboardingService = OnboardingService.getInstance();

// CRITICAL FIX: Configure OnboardingService with the correct AtClientPreference
log('🔧 Configuring OnboardingService with atClientPreference to preserve keychain...');
onboardingService.setAtClientPreference = atClientPreference;
log('✅ OnboardingService configured with atClientPreference');

final enrollResponse = await onboardingService.enroll(atsign, enrollmentRequest);
```

## How the Fix Works
1. **Proper Configuration**: The `OnboardingService` is now configured with the same `AtClientPreference` that was used to create the APKAM dialog
2. **Keychain Preservation**: The properly configured service uses the correct storage paths and settings, preserving existing atSigns in the keychain
3. **Consistent Behavior**: This aligns with how other parts of the APKAM flow were already configured (like `AtAuthServiceImpl`)

## Files Modified
- `lib/gui/screens/onboarding_screen.dart` - `otpSubmit` method (~line 2342)

## Testing
- Build and run the app
- Start with an existing atSign (e.g., `@llama`)
- Perform APKAM enrollment for a new atSign (e.g., `@ssh_1`)
- Verify that both atSigns remain in the keychain after enrollment
- Verify that the new atSign can be successfully authenticated

## Expected Behavior After Fix
1. **APKAM Enrollment**: Completes successfully for new atSign
2. **Keychain Preservation**: All previously stored atSigns remain in the keychain
3. **Authentication**: New atSign is properly authenticated and becomes active
4. **Navigation**: User proceeds to groups screen without issues

## Impact
This fix resolves the critical APKAM keychain wiping issue and allows users to maintain multiple atSigns when using APKAM onboarding, which is essential for the multi-atSign functionality of the app.

---

**Date**: December 2024  
**Status**: Implemented  
**Priority**: Critical - Fixes data loss issue in APKAM onboarding
