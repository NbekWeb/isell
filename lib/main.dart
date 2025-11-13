import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'components/main_layout.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Yandex MapKit with API key
  // API key is configured in AndroidManifest.xml and Info.plist
  // For now, we'll initialize it here if needed
  // await YandexMapkit.initMapkit(apiKey: '491a85a5-7445-4d5d-a419-84bda4ad6328');
  
  runApp(const ISellApp());
}

class ISellApp extends StatefulWidget {
  const ISellApp({super.key});

  @override
  State<ISellApp> createState() => _ISellAppState();
}

class _ISellAppState extends State<ISellApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeMode = await ThemeService.getThemeMode();
    setState(() {
      _themeMode = themeMode;
    });
    // Update status bar when theme is loaded
    _updateStatusBar(themeMode);
  }

  void _updateTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    // Update status bar immediately when theme changes
    _updateStatusBar(themeMode);
    // Also update after frame to ensure it's applied
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateStatusBar(themeMode);
    });
  }

  void _updateStatusBar(ThemeMode themeMode) {
    // Determine if dark theme should be used
    bool isDark;
    if (themeMode == ThemeMode.dark) {
      isDark = true;
    } else if (themeMode == ThemeMode.light) {
      isDark = false;
    } else {
      // System mode - use platform brightness
      isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        // Set status bar style based on theme - only update when theme actually changes
        // This is handled in _updateTheme and _loadTheme methods
        
        return MaterialApp(
          title: 'ISell',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
            fontFamily: GoogleFonts.poppins().fontFamily,
            textTheme: GoogleFonts.poppinsTextTheme(),
            scaffoldBackgroundColor: const Color(0xFFEBEBEB),
            brightness: Brightness.light,
            appBarTheme: const AppBarTheme(
              backgroundColor:  Color(0xFFEBEBEB),
              foregroundColor: Colors.black,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
            fontFamily: GoogleFonts.poppins().fontFamily,
            textTheme: GoogleFonts.poppinsTextTheme(),
            scaffoldBackgroundColor: const Color(0xFF1A1A1A),
            brightness: Brightness.dark,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          themeMode: _themeMode,
          home: SplashScreen(onThemeUpdate: _updateTheme),
          routes: {
            '/home': (context) => MainLayout(onThemeUpdate: _updateTheme),
          },
        );
      },
    );
  }
}