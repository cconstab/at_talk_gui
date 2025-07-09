# APKAM Keychain Preservation - Deep Fix for OnboardingService

## Summary
Fixed the root cause of APKAM onboarding deleting previous atSigns from the keychain. The issue was that `OnboardingService.authenticate()` calls in the APKAM dialog were not properly configured to preserve existing keychain entries.

## Root Cause Analysis
The previous fix addressed the `_handleOnboardingResult` method but missed the critical issue: the APKAM dialog's `onApproved()` method was calling `OnboardingService.authenticate()` without proper storage configuration, which was causing keychain cleanup internally.

## Technical Details
When APKAM enrollment is approved, the dialog calls `OnboardingService.authenticate()` to save keys to the keychain. However, this process was not configured to preserve existing atSigns in the keychain, causing them to be wiped during the authentication step.

## Fixes Applied

### 1. APKAM Approval Handler (`onApproved()`)
**File**: `lib/gui/screens/onboarding_screen.dart` (lines ~2254-2280)

**Before:**
```dart
// Use OnboardingService to authenticate after enrollment approval
final onboardingService = OnboardingService.getInstance();
onboardingService.setAtClientPreference = atClientPreference;
onboardingService.setAtsign = atsign;

// Authenticate after APKAM enrollment to save keys to keychain
final authStatus = await onboardingService.authenticate(atsign);
```

**After:**
```dart
// First, ensure storage is configured to preserve existing atSigns
log('Configuring storage to preserve existing atSigns...');
await AtTalkService.configureAtSignStorage(atsign, cleanupExisting: false);

// Use OnboardingService to authenticate after enrollment approval
final onboardingService = OnboardingService.getInstance();
onboardingService.setAtClientPreference = atClientPreference;
onboardingService.setAtsign = atsign;

// Authenticate after APKAM enrollment to save keys to keychain
final authStatus = await onboardingService.authenticate(atsign);
```

### 2. CRAM Authentication Handler
**File**: `lib/gui/screens/onboarding_screen.dart` (lines ~2428-2435)

**Before:**
```dart
log('Authenticating after CRAM onboarding to save keys to keychain...');
final authStatus = await onboardingService.authenticate(atsign);
```

**After:**
```dart
log('Authenticating after CRAM onboarding to save keys to keychain...');

// First, ensure storage is configured to preserve existing atSigns
log('Configuring storage to preserve existing atSigns...');
await AtTalkService.configureAtSignStorage(atsign, cleanupExisting: false);

final authStatus = await onboardingService.authenticate(atsign);
```

## Why This Fix Works
1. **Proactive Configuration**: Before calling `OnboardingService.authenticate()`, we explicitly configure the storage with `cleanupExisting: false`
2. **Keychain Preservation**: This ensures that when the authentication process runs, it doesn't wipe existing atSigns from the keychain
3. **Comprehensive Coverage**: Fixed both APKAM and CRAM authentication paths in the dialog

## Expected Behavior After Fix
- ✅ APKAM enrollment adds new atSign without removing previous ones
- ✅ All existing atSigns remain visible and functional after APKAM onboarding
- ✅ CRAM authentication also preserves existing atSigns
- ✅ No keychain cleanup during normal APKAM/CRAM flows

## Testing Recommendations
1. Add multiple atSigns to the app using .atKeys method
2. Perform APKAM enrollment for a new atSign
3. Verify all previous atSigns are still present and functional
4. Test CRAM authentication to ensure it also preserves existing atSigns
5. Verify error recovery scenarios don't cause keychain cleanup

## Previous Fixes Combined
This fix works in conjunction with the previous fixes:
- `_handleOnboardingResult` uses `cleanupExisting: false` (already applied)
- Robust error handling for keychain corruption (already applied)
- Proactive keychain integrity checks (already applied)

The combination ensures comprehensive keychain preservation throughout the entire APKAM onboarding flow.
