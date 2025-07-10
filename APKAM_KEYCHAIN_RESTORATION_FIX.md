# APKAM Keychain Restoration Fix

## Problem Identified
After extensive debugging, I found that the keychain is being wiped during **APKAM enrollment** (not during authentication). Specifically, when `AtAuthServiceImpl(atsign, atClientPreference)` is created in the APKAM dialog's `init()` method, it creates a new AtClient that overwrites the keychain.

## Root Cause
The `AtAuthServiceImpl` constructor in the `@at_auth` library creates a new AtClient instance that conflicts with existing keychain data, causing previous atSigns to be lost.

## Solution Implemented
Since we can't prevent the keychain from being wiped during APKAM enrollment, I implemented a **keychain restoration** mechanism that:

1. **Detects missing atSigns** after APKAM enrollment
2. **Restores them to the keychain** before final authentication
3. **Preserves all atSigns** in the final result

## Implementation Details

### Location
File: `lib/gui/screens/onboarding_screen.dart`
Method: `_handleOnboardingResult()` - around line 660

### Logic Flow
1. **Check keychain state** after APKAM enrollment
2. **If only the new atSign is present**, assume other atSigns were wiped
3. **Get complete atSign list** from the information file (`getAtsignEntries()`)
4. **Find missing atSigns** by comparing keychain vs. information file
5. **Restore missing atSigns** by calling `authenticateExisting()` for each
6. **Continue with normal authentication** for the new atSign

### Key Code Changes
```dart
// KEYCHAIN RESTORATION: Check if we need to restore other atSigns that may have been wiped
// during APKAM enrollment. This is a workaround for the AtAuthServiceImpl creating a new
// AtClient that wipes the keychain.
if (keychainAtSigns.length == 1 && keychainAtSigns.contains(result.atsign)) {
  print('🔄 Checking if other atSigns need to be restored to keychain...');
  
  // Try to get the list of atSigns from the information file
  final atSigns = await getAtsignEntries();
  final atSignKeys = atSigns.keys.toList();
  
  // Find atSigns that are in the info file but not in keychain
  final missingAtSigns = atSignKeys.where((atSign) => !keychainAtSigns.contains(atSign)).toList();
  
  if (missingAtSigns.isNotEmpty) {
    // For each missing atSign, try to restore it to the keychain
    for (final missingAtSign in missingAtSigns) {
      await AtTalkService.configureAtSignStorage(missingAtSign, cleanupExisting: false);
      await authProvider.authenticateExisting(missingAtSign, cleanupExisting: false);
    }
  }
}
```

## Expected Debug Output
```
🔍 Before authentication, keychain contains: [@llama]
🔄 Checking if other atSigns need to be restored to keychain...
📋 Found 2 atSigns in information file: [@cconstab, @llama]
🔄 Attempting to restore 1 missing atSigns to keychain: [@cconstab]
🔄 Attempting to restore @cconstab to keychain...
✅ Successfully restored @cconstab to keychain
🔍 After restoration, keychain contains: [@cconstab, @llama]
```

## Testing Steps
1. **Start with one atSign** (e.g., `@cconstab`) in keychain
2. **Perform APKAM onboarding** for another atSign (e.g., `@llama`)
3. **Verify both atSigns** are present in keychain after completion
4. **Restart app** and verify both atSigns persist

## Advantages of This Approach
1. **Non-invasive**: Doesn't modify library code or core authentication flows
2. **Robust**: Handles cases where keychain is wiped by external factors
3. **Automatic**: Restores missing atSigns without user intervention
4. **Safe**: Uses `cleanupExisting: false` to avoid further keychain disruption

## Limitations
1. **Depends on information file**: If the information file is corrupted, restoration may fail
2. **Performance**: Slight delay during restoration process
3. **Authentication required**: Missing atSigns must be re-authenticated to restore

This solution should resolve the APKAM keychain preservation issue by working around the underlying library behavior rather than trying to prevent it.
