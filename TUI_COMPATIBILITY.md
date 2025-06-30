# AtTalk GUI - TUI Compatibility Implementation

## Overview
This document outlines the changes made to ensure full compatibility between the AtTalk GUI app and the TUI (Terminal User Interface) at_talk app from https://github.com/atsign-foundation/at_talk.

## Key Compatibility Requirements

### 1. Namespace
- **TUI uses**: `'ai6bh'`
- **GUI configured**: `'ai6bh'` (in `lib/utils/at_talk_env.dart`)

### 2. Message Key Structure
Both apps use identical AtKey structure:
```dart
var key = AtKey()
  ..key = 'attalk'
  ..sharedBy = fromAtsign
  ..sharedWith = toAtsign
  ..namespace = 'ai6bh'
  ..metadata = metaData;
```

### 3. Metadata Configuration
Both apps use identical metadata:
```dart
var metaData = Metadata()
  ..isPublic = false
  ..isEncrypted = true
  ..namespaceAware = true;
```

### 4. Notification Subscription
- **Subscription regex**: `'attalk.ai6bh@'`
- **Decryption**: `shouldDecrypt: true`

### 5. Message Filtering
Both apps use identical filtering logic:
```dart
String keyAtsign = notification.key;
keyAtsign = keyAtsign.replaceAll('${notification.to}:', '');
keyAtsign = keyAtsign.replaceAll('.ai6bh${notification.from}', '');
return keyAtsign == 'attalk';
```

### 6. Notification Parameters
Both apps send notifications with identical parameters:
```dart
NotificationParams.forUpdate(key, value: message),
waitForFinalDeliveryStatus: false,
checkForFinalDeliveryStatus: false
```

## Implementation Details

### Files Modified for Compatibility

1. **`lib/utils/at_talk_env.dart`**
   - Set namespace to `'ai6bh'` to match TUI

2. **`lib/services/at_talk_service.dart`**
   - Updated subscription regex to match TUI exactly
   - Implemented identical message filtering logic
   - Added debug logging for troubleshooting
   - Used same AtKey structure and metadata as TUI
   - Used same notification parameters as TUI

3. **`lib/providers/chat_provider.dart`**
   - Added debug logging for message send/receive
   - Fixed corrupted imports after editing

## Debug Features Added

### Message Sending Debug
```dart
print('DEBUG: Sending message - key: ${key.toString()}, value: $message, to: $toAtSign');
print('DEBUG: Send result - success: $success, exception: ${result.atClientException}');
```

### Message Receiving Debug
```dart
print('DEBUG: Filtering notification key: ${notification.key} -> filtered: $keyAtsign, matches: ${keyAtsign == 'attalk'}');
print('DEBUG: Received valid message from ${notification.from}: ${notification.value}');
```

### Chat Provider Debug
```dart
print('Sending message to ${_currentChatPartner!}: $message');
print('Received message from ${_currentChatPartner!}: $message');
```

## Testing Compatibility

### Test Scenario 1: GUI to TUI
1. Start TUI app: `dart bin/at_talk.dart -a "@user1" -t "@user2"`
2. Start GUI app with @user2, chat with @user1
3. Send message from GUI → Should appear in TUI
4. Verify debug logs show successful send

### Test Scenario 2: TUI to GUI
1. Start GUI app with @user1, chat with @user2
2. Start TUI app: `dart bin/at_talk.dart -a "@user2" -t "@user1"`
3. Send message from TUI → Should appear in GUI
4. Verify debug logs show message received and filtered correctly

### Test Scenario 3: Bidirectional
1. Both apps running as above
2. Send messages back and forth
3. Verify all messages appear in both interfaces
4. Verify message ordering and timestamps

## Known Issues Resolved

1. **Namespace Mismatch**: Fixed by changing from 'attalk' to 'ai6bh'
2. **Subscription Pattern**: Fixed by using exact TUI regex pattern
3. **Message Filtering**: Implemented exact TUI filtering logic
4. **Compilation Errors**: Fixed corrupted imports in chat_provider.dart

## Next Steps

1. Test actual message exchange between GUI and TUI apps
2. Remove debug print statements after confirming compatibility
3. Replace debug prints with proper logging framework
4. Add unit tests for message protocol compatibility
5. Document message protocol for future reference

## Root Domain & Environment

- **Root Domain**: `root.atsign.org` (same as TUI default)
- **Environment**: Using Staging for development
- **API Key**: Not required for staging environment

## Dependencies

All dependencies match the atPlatform ecosystem used by the TUI app:
- `at_client_mobile`
- `at_onboarding_flutter`
- Same namespace and protocol structure

This ensures full protocol compatibility between the GUI and TUI versions of AtTalk.
