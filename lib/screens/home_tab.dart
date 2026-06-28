import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/cricket_provider.dart';
import '../widgets/glass_container.dart';
import '../responsive_helper.dart';
import 'single_mode_screen.dart';
import 'pair_mode_screen.dart';
import 'match_setup_wizard.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import '../rewarded_ad_helper.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CRICKET PRO',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white10,
                  backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null
                      ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                      : null,
                  child: FirebaseAuth.instance.currentUser?.photoURL == null
                      ? const Icon(Icons.person, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Radial Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.4,
                colors: [
                  Color(0xFF141A29), // Subtle deep slate blue/navy center
                  Color(0xFF07090F), // Fade to pitch black edges
                ],
              ),
            ),
          ),

          // Glowing background elements
          Positioned(
            top: 150,
            right: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.06),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: const Text(
                          'SELECT GAME MODE',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: Colors.white54,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 450.ms)
                        .slideY(begin: -0.2, end: 0),
                      ),
                      const SizedBox(height: 24),

                      Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        alignment: WrapAlignment.center,
                        children: [
                          // Single Mode Button Card
                          SizedBox(
                            width: ResponsiveHelper.getValue(context, defaultVal: double.infinity, medium: 320.0, large: 320.0, extraLarge: 320.0),
                            child: _buildModeCard(
                              title: 'SINGLE MODE',
                              subtitle: 'Perfect for 1v1 challenges or individual player practice. Quick & direct scoring.',
                              icon: Icons.person_rounded,
                              accentColor: primaryColor,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, a, b) => const SingleModeScreen(),
                                    transitionsBuilder: (context, a, b, child) =>
                                        FadeTransition(opacity: a, child: child),
                                  ),
                                );
                              },
                            ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1, end: 0),
                          ),

                          // Pair Mode Button Card
                          SizedBox(
                            width: ResponsiveHelper.getValue(context, defaultVal: double.infinity, medium: 320.0, large: 320.0, extraLarge: 320.0),
                            child: _buildModeCard(
                              title: 'PAIR MODE',
                              subtitle: 'Track statistics in batsman pairs (e.g. partnership scoring, backyard rule systems).',
                              icon: Icons.people_rounded,
                              accentColor: secondaryColor,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, a, b) => const PairModeScreen(),
                                    transitionsBuilder: (context, a, b, child) =>
                                        FadeTransition(opacity: a, child: child),
                                  ),
                                );
                              },
                            ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0),
                          ),

                          // Team Mode Button Card
                          SizedBox(
                            width: ResponsiveHelper.getValue(context, defaultVal: double.infinity, medium: 320.0, large: 320.0, extraLarge: 320.0),
                            child: _buildModeCard(
                              title: 'TEAM MODE',
                              subtitle: 'Classic 11v11 match play. Set custom roster lists, captains, and track full overs.',
                              icon: Icons.groups_rounded,
                              accentColor: const Color(0xFFFFDF7A), // Shiny highlight gold
                              onTap: () {
                                RewardedAdHelper.showAd(
                                  onComplete: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, a, b) => const MatchSetupWizard(),
                                        transitionsBuilder: (context, a, b, child) =>
                                            FadeTransition(opacity: a, child: child),
                                      ),
                                    );
                                  },
                                );
                              },
                            ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),
                          ),
                        ],
                      ),

                      const SizedBox(height: 36),

                      Center(
                        child: const Text(
                          'Choose a game mode to start scoring',
                          style: TextStyle(
                            color: Colors.white30,
                            letterSpacing: 1.2,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ).animate().fadeIn(delay: 600.ms),
                      ),
                      const SizedBox(height: 24),
                      
                      Center(
                        child: SizedBox(
                          width: ResponsiveHelper.getValue(context, defaultVal: double.infinity, medium: 200.0, large: 200.0, extraLarge: 200.0),
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.04),
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.ads_click, size: 16),
                            label: const Text('SHOW AD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            onPressed: () {
                              RewardedAdHelper.showAd();
                            },
                          ),
                        ).animate().fadeIn(delay: 700.ms),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: 24,
        blur: 20,
        padding: const EdgeInsets.all(20),
        borderColor: accentColor,
        borderOpacity: 0.15,
        backgroundOpacity: 0.04,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
              ),
              child: Icon(
                icon,
                size: 32,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(color: accentColor.withOpacity(0.3), blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white24,
            ),
          ],
        ),
      ),
    );
  }

  void _showModeComingSoonDialog({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161D29),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: accentColor.withOpacity(0.3), width: 1.5),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: accentColor, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Rules & setup will be ready soon!',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'GOT IT',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ],
        );
      },
    );
  }
}
