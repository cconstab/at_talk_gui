import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:at_client_mobile/at_client_mobile.dart';

import 'screens/onboarding_screen.dart';
import 'screens/groups_list_screen.dart';
import 'providers/groups_provider.dart';
import 'providers/auth_provider.dart';
import 'services/at_talk_service.dart';
import 'utils/at_talk_env.dart';

void main() {
  runApp(const AtTalkApp());
}

class AtTalkApp extends StatelessWidget {
  const AtTalkApp({super.key});

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
          '/groups': (context) => const GroupsListScreen(),
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

    // Initialize AtClient preferences
    final dir = await getApplicationSupportDirectory();
    final atClientPreference = AtClientPreference()
      ..rootDomain = AtTalkEnv.rootDomain
      ..namespace = AtTalkEnv.namespace
      ..hiveStoragePath = dir.path
      ..commitLogPath = dir.path
      ..isLocalStoreRequired = true
      ..fetchOfflineNotifications = true;

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
