# File Transfer Fix: Sender-Based Chunk Storage

## Problem
File chunks were not being found during download. The error showed:
```
❌ Failed get file metadata (attempt 1/3): Exception: file_meta_1752597942549_9396.default.attalk@bravo does not exist in keystore
```

## Root Cause
The issue was that the file transfer system was storing chunks with the sender's `sharedBy` atSign, but during download, the receiver was trying to look up chunks from their own atSign instead of the sender's atSign.

**Upload Process (Correct):**
- Sender uploads chunks with `sharedBy = sender@atsign`
- Chunks are stored as: `file_chunk_12345_0.default.attalk@sender`

**Download Process (Incorrect):**
- Receiver tried to download chunks with `sharedBy = receiver@atsign`
- Receiver looked for: `file_chunk_12345_0.default.attalk@receiver` ❌ (doesn't exist)

## Solution
Modified the download process to look for chunks from the sender's atSign instead of the receiver's atSign.

### Changes Made

#### 1. File Transfer Service (`lib/core/services/file_transfer_service.dart`)
- **Added `fromAtSign` parameter** to `downloadFile()` method
- **Added `fromAtSign` parameter** to `downloadFileToAppDirectory()` method
- **Added `fromAtSign` parameter** to `_downloadFileFromAtPlatform()` method
- **Added `fromAtSign` parameter** to `_downloadChunkWithRetry()` method
- **Updated metadata lookup** to use sender's atSign: `..sharedBy = fromAtSign ?? AtTalkService.instance.currentAtSign`
- **Updated chunk lookup** to use sender's atSign: `..sharedBy = fromAtSign ?? AtTalkService.instance.currentAtSign`

#### 2. Groups Provider (`lib/core/providers/groups_provider.dart`)
- **Updated `downloadFileAttachment()` calls** to pass the `fromAtSign` parameter
- **Updated `autoDownloadFileAttachment()` calls** to pass the `fromAtSign` parameter

### Key Code Changes

**Before:**
```dart
// Download tried to find chunks from receiver's atSign
final metadataKey = AtKey()
  ..key = 'file_meta_$fileId'
  ..sharedBy = AtTalkService.instance.currentAtSign  // ❌ Wrong! This is the receiver
```

**After:**
```dart
// Download now looks for chunks from sender's atSign
final metadataKey = AtKey()
  ..key = 'file_meta_$fileId'
  ..sharedBy = fromAtSign ?? AtTalkService.instance.currentAtSign  // ✅ Correct! This is the sender
```

### Data Flow
1. **Upload**: Sender stores chunks with their atSign
2. **Message**: File message includes sender's atSign (`fromAtSign`)
3. **Download**: Receiver uses sender's atSign to find chunks

### Backward Compatibility
- All parameters are optional with fallback to `currentAtSign`
- Existing code without `fromAtSign` parameter still works
- No breaking changes to existing API

### Testing
- The fix addresses the exact error message seen in the logs
- File chunks are now correctly located by looking in the sender's keystore
- Download process now works for file transfers between different atSigns

## Files Modified
- `lib/core/services/file_transfer_service.dart`
- `lib/core/providers/groups_provider.dart`
