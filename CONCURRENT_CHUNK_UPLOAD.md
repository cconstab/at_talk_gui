# Concurrent Chunk Upload with Concurrency Control

## Overview

Enhanced the file transfer service to use concurrent chunk uploads with a configurable concurrency limit to optimize performance while avoiding atServer overload.

## Key Changes

### Previous Approach (Sequential):
```dart
// Upload chunks one by one sequentially
await for (final chunkData in fileStream.transform(ChunkReader(chunkSize))) {
  await _uploadChunkWithRetry(client, fileId, chunkIndex, chunkData, totalChunks);
  chunkIndex++;
}
```

### New Approach (Controlled Concurrency):
```dart
// Upload chunks with controlled concurrency using semaphore
final semaphore = Semaphore(maxConcurrentUploads);
final futures = <Future<void>>[];

for (int i = 0; i < chunkDataList.length; i++) {
  final future = semaphore.acquire().then((_) async {
    try {
      await _uploadChunkWithRetry(client, fileId, chunkIndex, chunkData, totalChunks);
    } finally {
      semaphore.release();
    }
  });
  futures.add(future);
}

// Wait for all chunks to complete
for (final future in futures) {
  await future;
}
```

## Configuration

### Concurrency Limit
```dart
static const int maxConcurrentUploads = 3; // Maximum concurrent chunk uploads
```

- **Default**: 3 concurrent uploads
- **Rationale**: Balances performance with server load
- **Adjustable**: Can be tuned based on atServer capacity and network conditions

## Semaphore Implementation

Added a lightweight semaphore class to control concurrent operations:

```dart
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}
```

## Benefits

1. **Improved Performance**:
   - Faster uploads through concurrent chunk processing
   - Reduced total upload time for large files
   - Better network utilization

2. **Server Protection**:
   - Prevents overwhelming the atServer with too many simultaneous requests
   - Configurable concurrency limit for different server capacities
   - Graceful queuing when limit is reached

3. **Better User Experience**:
   - Faster file uploads
   - Responsive progress updates
   - Maintains reliability through controlled concurrency

4. **Resource Management**:
   - Controlled memory usage (chunks are small - 8KB each)
   - Proper cleanup with try/finally blocks
   - Queue-based waiting for available slots

## Technical Implementation

### Upload Flow
1. **Read All Chunks**: Load all 8KB chunks into memory (manageable for 5MB max files)
2. **Create Semaphore**: Initialize with `maxConcurrentUploads` permits
3. **Submit Futures**: Create futures for each chunk upload
4. **Acquire Permits**: Each upload acquires a semaphore permit
5. **Upload Concurrently**: Multiple chunks upload simultaneously (up to limit)
6. **Release Permits**: Permits are released when uploads complete
7. **Progress Tracking**: Updates progress as chunks complete

### Error Handling
- Maintains existing retry mechanisms per chunk
- Semaphore permits are properly released even on failure
- Individual chunk failures don't affect other concurrent uploads
- Overall upload fails only if all retries are exhausted

### Memory Management
- All chunks loaded into memory initially (8KB × chunks = manageable)
- For 5MB max files: ~625 chunks × 8KB = ~5MB total memory
- Chunks are garbage collected after upload
- No memory leaks from semaphore implementation

## Performance Comparison

### Sequential Upload (Previous)
- **Time**: O(n) where n is number of chunks
- **Throughput**: Single network connection utilization
- **Server Load**: Minimal (1 request at a time)

### Concurrent Upload (New)
- **Time**: O(n/c) where c is concurrency limit
- **Throughput**: Multiple network connections utilized
- **Server Load**: Controlled by concurrency limit

### Example for 5MB File (625 chunks):
- **Sequential**: 625 × 100ms = 62.5 seconds
- **Concurrent (3)**: 625 ÷ 3 × 100ms = ~20.8 seconds
- **Improvement**: ~3x faster upload time

## Configuration Recommendations

### Development/Testing
```dart
static const int maxConcurrentUploads = 2; // Conservative for testing
```

### Production
```dart
static const int maxConcurrentUploads = 3; // Balanced performance/load
```

### High-Performance Environments
```dart
static const int maxConcurrentUploads = 5; // Higher throughput
```

## Monitoring and Tuning

### Metrics to Monitor
- Average upload time per file
- atServer response times
- Error rates during uploads
- Memory usage during uploads

### Tuning Guidelines
- **Increase concurrency** if server can handle more load
- **Decrease concurrency** if seeing timeout errors or server overload
- **Monitor network conditions** and adjust accordingly

## Files Modified

- `lib/core/services/file_transfer_service.dart`
  - Added `Semaphore` class implementation
  - Added `maxConcurrentUploads` configuration
  - Updated `_uploadFileToAtPlatform()` method
  - Enhanced logging for concurrent operations

## Testing Recommendations

1. **Performance Testing**: Compare upload times with sequential approach
2. **Load Testing**: Verify atServer stability under concurrent load
3. **Error Resilience**: Test behavior when some chunks fail
4. **Memory Usage**: Monitor memory consumption during large uploads
5. **Network Conditions**: Test with various network speeds and reliability

## Future Enhancements

1. **Dynamic Concurrency**: Adjust concurrency based on server response times
2. **Bandwidth Throttling**: Limit total bandwidth usage
3. **Retry Strategy**: Implement backoff based on server load
4. **Monitoring**: Add metrics collection for performance analysis

---

**Date**: July 15, 2025  
**Change Type**: Performance Optimization  
**Impact**: Faster uploads with controlled server load  
**Status**: Implemented and Ready for Testing
