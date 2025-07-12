# PKAM Flow CRAM Cleanup

## Overview
This document summarizes the cleanup of CRAM references from the PKAM (.atKeys upload) flow and ensures proper separation of authentication methods.

## Changes Made

### 1. APKAM Dialog Cleanup
- **Removed CRAM references**: Updated APKAM dialog description from "Enroll using OTP from authenticator app or license key (CRAM secret)" to "Enroll using OTP from authenticator app for existing atSigns"
- **Removed CRAM submit function**: Completely removed the `cramSubmit()` function from the APKAM dialog as it should only handle OTP authentication
- **Updated UI text**: Changed "Enter OTP from Authenticator or CRAM Secret" to "Enter OTP from Authenticator App"
- **Removed CRAM instructions**: Removed "Use either your authenticator app OTP OR enter your CRAM secret (license key)" text

### 2. Main Onboarding Info Updates
- **Clarified method descriptions**: Updated info text to better distinguish between the three authentication methods
- **Improved help text**: Changed from "Already have an atSign? You can use:" to "Already have an atSign? Choose the right method:"
- **Method-specific descriptions**:
  - `.atKeys file (recommended for existing atSigns)`
  - `Authenticator app (APKAM) for enrolled atSigns`
  - `New atSign activation (CRAM) for brand new atSigns`

### 3. CRAM Onboarding Access Fix
- **Removed API key restriction**: Changed CRAM onboarding from requiring an API key to allowing attempts without one
- **Updated warning text**: Changed from "Requires API key" to "May require API key for some atSigns"
- **Improved accessibility**: Users can now attempt CRAM onboarding and receive appropriate error messages if API key is needed
- **Updated help text**: Changed "Valid API key (may be required)" to "API key (may be required for some atSigns)"

### 4. Flow Separation Verification
- **PKAM (.atKeys upload)**: ✅ Clean of CRAM references, only handles .atKeys file authentication
- **APKAM (Authenticator)**: ✅ Clean of CRAM references, only handles OTP authentication
- **CRAM (New atSign)**: ✅ Accessible via "New atSign Activation" option with custom domain support

## Current State

### Three Distinct Authentication Flows:

1. **New atSign Activation (CRAM)**
   - Purpose: Activate brand new atSigns that have never been used
   - Method: CRAM secret (license key) provided during atSign purchase
   - Domain support: ✅ Custom domain with fallback to standard domain
   - Access: "New atSign Activation" option in onboarding dialog

2. **Upload .atKeys File (PKAM)**
   - Purpose: Import existing atSign using .atKeys backup file
   - Method: File upload and validation
   - Domain support: ✅ Custom domain support
   - Access: "Upload .atKeys File" option in onboarding dialog

3. **Authenticator (APKAM)**
   - Purpose: Authenticate with existing atSign using authenticator app
   - Method: OTP verification only
   - Domain support: ✅ Custom domain support
   - Access: "Authenticator (APKAM)" option in onboarding dialog

## Files Modified
- `lib/gui/screens/onboarding_screen.dart`: Main onboarding logic cleanup

## Verification
- ✅ No compilation errors
- ✅ All three flows are accessible from the main onboarding dialog
- ✅ CRAM references removed from PKAM and APKAM flows
- ✅ CRAM onboarding available for new atSigns with custom domain support
- ✅ Help text updated to clearly distinguish between methods

## Next Steps
The onboarding flows are now properly separated and clearly documented. Users can:
- Access CRAM onboarding for new atSigns with custom domain support
- Use .atKeys files for existing atSigns without CRAM confusion
- Use APKAM for OTP-based authentication without CRAM options
