import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'models/player.dart';
import 'models/match.dart';
import 'providers/cricket_provider.dart';
import 'screens/splash_screen.dart';
import 'rewarded_ad_helper.dart';
import 'package:device_preview/device_preview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await MobileAds.instance.initialize();
    RewardedAdHelper.loadAd();
  }

  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase initialization failed: $e');
  }
  await Hive.initFlutter();
  Hive.registerAdapter(PlayerAdapter());
  Hive.registerAdapter(MatchModelAdapter());
  await Hive.openBox<Player>('players');
  await Hive.openBox<MatchModel>('matches');
  if (kIsWeb) {
    runApp(
      DevicePreview(
        enabled: true,
        builder: (context) => const MyApp(),
      ),
    );
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryNeon = Color(0xFF00E5FF);
    const darkBg = Color(0xFF0A0F1D);
    const darkSurface = Color(0xFF151A2E);

    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => CricketProvider())],
      child: MaterialApp(
        builder: kIsWeb ? DevicePreview.appBuilder : null,
        locale: kIsWeb ? DevicePreview.locale(context) : null,
        title: 'Cricket Score App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: darkBg,
          primaryColor: primaryNeon,
          colorScheme: const ColorScheme.dark(
            primary: primaryNeon,
            secondary: Color(0xFFFF2E93), // Neon Magenta/Pink
            surface: darkSurface,
          ),
          textTheme: GoogleFonts.outfitTextTheme(
            ThemeData.dark().textTheme,
          ).apply(bodyColor: Colors.white, displayColor: Colors.white),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            color: darkSurface.withOpacity(0.6),
            elevation: 12,
            shadowColor: Colors.black.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryNeon,
              foregroundColor: const Color(0xFF0A0F1D),
              elevation: 8,
              splashFactory: InkSparkle.splashFactory,
              shadowColor: primaryNeon.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryNeon,
              side: const BorderSide(color: primaryNeon, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              splashFactory: InkSparkle.splashFactory,
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: primaryNeon,
            foregroundColor: const Color(0xFF0A0F1D),
            elevation: 12,
            splashColor: Colors.white.withOpacity(0.3),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: darkSurface.withOpacity(0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primaryNeon, width: 2),
            ),
            labelStyle: const TextStyle(color: Colors.white70),
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIconColor: Colors.white54,
            suffixIconColor: Colors.white54,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
