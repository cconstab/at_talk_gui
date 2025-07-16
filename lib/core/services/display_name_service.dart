import 'dart:convert';
import 'package:at_client/at_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'at_talk_service.dart';

class DisplayNameService {
  static DisplayNameService? _instance;
  static DisplayNameService get instance => _instance ??= DisplayNameService._internal();

  DisplayNameService._internal();

  static const String _localCachePrefix = 'display_name_';
  final Map<String, String> _memoryCache = {};

  /// Set display name for the current user
  /// This will be stored as a public atKey so others can see it
  Future<bool> setMyDisplayName(String displayName) async {
    try {
      final client = AtTalkService.instance.atClient;
      final currentAtSign = AtTalkService.instance.currentAtSign;

      if (client == null || currentAtSign == null) {
        throw Exception('AtClient not initialized');
      }

      // Store as public atKey so others can read it
      final key = AtKey()
        ..key = 'display_name'
        ..sharedBy = currentAtSign
        ..namespace = 'attalk.profile'
        ..metadata = (Metadata()
          ..isPublic = true
          ..isEncrypted = false
          ..namespaceAware = true
          ..ttl = null); // No expiration

      final displayNameData = {
        'displayName': displayName.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
        'version': '1.0',
      };

      await client.put(
        key,
        jsonEncode(displayNameData),
        putRequestOptions: PutRequestOptions()..useRemoteAtServer = true,
      );

      // Cache locally
      _memoryCache[currentAtSign] = displayName.trim();
      await _cacheDisplayNameLocally(currentAtSign, displayName.trim());

      print('✅ Display name set successfully: $displayName');
      return true;
    } catch (e) {
      print('❌ Failed to set display name: $e');
      return false;
    }
  }

  /// Clear/delete the display name for the current user
  Future<bool> clearMyDisplayName() async {
    try {
      final client = AtTalkService.instance.atClient;
      final currentAtSign = AtTalkService.instance.currentAtSign;

      if (client == null || currentAtSign == null) {
        throw Exception('AtClient not initialized');
      }

      // Delete the public atKey
      final key = AtKey()
        ..key = 'display_name'
        ..sharedBy = currentAtSign
        ..namespace = 'attalk.profile'
        ..metadata = (Metadata()
          ..isPublic = true
          ..isEncrypted = false
          ..namespaceAware = true);

      await client.delete(key, deleteRequestOptions: DeleteRequestOptions()..useRemoteAtServer = true);

      // Clear from caches
      _memoryCache.remove(currentAtSign);
      await _clearCachedDisplayNameLocally(currentAtSign);

      print('✅ Display name cleared successfully');
      return true;
    } catch (e) {
      print('❌ Failed to clear display name: $e');
      return false;
    }
  }

  /// Get display name for a given atSign
  /// First checks memory cache, then local cache, then fetches from atPlatform
  Future<String?> getDisplayName(String atSign) async {
    final normalizedAtSign = atSign.startsWith('@') ? atSign : '@$atSign';

    // Check memory cache first
    if (_memoryCache.containsKey(normalizedAtSign)) {
      return _memoryCache[normalizedAtSign];
    }

    // Check local cache
    final cachedName = await _getCachedDisplayNameLocally(normalizedAtSign);
    if (cachedName != null) {
      _memoryCache[normalizedAtSign] = cachedName;
      return cachedName;
    }

    // Fetch from atPlatform
    final fetchedName = await _fetchDisplayNameFromAtPlatform(normalizedAtSign);
    if (fetchedName != null) {
      _memoryCache[normalizedAtSign] = fetchedName;
      await _cacheDisplayNameLocally(normalizedAtSign, fetchedName);
      return fetchedName;
    }

    return null;
  }

  /// Get formatted name for display (display name or fallback to atSign)
  Future<String> getFormattedName(String atSign) async {
    final displayName = await getDisplayName(atSign);
    if (displayName != null && displayName.isNotEmpty) {
      return '$displayName ($atSign)';
    }
    return atSign;
  }

  /// Get short name for display (display name or atSign without @)
  Future<String> getShortName(String atSign) async {
    final displayName = await getDisplayName(atSign);
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    return atSign.startsWith('@') ? atSign.substring(1) : atSign;
  }

  /// Clear all cached display names (useful when switching atSigns)
  Future<void> clearCache() async {
    _memoryCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_localCachePrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
      print('✅ Display name cache cleared');
    } catch (e) {
      print('⚠️ Error clearing display name cache: $e');
    }
  }

  /// Refresh a specific atSign's display name from server
  Future<void> refreshDisplayName(String atSign) async {
    final normalizedAtSign = atSign.startsWith('@') ? atSign : '@$atSign';

    // Remove from caches
    _memoryCache.remove(normalizedAtSign);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localCachePrefix + normalizedAtSign);
    } catch (e) {
      print('⚠️ Error removing cached display name: $e');
    }

    // Fetch fresh data
    await getDisplayName(normalizedAtSign);
  }

  /// Get display names for multiple atSigns (batch operation)
  Future<Map<String, String?>> getDisplayNames(List<String> atSigns) async {
    final results = <String, String?>{};

    for (final atSign in atSigns) {
      results[atSign] = await getDisplayName(atSign);
    }

    return results;
  }

  /// Get my current display name
  Future<String?> getMyDisplayName() async {
    final currentAtSign = AtTalkService.instance.currentAtSign;
    if (currentAtSign == null) return null;

    return await getDisplayName(currentAtSign);
  }

  /// Fetch display name from atPlatform
  Future<String?> _fetchDisplayNameFromAtPlatform(String atSign) async {
    try {
      final client = AtTalkService.instance.atClient;
      if (client == null) return null;

      final key = AtKey()
        ..key = 'display_name'
        ..sharedBy = atSign
        ..namespace = 'attalk.profile';

      final result = await client.get(key, getRequestOptions: GetRequestOptions()..bypassCache = true);
      if (result.value == null) return null;

      final data = jsonDecode(result.value.toString());
      final displayName = data['displayName'] as String?;

      if (displayName != null && displayName.isNotEmpty) {
        print('📥 Fetched display name for $atSign: $displayName');
        return displayName.trim();
      }

      return null;
    } catch (e) {
      // Don't log this as an error since it's normal for users to not have display names set
      print('📝 No display name found for $atSign');
      return null;
    }
  }

  /// Cache display name locally
  Future<void> _cacheDisplayNameLocally(String atSign, String displayName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localCachePrefix + atSign, displayName);
    } catch (e) {
      print('⚠️ Error caching display name locally: $e');
    }
  }

  /// Clear cached display name from local storage
  Future<void> _clearCachedDisplayNameLocally(String atSign) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localCachePrefix + atSign);
    } catch (e) {
      print('⚠️ Error clearing cached display name: $e');
    }
  }

  /// Get cached display name from local storage
  Future<String?> _getCachedDisplayNameLocally(String atSign) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_localCachePrefix + atSign);
    } catch (e) {
      print('⚠️ Error getting cached display name: $e');
      return null;
    }
  }

  /// Check if a display name is valid
  bool isValidDisplayName(String displayName) {
    final trimmed = displayName.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= 50 &&
        !trimmed.contains('@') &&
        !trimmed.contains('\n') &&
        !trimmed.contains('\r');
  }

  /// Get suggested display name from atSign
  String getSuggestedDisplayName(String atSign) {
    final withoutAt = atSign.startsWith('@') ? atSign.substring(1) : atSign;

    // Split by common separators and capitalize
    final parts = withoutAt.split(RegExp(r'[._-]'));
    if (parts.length > 1) {
      return parts.map((part) => part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1)).join(' ');
    }

    // Just capitalize first letter
    return withoutAt.isEmpty ? '' : withoutAt[0].toUpperCase() + withoutAt.substring(1);
  }
}
