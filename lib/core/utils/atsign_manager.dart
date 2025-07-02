import 'dart:convert';
import 'dart:io';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AtsignInformation {
  final String atSign;
  final String rootDomain;

  const AtsignInformation({required this.atSign, required this.rootDomain});

  Map<String, String> toJson() => {"atsign": atSign, "root-domain": rootDomain};

  static AtsignInformation? fromJson(Map json) {
    if (json["atsign"] is! String || json["root-domain"] is! String) {
      return null;
    }
    return AtsignInformation(atSign: json["atsign"], rootDomain: json["root-domain"]);
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
  var keychainAtSigns = await keyChainManager.getAtSignListFromKeychain();
  var atSignInfo = <AtsignInformation>[];

  try {
    atSignInfo = await _getAtsignInformationFromFile();
  } catch (e) {
    // Check if this is just a "file not found" error (normal for first run)
    if (e is PathNotFoundException || e.toString().contains('Cannot open file')) {
      print("AtSign information file does not exist yet (first run) - this is normal");
      // Ensure the directory structure exists for future saves
      await _getAtsignInformationFile();
      return {};
    } else {
      print("Failed to get AtSign Information, ignoring invalid file: ${e.toString()}");
      return {};
    }
  }

  var atSignMap = <String, AtsignInformation>{};
  for (var item in atSignInfo) {
    if (keychainAtSigns.contains(item.atSign)) {
      atSignMap[item.atSign] = item;
    }
  }
  return atSignMap;
}

/// Save atSign information after successful onboarding
Future<bool> saveAtsignInformation(AtsignInformation info) async {
  var f = await _getAtsignInformationFile();
  final List<AtsignInformation> atSignInfo;
  try {
    atSignInfo = await _getAtsignInformationFromFile(f);
  } catch (e) {
    // We only end up here if we failed to create, get, or read the file
    // we don't want to overwrite it in that scenario, so return false
    //
    // We won't end up here if it was a json parse error, such as invalid
    // json, we do want to overwrite that so that the app can recover as best
    // as possible
    return false;
  }
  if (f == null) return false;

  // Replace the existing entry with the new one if it exists
  bool found = false;
  for (int i = 0; i < atSignInfo.length; i++) {
    if (atSignInfo[i].atSign == info.atSign) {
      found = true;
      atSignInfo[i] = info;
    }
  }
  // Otherwise add it as a new entry
  if (!found) {
    atSignInfo.add(info);
  }
  try {
    f.writeAsString(jsonEncode(atSignInfo.map((e) => e.toJson()).toList()), mode: FileMode.writeOnly, flush: true);
    return true;
  } catch (e) {
    print("Failed to save AtSign information : ${e.toString()}");
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
