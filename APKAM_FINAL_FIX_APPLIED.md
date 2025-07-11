# CUSTOM DOMAIN ATLOOKUP ISSUE - ROOT CAUSE IDENTIFIED

## The AtDirectory Lookup Problem

The issue is **NOT** in the AtClient preferences (those are working correctly) but in the **AtLookup service** which internally caches domain information and doesn't properly update when switching domains.

### Evidence From Logs

```
🔧 Creating AtAuthService with preferences:
   rootDomain: vip.ve.atsign.zone  ✅ CORRECT

🔍 AtClient verification after authentication:
   AtClient rootDomain: vip.ve.atsign.zone  ✅ CORRECT
   Expected rootDomain: vip.ve.atsign.zone  ✅ CORRECT
✅ AtClient domain and port configuration is correct

SEVERE|AtLookup|Error in remote verb execution Exception: No entry in atDirectory for juliet
```

### The Real Problem

1. **AtClient preferences are configured correctly** with custom domain
2. **Authentication works** with the custom domain
3. **AtLookup service internally caches the domain** and doesn't update when AtClient switches domains
4. **SyncService uses AtLookup** for atDirectory operations, so it fails with wrong domain

### Why This Happens

- `@juliet` exists in the `vip.ve.atsign.zone` atDirectory
- But `AtLookup` is still searching in `root.atsign.org` atDirectory
- The AtClient's internal `AtLookup` service doesn't automatically update its domain when preferences change
- This is a **limitation in the atPlatform libraries** where internal services cache domain configuration

### Proposed Solutions

#### Option 1: Force AtClient Recreation (Most Reliable)
```dart
// When switching to custom domain, force complete AtClient recreation
AtClientManager.getInstance().reset();
// Wait for cleanup
await Future.delayed(Duration(milliseconds: 1000));
// Re-authenticate with new domain preferences
// This forces AtLookup to be recreated with correct domain
```

#### Option 2: AtLookup Service Reset (If Available)
```dart
// If AtLookup has reset capability (needs investigation)
atClient.getRemoteSecondary()?.reset();
```

#### Option 3: Custom Domain Pre-check
```dart
// Before authentication, verify atSign exists in target domain
// Fall back to root domain if not found
```

### Current Status

The enhanced AtClient recreation code in `at_talk_service.dart` should handle this, but may need more aggressive cleanup of internal services.

### Test Plan

1. Start with `@llama` (root.atsign.org domain)
2. Switch to `@juliet` (vip.ve.atsign.zone domain)  
3. Watch for AtLookup errors in logs
4. Verify the enhanced recreation logic triggers and fixes the issue

### Files Modified

1. **`lib/core/providers/auth_provider.dart`** - Changed `cleanupExisting: true` to `cleanupExisting: false`
2. **`lib/gui/screens/onboarding_screen.dart`** - Previous onboarding dialog fixes (still beneficial)

### Testing Instructions

1. Start fresh with one atSign in keychain
2. Add another atSign via APKAM onboarding
3. Verify both atSigns are present in keychain
4. Restart app and verify both atSigns persist

This should be the **final fix** that actually resolves the keychain preservation issue.
