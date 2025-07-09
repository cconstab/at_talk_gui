# APKAM Keychain Configuration Approach

## Summary
Investigation into preventing keychain wiping during APKAM enrollment revealed that `OnboardingService.enroll()` wipes the keychain by default. We implemented a configuration approach to prevent this.

## Root Cause
- `OnboardingService.enroll()` in the APKAM enrollment process wipes the keychain
- This happens because the OnboardingService was not properly configured with the correct `AtClientPreference`
- Without the proper configuration, the service uses default behavior which clears existing keychain data

## Solution Implemented

### 1. OnboardingService Configuration
```dart
// CRITICAL FIX: Configure OnboardingService with the correct AtClientPreference
// to prevent keychain wiping during enrollment
log('🔧 Configuring OnboardingService with atClientPreference to preserve keychain...');
onboardingService.setAtClientPreference = atClientPreference;
```

### 2. Comprehensive Logging
Added detailed logging around the enrollment process:
```dart
// Before enrollment
final keyChainManager = KeyChainManager.getInstance();
existingAtSigns = await keyChainManager.getAtSignListFromKeychain();
log('🔍 Keychain BEFORE OnboardingService.enroll(): $existingAtSigns');

// After enrollment  
final atSignsAfterEnroll = await keyChainManager.getAtSignListFromKeychain();
log('🔍 Keychain AFTER OnboardingService.enroll(): $atSignsAfterEnroll');
```

### 3. Backup/Restore Approach (Abandoned)
Initially attempted a backup/restore approach but discovered:
- `KeyChainManager` API limitations - no direct store/restore methods
- Type issues with `AtsignKey` (undefined type)
- `storeCredentialToKeychain` method does not exist
- Configuration approach is more reliable than backup/restore

## Current Implementation Status

### ✅ Completed
1. **OnboardingService Configuration**: Set `atClientPreference` to preserve keychain
2. **Comprehensive Logging**: Added detailed logging before/after enrollment
3. **Error Handling**: Proper error handling for keychain operations
4. **Type Safety**: Removed invalid type references and method calls

### ⚠️ Testing Required
1. **Manual Testing**: Need to test APKAM enrollment to verify keychain preservation
2. **Multiple AtSign Test**: Verify that both old and new atSigns remain after enrollment
3. **Edge Cases**: Test with corrupted keychain, missing atSigns, etc.

## Expected Behavior
After running APKAM enrollment with the configuration fix:
- **Before**: Keychain contains `[@llama]`
- **After**: Keychain should contain `[@llama, @ssh_1]` (or similar)
- **Success Criteria**: Both atSigns present and accessible in the app

## Key Files Modified
- `lib/gui/screens/onboarding_screen.dart` - APKAM enrollment logic
- `lib/core/services/at_talk_service.dart` - Storage configuration
- `lib/core/providers/auth_provider.dart` - Authentication logic
- `lib/main.dart` - App initialization

## Next Steps
1. **Manual Testing**: Test APKAM enrollment in the running app
2. **Verification**: Confirm both atSigns are present and functional
3. **Documentation**: Update final implementation docs
4. **Cleanup**: Remove debug logging after successful verification

## Alternative Approaches Considered
1. **Backup/Restore**: Abandoned due to API limitations
2. **Separate Storage**: Would require major architectural changes
3. **AtClient State Management**: Implemented as complementary solution
4. **OnboardingService Bypass**: Would break enrollment functionality

## Technical Notes
- The `atClientPreference` configuration is crucial for keychain preservation
- The OnboardingService must be configured BEFORE calling `enroll()`
- Storage paths must be atSign-specific to prevent conflicts
- The `cleanupExisting: false` parameter is critical throughout the chain
