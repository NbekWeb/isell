import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';
import '../services/myid_service.dart';
import '../services/user_service.dart';
import '../widgets/custom_toast.dart';

class SmsCodePage extends StatefulWidget {
  final String phoneNumber;

  const SmsCodePage({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<SmsCodePage> createState() => _SmsCodePageState();
}

class _SmsCodePageState extends State<SmsCodePage> {
  final List<TextEditingController> _controllers = List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    // Focus on first input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onCodeChanged(String value, int index) {
    if (value.isNotEmpty) {
      // Move to next input
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // All inputs filled, verify code
        _verifyCode();
      }
    }
  }

  void _onCodeDeleted(int index) {
      if (index > 0) {
      // Move to previous input
        _focusNodes[index - 1].requestFocus();
      }
    }

  String _getEnteredCode() {
    return _controllers.map((controller) => controller.text).join();
  }

  bool _isCodeComplete() {
    return _controllers.every((controller) => controller.text.isNotEmpty);
  }

  Future<void> _verifyCode() async {
    if (!_isCodeComplete()) {
      CustomToast.show(
        context,
        message: 'Введите полный код',
        isSuccess: false,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final code = _getEnteredCode();
      final result = await AuthService.verifyCode(
        phoneNumber: widget.phoneNumber,
        code: code,
      );

      if (result != null && result['success'] == true) {
        final responseData = result['data'];
        
        // Check if data is empty - then MyID verification is required
        if (responseData == null || 
            (responseData is Map && responseData.isEmpty) ||
            (responseData is Map && responseData['data'] != null && (responseData['data'] as Map).isEmpty)) {
          
          CustomToast.show(
            context,
            message: 'SMS код подтвержден. Запуск MyID верификации...',
            isSuccess: true,
          );
          
          // Start MyID verification process
          _startMyIdVerification();
        } else {
          // Full authentication completed - data contains tokens
          // Save tokens and user data
          await _saveTokensFromResponse({'data': responseData});
          
          // Fetch fresh user data from API
          final userResult = await UserService.getCurrentUser();
          if (userResult != null && userResult['success'] == true) {
            print('✅ User data fetched after SMS verification');
          }
          
          CustomToast.show(
            context,
            message: 'Авторизация успешна!',
            isSuccess: true,
          );

          // Navigate to main layout (named route so theme callback works)
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
        }
      } else {
        final errorMessage = result?['error'] ?? 'Неверный код';
        CustomToast.show(
          context,
          message: errorMessage,
          isSuccess: false,
        );
        
        // Clear inputs and focus first input
        _clearInputs();
      }
    } catch (e) {
      CustomToast.show(
        context,
        message: 'Произошла ошибка при проверке кода',
        isSuccess: false,
      );
      _clearInputs();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearInputs() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _resendCode() async {
    if (_isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final result = await AuthService.resendCode(
        phoneNumber: widget.phoneNumber,
      );

      if (result != null && result['success'] == true) {
        CustomToast.show(
          context,
          message: 'Код отправлен повторно',
          isSuccess: true,
        );
        _clearInputs();
      } else {
        final errorMessage = result?['error'] ?? 'Ошибка при повторной отправке кода';
        CustomToast.show(
          context,
          message: errorMessage,
          isSuccess: false,
        );
      }
    } catch (e) {
      CustomToast.show(
        context,
        message: 'Произошла ошибка при повторной отправке',
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _startMyIdVerification() async {
    try {
      // Step 1: Check camera permission first
      final cameraStatus = await Permission.camera.status;
      
      if (!cameraStatus.isGranted) {
        // Request camera permission
        final requestResult = await Permission.camera.request();
        
        if (!requestResult.isGranted) {
          // Permission denied - SMS is correct but camera permission not granted
          // Navigate to home page instead of staying on SMS page
          CustomToast.show(
            context,
            message: 'Камера разрешение требуется для MyID. Переход на главную страницу...',
            isSuccess: false,
          );
          
          // Navigate to home page
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          }
          return;
        }
      }
      
      // Step 2: Get session ID from MyID API
      String sessionId = await MyIdService.getSessionId();

      // Step 3: Start MyID SDK authentication
      // Add a small delay to ensure permission is fully processed
      await Future.delayed(const Duration(milliseconds: 300));
      
      final result = await MyIdService.startAuthentication(
        sessionId: sessionId,
        clientHash: MyIdService.clientHash,
        clientHashId: MyIdService.clientHashId,
        environment: 'debug',
        entryType: 'identification',
        locale: 'russian',
      );

      // Step 4: Handle MyID SDK result
      if (result.code != null) {
        
        // Step 5: Call backend MyID verify API
        await _verifyMyIdWithBackend(result.code!, result.image, result.comparisonValue);
        
      } else {
        CustomToast.show(
          context,
          message: 'MyID верификация отменена',
          isSuccess: false,
        );
      }
    } on MyIdException catch (e) {
      // Handle specific MyID exceptions
      if (e.code == 'CAMERA_PERMISSION_DENIED') {
        // Camera permission was denied during SDK start
        // Check if we can request it again
        final cameraStatus = await Permission.camera.status;
        
        if (cameraStatus.isPermanentlyDenied) {
          // Permission permanently denied - go to home page
          CustomToast.show(
            context,
            message: 'Камера разрешение требуется. Переход на главную страницу...',
            isSuccess: false,
          );
          
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          }
        } else {
          // Permission can be requested - wait a bit and retry
          CustomToast.show(
            context,
            message: 'Запрос разрешения камеры...',
            isSuccess: true,
          );
          
          // Wait for permission to be granted and retry
          await Future.delayed(const Duration(milliseconds: 500));
          await _startMyIdVerification();
        }
      } else {
        CustomToast.show(
          context,
          message: 'Ошибка MyID верификации: ${e.message}',
          isSuccess: false,
        );
      }
    } catch (e) {
      // Check if it's a PlatformException with CAMERA_PERMISSION_DENIED
      if (e is PlatformException && e.code == 'CAMERA_PERMISSION_DENIED') {
        // Wait a bit for permission to be processed, then retry
        CustomToast.show(
          context,
          message: 'Ожидание разрешения камеры...',
          isSuccess: true,
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Check permission status and retry
        final cameraStatus = await Permission.camera.status;
        if (cameraStatus.isGranted) {
          // Permission granted, retry
          await _startMyIdVerification();
        } else if (cameraStatus.isPermanentlyDenied) {
          // Permission permanently denied - go to home page
          CustomToast.show(
            context,
            message: 'Камера разрешение требуется. Переход на главную страницу...',
            isSuccess: false,
          );
          
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          }
        } else {
          // Try requesting again
          final requestResult = await Permission.camera.request();
          if (requestResult.isGranted) {
            await _startMyIdVerification();
          } else {
            // Still denied - go to home page
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/home',
                (route) => false,
              );
            }
          }
        }
      } else {
      CustomToast.show(
        context,
        message: 'Ошибка MyID верификации: ${e.toString()}',
        isSuccess: false,
      );
      }
    }
  }

  Future<void> _verifyMyIdWithBackend(String code, String? image, double? comparisonValue) async {
    try {
      
      // Get access token for the API call
      final accessToken = await MyIdService.getAccessToken();
      
      // Call the MyID verify endpoint
      final response = await MyIdService.verifyMyIdWithBackend(
        code: code,
        token: accessToken,
        phoneNumber: widget.phoneNumber,
      );
      
      
      if (response != null && response['success'] == true) {
        // Success - save tokens and user data
        await _saveTokensFromResponse(response);
        
        CustomToast.show(
          context,
          message: 'MyID верификация успешна! Авторизация завершена',
          isSuccess: true,
        );
        
        // Navigate to main layout (with bottom navigation, using named route)
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
      } else {
        // Failure - retry MyID verification
        final errorMessage = response?['error'] ?? 'Ошибка верификации MyID';
        print('❌ MyID verification failed: $errorMessage');
        
        CustomToast.show(
          context,
          message: 'Ошибка верификации. Повторная попытка...',
          isSuccess: false,
        );
        
        // Retry MyID verification process
        await Future.delayed(const Duration(seconds: 1));
        _startMyIdVerification();
      }
    } catch (e) {
      print('❌ Error in backend MyID verification: $e');
      CustomToast.show(
        context,
        message: 'Ошибка сервера. Повторная попытка...',
        isSuccess: false,
      );
      
      // Retry MyID verification on error
      await Future.delayed(const Duration(seconds: 1));
      _startMyIdVerification();
    }
  }

  Future<void> _saveTokensFromResponse(Map<String, dynamic> response) async {
    try {
      final data = response['data'];
      if (data is Map) {
        // Save tokens
        if (data.containsKey('tokens') && data['tokens'] is Map) {
          final tokens = data['tokens'] as Map;
          final prefs = await SharedPreferences.getInstance();
          
          if (tokens.containsKey('access')) {
            await prefs.setString('accessToken', tokens['access'].toString());
            print('✅ Access token saved: ${tokens['access'].toString().substring(0, 20)}...');
        }
          
          if (tokens.containsKey('refresh')) {
            await prefs.setString('refreshToken', tokens['refresh'].toString());
            print('✅ Refresh token saved');
          }
        }
        
        // Save user data
        if (data.containsKey('user') && data['user'] is Map) {
          final userData = data['user'] as Map;
          await UserService.saveUserData(userData);
      }
      }
    } catch (e) {
      print('❌ Error saving tokens from response: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final inputBorderColor = isDark ? Colors.grey[700] : Colors.grey[300];
    final inputFillColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: textColor,
                    ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Image.asset(
                          'assets/img/logo.png',
          height: 32.h,
                        ),
        centerTitle: true,
                ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 40.h),
            
            // Title
                      Text(
                        'Введите отправленной код',
              textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                fontSize: 24.sp,
                          fontWeight: FontWeight.w600,
                color: textColor,
                        ),
                      ),
            
                      SizedBox(height: 8.h),
            
            // Subtitle
                      Text(
                        'Мы отправляем смс код',
              textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                color: subtitleColor,
                        ),
                      ),
            
            SizedBox(height: 40.h),
            
            // SMS Code Input Fields
                      Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(4, (index) {
                return Container(
                  width: 60.w,
                  height: 60.h,
                  decoration: BoxDecoration(
                    color: inputFillColor,
                    border: Border.all(
                      color: inputBorderColor ?? Colors.grey,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: TextFormField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(1),
                              ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                                  ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        _onCodeChanged(value, index);
                      } else {
                        // Handle backspace - move to previous input
                        if (index > 0) {
                          _onCodeDeleted(index);
                        }
                      }
                    },
                              onTap: () {
                      // Clear current input when tapped
                      _controllers[index].clear();
                              },
                            ),
                          );
                        }),
                      ),
            
            SizedBox(height: 40.h),
            
            // Continue Button
                      SizedBox(
                        width: double.infinity,
                        height: 50.h,
                        child: ElevatedButton(
                onPressed: _isLoading || !_isCodeComplete() ? null : _verifyCode,
                          style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B7EFF),
                  disabledBackgroundColor: isDark 
                      ? const Color(0xFF1B7EFF).withOpacity(0.5)
                      : Colors.grey[400],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                child: _isLoading
                    ? SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                            'Продолжить',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
            
            SizedBox(height: 24.h),
            
            // Resend Code Button
            Center(
              child: TextButton(
                onPressed: _isResending ? null : _resendCode,
                child: _isResending
                    ? SizedBox(
                        width: 16.w,
                        height: 16.h,
                        child: CircularProgressIndicator(
                          color: const Color(0xFF1B7EFF),
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Отправить код повторно',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          color: const Color(0xFF1B7EFF),
                          decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            
            const Spacer(),
            ],
        ),
      ),
    );
  }
}