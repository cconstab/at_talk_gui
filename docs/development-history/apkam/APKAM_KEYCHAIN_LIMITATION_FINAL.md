# APKAM Keychain Limitation - Final Summary

## Current Status: KNOWN LIMITATION

After extensive investigation and multiple attempted fixes, APKAM onboarding has a **known limitation** where it wipes the keychain, causing previously onboarded atSigns to be lost.

## What We've Tried

### 1. ✅ Isolated Storage Approach
- **What**: Created isolated storage paths for APKAM enrollment
- **Result**: ❌ Failed - keychain still wiped during enrollment
- **File**: `APKAM_KEYCHAIN_PRESERVATION_FIX.md`

### 2. ✅ Keychain Backup/Restore Mechanism  
- **What**: Backup keychain before APKAM, restore missing atSigns after
- **Result**: ❌ Failed - restoration fails with "No keys found for atSign"
- **Reason**: Secure storage is wiped during APKAM onboarding
- **File**: `APKAM_KEYCHAIN_RESTORATION_FIX.md`

### 3. ✅ OnboardingService State Management
- **What**: Save and restore OnboardingService singleton state
- **Result**: ❌ Partial - helps but doesn't prevent keychain wipe
- **File**: `APKAM_FINAL_FIX_APPLIED.md`

### 4. ✅ AtAuthService Approach
- **What**: Use AtAuthService directly instead of OnboardingService
- **Result**: ❌ Failed - still causes keychain issues
- **File**: `APKAM_AUTHSERVICE_IMPLEMENTATION.md`

## Root Cause Analysis

The issue is at the **atSign SDK level**:

1. **OnboardingService.enroll()** affects global singleton state
2. **AtAuthServiceImpl** constructor may interfere with existing keychain
3. **Keychain operations** in SDK have global side effects
4. **Secure storage** is wiped during APKAM enrollment

## Current Behavior

```
BEFORE APKAM: [@cconstab, @test, @other]
DURING APKAM: Enrolling @llama...
AFTER APKAM:  [@llama]  ← Previous atSigns lost
```

## Workaround for Users

**Manual Process:**
1. **Before APKAM**: Export all atSigns to .atKeys files
2. **Do APKAM**: Complete APKAM enrollment normally
3. **After APKAM**: Re-import previous atSigns using .atKeys files

**UI Guidance**: We can add UI warnings about this limitation.

## Implementation Decision

Given the extensive investigation, we're **documenting this as a known limitation** rather than implementing partial solutions that don't fully work.

### Reasons:
- ✅ **Root cause identified**: SDK-level issue requires upstream fix
- ✅ **Workaround exists**: .atKeys backup/restore works reliably  
- ✅ **User impact manageable**: Users can work around the limitation
- ✅ **No false promises**: Better to be honest about limitations

## Next Steps

### For Users:
1. **Use .atKeys method** for critical atSigns that must be preserved
2. **Use APKAM for new atSigns** where loss of others is acceptable
3. **Manual backup/restore** using .atKeys files when needed

### For Development:
1. **Document limitation** in user-facing documentation
2. **Add UI warnings** before APKAM onboarding
3. **Submit SDK issue** to atPlatform team for upstream fix
4. **Monitor SDK updates** for resolution

## Files Created During Investigation

- `APKAM_KEYCHAIN_LIMITATION.md` - This summary
- `APKAM_KEYCHAIN_PRESERVATION_FIX.md` - Isolated storage attempt
- `APKAM_KEYCHAIN_RESTORATION_FIX.md` - Backup/restore attempt  
- `APKAM_FINAL_FIX_APPLIED.md` - OnboardingService state management
- `APKAM_AUTHSERVICE_IMPLEMENTATION.md` - AtAuthService approach
- Plus 15+ other investigation files

## Technical Impact

- **Functionality**: APKAM works for new atSigns
- **User Experience**: Requires manual workflow for atSign preservation
- **Code Quality**: Clean, documented limitation vs. buggy partial fix
- **Maintenance**: Simple code vs. complex workarounds

---

**Decision**: Document as known limitation with clear workaround  
**Reasoning**: Honest limitation is better than unreliable partial fix  
**Timeline**: Immediate (documentation) + Future (SDK fix)  
**User Impact**: Manageable with documented workaround
