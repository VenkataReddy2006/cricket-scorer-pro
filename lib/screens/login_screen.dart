import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../providers/cricket_provider.dart';
import '../widgets/glass_container.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Trigger the Google Authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // User cancelled the sign-in dialog
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase Auth
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final email = user.email ?? '';
        final name = user.displayName ?? '';

        // Try to authenticate with our node backend
        final response = await ApiService.googleLogin(email, name);

        final prefs = await SharedPreferences.getInstance();
        if (response['statusCode'] == 200 || response['statusCode'] == 201) {
          final token = response['body']['token'];
          await prefs.setString('auth_token', token);
          
          // Trigger sync since we logged in successfully to backend
          if (mounted) {
            Provider.of<CricketProvider>(context, listen: false).syncWithBackend();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainScreen()),
            );
          }
        } else {
          // Backend is down/unavailable - offline google mode is disabled.
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn().signOut();
          setState(() {
            _errorMessage = 'Internet connection is required to login with Google.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Firebase Google Sign-In failed.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google Sign-In failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loginAsGuest() async {
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Guest Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'You are logging in as a guest. All your matches and player data will be saved LOCALLY on this device only.\n\n'
          'If you log out or uninstall the app, your data will be permanently deleted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            child: const Text('CONTINUE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'guest');

    if (mounted) {
      // Clear any prior data to ensure a fresh guest session
      Provider.of<CricketProvider>(context, listen: false).clearData();
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      body: Stack(
        children: [
          // Background subtle gradients
          Container(
            color: const Color(0xFF0A0F1D),
          ),
          
          // Glowing Ambient Orbs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              key: const ValueKey('glowing_orb_top_left'),
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              key: const ValueKey('glowing_orb_bottom_right'),
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: secondaryColor.withOpacity(0.12),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: GlassContainer(
                  borderRadius: 32,
                  blur: 24,
                  borderOpacity: 0.1,
                  backgroundOpacity: 0.05,
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withOpacity(0.1),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.sports_cricket_rounded,
                          size: 64,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'CRICKET PRO',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(
                              color: primaryColor.withOpacity(0.4),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Login to sync your matches',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 36),

                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(),
                        )
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Colors.white.withOpacity(0.04),
                            ),
                            icon: Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                              height: 22,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.login,
                                color: Colors.white,
                              ),
                            ),
                            label: const Text(
                              'CONNECT WITH GOOGLE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 1.2,
                              ),
                            ),
                            onPressed: _isLoading ? null : _loginWithGoogle,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: _isLoading ? null : _loginAsGuest,
                          child: Text(
                            'Continue as Guest',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
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
}
