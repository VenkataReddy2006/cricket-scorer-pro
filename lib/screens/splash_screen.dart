import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialRoute();
  }

  Future<void> _checkInitialRoute() async {
    await Future.delayed(const Duration(seconds: 3));
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    final String? token = prefs.getString('auth_token');
    final bool isLoggedIn = token != null && token.isNotEmpty;

    if (!mounted) return;

    if (!hasSeenOnboarding) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else if (!isLoggedIn) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.4,
            colors: [
              Color(0xFF1A2236), // Deep glowing slate navy center
              Color(0xFF080B11), // Midnight black edges
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Decorative background glowing element in Stack
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.18),
                            Theme.of(context).primaryColor.withOpacity(0),
                          ],
                        ),
                      ),
                    )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.3, 1.3),
                      duration: 2.seconds,
                      curve: Curves.easeInOut,
                    ),
                Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.08),
                            Colors.white.withOpacity(0.02),
                          ],
                        ),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.25),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.sports_cricket,
                        size: 84,
                        color: Theme.of(context).primaryColor,
                      ),
                    )
                    .animate()
                    .scale(duration: 800.ms, curve: Curves.easeOutBack)
                    .shimmer(
                      duration: 1800.ms,
                      color: Colors.white.withOpacity(0.5),
                      angle: 1,
                    )
                    .then()
                    .shake(
                      hz: 3,
                      curve: Curves.easeInOutCubic,
                      duration: 800.ms,
                    ),
              ],
            ),

            const SizedBox(height: 50),

            Text(
                  'CRICKET',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.6),
                        blurRadius: 25,
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(delay: 400.ms, duration: 800.ms)
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOutBack),
            Text(
                  'SCORER PRO',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.6),
                        blurRadius: 25,
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(delay: 400.ms, duration: 800.ms)
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOutBack),

            const SizedBox(height: 12),

            Text(
              'ELITE SCORING',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: Theme.of(context).colorScheme.secondary,
                shadows: [
                  Shadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withOpacity(0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 800.ms),
          ],
        ),
      ),
    );
  }
}
