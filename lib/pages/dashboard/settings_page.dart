import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/theme_service.dart';
import '../../services/myid_service.dart';
import '../../services/user_service.dart';
// import '../../services/api_service.dart'; // TODO: Uncomment when backend is ready
import '../../widgets/custom_toast.dart';
import '../phone_input_page.dart';
import '../profile_page.dart';
import 'company_addresses_page.dart';

class SettingsPage extends StatefulWidget {
  final Function(ThemeMode)? onThemeUpdate;
  
  const SettingsPage({super.key, this.onThemeUpdate});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ThemeMode _currentTheme = ThemeMode.system;
  bool _pushNotificationsEnabled = true;
  bool _isProcessingMyId = false;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _userData;
  PermissionStatus? _cameraPermissionStatus;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadPushNotifications();
    _checkAuthStatus();
    _checkCameraPermission();
    
    // Test token status on page load
    UserService.testTokenStatus();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    setState(() {
      _cameraPermissionStatus = status;
    });
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    
    if (token != null && token.isNotEmpty) {
      // Load cached user data first
      final cachedData = await UserService.getCachedUserData();
      
      setState(() {
        _isLoggedIn = true;
        _userData = cachedData;
      });
      
      // Try to fetch fresh user data
      final result = await UserService.getCurrentUser();
      if (result != null && result['success'] == true) {
        setState(() {
          _userData = result['data'];
        });
      }
    } else {
      setState(() {
        _isLoggedIn = false;
        _userData = null;
      });
    }
  }

  Future<void> _loadTheme() async {
    final themeMode = await ThemeService.getThemeMode();
    setState(() {
      _currentTheme = themeMode;
    });
  }

  Future<void> _loadPushNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotificationsEnabled = prefs.getBool('push_notifications_enabled') ?? true;
    });
  }

  Future<void> _togglePushNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications_enabled', value);
    setState(() {
      _pushNotificationsEnabled = value;
    });
  }

  Future<void> _toggleTheme(bool isCurrentlyDark) async {
    // Haqiqiy ekrandagi temaga qarab toggle qilamiz
    final newTheme = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;

    debugPrint('🎨 Theme toggle: ${isCurrentlyDark ? "dark" : "light"} -> $newTheme');

    await ThemeService.setThemeMode(newTheme);
    setState(() {
      _currentTheme = newTheme;
    });

    if (widget.onThemeUpdate != null) {
      widget.onThemeUpdate!(newTheme);
      debugPrint('🎨 Theme update callback called');
    }
  }

  Future<void> _handleLogin() async {
    // Phone input page-ga o'tish
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PhoneInputPage(),
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      print('🔄 Starting logout process...');
      
      // Clear all user data and tokens
      await UserService.clearUserData();
      
      // Update UI state
      setState(() {
        _isLoggedIn = false;
        _userData = null;
      });
      
      print('✅ Logout completed successfully');
      print('📋 UI State: _isLoggedIn = $_isLoggedIn, _userData = $_userData');
      
      CustomToast.show(
        context,
        message: 'Вы вышли из системы',
        isSuccess: true,
      );
      
      // Refresh auth status to double-check
      await _checkAuthStatus();
      
    } catch (e) {
      print('❌ Error during logout: $e');
      
      CustomToast.show(
        context,
        message: 'Ошибка при выходе из системы',
        isSuccess: false,
      );
    }
  }

  String _getUserDisplayName() {
    if (_userData == null) return 'Пользователь';
    
    final firstName = _userData!['first_name']?.toString() ?? '';
    final lastName = _userData!['last_name']?.toString() ?? '';
    
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    }
    
    return 'Пользователь';
  }

  String _getUserPhone() {
    if (_userData == null) return 'Нет данных';
    
    final phone = _userData!['phone_number']?.toString() ?? '';
    if (phone.isNotEmpty) {
      // Format phone number: 998770580502 -> +998 77 058 05 02
      if (phone.length >= 12 && phone.startsWith('998')) {
        return '+${phone.substring(0, 3)} ${phone.substring(3, 5)} ${phone.substring(5, 8)} ${phone.substring(8, 10)} ${phone.substring(10)}';
      }
      return '+$phone';
    }
    
    return 'Нет данных';
  }

  Future<void> _requestCameraPermission() async {
    try {
      print('🔵 Requesting camera permission...');
      print('📱 Platform: ${Theme.of(context).platform}');
      
      // Check current status first
      final cameraStatus = await Permission.camera.status;
      print('   - Current cameraStatus: $cameraStatus');
      print('   - isGranted: ${cameraStatus.isGranted}');
      print('   - isDenied: ${cameraStatus.isDenied}');
      print('   - isPermanentlyDenied: ${cameraStatus.isPermanentlyDenied}');
      print('   - isLimited: ${cameraStatus.isLimited}');
      print('   - isRestricted: ${cameraStatus.isRestricted}');
      
      if (cameraStatus.isGranted) {
        if (mounted) {
          setState(() {
            _cameraPermissionStatus = cameraStatus;
          });
          CustomToast.show(
            context,
            message: 'Доступ к камере уже разрешен',
            isSuccess: true,
          );
        }
        return;
      }
      
      if (cameraStatus.isPermanentlyDenied) {
        print('❌ Camera permission permanently denied, opening settings...');
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Доступ к камере требуется'),
                content: const Text(
                  'Для работы приложения требуется доступ к камере. Пожалуйста, разрешите доступ к камере в настройках приложения.\n\nЕсли диалог разрешения не появляется, убедитесь, что:\n1. Приложение пересобрано после добавления разрешения\n2. Вы используете реальное устройство (не симулятор)\n3. В Info.plist добавлен ключ NSCameraUsageDescription',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await openAppSettings();
                    },
                    child: const Text('Настройки'),
                  ),
                ],
              );
            },
          );
        }
        return;
      }
      
      if (cameraStatus.isRestricted) {
        print('⚠️ Camera permission is restricted by system');
        if (mounted) {
          CustomToast.show(
            context,
            message: 'Доступ к камере ограничен системой',
            isSuccess: false,
          );
        }
        return;
      }
      
      print('⚠️ Camera permission not granted, requesting...');
      print('   - Requesting permission dialog should appear now...');
      
      // Request camera permission - this should show the system dialog
      final requestResult = await Permission.camera.request();
      print('   - requestResult: $requestResult');
      print('   - requestResult.isGranted: ${requestResult.isGranted}');
      print('   - requestResult.isDenied: ${requestResult.isDenied}');
      print('   - requestResult.isPermanentlyDenied: ${requestResult.isPermanentlyDenied}');
      
      // Update permission status
      if (mounted) {
        setState(() {
          _cameraPermissionStatus = requestResult;
        });
      }
      
      // Re-check status after request
      final newStatus = await Permission.camera.status;
      print('   - New status after request: $newStatus');
      
      // Check if permission became permanently denied (iOS remembers previous denial)
      if (requestResult.isPermanentlyDenied || newStatus.isPermanentlyDenied) {
        print('❌ Camera permission permanently denied - iOS remembers previous denial');
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Доступ к камере требуется'),
                content: const Text(
                  'iOS запомнил предыдущий отказ в доступе к камере. Пожалуйста:\n\n1. Удалите приложение полностью\n2. Перезапустите устройство (рекомендуется)\n3. Установите приложение заново\n\nИли откройте Настройки и разрешите доступ к камере вручную.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await openAppSettings();
                    },
                    child: const Text('Настройки'),
                  ),
                ],
              );
            },
          );
        }
      } else if (requestResult.isGranted || newStatus.isGranted) {
        print('✅ Camera permission granted');
        if (mounted) {
          CustomToast.show(
            context,
            message: 'Доступ к камере разрешен',
            isSuccess: true,
          );
        }
      } else if (requestResult.isDenied || newStatus.isDenied) {
        print('❌ Camera permission denied');
        if (mounted) {
          CustomToast.show(
            context,
            message: 'Доступ к камере отклонен. Если диалог не появился, удалите приложение и установите заново.',
            isSuccess: false,
          );
        }
      } else {
        print('❌ Camera permission permanently denied');
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Доступ к камере требуется'),
                content: const Text(
                  'Для работы приложения требуется доступ к камере. Пожалуйста, разрешите доступ к камере в настройках приложения.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await openAppSettings();
                    },
                    child: const Text('Настройки'),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error requesting camera permission: $e');
      print('📋 Stack trace: $stackTrace');
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Ошибка при запросе доступа к камере: ${e.toString()}',
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _handleMyIdAuthentication() async {
    if (_isProcessingMyId) {
      return;
    }

    setState(() {
      _isProcessingMyId = true;
    });

    try {
      // Step 0: Check and request camera permission first
      print('🔵 Step 0: Checking camera permission...');
      final cameraStatus = await Permission.camera.status;
      print('   - cameraStatus: $cameraStatus');
      
      if (!cameraStatus.isGranted) {
        // Check if permission is permanently denied
        if (cameraStatus.isPermanentlyDenied) {
          print('❌ Camera permission permanently denied, opening settings...');
          setState(() {
            _isProcessingMyId = false;
          });
          
          // Show dialog to open settings
          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Доступ к камере требуется'),
                  content: const Text(
                    'Для работы MyID требуется доступ к камере. Пожалуйста, разрешите доступ к камере в настройках приложения.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await openAppSettings();
                      },
                      child: const Text('Настройки'),
                    ),
                  ],
                );
              },
            );
          }
          return;
        }
        
        print('⚠️ Camera permission not granted, requesting...');
        // Request camera permission
        final requestResult = await Permission.camera.request();
        print('   - requestResult: $requestResult');
        
        if (!requestResult.isGranted) {
          print('❌ Camera permission denied');
          setState(() {
            _isProcessingMyId = false;
          });
          
          // Show dialog to open settings
          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Доступ к камере требуется'),
                  content: const Text(
                    'Для верификации через MyID требуется доступ к камере. Пожалуйста, разрешите доступ к камере в настройках приложения.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await openAppSettings();
                      },
                      child: const Text('Настройки'),
                    ),
                  ],
                );
              },
            );
          }
          return;
        }
        
        print('✅ Camera permission granted');
      } else {
        print('✅ Camera permission already granted');
      }

      // Step 1: Get session ID from MyID API directly
      print('🔵 Step 1: Getting session ID from MyID API...');
      String sessionId;

      // Option 1: From YOUR backend (commented out)
      // try {
      //   final response = await ApiService.request(
      //     url: 'accounts/myid/session/',
      //     method: 'POST',
      //     data: {
      //       'phone_number': '998770580502', // Optional
      //       'birth_date': '2003-05-02', // Optional
      //       'pinfl': '50205035360010', // Optional
      //       'pass_data': 'AC2190972', // Optional
      //     },
      //   );
      //   if (response.data != null &&
      //       response.data['success'] == true &&
      //       response.data['data'] != null &&
      //       response.data['data']['session_id'] != null) {
      //     sessionId = response.data['data']['session_id'] as String;
      //     print('✅ Session ID obtained from backend: $sessionId');
      //   } else {
      //     throw Exception('Session ID not found in backend response');
      //   }
      // } catch (e) {
      //   print('⚠️ Backend endpoint not available. Using direct MyID API...');
      // }

      // Option 2: Directly from MyID API (using now)
      try {
        // All parameters are optional - SDK will ask user if not provided
        sessionId = await MyIdService.getSessionId(
          // phoneNumber: '998770580502', // Optional
          // birthDate: '2003-05-02', // Optional
          // pinfl: '50205035360010', // Optional
          // passData: 'AC2190972', // Optional
        );
        print('✅ Session ID obtained from MyID API: $sessionId');
      } catch (apiError) {
        print('❌ Failed to get session ID from MyID API: $apiError');
        throw Exception('Failed to get session ID from MyID API: ${apiError.toString()}');
      }

      // Step 2: Start MyID SDK with session_id from backend
      print('🚀 Step 2: Starting MyID SDK with session ID: $sessionId');
      print(
        '📸 SDK will open camera, capture image, and send to MyID servers for verification',
      );

      // Debug: Print session ID details
      print('🔍 Session ID details:');
      print('   - sessionId: $sessionId');
      print('   - sessionId length: ${sessionId.length}');
      print('   - clientHashId: ${MyIdService.clientHashId}');

      // Start SDK immediately - session expires quickly, no delay needed
      // Backend is on dev server, so use debug environment
      final result = await MyIdService.startAuthentication(
        sessionId: sessionId,
        clientHash: MyIdService.clientHash,
        clientHashId: MyIdService.clientHashId,
        environment: 'debug', // Backend is on dev server (http://192.81.218.80:6060)
        entryType: 'identification',
        locale: 'russian',
      );

      // Step 3: SDK returned code (image was captured and verified by MyID servers)
      if (result.code != null) {
        print('✅ Step 3: MyID SDK - Authentication successful');
        print('📋 Code received: ${result.code}');
        print('📸 Image: ${result.image != null ? "present" : "null"}');
        print('🔢 Comparison value: ${result.comparisonValue}');

        CustomToast.show(
          context,
          message: 'Авторизация успешна',
          isSuccess: true,
        );

        // Step 4: Show debug page with code and access token for backend testing
        print('📤 Step 4: Navigating to debug page...');
        try {
          // Get fresh access token for backend testing
          final accessToken = await MyIdService.getAccessToken();
          
          print('✅ Access token obtained for debug page');
          print('📋 Code: ${result.code}');
          print('🔑 Access Token: ${accessToken.substring(0, 20)}...');
          
          CustomToast.show(
            context,
            message: 'Авторизация успешна. Переход к отладочной странице...',
            isSuccess: true,
          );
          
          // Show success message
          CustomToast.show(
            context,
            message: 'MyID верификация успешна!',
            isSuccess: true,
          );
          
          // TODO: When backend is ready, replace debug page with actual user verification:
          // final userData = await MyIdService.getUserDataByCode(result.code!);
          // final verifyResponse = await ApiService.request(
          //   url: 'accounts/myid/verify/',
          //   method: 'POST',
          //   data: {
          //     'user_data': userData,
          //     'myid_code': result.code,
          //     'myid_image': result.image,
          //   },
          // );
          
        } catch (e) {
          print('❌ Error getting access token: $e');
          CustomToast.show(
            context,
            message: 'Ошибка при получении токена: ${e.toString()}',
            isSuccess: false,
          );
        }
      }
    } on MyIdException catch (e) {
      String errorMessage = 'Ошибка авторизации';
      bool isCameraPermissionError = false;

      // Handle specific error codes
      switch (e.code) {
        case '102':
        case 'CAMERA_PERMISSION_DENIED':
          errorMessage = 'Доступ к камере запрещен';
          isCameraPermissionError = true;
          break;
        case '103':
          errorMessage = 'Ошибка при получении данных';
          break;
        case '122':
          errorMessage = 'Пользователь заблокирован';
          break;
        case 'USER_EXITED':
          errorMessage = 'Авторизация отменена';
          break;
        default:
          errorMessage = e.message;
          // Check if it's a camera permission error by message
          if (e.message.toLowerCase().contains('камера') || 
              e.message.toLowerCase().contains('camera') ||
              e.code == 'CAMERA_PERMISSION_DENIED') {
            isCameraPermissionError = true;
          }
      }

      // If it's a camera permission error, show dialog to open settings
      if (isCameraPermissionError && mounted) {
        // Check current permission status
        final cameraStatus = await Permission.camera.status;
        
        if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
          // Show dialog to open settings
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Доступ к камере требуется'),
                content: const Text(
                  'Для работы MyID требуется доступ к камере. Пожалуйста, разрешите доступ к камере в настройках приложения.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await openAppSettings();
                    },
                    child: const Text('Настройки'),
                  ),
                ],
              );
            },
          );
        } else {
          CustomToast.show(context, message: errorMessage, isSuccess: false);
        }
      } else {
        CustomToast.show(context, message: errorMessage, isSuccess: false);
      }
    } catch (e) {
      print('❌ Error: $e');
      CustomToast.show(
        context,
        message: 'Произошла ошибка: ${e.toString()}',
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingMyId = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Haqiqiy aktiv temani kontekstdan olamiz
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? (Colors.grey[400] ?? Colors.grey) : (Colors.grey[600] ?? Colors.grey);
    final dividerColor = isDark ? (Colors.grey[800] ?? Colors.grey) : (Colors.grey[300] ?? Colors.grey);
    final iconBgColor = isDark ? const Color(0xFF374151) : (Colors.grey[200] ?? Colors.grey);
    final iconColor = isDark ? const Color(0xFF9CA3AF) : Colors.black87;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),
            
            // User Profile Header (faqat login bo'lsa ko'rinadi)
            if (_isLoggedIn) ...[
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF374151) : const Color(0xFFDBEAFE),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/svg/user.svg',
                          width: 24,
                          height: 24,
                          colorFilter: ColorFilter.mode(
                            isDark ? const Color(0xFF9CA3AF) : const Color(0xFF2563EB),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getUserDisplayName(),
                            style: GoogleFonts.poppins(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _getUserPhone(),
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
            ],
            // User Profile Settings (faqat login bo'lsa ko'rinadi)
            if (_isLoggedIn) ...[
              Container(
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  children: [
                    _buildSettingItem(
                      icon: 'assets/svg/user.svg',
                      title: 'Профиль',
                      subtitle: 'Личные данные и настройки',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfilePage(),
                          ),
                        );
                      },
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                      iconBgColor: iconBgColor,
                      iconColor: iconColor,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
            ],

            // MyID Authentication Button (for logged in users)
            if (_isLoggedIn) ...[
              Container(
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isProcessingMyId ? null : _handleMyIdAuthentication,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16.w),
                        child: Row(
                          children: [
                            Container(
                              width: 40.w,
                              height: 40.w,
                              decoration: BoxDecoration(
                                color: iconBgColor,
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Center(
                                child: _isProcessingMyId
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            const Color(0xFF1B7EFF),
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.verified_user,
                                        size: 20,
                                        color: const Color(0xFF1B7EFF),
                                      ),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MyID верификация',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    _isProcessingMyId
                                        ? 'Обработка...'
                                        : 'Верификация через MyID',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.sp,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!_isProcessingMyId)
                              Icon(
                                Icons.chevron_right,
                                color: subtitleColor,
                                size: 24.w,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
            ],

            // Camera Permission Button (Always visible)
            Container(
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _requestCameraPermission,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        children: [
                          Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: _cameraPermissionStatus?.isGranted == true
                                    ? Colors.green
                                    : const Color(0xFF1B7EFF),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Доступ к камере',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  _cameraPermissionStatus?.isGranted == true
                                      ? 'Разрешение предоставлено'
                                      : _cameraPermissionStatus?.isPermanentlyDenied == true
                                          ? 'Разрешение отклонено. Откройте настройки'
                                          : 'Запросить разрешение на использование камеры',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.sp,
                                    color: _cameraPermissionStatus?.isGranted == true
                                        ? Colors.green
                                        : subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: subtitleColor,
                            size: 24.w,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Push Notifications, Help and Addresses - Always visible (grouped together)
            Container(
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  // Push Notifications Toggle
                  Container(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/svg/ring.svg',
                              width: 20,
                              height: 20,
                              colorFilter: ColorFilter.mode(
                                iconColor,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Push-уведомления',
                                style: GoogleFonts.poppins(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                _pushNotificationsEnabled ? 'Включено' : 'Выключено',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _pushNotificationsEnabled,
                          onChanged: _togglePushNotifications,
                          activeColor: const Color(0xFF1B7EFF),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: dividerColor,
                  ),
                  // Help
                  _buildSettingItem(
                    icon: 'assets/svg/question.svg',
                    title: 'Помощь',
                    subtitle: 'FAQ и служба поддержки',
                    onTap: () {},
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    iconBgColor: iconBgColor,
                    iconColor: iconColor,
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: dividerColor,
                  ),
                  // Addresses
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CompanyAddressesPage(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        children: [
                          Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/svg/doc.svg',
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  iconColor,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Адреса',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Адреса компании',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.sp,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: subtitleColor,
                            size: 24.w,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            
            // Dark Theme Toggle
            GestureDetector(
              onTap: () => _toggleTheme(isDark),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Stack(
                  children: [
                    // Icon on the left
                    Positioned(
                      left: 16.w,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SvgPicture.asset(
                          isDark ? 'assets/svg/moon.svg' : 'assets/svg/moonl.svg',
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            textColor,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    // Text centered
                    Center(
                      child: Text(
                        // Matnni real aktiv tema holatiga qarab ko'rsatamiz
                        // (ThemeMode.system bo'lganda ham to'g'ri ishlashi uchun)
                        isDark ? 'Тёмная тема' : 'Светлая тема',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),
            
            // Login/Logout Button
            GestureDetector(
              onTap: _isLoggedIn ? _handleLogout : _handleLogin,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Stack(
                  children: [
                    // Icon on the left
                    Positioned(
                      left: 16.w,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SvgPicture.asset(
                          _isLoggedIn ? 'assets/svg/logout.svg' : 'assets/svg/user.svg',
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            _isLoggedIn 
                                ? (isDark ? const Color(0xFFEF4444) : Colors.red)
                                : (isDark ? const Color(0xFF2196F3) : const Color(0xFF2196F3)),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    // Text centered
                    Center(
                      child: Text(
                        _isLoggedIn ? 'Выйти' : 'Войти',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: _isLoggedIn 
                              ? (isDark ? const Color(0xFFEF4444) : Colors.red)
                              : (isDark ? const Color(0xFF2196F3) : const Color(0xFF2196F3)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color textColor,
    required Color subtitleColor,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Center(
                child: SvgPicture.asset(
                  icon,
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    iconColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: subtitleColor,
              size: 24.w,
            ),
          ],
        ),
      ),
    );
  }
}

