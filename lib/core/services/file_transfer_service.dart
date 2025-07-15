import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:async';
import 'dart:collection';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:at_client/at_client.dart';
import 'package:file_picker/file_picker.dart';

import '../models/chat_message.dart';
import 'at_talk_service.dart';

/// Simple semaphore implementation for controlling concurrent operations
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

/// Helper class for reading files in chunks to avoid memory issues
class ChunkReader implements StreamTransformer<List<int>, Uint8List> {
  final int chunkSize;

  ChunkReader(this.chunkSize);

  @override
  Stream<Uint8List> bind(Stream<List<int>> stream) {
    return stream.transform(_ChunkTransformer(chunkSize));
  }

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() {
    return StreamTransformer.castFrom<List<int>, Uint8List, RS, RT>(this);
  }
}

class _ChunkTransformer extends StreamTransformerBase<List<int>, Uint8List> {
  final int chunkSize;
  final List<int> _buffer = [];

  _ChunkTransformer(this.chunkSize);

  @override
  Stream<Uint8List> bind(Stream<List<int>> stream) {
    late StreamController<Uint8List> controller;

    controller = StreamController<Uint8List>(
      onListen: () {
        stream.listen(
          (data) {
            _buffer.addAll(data);

            while (_buffer.length >= chunkSize) {
              final chunk = Uint8List.fromList(_buffer.take(chunkSize).toList());
              _buffer.removeRange(0, chunkSize);
              controller.add(chunk);
            }
          },
          onDone: () {
            // Add remaining data as final chunk
            if (_buffer.isNotEmpty) {
              controller.add(Uint8List.fromList(_buffer));
              _buffer.clear();
            }
            controller.close();
          },
          onError: controller.addError,
        );
      },
    );

    return controller.stream;
  }
}

class FileTransferService {
  static FileTransferService? _instance;
  static FileTransferService get instance => _instance ??= FileTransferService._internal();

  FileTransferService._internal();

  static const int maxFileSize = 5 * 1024 * 1024; // 5MB limit (further reduced for reliability)
  static const int chunkSize = 8 * 1024; // 8KB chunks for sequential processing and better reliability
  static const int thumbnailSize = 300; // 300px max for thumbnails
  static const int maxRetries = 3; // Maximum retries for failed operations
  static const Duration chunkTimeout = Duration(seconds: 30); // Timeout per chunk operation
  static const int maxConcurrentUploads = 3; // Maximum concurrent chunk uploads to avoid overloading atServer
  static const int maxConcurrentDownloads = 1; // Sequential downloads to be gentle on atServer
  static const Duration chunkUploadDelay = Duration(milliseconds: 100); // Small delay between uploads for ordering

  /// Upload a file and return MessageAttachment with progress callback
  Future<MessageAttachment?> uploadFile(String filePath, [Function(double)? onProgress]) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final fileSize = await file.length();
      if (fileSize > maxFileSize) {
        final maxSizeMB = maxFileSize ~/ (1024 * 1024);
        final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        throw Exception('File too large: ${fileSizeMB}MB (max ${maxSizeMB}MB allowed)');
      }

      // Check AtClient health before proceeding
      if (!await _checkAtClientHealth()) {
        throw Exception('AtClient connection is not healthy');
      }

      final fileName = path.basename(filePath);
      print('📁 Processing file: $fileName (${_formatFileSize(fileSize)})');

      final mimeType = lookupMimeType(filePath);
      print('🔍 Detected MIME type: $mimeType');
      final attachmentType = _getAttachmentType(mimeType);
      final fileId = _generateFileId();

      // Create attachment object
      var attachment = MessageAttachment(
        id: fileId,
        originalFileName: fileName,
        type: attachmentType,
        sizeInBytes: fileSize,
        mimeType: mimeType,
        isDownloaded: true,
        localPath: filePath,
      );

      // Generate thumbnail for images (10% of progress)
      if (attachmentType == AttachmentType.image) {
        onProgress?.call(0.1);
        final thumbnailPath = await _generateThumbnail(filePath, fileId);
        attachment = attachment.copyWith(thumbnailPath: thumbnailPath);
      }

      // Upload file to atPlatform in chunks (90% of progress)
      await _uploadFileToAtPlatform(file, fileId, (chunkProgress) {
        final totalProgress = 0.1 + (chunkProgress * 0.9);
        onProgress?.call(totalProgress);
      });

      onProgress?.call(1.0);
      print('✅ File uploaded successfully: $fileName (${_formatFileSize(fileSize)})');
      return attachment;
    } catch (e) {
      print('❌ Failed to upload file: $e');
      return null;
    }
  }

  /// Send a file as a message
  Future<bool> sendFileMessage({
    required String toAtSign,
    required MessageAttachment attachment,
    String? caption,
    List<String>? groupMembers,
  }) async {
    try {
      // First, share the file keys with the receiver
      await _shareFileKeysWithReceiver(attachment.id, toAtSign);

      final messageData = {
        'type': 'file',
        'fileId': attachment.id,
        'fileName': attachment.originalFileName,
        'fileSize': attachment.sizeInBytes,
        'mimeType': attachment.mimeType,
        'attachmentType': attachment.type.name,
        'caption': caption ?? '',
        'msg': caption ?? 'Sent a file: ${attachment.originalFileName}',
        'isGroup': groupMembers != null && groupMembers.length > 2,
        'group': groupMembers ?? [AtTalkService.instance.currentAtSign!, toAtSign],
        'instanceId': groupMembers != null
            ? (groupMembers.toList()..sort()).join(',')
            : ([AtTalkService.instance.currentAtSign!, toAtSign]..sort()).join(','),
        'from': AtTalkService.instance.currentAtSign,
      };

      final jsonMessage = jsonEncode(messageData);

      final client = AtTalkService.instance.atClient;
      if (client == null) return false;

      var metaData = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true;

      var key = AtKey()
        ..key = 'message'
        ..sharedBy = AtTalkService.instance.currentAtSign
        ..sharedWith = toAtSign
        ..namespace = AtTalkService.instance.atClientPreference!.namespace
        ..metadata = metaData;

      final result = await client.notificationService.notify(
        NotificationParams.forUpdate(key, value: jsonMessage),
        checkForFinalDeliveryStatus: false,
        waitForFinalDeliveryStatus: false,
      );

      bool success = result.atClientException == null;
      if (!success) {
        print('Failed to send file message: ${result.atClientException}');
      } else {
        print('✅ File message sent successfully to $toAtSign');
      }

      return success;
    } catch (e) {
      print('❌ Error sending file message: $e');
      return false;
    }
  }

  /// Share file keys with receiver by explicitly putting them with sharedWith
  Future<void> _shareFileKeysWithReceiver(String fileId, String toAtSign) async {
    try {
      final client = AtTalkService.instance.atClient;
      if (client == null) throw Exception('AtClient not initialized');

      print('📤 Sharing file keys with receiver: $toAtSign');

      // Get the metadata first to know how many chunks to share
      final metadataKey = AtKey()
        ..key = 'file_meta_$fileId'
        ..sharedBy = AtTalkService.instance.currentAtSign
        ..namespace = AtTalkService.instance.atClientPreference!.namespace;

      final metadataResult = await client.get(metadataKey);
      if (metadataResult.value == null) {
        throw Exception('File metadata not found for sharing');
      }

      final metadata = jsonDecode(metadataResult.value.toString());
      final totalChunks = metadata['totalChunks'] as int;

      // Share metadata key with receiver
      final sharedMetadataKey = AtKey()
        ..key = 'file_meta_$fileId'
        ..sharedBy = AtTalkService.instance.currentAtSign
        ..sharedWith = toAtSign
        ..namespace = AtTalkService.instance.atClientPreference!.namespace
        ..metadata = (Metadata()
          ..isPublic = false
          ..isEncrypted = true
          ..namespaceAware = true
          ..ttl = 86400000);

      await client.put(
        sharedMetadataKey,
        jsonEncode(metadata),
        putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
      );
      print('✅ Shared metadata key with $toAtSign');

      // Share all chunk keys with receiver
      for (int i = 0; i < totalChunks; i++) {
        final originalChunkKey = AtKey()
          ..key = 'file_chunk_${fileId}_$i'
          ..sharedBy = AtTalkService.instance.currentAtSign
          ..namespace = AtTalkService.instance.atClientPreference!.namespace;

        final chunkResult = await client.get(originalChunkKey);
        if (chunkResult.value != null) {
          final sharedChunkKey = AtKey()
            ..key = 'file_chunk_${fileId}_$i'
            ..sharedBy = AtTalkService.instance.currentAtSign
            ..sharedWith = toAtSign
            ..namespace = AtTalkService.instance.atClientPreference!.namespace
            ..metadata = (Metadata()
              ..isPublic = false
              ..isEncrypted = true
              ..namespaceAware = true
              ..isBinary = true
              ..ttl = 86400000);

          await client.put(
            sharedChunkKey,
            chunkResult.value,
            putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
          );
        }
      }

      print('✅ Shared all $totalChunks chunk keys with $toAtSign');
    } catch (e) {
      print('❌ Failed to share file keys with receiver: $e');
      throw e;
    }
  }

  /// Download file by fileId with user-selected save location
  Future<String?> downloadFile(
    String fileId,
    String fileName, [
    String? fromAtSign, // Add sender parameter
  ]) async {
    try {
      print('📥 Downloading file: $fileName');

      // First, download the file bytes from atPlatform
      final fileBytes = await _downloadFileFromAtPlatform(fileId, fromAtSign);
      if (fileBytes == null) {
        throw Exception('Failed to download file chunks');
      }

      // Show save dialog to let user choose where to save the file
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save file',
        fileName: fileName,
        type: FileType.any,
      );

      if (result == null) {
        print('❌ User cancelled file save');
        return null;
      }

      // Write to the user-selected location
      final file = File(result);
      await file.writeAsBytes(fileBytes);

      // Generate thumbnail if it's an image file
      await _generateThumbnailIfNeeded(fileId, result);

      print('✅ File downloaded successfully: $result');
      return result;
    } catch (e) {
      print('❌ Failed to download file: $e');
      return null;
    }
  }

  /// Download a file automatically to app directory (for previews, thumbnails, etc.)
  /// For images, downloads lightweight thumbnail first
  Future<String?> downloadFileToAppDirectory(String fileId, String fileName, [String? fromAtSign]) async {
    try {
      print('📥 Auto-downloading file for preview: $fileName');

      // For images, try to download thumbnail first (much faster and lighter)
      final mimeType = _getMimeType(fileName);
      if (mimeType != null && mimeType.startsWith('image/')) {
        print('� Image detected - attempting thumbnail download first');

        // Thumbnail download not implemented - fallback to full download
      }

      // Fall back to full download for non-images or if thumbnail fails
      final downloadDir = await _getDownloadDirectory();
      final localPath = path.join(downloadDir, fileName);

      // Check if file already exists
      final file = File(localPath);
      if (await file.exists()) {
        print('📁 File already exists: $localPath');
        return localPath;
      }

      // Download file chunks from atPlatform
      final fileBytes = await _downloadFileFromAtPlatform(fileId, fromAtSign);
      if (fileBytes == null) {
        throw Exception('Failed to download file chunks');
      }

      // Write to app directory
      await file.writeAsBytes(fileBytes);

      // Generate thumbnail if it's an image file
      await _generateThumbnailIfNeeded(fileId, localPath);

      print('✅ File auto-downloaded successfully: $localPath');
      return localPath;
    } catch (e) {
      print('❌ Failed to auto-download file: $e');
      return null;
    }
  }

  /// Get downloads directory
  Future<String> _getDownloadDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory(path.join(appDir.path, 'AtTalk', 'Downloads'));
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  /// Upload file to atPlatform in chunks with retry mechanism and progress callback
  Future<void> _uploadFileToAtPlatform(File file, String fileId, Function(double) onProgress) async {
    final client = AtTalkService.instance.atClient;
    if (client == null) throw Exception('AtClient not initialized');

    // Read file in chunks to avoid memory issues with large files
    final fileSize = await file.length();
    final totalChunks = (fileSize / chunkSize).ceil();

    print(
      '📤 Uploading file with controlled concurrency: $totalChunks chunks of ${_formatFileSize(chunkSize)} each with 1-day TTL',
    );

    // Upload metadata first with retry
    final metadataKey = AtKey()
      ..key = 'file_meta_$fileId'
      ..sharedBy = AtTalkService.instance.currentAtSign
      ..namespace = AtTalkService.instance.atClientPreference!.namespace
      ..metadata = (Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true
        ..ttl = 86400000); // 1 day TTL in milliseconds

    final metadata = {
      'fileName': path.basename(file.path),
      'fileSize': fileSize,
      'totalChunks': totalChunks,
      'mimeType': lookupMimeType(file.path),
      'uploadTimestamp': DateTime.now().millisecondsSinceEpoch,
    };

    print('📤 Metadata key: ${metadataKey.toString()}');

    // Upload metadata with retry and push to remote
    await _retryOperation(() async {
      await client.put(
        metadataKey,
        jsonEncode(metadata),
        putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
      );
      print('✅ Uploaded file metadata directly to remote atServer');
    }, 'upload metadata');

    // Upload chunks with controlled concurrency to avoid overloading atServer
    final fileStream = file.openRead();
    final chunkDataList = <Uint8List>[];

    // First, read all chunks into memory (they're small - 8KB each)
    await for (final chunkData in fileStream.transform(ChunkReader(chunkSize))) {
      chunkDataList.add(chunkData);
    }

    print('📤 Uploading ${chunkDataList.length} chunks with max $maxConcurrentUploads concurrent uploads...');

    // Create a semaphore to limit concurrent uploads
    final semaphore = Semaphore(maxConcurrentUploads);
    final futures = <Future<void>>[];

    // Upload chunks with concurrency control
    for (int i = 0; i < chunkDataList.length; i++) {
      final chunkIndex = i;
      final chunkData = chunkDataList[i];

      final future = semaphore.acquire().then((_) async {
        try {
          // Add small delay to help with chunk ordering on remote server
          if (chunkIndex > 0) {
            await Future.delayed(chunkUploadDelay);
          }
          await _uploadChunkWithRetry(client, fileId, chunkIndex, chunkData, totalChunks);
        } finally {
          semaphore.release();
        }
      });

      futures.add(future);
    }

    // Wait for all chunks to complete and update progress
    int completedChunks = 0;
    for (final future in futures) {
      await future;
      completedChunks++;
      onProgress(completedChunks / totalChunks);
    }

    print('✅ All chunks uploaded successfully with controlled concurrency');
    print('✅ All file data uploaded directly to remote atServer - no sync needed');
  }

  /// Upload a single chunk with retry mechanism
  Future<void> _uploadChunkWithRetry(
    AtClient client,
    String fileId,
    int chunkIndex,
    Uint8List chunkData,
    int totalChunks,
  ) async {
    final chunkKey = AtKey()
      ..key = 'file_chunk_${fileId}_$chunkIndex'
      ..sharedBy = AtTalkService.instance.currentAtSign
      ..namespace = AtTalkService.instance.atClientPreference!.namespace
      ..metadata = (Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true
        ..isBinary = true
        ..ttl = 86400000); // 1 day TTL in milliseconds

    await _retryOperation(() async {
      await client
          .put(chunkKey, chunkData, putRequestOptions: PutRequestOptions()..useRemoteAtServer = true)
          .timeout(chunkTimeout);
      print(
        '📤 Uploaded chunk ${chunkIndex + 1}/$totalChunks (${_formatFileSize(chunkData.length)}) directly to remote',
      );
    }, 'upload chunk ${chunkIndex + 1}/$totalChunks');
  }

  /// Generic retry mechanism for operations
  Future<T> _retryOperation<T>(Future<T> Function() operation, String operationName) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('❌ Failed $operationName (attempt $attempt/$maxRetries): $e');

        if (attempt < maxRetries) {
          final delay = Duration(seconds: attempt * 2); // Exponential backoff
          print('⏳ Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      }
    }

    throw Exception('Failed $operationName after $maxRetries attempts: $lastException');
  }

  /// Check if file keys exist before attempting download
  Future<bool> _checkFileKeysExist(String fileId, String? fromAtSign) async {
    try {
      final client = AtTalkService.instance.atClient;
      if (client == null) return false;

      // Check metadata key first
      final metadataKey = AtKey()
        ..key = 'file_meta_$fileId'
        ..sharedBy = fromAtSign ?? AtTalkService.instance.currentAtSign
        ..sharedWith = AtTalkService.instance.currentAtSign
        ..namespace = AtTalkService.instance.atClientPreference!.namespace;

      final isRemoteFetch = fromAtSign != null && fromAtSign != AtTalkService.instance.currentAtSign;

      print('🔍 Checking if file keys exist...');
      print('🔍 Metadata key: ${metadataKey.toString()}');

      final metadataResult = isRemoteFetch
          ? await client.get(metadataKey, getRequestOptions: GetRequestOptions()..bypassCache = true)
          : await client.get(metadataKey);

      if (metadataResult.value == null) {
        print('❌ Metadata key not found');
        return false;
      }

      final metadata = jsonDecode(metadataResult.value.toString());
      final totalChunks = metadata['totalChunks'] as int;

      print('✅ Metadata key found, checking $totalChunks chunks...');

      // Check first few chunks to see if they exist
      for (int i = 0; i < min(3, totalChunks); i++) {
        final chunkKey = AtKey()
          ..key = 'file_chunk_${fileId}_$i'
          ..sharedBy = fromAtSign ?? AtTalkService.instance.currentAtSign
          ..sharedWith = AtTalkService.instance.currentAtSign
          ..namespace = AtTalkService.instance.atClientPreference!.namespace;

        final chunkResult = isRemoteFetch
            ? await client.get(chunkKey, getRequestOptions: GetRequestOptions()..bypassCache = true)
            : await client.get(chunkKey);

        if (chunkResult.value == null) {
          print('❌ Chunk $i key not found: ${chunkKey.toString()}');
          return false;
        } else {
          print('✅ Chunk $i key exists');
        }
      }

      print('✅ File keys validation passed');
      return true;
    } catch (e) {
      print('❌ Error checking file keys: $e');
      return false;
    }
  }

  /// Download file from atPlatform by reconstructing chunks with retry mechanism
  Future<Uint8List?> _downloadFileFromAtPlatform(
    String fileId, [
    String? fromAtSign, // Add sender parameter
  ]) async {
    try {
      final client = AtTalkService.instance.atClient;
      if (client == null) {
        print('❌ AtClient not available for download');
        return null;
      }

      print('📥 Getting file metadata for: $fileId');
      print('📥 Current atSign: ${AtTalkService.instance.currentAtSign}');
      print('📥 Sender atSign: ${fromAtSign ?? "same as current"}');

      // Check if file keys exist before attempting download
      final keysExist = await _checkFileKeysExist(fileId, fromAtSign);
      if (!keysExist) {
        print('❌ File keys not found or inaccessible');
        return null;
      }

      // Get metadata first with retry
      final metadataKey = AtKey()
        ..key = 'file_meta_$fileId'
        ..sharedBy = fromAtSign ?? AtTalkService.instance.currentAtSign
        ..sharedWith = AtTalkService
            .instance
            .currentAtSign // Explicitly set sharedWith
        ..namespace = AtTalkService.instance.atClientPreference!.namespace;

      final isRemoteFetch = fromAtSign != null && fromAtSign != AtTalkService.instance.currentAtSign;
      print(
        '📥 ${isRemoteFetch ? "Remote" : "Local"} fetch from: ${fromAtSign ?? AtTalkService.instance.currentAtSign}',
      );
      print('📥 Metadata key: ${metadataKey.toString()}');

      final metadataResult = await _retryOperation(() async {
        // If fromAtSign is provided and different from current user, fetch from remote
        final result = isRemoteFetch
            ? await client
                  .get(metadataKey, getRequestOptions: GetRequestOptions()..bypassCache = true)
                  .timeout(chunkTimeout)
            : await client.get(metadataKey).timeout(chunkTimeout);

        if (result.value == null) {
          throw Exception('File metadata not found for key: ${metadataKey.toString()}');
        }
        return result;
      }, 'get file metadata');

      final metadata = jsonDecode(metadataResult.value.toString());
      final totalChunks = metadata['totalChunks'] as int;
      final expectedSize = metadata['fileSize'] as int;

      print(
        '📥 Downloading file: ${metadata['fileName']} (${_formatFileSize(expectedSize)}) in $totalChunks chunks sequentially',
      );

      // Download chunks sequentially to be gentle on atServer
      final chunks = <Uint8List>[];

      for (int i = 0; i < totalChunks; i++) {
        print('📥 Downloading chunk ${i + 1}/$totalChunks in sequence...');
        final chunkData = await _downloadChunkWithRetry(client, fileId, i, totalChunks, fromAtSign);
        chunks.add(chunkData);
      }

      // Reconstruct file
      final buffer = BytesBuilder();
      for (final chunk in chunks) {
        buffer.add(chunk);
      }

      final fileBytes = buffer.toBytes();
      print('📥 Reconstructed file: ${_formatFileSize(fileBytes.length)} (expected: ${_formatFileSize(expectedSize)})');

      if (fileBytes.length != expectedSize) {
        throw Exception('File size mismatch: got ${fileBytes.length}, expected $expectedSize');
      }

      print('✅ File download completed successfully');
      return fileBytes;
    } catch (e) {
      print('❌ Error downloading file: $e');
      return null;
    }
  }

  /// Download a single chunk with retry mechanism
  Future<Uint8List> _downloadChunkWithRetry(
    AtClient client,
    String fileId,
    int chunkIndex,
    int totalChunks, [
    String? fromAtSign, // Add sender parameter
  ]) async {
    final chunkKey = AtKey()
      ..key = 'file_chunk_${fileId}_$chunkIndex'
      ..sharedBy = fromAtSign ?? AtTalkService.instance.currentAtSign
      ..sharedWith = AtTalkService
          .instance
          .currentAtSign // Explicitly set sharedWith
      ..namespace = AtTalkService.instance.atClientPreference!.namespace;

    final isRemoteFetch = fromAtSign != null && fromAtSign != AtTalkService.instance.currentAtSign;
    if (chunkIndex == 0) {
      // Only log once for the first chunk to avoid spam
      print(
        '📥 ${isRemoteFetch ? "Remote" : "Local"} chunk fetch from: ${fromAtSign ?? AtTalkService.instance.currentAtSign}',
      );
      print('📥 Chunk key format: ${chunkKey.toString()}');
    }

    return await _retryOperation(() async {
      // If fromAtSign is provided and different from current user, fetch from remote
      final chunkResult = isRemoteFetch
          ? await client.get(chunkKey, getRequestOptions: GetRequestOptions()..bypassCache = true).timeout(chunkTimeout)
          : await client.get(chunkKey).timeout(chunkTimeout);

      if (chunkResult.value == null) {
        print('❌ Chunk key not found: ${chunkKey.toString()}');
        throw Exception('Missing chunk $chunkIndex - key: ${chunkKey.toString()}');
      }

      final chunkData = chunkResult.value as Uint8List;
      print('📥 Downloaded chunk ${chunkIndex + 1}/$totalChunks (${_formatFileSize(chunkData.length)})');
      return chunkData;
    }, 'download chunk ${chunkIndex + 1}/$totalChunks');
  }

  /// Generate thumbnail for images
  Future<String?> _generateThumbnail(String imagePath, String fileId) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        print('❌ Image file does not exist: $imagePath');
        return null;
      }

      print('📸 Reading image file: $imagePath');
      final imageBytes = await file.readAsBytes();

      if (imageBytes.isEmpty) {
        print('❌ Image file is empty: $imagePath');
        return null;
      }

      print('📸 Decoding image (${_formatFileSize(imageBytes.length)})');
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        print('❌ Failed to decode image - unsupported format or corrupted file: $imagePath');
        return null;
      }

      print('📸 Image decoded successfully: ${image.width}x${image.height}');

      // Resize image to thumbnail size
      final thumbnail = img.copyResize(
        image,
        width: image.width > image.height ? thumbnailSize : null,
        height: image.height >= image.width ? thumbnailSize : null,
      );

      print('📸 Thumbnail resized to: ${thumbnail.width}x${thumbnail.height}');

      // Save thumbnail - ensure consistent path with getThumbnailPath
      final thumbnailDir = await _getThumbnailDirectory();
      final thumbnailPath = path.join(thumbnailDir, 'thumb_$fileId.jpg');
      final thumbnailFile = File(thumbnailPath);

      // Encode as JPEG with error handling
      final jpegBytes = img.encodeJpg(thumbnail, quality: 80);
      if (jpegBytes.isEmpty) {
        print('❌ Failed to encode thumbnail as JPEG');
        return null;
      }

      await thumbnailFile.writeAsBytes(jpegBytes);

      print('✅ Thumbnail generated: $thumbnailPath (${_formatFileSize(jpegBytes.length)})');
      return thumbnailPath;
    } catch (e) {
      print('❌ Failed to generate thumbnail: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Get consistent thumbnail directory
  Future<String> _getThumbnailDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbnailDir = Directory(path.join(appDir.path, 'AtTalk', 'Thumbnails'));
    if (!await thumbnailDir.exists()) {
      await thumbnailDir.create(recursive: true);
    }
    return thumbnailDir.path;
  }

  /// Generate thumbnail if needed for downloaded files
  Future<void> _generateThumbnailIfNeeded(String fileId, String filePath) async {
    try {
      // Check if it's an image file
      final mimeType = _getMimeType(filePath);

      print('🔍 Checking thumbnail generation for: $filePath');
      print('🔍 Detected MIME type: $mimeType');

      if (mimeType != null && mimeType.startsWith('image/')) {
        print('📸 Generating thumbnail for image file: $filePath');
        final thumbnailPath = await _generateThumbnail(filePath, fileId);
        if (thumbnailPath != null) {
          print('✅ Thumbnail generated successfully: $thumbnailPath');
        } else {
          print('❌ Failed to generate thumbnail for: $filePath');
        }
      } else {
        print('⏭️ Skipping thumbnail generation - not an image file');
      }
    } catch (e) {
      print('❌ Error generating thumbnail: $e');
    }
  }

  /// Get thumbnail path for a file ID
  Future<String?> getThumbnailPathAsync(String fileId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbnailDir = path.join(appDir.path, 'AtTalk', 'Thumbnails');
      final thumbnailPath = path.join(thumbnailDir, 'thumb_$fileId.jpg');

      if (File(thumbnailPath).existsSync()) {
        return thumbnailPath;
      }
      return null;
    } catch (e) {
      print('❌ Error getting thumbnail path: $e');
      return null;
    }
  }

  /// Get thumbnail path for a file ID (synchronous version for UI)
  String? getThumbnailPath(String fileId) {
    try {
      // Use the same base path as downloads for consistency
      final thumbnailPath = path.join(
        Platform.environment['HOME'] ?? '',
        'Library',
        'Containers',
        'com.example.atTalkGui',
        'Data',
        'Library',
        'Application Support',
        'com.example.atTalkGui',
        'AtTalk',
        'Thumbnails',
        'thumb_$fileId.jpg',
      );

      if (File(thumbnailPath).existsSync()) {
        print('📸 Found thumbnail: $thumbnailPath');
        return thumbnailPath;
      } else {
        print('❓ Thumbnail not found: $thumbnailPath');
        // Also check the simplified path
        final simplePath = path.join(
          Platform.environment['HOME'] ?? '',
          'Documents',
          'AtTalk',
          'Thumbnails',
          'thumb_$fileId.jpg',
        );
        if (File(simplePath).existsSync()) {
          print('📸 Found thumbnail (simple path): $simplePath');
          return simplePath;
        }
        return null;
      }
    } catch (e) {
      print('❌ Error getting thumbnail path: $e');
      return null;
    }
  }

  /// Get MIME type from file extension
  String? _getMimeType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.bmp':
        return 'image/bmp';
      case '.webp':
        return 'image/webp';
      case '.tiff':
      case '.tif':
        return 'image/tiff';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.txt':
        return 'text/plain';
      case '.mp3':
        return 'audio/mpeg';
      case '.mp4':
        return 'video/mp4';
      default:
        return lookupMimeType(filePath); // Fallback to mime package
    }
  }

  /// Determine attachment type from MIME type
  AttachmentType _getAttachmentType(String? mimeType) {
    if (mimeType == null) return AttachmentType.other;

    if (mimeType.startsWith('image/')) return AttachmentType.image;
    if (mimeType.startsWith('audio/')) return AttachmentType.audio;
    if (mimeType.startsWith('video/')) return AttachmentType.video;
    if (mimeType.startsWith('text/') ||
        mimeType.contains('pdf') ||
        mimeType.contains('document') ||
        mimeType.contains('msword') ||
        mimeType.contains('sheet'))
      return AttachmentType.document;

    return AttachmentType.other;
  }

  /// Generate unique file ID
  String _generateFileId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return '${timestamp}_$random';
  }

  /// Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Check AtClient health before operations
  Future<bool> _checkAtClientHealth() async {
    try {
      final client = AtTalkService.instance.atClient;
      if (client == null) {
        print('❌ AtClient is null');
        return false;
      }

      // Try a simple operation to test connectivity
      final testKey = AtKey()
        ..key = 'health_check'
        ..sharedBy = AtTalkService.instance.currentAtSign
        ..namespace = AtTalkService.instance.atClientPreference!.namespace
        ..metadata = (Metadata()
          ..isPublic = false
          ..isEncrypted = true
          ..namespaceAware = true);

      await client.put(testKey, 'health_check_${DateTime.now().millisecondsSinceEpoch}').timeout(Duration(seconds: 10));
      print('✅ AtClient health check passed');
      return true;
    } catch (e) {
      print('❌ AtClient health check failed: $e');
      return false;
    }
  }
}
