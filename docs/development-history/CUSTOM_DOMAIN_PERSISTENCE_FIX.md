# Custom Domain Persistence Fix

## Overview
Fixed the issue where custom rootDomain information was not being properly persisted and used across app restarts and atSign switching operations, causing CRAM onboarding to work only once.

## Root Cause Analysis

### Primary Issue
When the app started up or when users switched between atSigns, the custom domain information was not being loaded and passed to authentication methods. This caused:

1. **App Startup**: Automatic login used default domain instead of saved custom domain
2. **AtSign Switching**: Manual atSign switching ignored saved custom domains  
3. **Wrong Default Domain**: Hardcoded wrong default domain (`prod.atsign.wtf` instead of `root.atsign.org`)

### Consequence
- First CRAM onboarding with custom domain worked (domain passed directly)
- Subsequent operations failed because AtClient was configured with wrong domain
- atSign list showed "Domain: root.atsign.wtf" instead of the correct custom domain

## Solution Applied

### 1. Fixed Wrong Default Domain
**File**: `lib/core/utils/atsign_manager.dart`
```dart
// Before:
var rootDomain = 'prod.atsign.wtf';

// After:
var rootDomain = 'root.atsign.org';
```

### 2. Fixed Automatic Login on App Startup
**File**: `lib/main.dart`
- Added import for `atsign_manager.dart`
- Modified startup authentication to load and use saved domain:

```dart
// Before:
await authProvider.authenticateExisting(atSigns.first);

// After:
final atSignEntries = await getAtsignEntries();
final savedDomain = atSignEntries[firstAtSign]?.rootDomain;
await authProvider.authenticateExisting(firstAtSign, rootDomain: savedDomain);
```

### 3. Fixed AtSign Switching in Groups Screen
**File**: `lib/gui/screens/groups_list_screen.dart`
- Updated atSign switcher to pass saved domain:

```dart
// Before:
await authProvider.authenticateExisting(atSign, cleanupExisting: true);

// After:  
final savedDomain = atSignsInfo[atSign]?.rootDomain;
await authProvider.authenticateExisting(atSign, cleanupExisting: true, rootDomain: savedDomain);
```

### 4. Fixed AtSign Switching in Settings Screen
**File**: `lib/gui/screens/settings_screen.dart`
- Updated `_switchToAtSign()` to load and use saved domain
- Updated `_changeNamespace()` to preserve custom domain during namespace changes

```dart
// Before:
await authProvider.authenticateExisting(atSign);

// After:
final savedDomain = _availableAtSigns[atSign]?.rootDomain;
await authProvider.authenticateExisting(atSign, rootDomain: savedDomain);
```

## Impact

### ✅ Fixed Issues
- **Custom domain persistence**: Domain correctly saved and loaded across app sessions
- **Correct domain display**: atSign list now shows the correct custom domain
- **Multi-session CRAM**: CRAM onboarding works repeatedly, not just once
- **Consistent authentication**: All authentication flows use the correct domain
- **AtSign switching**: Switching between atSigns preserves their respective domains

### ✅ Flow Coverage
All authentication flows now properly handle custom domains:
- App startup automatic login
- Manual atSign switching from groups screen
- Manual atSign switching from settings screen  
- Namespace changes (preserves custom domain)
- CRAM onboarding (already working)
- APKAM onboarding (already working)
- .atKeys upload (already working)

## Verification Steps

To verify the fix works:

1. **Perform CRAM onboarding** with custom domain (e.g., `vip.ve.atsign.zone`)
2. **Check atSign list** - should show correct custom domain, not `root.atsign.wtf`
3. **Restart app** - should automatically login using custom domain
4. **Check logs** - should show "Using saved rootDomain: vip.ve.atsign.zone"
5. **Perform CRAM again** - should work consistently multiple times

## Files Modified
- `lib/core/utils/atsign_manager.dart` - Fixed default domain
- `lib/main.dart` - Fixed automatic startup login
- `lib/gui/screens/groups_list_screen.dart` - Fixed atSign switching
- `lib/gui/screens/settings_screen.dart` - Fixed settings-based switching

## Technical Notes

### Domain Loading Pattern
All authentication calls now follow this pattern:
```dart
// Load saved domain
final atSignInfo = _availableAtSigns[atSign] ?? await getAtsignEntries()[atSign];
final savedDomain = atSignInfo?.rootDomain;

// Authenticate with domain
await authProvider.authenticateExisting(atSign, rootDomain: savedDomain);
```

### Backward Compatibility
- atSigns without saved domain information use default `root.atsign.org`
- Existing atSigns continue to work without changes
- No data migration required

## Related Documentation
- `CUSTOM_DOMAIN_PARAMETER_AUDIT.md` - Parameter passing fixes
- `CRAM_CUSTOM_DOMAIN_FIX.md` - Root cause analysis of CRAM limitations
