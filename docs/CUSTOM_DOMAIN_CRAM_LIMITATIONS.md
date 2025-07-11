# Custom Domain CRAM Limitations - Investigation Results

**Date**: July 10, 2025  
**Status**: Library Limitation Identified  
**Workaround**: Partial Success with Manual Authentication

## Problem Summary

Custom domain CRAM activation encounters fundamental limitations in the atPlatform libraries where certain operations (particularly atDirectory lookups) are hardcoded to use `root.atsign.org` regardless of the `rootDomain` preference setting.

## Technical Analysis

### What Works ✅
- **Domain preference configuration**: Custom domain is correctly set in AtClientPreference
- **Network connectivity**: Custom domain servers are reachable and responsive
- **Initial CRAM handshake**: Authentication process begins successfully
- **Key generation**: Cryptographic keys are generated and stored in keychain
- **Fallback mechanism**: Null check errors are handled with standard domain fallback

### What Fails ❌
- **atDirectory lookups**: Always query `root.atsign.org` instead of custom domain
- **Server status checking**: `_checkRootLocation` uses wrong domain
- **Sync operations**: SyncService defaults to standard domain for atDirectory queries

### Evidence From Logs

```
SEVERE|AtLookup|Error in remote verb execution Exception: No entry in atDirectory for lima
_checkRootLocation error: Exception: No entry in atDirectory for lima
🔄 Waiting for server activation... round 4, status: ServerStatus.unavailable
```

The pattern shows that while the CRAM process progresses (reaching server status checks), the underlying atDirectory lookups are still targeting the wrong domain.

## Root Cause

The limitation appears to be in the `at_onboarding_flutter` and related atPlatform libraries where:

1. **OnboardingService**: Hardcoded domain usage for certain operations
2. **AtLookup**: Internal domain resolution ignores rootDomain preference
3. **SyncUtil**: Default domain fallback for atDirectory operations

## Current Workaround

### Partial Success Achieved ✅
- CRAM activation reaches server status checking phase
- Keys are successfully saved to device keychain  
- Domain information is preserved for future authentication
- AtSign appears in keychain despite "failed" activation

### User Experience
1. **CRAM Activation**: Shows as "partially successful" with technical explanation
2. **Manual Authentication**: User logs in from main screen using saved keys
3. **Custom Domain Applied**: Subsequent operations use correct custom domain
4. **Full Functionality**: Messaging and sync work with custom domain after manual auth

## Alternative Solutions

### 1. .atKeys File Upload (Fully Supported) ✅
- **Status**: Works perfectly with custom domains
- **Process**: User uploads their .atKeys backup file
- **Result**: Complete custom domain support without limitations

### 2. APKAM/Authenticator (Supported) ✅
- **Status**: Works with custom domains
- **Process**: Device registration via authenticator app
- **Result**: Full functionality with custom domain

### 3. Manual Key Import (Advanced) ✅
- **Status**: Developer option for key migration
- **Process**: Direct keychain import with custom domain metadata
- **Result**: Complete control over domain configuration

## Recommendations

### For Users
1. **Try CRAM first**: May partially succeed and provide keychain entry
2. **Use manual authentication**: Log in from main screen after partial CRAM
3. **Fallback to .atKeys**: Upload backup file for complete custom domain support
4. **Consider APKAM**: Use authenticator app for seamless enrollment

### For Developers
1. **Library updates needed**: atPlatform libraries need custom domain support
2. **Enhanced error handling**: Current implementation provides clear guidance
3. **Documentation**: Users understand limitations and available alternatives
4. **Monitoring**: Track when upstream libraries gain full custom domain support

## Implementation Status

### Enhanced Error Messages ✅
- Clear explanation of library limitations
- Technical details for advanced users
- Step-by-step guidance for alternatives
- Positive messaging for partial success

### Fallback Mechanisms ✅
- Null check error handling with standard domain fallback
- Keychain verification and domain preservation
- Automatic domain correction for post-auth operations

### User Guidance ✅
- Multiple pathways to achieve custom domain functionality
- Clear expectations about CRAM limitations
- Alternative methods prominently featured

## Future Improvements

### Upstream Library Updates
- Monitor at_onboarding_flutter for custom domain support
- Track atPlatform roadmap for domain flexibility
- Consider contributing patches for domain configuration

### Enhanced Workarounds
- Automatic .atKeys generation after partial CRAM success
- Streamlined transition from partial CRAM to manual auth
- Background domain verification and correction

---

**Conclusion**: While CRAM activation with custom domains has library-level limitations, the implemented workarounds provide multiple pathways for users to achieve full custom domain functionality. The current solution balances technical constraints with user experience.
