import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// KeyChainManager is used in getAtsignEntries()
import 'package:at_client_mobile/at_client_mobile.dart';

class AtsignInformation {
  final String atSign;
  final String rootDomain;

  const AtsignInformation({required this.atSign, required this.rootDomain});

  Map<String, String> toJson() => {"atsign": atSign, "root-domain": rootDomain};

  static AtsignInformation? fromJson(Map json) {
    if (json["atsign"] is! String || json["root-domain"] is! String) {
      return null;
    }
    return AtsignInformation(
      atSign: json["atsign"],
      rootDomain: json["root-domain"],
    );
  }

  @override
  String toString() {
    return 'AtsignInformation($atSign, $rootDomain)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AtsignInformation &&
          runtimeType == other.runtimeType &&
          atSign == other.atSign &&
          rootDomain == other.rootDomain;

  @override
  int get hashCode => atSign.hashCode ^ rootDomain.hashCode;
}

/// Get all atSigns that are stored in the keychain along with their root domains
Future<Map<String, AtsignInformation>> getAtsignEntries() async {
  final keyChainManager = KeyChainManager.getInstance();
  var atSignMap = <String, AtsignInformation>{};

  try {
    var keychainAtSigns = await keyChainManager.getAtSignListFromKeychain();
    print(
      'Successfully retrieved ${keychainAtSigns.length} atSigns from keychain: $keychainAtSigns',
    );

    // Use only the keychain as the source of truth for atSign listing
    for (var atSign in keychainAtSigns) {
      // Try to get root domain from information file, but default to standard domain if not found
      var rootDomain = 'root.atsign.org';
      try {
        var atSignInfo = await _getAtsignInformationFromFile();
        print(
          "Debug: Read ${atSignInfo.length} atSign entries from information file",
        );
        for (var info in atSignInfo) {
          print(
            "Debug: Found atSign: ${info.atSign}, domain: ${info.rootDomain}",
          );
        }
        var info = atSignInfo.firstWhere(
          (item) => item.atSign == atSign,
          orElse: () =>
              AtsignInformation(atSign: atSign, rootDomain: rootDomain),
        );
        rootDomain = info.rootDomain;
        print("Debug: Using domain '$rootDomain' for atSign '$atSign'");
      } catch (e) {
        // If we can't read the information file, use the default domain
        print(
          "Could not read atSign information file for root domain, using default: $e",
        );
      }

      atSignMap[atSign] = AtsignInformation(
        atSign: atSign,
        rootDomain: rootDomain,
      );
    }
  } catch (e) {
    print('Error reading from keychain: $e');

    // Check if this is a JSON parsing error indicating keychain corruption
    if (e.toString().contains('FormatException') ||
        e.toString().contains('ChunkedJsonParser') ||
        e.toString().contains('Invalid JSON') ||
        e.toString().contains('Unexpected character')) {
      print(
        'Keychain appears to be corrupted, throwing specific error for UI handling',
      );
      throw Exception(
        'Keychain data is corrupted. Please use the "Manage Keys" option to clean up corrupted data.',
      );
    }

    // For other errors, re-throw to let the UI handle them
    rethrow;
  }

  return atSignMap;
}

/// Save atSign information after successful onboarding
Future<bool> saveAtsignInformation(AtsignInformation info) async {
  print("DEBUG: saveAtsignInformation called with: $info");
  var f = await _getAtsignInformationFile();
  print("DEBUG: Got information file: ${f?.path}");
  final List<AtsignInformation> atSignInfo;
  try {
    atSignInfo = await _getAtsignInformationFromFile(f);
    print("DEBUG: Read ${atSignInfo.length} existing entries from file");
  } catch (e) {
    print("DEBUG: Error reading existing entries: $e");
    // We only end up here if we failed to create, get, or read the file
    // we don't want to overwrite it in that scenario, so return false
    //
    // We won't end up here if it was a json parse error, such as invalid
    // json, we do want to overwrite that so that the app can recover as best
    // as possible
    return false;
  }
  if (f == null) {
    print("DEBUG: Information file is null, returning false");
    return false;
  }

  // Replace the existing entry with the new one if it exists
  bool found = false;
  for (int i = 0; i < atSignInfo.length; i++) {
    if (atSignInfo[i].atSign == info.atSign) {
      found = true;
      atSignInfo[i] = info;
      print("DEBUG: Updated existing entry for ${info.atSign}");
    }
  }
  // Otherwise add it as a new entry
  if (!found) {
    atSignInfo.add(info);
    print("DEBUG: Added new entry for ${info.atSign}");
  }
  try {
    final jsonString = jsonEncode(atSignInfo.map((e) => e.toJson()).toList());
    print("DEBUG: Writing JSON to file: $jsonString");
    await f.writeAsString(jsonString, mode: FileMode.writeOnly, flush: true);
    print("DEBUG: Successfully wrote to file");
    return true;
  } catch (e) {
    print("DEBUG: Failed to save AtSign information: ${e.toString()}");
    return false;
  }
}

/// Remove atSign information (for logout/delete)
Future<bool> removeAtsignInformation(String atSign) async {
  var f = await _getAtsignInformationFile();
  if (f == null) return false;

  try {
    var atSignInfo = await _getAtsignInformationFromFile(f);
    atSignInfo.removeWhere((info) => info.atSign == atSign);

    await f.writeAsString(
      jsonEncode(atSignInfo.map((e) => e.toJson()).toList()),
      mode: FileMode.writeOnly,
      flush: true,
    );
    return true;
  } catch (e) {
    print("Failed to remove AtSign information : ${e.toString()}");
    return false;
  }
}

Future<File?> _getAtsignInformationFile() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final atTalkDir = Directory(p.join(dir.path, 'at_talk'));
    if (!atTalkDir.existsSync()) {
      print("Creating AtTalk directory: ${atTalkDir.path}");
      atTalkDir.createSync(recursive: true);
    }
    final file = File(p.join(atTalkDir.path, 'atsign_info.json'));

    // If file doesn't exist, create it with an empty JSON array
    if (!file.existsSync()) {
      print("Creating AtSign information file: ${file.path}");
      await file.writeAsString('[]');
    }

    return file;
  } catch (e) {
    print("Failed to get AtSign information file : ${e.toString()}");
    return null;
  }
}

Future<List<AtsignInformation>> _getAtsignInformationFromFile([File? f]) async {
  f ??= await _getAtsignInformationFile();
  if (f == null) throw Exception("Failed to get the Atsign Information File");

  // Check if file exists, if not return empty list
  if (!await f.exists()) {
    print("AtSign information file does not exist, returning empty list");
    return [];
  }

  try {
    var contents = await f.readAsString();
    if (contents.trim().isEmpty) return [];
    var json = jsonDecode(contents);
    if (json is! Iterable) {
      return []; // The file format is invalid so return as a non-error and we will overwrite it
    }
    var res = <AtsignInformation>[];
    for (var item in json) {
      if (item is! Map) continue;
      var info = AtsignInformation.fromJson(item);
      if (info == null) continue;
      res.add(info);
    }
    return res;
  } catch (e) {
    print("Failed to Parse Atsign Information File : ${e.toString()}");
    rethrow;
  }
}
