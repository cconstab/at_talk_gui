import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/at_talk_service.dart';
import '../utils/at_talk_env.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo and title
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 60,
                  color: Color(0xFF2196F3),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Welcome to AtTalk',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Secure, private messaging using atSigns.\nGet started by setting up your atSign.',
                style: TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Onboarding button
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authProvider.isLoading
                          ? null
                          : _startOnboarding,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2196F3),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: authProvider.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2196F3),
                                ),
                              ),
                            )
                          : const Text(
                              'Setup atSign',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Error message display
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  if (authProvider.errorMessage != null) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              authProvider.errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: authProvider.clearError,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              const SizedBox(height: 48),

              // Info text
              const Text(
                'Need an atSign? Visit atsign.com to get yours.',
                style: TextStyle(fontSize: 14, color: Colors.white60),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startOnboarding() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final atClientPreference = AtTalkService.instance.atClientPreference;
      if (atClientPreference == null) {
        throw Exception('AtClient not initialized');
      }

      final result = await AtOnboarding.onboard(
        context: context,
        config: AtOnboardingConfig(
          atClientPreference: atClientPreference,
          domain: AtTalkEnv.rootDomain,
          rootEnvironment: AtTalkEnv.rootEnvironment,
          appAPIKey: AtTalkEnv.appApiKey,
        ),
      );

      switch (result.status) {
        case AtOnboardingResultStatus.success:
          await authProvider.authenticate(result.atsign);
          if (mounted && authProvider.isAuthenticated) {
            Navigator.pushReplacementNamed(context, '/groups');
          }
          break;
        case AtOnboardingResultStatus.error:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Onboarding failed. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;
        case AtOnboardingResultStatus.cancel:
          // User cancelled onboarding
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
