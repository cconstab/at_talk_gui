import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:window_manager/window_manager.dart';
import 'package:args/args.dart';
import 'dart:io';

import 'gui/screens/onboarding_screen.dart';
import 'gui/screens/main_screen.dart';
import 'gui/screens/settings_screen.dart';
import 'core/providers/groups_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/services/at_talk_service.dart';
import 'core/utils/at_talk_env.dart';

void main(List<String> args) async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Parse command line arguments like TUI
  _parseCommandLineArgs(args);

  // Debug: Show what namespace is being used
  print('🔧 GUI using namespace: ${AtTalkEnv.namespace}');

  // Continue with normal initialization

  // Initialize window manager for desktop platforms to handle window close events
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Set up signal handlers for graceful shutdown (like TUI)
  if (!Platform.isWindows) {
    ProcessSignal.sigint.watch().listen((signal) {
      print('🧹 Received SIGINT, cleaning up GUI resources...');
      AtTalkService.instance
          .cleanup()
          .then((_) {
            exit(0);
          })
          .catchError((e) {
            print('⚠️ Error during signal cleanup: $e');
            exit(1);
          });
    });

    ProcessSignal.sigterm.watch().listen((signal) {
      print('🧹 Received SIGTERM, cleaning up GUI resources...');
      AtTalkService.instance
          .cleanup()
          .then((_) {
            exit(0);
          })
          .catchError((e) {
            print('⚠️ Error during signal cleanup: $e');
            exit(1);
          });
    });
  }

  runApp(const AtTalkApp());
}

class AtTalkApp extends StatefulWidget {
  const AtTalkApp({super.key});

  @override
  State<AtTalkApp> createState() => _AtTalkAppState();
}

class _AtTalkAppState extends State<AtTalkApp>
    with WidgetsBindingObserver, WindowListener {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Add window close listener for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Remove window close listener for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }

    // Ensure cleanup is called when the app widget is disposed
    print('🧹 App widget disposing, cleaning up GUI resources...');
    // Note: dispose() is synchronous, so we can't await here
    // The cleanup will run in the background
    AtTalkService.instance.cleanup().catchError((e) {
      print('⚠️ Error during app dispose cleanup: $e');
    });

    super.dispose();
  }

  @override
  Future<bool> onWindowClose() async {
    print('🪟 Window close requested, cleaning up GUI resources...');

    // Perform cleanup before allowing the window to close
    try {
      await AtTalkService.instance.cleanup();
      print('✅ GUI cleanup completed, allowing window to close');
      return true; // Allow window to close
    } catch (e) {
      print('⚠️ Error during window close cleanup: $e');
      return true; // Still allow window to close even if cleanup fails
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Cleanup when app is terminated, backgrounded indefinitely, or paused for extended periods
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      print('🧹 App lifecycle change ($state), cleaning up GUI resources...');
      AtTalkService.instance.cleanup().catchError((e) {
        print('⚠️ Error during lifecycle cleanup: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GroupsProvider()),
      ],
      child: MaterialApp(
        title: 'AtTalk GUI',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/onboarding': (context) => const OnboardingScreen(),
          '/groups': (context) => const MainScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Note: Storage path will be determined when user authenticates with an atSign
    // For now, use a temporary generic path that will be updated during onboarding
    final dir = await getApplicationSupportDirectory();
    String storagePath =
        '${dir.path}/.${AtTalkEnv.namespace}/temp_initialization/storage';
    String commitLogPath = '$storagePath/commitLog';
    bool usingEphemeral = false;

    // Create temporary directories for initialization
    await Directory(storagePath).create(recursive: true);
    await Directory(commitLogPath).create(recursive: true);

    print('Using temporary GUI storage for initialization: $storagePath');
    print('(Will be updated to atSign-specific path during authentication)');

    // Initialize AtClient preferences with temporary storage path
    final atClientPreference = AtClientPreference()
      ..rootDomain = AtTalkEnv.rootDomain
      ..namespace = AtTalkEnv.namespace
      ..hiveStoragePath = storagePath
      ..commitLogPath = commitLogPath
      ..isLocalStoreRequired = true
      ..fetchOfflineNotifications = true;

    // Debug logging to verify paths
    print('🔧 AtClient preferences configured:');
    print('   hiveStoragePath: $storagePath');
    print('   commitLogPath: $commitLogPath');
    print('   usingEphemeral: $usingEphemeral');

    AtTalkService.initialize(atClientPreference);

    // Check if user is already authenticated
    final keyChainManager = KeyChainManager.getInstance();
    final atSigns = await keyChainManager.getAtSignListFromKeychain();

    if (atSigns.isNotEmpty) {
      // Try to authenticate with the first available atSign
      await authProvider.authenticateExisting(atSigns.first);
      if (mounted) {
        if (authProvider.isAuthenticated) {
          Navigator.pushReplacementNamed(context, '/groups');
        } else {
          Navigator.pushReplacementNamed(context, '/onboarding');
        }
      }
    } else {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 50,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'AtTalk',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Secure Messaging with atSigns',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Parse command line arguments like TUI's -n option
void _parseCommandLineArgs(List<String> args) {
  final parser = ArgParser();

  // Add namespace option like TUI
  parser.addOption(
    'namespace',
    abbr: 'n',
    mandatory: false,
    help: 'Namespace (defaults to default.attalk)',
  );

  parser.addFlag(
    'help',
    abbr: 'h',
    help: 'Show this help message',
    negatable: false,
  );

  try {
    final parsedArgs = parser.parse(args);

    // Check for help flag
    if (parsedArgs['help']) {
      print('AtTalk GUI - Flutter-based chat for the atPlatform');
      print('');
      print(parser.usage);
      exit(0);
    }

    // Set namespace if provided
    if (parsedArgs['namespace'] != null) {
      final namespace = parsedArgs['namespace'] as String;
      AtTalkEnv.setNamespace(namespace);
      print('Using namespace: ${AtTalkEnv.namespace}');
    }
  } catch (e) {
    print('Error parsing arguments: $e');
    print('Use --help for usage information');
    // Don't exit on argument errors for GUI - just continue with defaults
  }
}
