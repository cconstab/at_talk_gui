# AtTalk GUI - Upload Keys Widget Fix

## Issue
The upload keys widget in the AtTalk GUI was not working on macOS due to missing permissions and configuration issues.

## Root Causes Identified

### 1. Missing macOS Entitlements
macOS has strict security policies that prevent apps from accessing files and network resources without explicit permissions.

### 2. Missing Authentication Method
The `authenticateExisting` method was missing from the AuthProvider, causing compilation errors.

### 3. Missing Environment Configuration
The app was missing proper API key configuration for atSign onboarding.

### 4. Context Usage Issues
Improper use of BuildContext across async boundaries.

## Fixes Applied

### 1. Updated macOS Entitlements

**File: `macos/Runner/DebugProfile.entitlements`**
Added permissions for:
- Network client access (`com.apple.security.network.client`)
- User-selected file read/write (`com.apple.security.files.user-selected.read-write`)
- Downloads folder access (`com.apple.security.files.downloads.read-write`)
- App-scoped bookmarks (`com.apple.security.files.bookmarks.app-scope`)

**File: `macos/Runner/Release.entitlements`**
Added the same file and network permissions for release builds.

### 2. Fixed AuthProvider

**File: `lib/providers/auth_provider.dart`**
- Added missing `authenticateExisting(String atSign)` method
- Implemented proper error handling and state management

### 3. Created Environment Configuration

**File: `lib/utils/at_talk_env.dart`**
- Centralized configuration for atSign environment settings
- Set to Staging environment for development (no API key required)
- Included placeholder for API key when switching to Production

### 4. Updated Onboarding Configuration

**File: `lib/screens/onboarding_screen.dart`**
- Updated `AtOnboardingConfig` to use environment settings
- Added proper API key configuration structure

### 5. Fixed Context Usage

**File: `lib/main.dart`**
- Fixed async context usage with proper `mounted` checks
- Updated to use centralized environment configuration

### 6. Minor Code Quality Improvements
- Fixed deprecated `withOpacity` usage (replaced with `withValues`)
- Added TODO comments for print statements

## Key Technical Details

### macOS Entitlements Explained
```xml
<!-- Allows app to make outbound network connections -->
<key>com.apple.security.network.client</key>
<true/>

<!-- Allows app to read files selected by user through file picker -->
<key>com.apple.security.files.user-selected.read-only</key>
<true/>

<!-- Allows app to write to files selected by user -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<!-- Allows app to access Downloads folder -->
<key>com.apple.security.files.downloads.read-write</key>
<true/>

<!-- Allows app to maintain references to user-selected files -->
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
```

### Environment Configuration
The app now uses Staging environment by default, which:
- Doesn't require an API key for testing
- Connects to staging atSign servers
- Allows upload of .atKeys files for onboarding

To switch to Production:
1. Get an API key from https://my.atsign.com
2. Update `AtTalkEnv.rootEnvironment` to `RootEnvironment.Production`
3. Set `AtTalkEnv.appApiKey` to your actual API key

## Testing the Fix

1. Run the app: `flutter run -d macos`
2. Navigate to the onboarding screen
3. Click "Setup atSign" button
4. Try the "Upload atKeys" option in the onboarding flow
5. The file picker should now open and allow .atKeys file selection

## Expected Behavior

With these fixes:
- ✅ File picker opens when uploading .atKeys files
- ✅ Network connections work for atSign authentication
- ✅ App compiles without errors
- ✅ Proper error handling and user feedback
- ✅ Staging environment allows testing without API key

## Next Steps

1. Test the upload keys functionality with actual .atKeys files
2. Verify network connectivity to atSign servers
3. Consider obtaining a production API key for final deployment
4. Test other onboarding flows (QR code, new atSign generation)

## Files Changed

- `macos/Runner/DebugProfile.entitlements` - Added file and network permissions
- `macos/Runner/Release.entitlements` - Added file and network permissions
- `lib/utils/at_talk_env.dart` - New environment configuration file
- `lib/providers/auth_provider.dart` - Added missing authentication method
- `lib/screens/onboarding_screen.dart` - Updated onboarding configuration
- `lib/main.dart` - Fixed context usage and added environment config
- `lib/screens/chat_screen.dart` - Fixed deprecated API usage
- `lib/providers/chat_provider.dart` - Added TODO for print statement
- `lib/services/at_talk_service.dart` - Added TODO for print statement
