import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a, b) => const LoginScreen(),
        transitionsBuilder: (context, a, b, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Decorative glowing orbs
          Positioned(
                top: -100,
                left: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).primaryColor.withOpacity(0.15),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                        blurRadius: 100,
                      ),
                    ],
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(end: 1.2, duration: 4.seconds),

          Positioned(
                bottom: -50,
                right: -50,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.cyanAccent.withOpacity(0.1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.2),
                        blurRadius: 100,
                      ),
                    ],
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(end: 1.3, duration: 5.seconds),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      _OnboardingPage(
                        title: 'Elite Cricket Tracking',
                        description:
                            'Experience professional-grade match scoring right at your fingertips.',
                        icon: Icons.sports_cricket,
                        index: 0,
                        currentIndex: _currentPage,
                      ),
                      _OnboardingPage(
                        title: 'Deep Statistics',
                        description:
                            'Manage players and track comprehensive career statistics over time.',
                        icon: Icons.bar_chart,
                        index: 1,
                        currentIndex: _currentPage,
                      ),
                      _OnboardingPage(
                        title: 'Live Drafts & Toss',
                        description:
                            'Set up your matches with our immersive 3D drafting system.',
                        icon: Icons.group_add,
                        index: 2,
                        currentIndex: _currentPage,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dots Indicator
                      Row(
                        children: List.generate(
                          3,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8.0),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? Theme.of(context).primaryColor
                                  : Colors.white54,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: _currentPage == index
                                  ? [
                                      BoxShadow(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.5),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),

                      // Action Button
                      GestureDetector(
                        onTap: () {
                          if (_currentPage == 2) {
                            _finishOnboarding();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: EdgeInsets.symmetric(
                            horizontal: _currentPage == 2 ? 30 : 20,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(
                                _currentPage == 2 ? 'Get Started' : 'Next',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (_currentPage != 2) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final int index;
  final int currentIndex;

  const _OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.index,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    bool isActive = index == currentIndex;

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glassmorphism Card for Icon
          ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Color(0xFF1B5E20).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Color(0xFF1B5E20).withOpacity(0.1),
                      ),
                    ),
                    child:
                        Icon(
                              icon,
                              size: 100,
                              color: isActive
                                  ? Theme.of(context).primaryColor
                                  : Colors.white54,
                            )
                            .animate(target: isActive ? 1 : 0)
                            .scaleXY(
                              begin: 0.8,
                              end: 1.0,
                              duration: 400.ms,
                              curve: Curves.easeOutBack,
                            )
                            .shimmer(
                              delay: 400.ms,
                              duration: 1.seconds,
                              color: Colors.white54,
                            ),
                  ),
                ),
              )
              .animate(target: isActive ? 1 : 0)
              .slideY(
                begin: 0.2,
                end: 0,
                duration: 500.ms,
                curve: Curves.easeOut,
              )
              .fadeIn(),

          const SizedBox(height: 50),

          Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              )
              .animate(target: isActive ? 1 : 0)
              .slideY(
                begin: 0.5,
                end: 0,
                duration: 500.ms,
                delay: 100.ms,
                curve: Curves.easeOut,
              )
              .fadeIn(),

          const SizedBox(height: 20),

          Text(
                description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white60,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              )
              .animate(target: isActive ? 1 : 0)
              .slideY(
                begin: 0.5,
                end: 0,
                duration: 500.ms,
                delay: 200.ms,
                curve: Curves.easeOut,
              )
              .fadeIn(),
        ],
      ),
    );
  }
}
