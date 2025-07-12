# APKAM Keychain Preservation Fix - Final Implementation

## Issue Identified

The problem is that during APKAM onboarding, the `AtAuthServiceImpl` is being created with storage paths that conflict with the main keychain, causing it to wipe existing atSigns. Even though I created an isolated storage path, the `AtAuthServiceImpl` was still using the regular storage path.

## Root Cause

The issue was in the `_startAuthenticatorOnboarding` method:

1. I was calling `AtTalkService.configureAtSignStorage(atSign, cleanupExisting: false)` to get the base preference
2. This call was creating an `AtClient` that was wiping the keychain
3. Even though I created an isolated storage path, the APKAM dialog was still using the regular storage path

## Fix Applied

Changed the `_startAuthenticatorOnboarding` method to:

1. **Avoid calling `AtTalkService.configureAtSignStorage()`** - this was the key issue
2. **Create the isolated storage preference directly** without any AtClient creation
3. **Use hardcoded namespace** (`AtTalkEnv.namespace`) instead of getting it from a potentially keychain-wiping call

### Code Changes

```dart
// OLD CODE (problematic):
final basePreference = await AtTalkService.configureAtSignStorage(atSign, cleanupExisting: false);

final customPreference = AtClientPreference()
  ..rootDomain = domain
  ..namespace = basePreference.namespace  // This required the problematic call above
  ..hiveStoragePath = isolatedStoragePath
  ..commitLogPath = isolatedCommitLogPath
  ..isLocalStoreRequired = basePreference.isLocalStoreRequired;

// NEW CODE (fixed):
final customPreference = AtClientPreference()
  ..rootDomain = domain
  ..namespace = AtTalkEnv.namespace  // Direct use of namespace
  ..hiveStoragePath = isolatedStoragePath
  ..commitLogPath = isolatedCommitLogPath
  ..isLocalStoreRequired = true;  // Hardcoded value
```

## Additional Fixes

1. **Added OnboardingService configuration** in `otpSubmit` method to ensure isolated storage is used
2. **Maintained isolated storage path** throughout the entire APKAM flow
3. **Preserved keychain restoration logic** as a fallback in case of issues

## Expected Behavior

After this fix:
- APKAM onboarding should use completely isolated storage
- The main keychain should not be wiped during enrollment
- Both `@cconstab` and `@llama` should be visible in the keychain after APKAM onboarding
- The app should work normally with multiple atSigns

## Testing

The fix has been implemented and needs to be tested by:
1. Starting with `@cconstab` in the keychain
2. Doing APKAM onboarding for `@llama`
3. Verifying that both atSigns are present in the keychain after onboarding

## Files Modified

- `lib/gui/screens/onboarding_screen.dart`: Main fix in `_startAuthenticatorOnboarding` method
- Added `path_provider` import for `getApplicationSupportDirectory()`
- Enhanced `otpSubmit` method to configure OnboardingService with isolated storage

This should be the final fix for the keychain preservation issue.
