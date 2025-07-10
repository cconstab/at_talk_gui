# APKAM Keychain Preservation - Testing Guide

## Pre-Testing Setup

### 1. Ensure Existing atSigns
Before testing the fix, make sure you have at least one existing atSign in your keychain:
- Launch the app
- If no atSigns exist, add one via .atKeys file upload first
- Verify the existing atSign appears in the app and can be used

### 2. Check Current Keychain State
- Note down all existing atSigns visible in the app
- Ensure they are functional (can access chat, groups, etc.)

## Testing the APKAM Fix

### Test Case 1: APKAM Onboarding with Existing atSigns

**Steps:**
1. Launch the app with existing atSigns in keychain
2. Navigate to onboarding screen
3. Select "Get Started" and choose APKAM/OTP authentication
4. Complete the APKAM enrollment process:
   - Enter a new atSign (different from existing ones)
   - Follow the OTP/authenticator flow
   - Wait for enrollment completion

**Expected Results:**
- ✅ APKAM enrollment completes successfully
- ✅ New atSign is added to the keychain
- ✅ All previous atSigns remain in the keychain
- ✅ App navigates to main screen showing all atSigns
- ✅ All atSigns (old and new) are functional

**Debug Output to Monitor:**
Look for these log messages:
```
🔧 Configuring atSign-specific storage using .atKeys pattern: @newatsign
🔍 Keychain BEFORE authentication: [@existingatsign1, @existingatsign2]
🔄 Using AuthProvider.authenticate() directly (same as .atKeys flow)...
✅ Authentication completed using AuthProvider - keychain preserved
🔍 After authentication, keychain contains: [@existingatsign1, @existingatsign2, @newatsign]
```

### Test Case 2: App Restart Persistence

**Steps:**
1. After completing Test Case 1, close the app completely
2. Restart the app
3. Check the main screen/atSign list

**Expected Results:**
- ✅ All atSigns (including the new APKAM one) are still present
- ✅ No atSigns are missing from the keychain
- ✅ All atSigns remain functional

### Test Case 3: Multiple APKAM Enrollments

**Steps:**
1. With multiple atSigns already in keychain, perform another APKAM enrollment
2. Add a third atSign via APKAM/OTP
3. Verify keychain state

**Expected Results:**
- ✅ All three atSigns are present and functional
- ✅ No keychain corruption or data loss occurs

## Error Scenarios to Test

### Test Case 4: Keychain Corruption Handling

**Steps:**
1. If keychain corruption occurs during testing, note the error message
2. Verify that appropriate error handling is triggered

**Expected Results:**
- ✅ Clear error message about keychain corruption
- ✅ Guidance provided to user about using "Manage Keys" option
- ✅ APKAM enrollment still marked as successful

### Test Case 5: Authentication Fallback

**Steps:**
1. If initial authentication fails, observe the fallback mechanism
2. Check that storage reconfiguration and retry authentication occur

**Expected Results:**
- ✅ Fallback authentication attempts are logged
- ✅ Second authentication attempt uses `cleanupExisting: false`
- ✅ Authentication eventually succeeds or provides clear error

## Troubleshooting

### Common Issues and Solutions

**Issue: New atSign not appearing in keychain**
- Check debug logs for authentication errors
- Verify APKAM enrollment actually completed
- Look for keychain corruption messages

**Issue: Previous atSigns disappeared**
- This should NOT happen with the fix
- If it does, this indicates the fix needs refinement
- Check logs for unexpected calls to keychain cleanup

**Issue: App crashes during APKAM onboarding**
- Check for unhandled exceptions in authentication flow
- Verify all required dependencies are properly imported
- Look for null pointer exceptions in atSign handling

## Success Criteria

The fix is considered successful if:

1. **Keychain Preservation**: All existing atSigns remain in keychain after APKAM onboarding
2. **New atSign Addition**: APKAM-enrolled atSign is successfully added to keychain
3. **Persistence**: All atSigns persist after app restart
4. **Functionality**: All atSigns (old and new) remain fully functional
5. **Error Handling**: Appropriate error messages for any failures
6. **No Regressions**: Existing flows (.atKeys upload) continue to work

## Reporting Results

When testing is complete, document:
- Which test cases passed/failed
- Any error messages encountered
- Screenshots of atSign lists before/after onboarding
- Debug log excerpts showing keychain state changes
- Any unexpected behavior or edge cases discovered

## Next Steps After Testing

If testing is successful:
1. Remove or reduce debug logging if desired
2. Update user documentation
3. Consider adding automated tests for this scenario

If testing reveals issues:
1. Analyze debug logs to identify root cause
2. Refine the authentication flow as needed
3. Retest until all criteria are met
