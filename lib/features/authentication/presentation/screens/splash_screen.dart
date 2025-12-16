import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;
    
    // TODO: Check authentication status and navigate accordingly
    // For now, navigate to onboarding
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.search,
                size: 60,
                color: Color(0xFF1976D2),
              ),
            )
                .animate()
                .scale(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutBack,
                )
                .fadeIn(),
            
            const SizedBox(height: 30),
            
            // App Name
            const Text(
              'Lost & Found',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            )
                .animate()
                .fadeIn(delay: const Duration(milliseconds: 400))
                .slideY(begin: 0.3, end: 0),
            
            const SizedBox(height: 10),
            
            // Tagline
            const Text(
              'Reuniting People with Their Belongings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            )
                .animate()
                .fadeIn(delay: const Duration(milliseconds: 600))
                .slideY(begin: 0.3, end: 0),
            
            const SizedBox(height: 50),
            
            // Loading Indicator
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 1000)),
          ],
        ),
      ),
    );
  }
}
