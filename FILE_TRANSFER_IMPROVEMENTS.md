# File Transfer Improvements

## Summary
Enhanced the file transfer system with improved chunking strategy for better reliability and server resource management.

## Changes Made

### 1. Chunk Size Reduction (32KB → 8KB)
- **Before**: `static const int chunkSize = 32 * 1024; // 32KB chunks`
- **After**: `static const int chunkSize = 8 * 1024; // 8KB chunks for sequential processing and better reliability`

**Benefits:**
- Smaller chunks are more manageable for network transmission
- Reduces memory pressure during transfer
- Better progress granularity for users
- Lower chance of timeout for individual chunks

### 2. 1-Day TTL Implementation
- **Metadata TTL**: Added `..ttl = 86400000` (1 day in milliseconds) to file metadata
- **Chunk TTL**: Added `..ttl = 86400000` (1 day in milliseconds) to each file chunk

**Benefits:**
- Automatic cleanup of temporary files after 1 day
- Prevents server storage from accumulating stale file chunks
- Compliance with temporary data retention policies

### 3. Sequential Processing Confirmation
- **Upload**: Already implemented sequential processing using `await for` loop
- **Download**: Already implemented ordered processing using sequential `for` loop
- **Enhanced Logging**: Added clear indicators that chunks are processed "sequentially" and "in order"

**Current Implementation Details:**
```dart
// Upload - Sequential chunk processing
await for (final chunkData in fileStream.transform(ChunkReader(chunkSize))) {
  print('📤 Processing chunk ${chunkIndex + 1}/$totalChunks sequentially...');
  await _uploadChunkWithRetry(client, fileId, chunkIndex, chunkData, totalChunks);
  chunkIndex++;
  onProgress(chunkIndex / totalChunks);
}

// Download - Ordered chunk reconstruction  
for (int i = 0; i < totalChunks; i++) {
  print('📥 Downloading chunk ${i + 1}/$totalChunks in order...');
  final chunkData = await _downloadChunkWithRetry(client, fileId, i, totalChunks);
  chunks.add(chunkData);
}
```

## Technical Benefits

1. **Reliability**: Smaller chunks are less likely to fail during transmission
2. **Memory Efficiency**: 8KB chunks use less memory than 32KB chunks
3. **Server Hygiene**: 1-day TTL ensures automatic cleanup of temporary data
4. **Progress Tracking**: More granular progress updates for better UX
5. **Network Optimization**: Sequential sending avoids overwhelming the network or server
6. **Ordered Reconstruction**: Guarantees file integrity through ordered chunk assembly

## File Location
- **Service**: `lib/core/services/file_transfer_service.dart`
- **Key Constants**: Lines ~82-83 (chunk size configuration)
- **Upload Method**: `_uploadFileToAtPlatform` (~line 314)
- **Download Method**: `_downloadFileFromAtPlatform` (~line 433)

## Backward Compatibility
The changes are backward compatible with existing file transfers since:
- The chunking format remains the same
- Metadata structure is unchanged (TTL is just an additional property)
- Sequential processing was already the default behavior

## Testing Recommendations
1. Test file uploads/downloads with various file sizes
2. Verify TTL cleanup occurs after 1 day
3. Confirm progress tracking works smoothly with 8KB chunks
4. Test network resilience with smaller chunk sizes
