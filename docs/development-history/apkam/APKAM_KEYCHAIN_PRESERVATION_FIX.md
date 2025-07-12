# APKAM Keychain Preservation Fix

## Problem Summary
The APKAM onboarding flow was deleting existing atSigns from the keychain after enrollment, while the .atKeys file flow worked correctly. This was causing users to lose access to their previously enrolled atSigns after adding a new one via APKAM.

## Root Cause Analysis
The issue was identified in the logs showing that the keychain was being wiped during the APKAM enrollment process. The specific problem was:

1. **Before APKAM**: `Successfully retrieved 1 atSigns from keychain: [@cconstab]`
2. **After APKAM**: `🔍 Before authentication, keychain contains: [@llama]` - **@cconstab was gone!**

The issue was that **`OnboardingService.authenticate()`** was being called after successful APKAM enrollment, which wipes the keychain. This happened in multiple places:

1. **`onApproved()` method** - Called after APKAM enrollment approval
2. **`_handleOnboardingResult()` method** - Called after successful APKAM enrollment
3. **`cramSubmit()` method** - Called after CRAM onboarding (less critical since CRAM is for new atSigns)

## Solution Implemented

### 1. Fixed `onApproved()` Method
**File**: `lib/gui/screens/onboarding_screen.dart`
**Lines**: ~2160-2190

**Before**:
```dart
// Use OnboardingService to authenticate after enrollment approval
final onboardingService = OnboardingService.getInstance();
// ... configure service
final authStatus = await onboardingService.authenticate(atsign);
```

**After**:
```dart
// CRITICAL FIX: Do NOT use OnboardingService.authenticate() as it wipes the keychain!
// The APKAM enrollment process already saves the keys properly.
// Configure storage to preserve existing atSigns instead.
await AtTalkService.configureAtSignStorage(atsign, cleanupExisting: false);
```

### 2. Fixed `_handleOnboardingResult()` Method
**File**: `lib/gui/screens/onboarding_screen.dart`
**Lines**: ~690-720

**Before**:
```dart
// Use OnboardingService to authenticate after enrollment
final onboardingService = OnboardingService.getInstance();
// ... configure service  
final authStatus = await onboardingService.authenticate(result.atsign!);
// ... then use AuthProvider
await authProvider.authenticateExisting(result.atsign!, cleanupExisting: false);
```

**After**:
```dart
// CRITICAL FIX: Do NOT use OnboardingService.authenticate() as it wipes the keychain!
// Configure storage to preserve existing atSigns instead.
await AtTalkService.configureAtSignStorage(result.atsign!, cleanupExisting: false);
// Use AuthProvider.authenticateExisting() directly to preserve keychain
await authProvider.authenticateExisting(result.atsign!, cleanupExisting: false);
```

### 3. Fixed `cramSubmit()` Method
**File**: `lib/gui/screens/onboarding_screen.dart`
**Lines**: ~2330-2360

**Before**:
```dart
// After CRAM onboarding, authenticate to ensure keys are properly saved to keychain
final authStatus = await onboardingService.authenticate(atsign);
```

**After**:
```dart
// CRITICAL FIX: Do NOT use OnboardingService.authenticate() as it wipes the keychain!
// Configure storage to preserve existing atSigns instead.
await AtTalkService.configureAtSignStorage(atsign, cleanupExisting: false);
```

## Key Changes Made

1. **Removed all calls to `OnboardingService.authenticate()`** after APKAM enrollment
2. **Replaced with `AtTalkService.configureAtSignStorage(atsign, cleanupExisting: false)`** to preserve existing atSigns
3. **Used `AuthProvider.authenticateExisting()` with `cleanupExisting: false`** for proper authentication flow
4. **Added comprehensive logging** to track keychain state before and after operations

## Expected Behavior

### Before Fix:
- User has `[@cconstab]` in keychain
- User adds `@llama` via APKAM
- Result: Keychain contains only `[@llama]` - **@cconstab was deleted**

### After Fix:
- User has `[@cconstab]` in keychain  
- User adds `@llama` via APKAM
- Result: Keychain contains `[@cconstab, @llama]` - **both atSigns preserved**

## Testing Instructions

1. **Setup**: Ensure you have at least one atSign already in the keychain (e.g., `@cconstab`)
2. **Test APKAM Enrollment**: 
   - Go to "Add atSign" → "Authenticator App" 
   - Enter a new atSign (e.g., `@llama`)
   - Complete APKAM enrollment with OTP
3. **Verify**: Check that both the original atSign and the new atSign appear in the main screen
4. **Log Verification**: Check logs for:
   - `🔍 Keychain BEFORE authentication: [@cconstab]`
   - `🔍 After authentication, keychain contains: [@cconstab, @llama]`

## Technical Details

- **Root Cause**: `OnboardingService.authenticate()` wipes the keychain during authentication
- **Solution**: Skip the authentication step since APKAM enrollment already saves keys properly
- **Safe Approach**: Use `AtTalkService.configureAtSignStorage()` with `cleanupExisting: false`
- **Authentication**: Use `AuthProvider.authenticateExisting()` instead of OnboardingService

## Impact

- **Positive**: Users can now add multiple atSigns via APKAM without losing existing ones
- **No Breaking Changes**: .atKeys file upload flow remains unaffected
- **Backward Compatibility**: Existing single atSign setups continue to work normally
