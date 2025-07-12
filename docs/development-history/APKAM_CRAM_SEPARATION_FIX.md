# APKAM and CRAM Separation Fix

**Date**: July 9, 2025  
**Issue**: APKAM onboarding was incorrectly attempting CRAM authentication
**Status**: ✅ **FIXED**

## Problem Description

The APKAM (Authenticated Public Key Authentication Method) dialog was incorrectly configured to allow both OTP and CRAM authentication methods. This caused the following issues:

1. **Wrong Flow**: When users selected "CRAM Secret" in the APKAM dialog, it would attempt CRAM onboarding instead of APKAM enrollment
2. **Domain Error**: This led to "No entry in atDirectory for alpha" errors because CRAM onboarding was being attempted with custom domains
3. **Confusion**: APKAM should only use OTP-based enrollment, not CRAM authentication

## Root Cause

The `_ApkamOnboardingDialog` class had:
- A `useCramAuth` boolean toggle allowing users to choose between OTP and CRAM
- A `cramController` for CRAM secret input
- A `cramSubmit()` method that performed CRAM onboarding instead of APKAM enrollment

This was architecturally incorrect because:
- **APKAM** = OTP-based device enrollment for existing atSigns
- **CRAM** = Secret-based authentication for new atSign activation

These are completely different authentication flows and should not be mixed.

## Solution Applied

### Code Changes

**File**: `lib/gui/screens/onboarding_screen.dart` - `_ApkamOnboardingDialog` class

1. **Removed CRAM Option**: Eliminated the radio button selection between OTP and CRAM
2. **Simplified UI**: APKAM dialog now only shows OTP input field
3. **Cleaned Up Code**: Removed `useCramAuth`, `cramController`, and related logic
4. **Fixed Submit Logic**: Button now only calls `otpSubmit()` for OTP-based enrollment

### Before (Problematic)
```dart
// Radio buttons for OTP vs CRAM selection
RadioListTile<bool>(title: const Text('OTP'), ...),
RadioListTile<bool>(title: const Text('CRAM Secret'), ...),

// Conditional UI based on selection
if (useCramAuth) ... // CRAM input field
if (!useCramAuth) ... // OTP input field

// Submit button calling wrong method
if (useCramAuth) {
  await cramSubmit(cramController.text.trim()); // ❌ Wrong!
} else {
  await otpSubmit(pinController.text); // ✅ Correct
}
```

### After (Fixed)
```dart
// Only OTP input - no confusing options
const Text('Enter 6-digit OTP:', ...),
PinCodeTextField(...), // OTP input only

// Submit button only does OTP enrollment
if (pinController.text.length == _kPinLength) {
  await otpSubmit(pinController.text); // ✅ Always correct
}
```

## Expected Behavior

### APKAM Flow (Fixed)
1. User selects "Authenticator (APKAM)" from main onboarding dialog
2. APKAM dialog opens showing only OTP input
3. User enters 6-digit OTP from authenticator app
4. System performs proper APKAM enrollment via `otpSubmit()`
5. No domain-related errors occur

### CRAM Flow (Separate)
1. User selects "New atSign Activation" from main onboarding dialog
2. Separate CRAM dialog collects CRAM secret
3. System performs CRAM onboarding via `_startOnboarding()`
4. Custom domain fallback logic handles domain issues

## Files Modified
- `lib/gui/screens/onboarding_screen.dart`
  - Removed `useCramAuth` and `cramController` variables
  - Simplified APKAM dialog UI to OTP-only
  - Fixed submit button logic
  - Updated help text to remove CRAM references

## Testing Results

**Before Fix**:
```
OnboardingService.onboard result for APKAM: AtOnboardingResultStatus.error
OnboardingService.onboard APKAM error: CRAM onboarding failed: Exception: No entry in atDirectory for alpha
```

**After Fix**:
- APKAM dialog only shows OTP input
- No CRAM-related errors in APKAM flow
- Each authentication method uses its correct flow

## Impact

- ✅ **APKAM works correctly**: Only uses OTP enrollment as intended
- ✅ **CRAM separated**: CRAM authentication remains in its proper flow
- ✅ **No confusion**: Users see appropriate options for each method
- ✅ **Domain issues resolved**: APKAM no longer triggers custom domain CRAM errors

This fix ensures that each authentication method (APKAM vs CRAM) uses its correct and intended flow, eliminating the confusion and errors that occurred when they were mixed together.
