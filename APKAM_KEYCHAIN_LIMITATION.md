# APKAM Keychain Limitation - Current Status

## Problem Statement
During APKAM (Application Key Management) onboarding, the keychain is wiped, causing previously onboarded atSigns to be lost. This is a known limitation of the current implementation.

## Root Cause
The APKAM onboarding process calls `OnboardingService.enroll()` which modifies the global singleton state and appears to wipe the keychain, despite using isolated storage for the APKAM enrollment itself.

## Attempted Solutions

### 1. Isolated Storage Approach
- **Attempted**: Created isolated storage paths for APKAM enrollment
- **Result**: Failed - keychain still wiped
- **Reason**: The `OnboardingService` singleton affects global state

### 2. Keychain Backup/Restore Mechanism
- **Attempted**: Back up keychain before APKAM, restore after
- **Result**: Failed - restoration fails with "No keys found"
- **Reason**: Secure storage is also wiped during APKAM onboarding

### 3. OnboardingService State Restoration
- **Attempted**: Save and restore OnboardingService state
- **Result**: Partial success - helps preserve global state
- **Reason**: Still doesn't prevent the underlying keychain wipe

## Current Behavior
- **Before APKAM**: User has multiple atSigns (e.g., @cconstab, @test)
- **After APKAM**: Only the newly enrolled atSign is visible (e.g., @llama)
- **Lost atSigns**: Previous atSigns are removed from keychain and cannot be restored

## Workaround for Users
1. **Backup Keys**: Always backup .atKeys files before APKAM onboarding
2. **Re-import**: After APKAM onboarding, re-import previous atSigns using .atKeys files
3. **Sequential Process**: Complete one atSign at a time, backing up between each

## Technical Details
- **Affected Method**: `_startAuthenticatorOnboarding()` in `onboarding_screen.dart`
- **SDK Components**: `OnboardingService`, `AtAuthServiceImpl`, keychain management
- **Logs Show**: Keychain backup successful, restoration attempt fails
- **Error**: "No keys found for atSign @cconstab. Please onboard first."

## Next Steps Required
This limitation needs to be addressed at the SDK level:

1. **AtClient SDK**: Modify APKAM onboarding to not affect keychain for other atSigns
2. **OnboardingService**: Implement proper isolation for APKAM operations
3. **KeyChainManager**: Ensure keychain operations don't have global side effects

## Current Status
- ✅ **Issue Documented**: Root cause identified and documented
- ✅ **Workaround Available**: Users can re-import using .atKeys files
- ❌ **Not Fixed**: APKAM still wipes keychain
- ❌ **SDK Fix Needed**: Requires changes to atSign SDK

## Impact on Users
- **Moderate**: Users can still use APKAM but need to re-import previous atSigns
- **Temporary**: This is a temporary limitation until SDK is fixed
- **Workaround Available**: .atKeys backup/restore process works

---

**Date**: December 2024  
**Status**: Known Limitation - SDK Fix Required  
**Workaround**: Use .atKeys backup/restore process
