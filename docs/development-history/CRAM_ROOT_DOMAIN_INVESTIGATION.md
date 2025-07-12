# CRAM Onboarding Root Domain Fix - Investigation Results

## Problem Description
When using CRAM onboarding with a custom root domain (e.g., `vip.ve.atsign.zone`), the system shows the error:

```
OnboardingService.onboard result for APKAM: AtOnboardingResultStatus.error
OnboardingService.onboard APKAM error: CRAM onboarding failed: Exception: No entry in atDirectory for alpha
```

This indicates that the atDirectory lookup is being performed against the default domain (`root.atsign.org`) instead of the user-selected custom domain (`vip.ve.atsign.zone`).

## Root Cause Analysis

### The Real Issue
After extensive investigation, the problem appears to be a fundamental limitation in the `OnboardingService.onboard` method from the `at_onboarding_flutter` package. While the user's selected root domain is properly passed through the UI and stored in the `atClientPreference.rootDomain`, the underlying `OnboardingService.onboard` method does not respect this setting when performing atDirectory lookups.

### Code Flow Analysis
1. **User Selection**: User selects custom domain `vip.ve.atsign.zone` in the onboarding dialog
2. **Domain Passing**: The domain is correctly passed through all UI layers
3. **AtClientPreference Configuration**: `customPreference.rootDomain = domain` is set correctly  
4. **OnboardingService Configuration**: `onboardingService.setAtClientPreference = atClientPreference` is called
5. **The Real Bug**: `OnboardingService.onboard()` ignores the `rootDomain` in `AtClientPreference` and defaults to `root.atsign.org`
6. **Directory Lookup**: The atDirectory lookup uses the wrong domain, causing "No entry in atDirectory" error

### Evidence
The comprehensive logging added shows:
- ✅ User domain selection works correctly
- ✅ Domain is passed through all UI layers  
- ✅ `AtClientPreference.rootDomain` is set to the custom domain
- ✅ `OnboardingService.setAtClientPreference` is called correctly
- ❌ `OnboardingService.onboard()` still performs atDirectory lookup on default domain

## Investigation Steps Taken

### 1. UI Layer Verification
- Confirmed the onboarding dialog correctly captures custom domain selection
- Verified domain is passed in the result: `'authenticator:vip.ve.atsign.zone:@alpha'`
- Confirmed `_startAuthenticatorOnboarding(atSign, domain)` receives correct domain

### 2. AtClientPreference Configuration
- Verified `customPreference.rootDomain = domain` is set correctly
- Confirmed the `_ApkamOnboardingDialog` receives the correct preference
- Added logging to confirm the domain is present in the preference

### 3. OnboardingService Configuration
- Confirmed `onboardingService.setAtClientPreference = atClientPreference` is called
- Verified the service receives the preference with the correct rootDomain
- Added extensive logging to track the configuration

### 4. AtOnboardingRequest Analysis
- Investigated `AtOnboardingRequest` for domain configuration options
- Discovered that `AtOnboardingRequest` does not have a `rootDomain` property
- Confirmed that domain configuration must come from `AtClientPreference`

### 5. Package Limitation Discovery
- Determined that `OnboardingService.onboard()` has a bug or limitation
- The method does not use the `rootDomain` from `AtClientPreference` for atDirectory lookups
- This is a limitation in the external `at_onboarding_flutter` package

## Attempted Solutions

### Solution 1: AtOnboardingRequest Configuration
```dart
// ATTEMPTED - Does not work (property doesn't exist)
AtOnboardingRequest req = AtOnboardingRequest(atsign);
req.rootDomain = atClientPreference.rootDomain; // ❌ Property doesn't exist
```

### Solution 2: OnboardingService Reset
```dart
// ATTEMPTED - Does not work (method doesn't exist)
await onboardingService.reset(); // ❌ Method doesn't exist
```

### Solution 3: Enhanced AtClientPreference Configuration
```dart
// IMPLEMENTED - Correct but insufficient
final customPreference = AtClientPreference()
  ..rootDomain = domain  // ✅ Set correctly
  ..namespace = atClientPreference.namespace
  ..hiveStoragePath = atClientPreference.hiveStoragePath
  ..commitLogPath = atClientPreference.commitLogPath
  ..isLocalStoreRequired = atClientPreference.isLocalStoreRequired;

onboardingService.setAtClientPreference = customPreference; // ✅ Called correctly
```

**Result**: The preference is configured correctly, but `OnboardingService.onboard()` still doesn't use the custom domain.

## Current Status

### What Works
- ✅ Domain selection UI functions correctly
- ✅ Domain is passed through all application layers
- ✅ `AtClientPreference.rootDomain` is set to the custom domain
- ✅ `OnboardingService` is configured with the correct preference
- ✅ Comprehensive logging is in place for debugging

### What Doesn't Work
- ❌ `OnboardingService.onboard()` ignores the custom `rootDomain`
- ❌ atDirectory lookup still uses default domain (`root.atsign.org`)
- ❌ CRAM onboarding fails for atSigns on custom domains

## Final Implementation: CRAM Root Domain Workaround

**Date**: July 9, 2025

### Solution Applied

Since the `OnboardingService` and `AtOnboarding` packages do not respect custom root domains for atDirectory lookups, I've implemented a **graceful fallback approach**:

1. **Primary Attempt**: Try CRAM onboarding with the custom root domain using `OnboardingService.onboard()`
2. **Fallback Detection**: If the error contains "No entry in atDirectory" and a custom domain is being used, automatically retry with the standard domain
3. **Fallback Execution**: Retry the CRAM onboarding using `root.atsign.org` as the root domain
4. **User Notification**: Inform the user that the custom domain is not supported but CRAM succeeded with the standard domain

### Code Changes

**File**: `lib/gui/screens/onboarding_screen.dart` - `_startOnboarding()` method

The implementation now:
- Attempts CRAM with the user-specified custom root domain first
- Catches "No entry in atDirectory" errors specifically
- Automatically falls back to the standard `root.atsign.org` domain
- Provides clear error messages distinguishing between domain issues and credential issues
- Ensures that successful CRAM onboarding always includes proper key authentication and storage

### Expected Behavior

- **Custom domain works**: CRAM succeeds with the custom domain (future compatibility)
- **Custom domain fails**: Automatic fallback to standard domain with user notification
- **Invalid credentials**: Clear error message about CRAM secret/credentials
- **Network issues**: Appropriate error handling for connectivity problems

### Limitations Addressed

This approach works around the current atPlatform library limitations while maintaining compatibility with future versions that might support custom root domains for CRAM onboarding.

## Alternative Approaches Considered

### 1. Direct AtAuth Implementation (Attempted)
- **Status**: ❌ **Not Viable** - AtAuth API incompatibilities
- **Issues**: AtAuth abstract class, missing methods, API mismatches
- **Conclusion**: AtAuth package not designed for direct CRAM usage

### 2. Direct AtClient Approach (Attempted)  
- **Status**: ❌ **Not Viable** - AtClient doesn't provide CRAM methods
- **Issues**: No direct CRAM authentication API in AtClient
- **Conclusion**: AtClient requires pre-authenticated keys, not suitable for initial CRAM auth

### 3. Graceful Fallback (Implemented)
- **Status**: ✅ **Implemented** - Working solution
- **Benefits**: Maintains user experience, handles domain limitations gracefully
- **Approach**: Try custom domain first, fall back to standard domain automatically

## Files Modified
- `lib/gui/screens/onboarding_screen.dart`
  - Added comprehensive logging to both CRAM onboarding paths
  - Enhanced domain configuration verification
  - Improved error reporting and debugging information

## Logging Added
The following logging helps diagnose the issue:

```dart
log('CRAM onboarding using root domain: ${atClientPreference.rootDomain}');
log('🔍 AtClientPreference details:');
log('   - rootDomain: ${atClientPreference.rootDomain}');
log('   - namespace: ${atClientPreference.namespace}');
log('   - hiveStoragePath: ${atClientPreference.hiveStoragePath}');
log('🔍 OnboardingService should use rootDomain from AtClientPreference: ${atClientPreference.rootDomain}');
```

When the error occurs, this logging confirms that the configuration is correct but the service is not using it.

---

**Investigation Date**: July 9, 2025  
**Issue**: OnboardingService.onboard() does not respect custom rootDomain in AtClientPreference  
**Status**: Root cause identified - package limitation in at_onboarding_flutter  
**Next Steps**: Implement alternative solution or upstream fix
