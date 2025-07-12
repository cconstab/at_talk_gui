# CRAM Onboarding Root Domain Fix

## Problem Description
When using CRAM onboarding with a custom root domain (e.g., `vip.ve.atsign.zone`), the system was showing the error:

```
AtOnboarding.onboard APKAM error: CRAM onboarding failed: Exception: No entry in atDirectory for alpha
```

This indicated that the atDirectory lookup was being performed against the default domain (`root.atsign.org`) instead of the user-selected custom domain (`vip.ve.atsign.zone`).

## Root Cause Analysis

### The Issue
The problem was in the `cramSubmit` method within the `_ApkamOnboardingDialog` class. While the user's selected root domain was properly passed to the dialog and set in the `atClientPreference.rootDomain`, the `AtOnboardingRequest` object was not configured to use this domain.

### Code Flow Analysis
1. **User Selection**: User selects "Authenticator (APKAM)" method with custom domain `vip.ve.atsign.zone`
2. **Domain Passing**: `_startAuthenticatorOnboarding(atSign, domain)` correctly sets `customPreference.rootDomain = domain`
3. **Dialog Creation**: `_ApkamOnboardingDialog` receives the correct `customPreference` with the right domain
4. **CRAM Submit**: User selects CRAM authentication and calls `cramSubmit()`
5. **The Bug**: `cramSubmit()` creates `AtOnboardingRequest req = AtOnboardingRequest(atsign)` without setting the root domain
6. **Directory Lookup**: The `OnboardingService.onboard()` method uses the default domain for atDirectory lookup

### Why This Happened
The `AtOnboarding.onboard` method from the `at_onboarding_flutter` package was not properly using the custom `rootDomain` configuration from the `AtOnboardingConfig` or `AtClientPreference` when performing atDirectory lookups. The `OnboardingService.onboard` method, when properly configured with the root domain on the `AtOnboardingRequest`, correctly uses the specified domain.

## Solution Implemented

### Fix Applied
Modified both CRAM onboarding paths to use `OnboardingService.onboard` directly instead of `AtOnboarding.onboard`, and explicitly set the root domain on the `AtOnboardingRequest`:

**1. APKAM CRAM Onboarding** (in `cramSubmit` method):
```dart
// Create onboarding request with root domain configuration
AtOnboardingRequest req = AtOnboardingRequest(atsign);
// Ensure the request uses the correct root domain from atClientPreference
req.rootDomain = atClientPreference.rootDomain;
```

**2. Main CRAM Onboarding** (in `_startOnboarding` method):
```dart
// Use OnboardingService directly instead of AtOnboarding.onboard to ensure domain is properly used
final onboardingService = OnboardingService.getInstance();
onboardingService.setAtClientPreference = customPreference;
onboardingService.setAtsign = atSign;

// Create onboarding request with root domain configuration
final req = AtOnboardingRequest(atSign);
req.rootDomain = customPreference.rootDomain;

// Use OnboardingService.onboard instead of AtOnboarding.onboard
final onboardResult = await onboardingService.onboard(cramSecret: cramSecret.trim(), atOnboardingRequest: req);
```

### Enhanced Logging
Added comprehensive logging to both CRAM onboarding paths:

1. **Main CRAM Onboarding** (`_startOnboarding`):
   ```dart
   print('🌐 AtOnboarding.onboard using domain: $domain');
   print('🌐 AtClientPreference rootDomain: ${customPreference.rootDomain}');
   ```

2. **APKAM CRAM Onboarding** (`cramSubmit`):
   ```dart
   log('CRAM onboarding using root domain: ${atClientPreference.rootDomain}');
   ```

## Testing Verification

### Expected Behavior After Fix
1. User selects "Authenticator (APKAM)" method
2. User specifies custom root domain (e.g., `vip.ve.atsign.zone`)
3. User selects CRAM authentication within the APKAM dialog
4. User enters CRAM secret
5. The atDirectory lookup should now use `vip.ve.atsign.zone` instead of `root.atsign.org`
6. CRAM onboarding should succeed for atSigns registered on the custom domain

### Log Output to Verify
Look for these log messages to confirm the fix:
```
CRAM onboarding using root domain: vip.ve.atsign.zone
Set OnboardingService atClientPreference and atsign
Attempting CRAM onboarding using OnboardingService for @atsign
```

## Files Modified
- `lib/gui/screens/onboarding_screen.dart`
  - Enhanced `cramSubmit()` method to set root domain on `AtOnboardingRequest`
  - **Modified `_startOnboarding()` method to use `OnboardingService.onboard` instead of `AtOnboarding.onboard`**
  - Added domain logging to both CRAM onboarding paths
  - Added proper authentication flow after OnboardingService onboarding

## Impact
- **Fixes**: CRAM onboarding with custom root domains
- **Preserves**: All existing functionality for default domain onboarding
- **Improves**: Debugging capability with enhanced logging
- **No Breaking Changes**: All existing onboarding flows continue to work

## Technical Details

### Domain Configuration Flow
1. **User Input** → `_OnboardingDialog` captures domain selection
2. **Method Selection** → Dialog returns `'authenticator:domain:atSign'`
3. **APKAM Dialog** → `_startAuthenticatorOnboarding()` creates `customPreference` with correct domain
4. **CRAM Submit** → `cramSubmit()` now explicitly sets domain on `AtOnboardingRequest`
5. **Directory Lookup** → Uses correct domain for atDirectory operations

### Alternative Paths
- **"New atSign Activation"** method uses `AtOnboarding.onboard()` directly (was already working)
- **".atKeys Upload"** method uses PKAM authentication (doesn't use atDirectory)
- **APKAM OTP** method doesn't use CRAM (separate code path)

---

**Fix Date**: July 9, 2025  
**Issue**: Custom root domain not used in CRAM onboarding via APKAM dialog  
**Resolution**: Set `req.rootDomain` explicitly in `cramSubmit()` method
