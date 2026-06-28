import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/cricket_provider.dart';
import '../widgets/glass_container.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $urlString');
    }
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Future<void> _logout(BuildContext context) async {
    // Show confirmation dialog before logging out
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
        ),
        title: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to logout? If you are a guest, all your local data will be permanently deleted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');

    if (context.mounted) {
      Provider.of<CricketProvider>(context, listen: false).clearData();
      Navigator.pop(context); // Pop loading dialog
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PROFILE',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                GlassContainer(
                  borderRadius: 32,
                  blur: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  borderColor: isGuest ? Colors.orangeAccent : primaryColor,
                  borderOpacity: 0.15,
                  backgroundOpacity: 0.04,
                  child: Column(
                    children: [
                      // Profile Avatar
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isGuest ? Colors.orangeAccent : primaryColor,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isGuest ? Colors.orangeAccent : primaryColor).withOpacity(0.15),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: Colors.white10,
                          backgroundImage: !isGuest && user.photoURL != null
                              ? NetworkImage(user.photoURL!)
                              : null,
                          child: isGuest || user.photoURL == null
                              ? Icon(
                                  Icons.person,
                                  size: 54,
                                  color: isGuest ? Colors.orangeAccent : primaryColor,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Name
                      Text(
                        isGuest ? 'Guest User' : (user.displayName ?? 'Unknown Name'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Email
                      Text(
                        isGuest ? 'guest@cricketpro.local' : (user.email ?? 'No email linked'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 28),

                      // Account Status Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: (isGuest ? Colors.orangeAccent : Colors.tealAccent).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (isGuest ? Colors.orangeAccent : Colors.tealAccent).withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          isGuest ? 'OFFLINE GUEST SESSION' : 'CONNECTED WITH GOOGLE',
                          style: TextStyle(
                            color: isGuest ? Colors.orangeAccent : Colors.tealAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                
                // Settings Options
                GlassContainer(
                  borderRadius: 24,
                  blur: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  borderColor: Colors.white24,
                  borderOpacity: 0.1,
                  backgroundOpacity: 0.05,
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        onTap: () => _launchURL('https://sites.google.com/view/cricketscoringapp'),
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      _buildSettingsTile(
                        icon: Icons.description_outlined,
                        title: 'Terms & Conditions',
                        onTap: () => _launchURL('https://sites.google.com/view/cricketscoringapp/terms-conditions'),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () => _logout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.08),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.4), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'LOGOUT',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
