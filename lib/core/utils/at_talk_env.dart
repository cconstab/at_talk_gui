import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';

class AtTalkEnv {
  // Root domain for atSign servers
  static const String rootDomain = 'root.atsign.org';

  // Environment (using Staging for development/testing without API key)
  // Switch to Production when you have a valid API key
  static const RootEnvironment rootEnvironment = RootEnvironment.Staging;

  // API Key for getting free atSigns (required for production)
  // Note: This should be obtained from https://my.atsign.com and stored securely
  // Can be set via environment variable AT_TALK_API_KEY or hardcoded below
  static String? get appApiKey {
    // First try environment variable
    const envApiKey = String.fromEnvironment('AT_TALK_API_KEY');
    if (envApiKey.isNotEmpty) {
      return envApiKey;
    }

    // Fall back to hardcoded value (replace with your actual API key)
    return "da11d9fa-166b-493e-b10b-54a3c2a3d0d9"; // Set to null for staging/testing, or replace with actual API key
  }

  // App namespace - configurable like TUI's -n option
  static String _namespace = 'default.attalk';

  // App name
  static const String appName = 'atTalk';

  // Get current namespace
  static String get namespace => _namespace;

  // Set namespace (like TUI's -n option)
  static void setNamespace(String namespace) {
    // Ensure it ends with .attalk like the TUI does
    if (!namespace.endsWith('.attalk')) {
      _namespace = '$namespace.attalk';
    } else {
      _namespace = namespace;
    }
  }

  // Reset to default namespace
  static void resetNamespace() {
    _namespace = 'default.attalk';
  }
}
