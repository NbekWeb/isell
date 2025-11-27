import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import '../services/user_service.dart';

class SplashScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeUpdate;
  
  const SplashScreen({super.key, this.onThemeUpdate});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  ThemeMode _themeMode = ThemeMode.system;
  bool _isThemeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeAnimations();
    _startSplashSequence();
  }

  Future<void> _loadTheme() async {
    final themeMode = await ThemeService.getThemeMode();
    if (mounted) {
      setState(() {
        _themeMode = themeMode;
        _isThemeLoaded = true;
      });
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );
  }

  void _startSplashSequence() async {
    await _animationController.forward();

    // Check for access token and fetch user data if available
    await _checkAuthAndFetchUser();

    // Animation is 2 seconds, navigate immediately after
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _checkAuthAndFetchUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      
      print('🔍 Splash - Checking access token: ${accessToken != null ? "Found" : "Not found"}');
      
      if (accessToken != null && accessToken.isNotEmpty) {
        print('✅ Access token found, fetching user data...');
        
        // Fetch current user data from API
        final result = await UserService.getCurrentUser();
        
        if (result != null && result['success'] == true) {
          print('✅ User data fetched successfully in splash');
          print('📋 User: ${result['data']}');
        } else {
          print('❌ Failed to fetch user data: ${result?['error']}');
          // Clear invalid token
          await prefs.remove('accessToken');
          await prefs.remove('refreshToken');
        }
      } else {
        print('ℹ️ No access token found, user not logged in');
      }
    } catch (e) {
      print('❌ Error in splash auth check: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    if (!_isThemeLoaded) {
      // Default to system brightness while loading
      final brightness = MediaQuery.of(context).platformBrightness;
      return brightness == Brightness.light
          ? const Color(0xFFEBEBEB)
          : const Color(0xFF111111);
    }
    
    // Determine actual brightness based on theme mode
    Brightness brightness;
    switch (_themeMode) {
      case ThemeMode.light:
        brightness = Brightness.light;
        break;
      case ThemeMode.dark:
        brightness = Brightness.dark;
        break;
      case ThemeMode.system:
        brightness = MediaQuery.of(context).platformBrightness;
        break;
    }
    
    return brightness == Brightness.light
        ? const Color(0xFFEBEBEB) // Light theme background
        : const Color(0xFF111111); // Dark theme background
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Container(
        decoration: BoxDecoration(color: _backgroundColor),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 90.h,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20.r),
                          child: Image.asset(
                            'assets/img/logo.png',
                            height: 90.h,
                            width: null,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
