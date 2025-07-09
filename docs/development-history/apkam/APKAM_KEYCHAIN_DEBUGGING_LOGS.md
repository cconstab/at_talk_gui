# APKAM Keychain Debugging Logs

## Problem Description
When adding a new atSign via APKAM onboarding, previous atSigns are being deleted from the keychain. This prevents users from having multiple atSigns available in the app.

## Steps to Reproduce
1. Start with an existing atSign in the keychain (e.g., `@llama`)
2. Add a new atSign via APKAM onboarding (e.g., `@ssh_1`)
3. Notice that the original atSign (`@llama`) is no longer available in the keychain

## Current Logs Added
To debug this issue, detailed logging has been added to track keychain state at every step:

### 1. `onApproved()` method in APKAM dialog
- Logs keychain state BEFORE `OnboardingService.authenticate()`
- Logs keychain state JUST BEFORE the authenticate call
- Logs keychain state IMMEDIATELY AFTER the authenticate call

### 2. `_handleOnboardingResult()` method in onboarding screen
- Logs keychain state BEFORE main authentication flow
- Logs keychain state JUST BEFORE main `OnboardingService.authenticate()` call
- Logs keychain state IMMEDIATELY AFTER main authenticate call

### 3. `AuthProvider.authenticateExisting()` method
- Logs keychain state BEFORE AuthProvider authentication
- Logs keychain state AFTER `AtTalkService.configureAtSignStorage()`

### 4. `AtTalkService.onboard()` method
- Logs keychain state BEFORE keychain operations
- Logs keychain state AFTER `keyChainManager.readAtsign()`
- Logs keychain state BEFORE AtAuthService creation
- Logs keychain state AFTER AtAuthService creation
- Logs keychain state BEFORE `atAuthService.authenticate()`
- Logs keychain state AFTER `atAuthService.authenticate()`

## Expected Behavior
The keychain should preserve all existing atSigns when adding a new one via APKAM. The logs should show:
- Multiple atSigns in keychain before APKAM onboarding
- Multiple atSigns in keychain after APKAM onboarding (including the new one)

## Current Status
- ✅ Added comprehensive logging at all keychain interaction points
- ⏳ Waiting for app build to complete to test and analyze logs
- ⏳ Will identify exact point where keychain loses previous atSigns
- ⏳ Will apply targeted fix based on log analysis

## Key Questions to Answer
1. At what exact point do previous atSigns disappear from the keychain?
2. Is it during `OnboardingService.authenticate()` calls?
3. Is it during `AtAuthService` creation/authentication?
4. Is it during storage configuration?
5. Is it an internal AtClient/keychain manager operation?

## Next Steps
1. Run the app and perform APKAM onboarding
2. Analyze the detailed logs to pinpoint where atSigns are deleted
3. Apply a targeted fix to prevent keychain cleanup during APKAM onboarding
4. Test the fix to ensure all atSigns are preserved
