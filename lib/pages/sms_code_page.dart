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

class _SmsCodePageState extends State<SmsCodePage> with WidgetsBindingObserver {
  final List<TextEditingController> _controllers = List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  bool _isMyIdInProgress = false; // Track if MyID verification is in progress
  bool _waitingForPermissionFromSettings = false; // Track if we're waiting for permission from settings

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Focus on first input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app resumes from settings, check camera permission again
    if (state == AppLifecycleState.resumed && _waitingForPermissionFromSettings) {
      print('🔵 [SMS Code Page] App resumed, checking camera permission again...');
      _waitingForPermissionFromSettings = false;
      // Wait a bit for permission status to update
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          final cameraStatus = await Permission.camera.status;
          print('   - cameraStatus after resume: $cameraStatus');
          if (cameraStatus.isGranted) {
            print('✅ [SMS Code Page] Camera permission granted after returning from settings');
            // Permission granted, continue with MyID verification
            if (!_isMyIdInProgress) {
              await _startMyIdVerification();
            }
          } else {
            print('❌ [SMS Code Page] Camera permission still not granted');
            setState(() {
              _isMyIdInProgress = false;
            });
          }
        }
      });
    }
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
    // Clear current input
    _controllers[index].clear();
    // Move to previous input
    if (index > 0) {
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
    print('🔵 [SMS Code Page] _verifyCode called');
    print('   - phoneNumber: ${widget.phoneNumber}');
    
    if (!_isCodeComplete()) {
      print('⚠️ [SMS Code Page] Code not complete');
      CustomToast.show(
        context,
        message: 'Введите полный код',
        isSuccess: false,
      );
      return;
    }

    final code = _getEnteredCode();
    print('   - entered code: $code');
    print('   - setting _isLoading to true');
    
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔵 [SMS Code Page] Calling AuthService.verifyCode...');
      final result = await AuthService.verifyCode(
        phoneNumber: widget.phoneNumber,
        code: code,
      );

      print('📥 [SMS Code Page] AuthService.verifyCode response received');
      print('   - result: $result');
      print('   - result type: ${result.runtimeType}');

      if (result != null && result['success'] == true) {
        print('✅ [SMS Code Page] SMS code verification SUCCESS');
        final responseData = result['data'];
        print('   - responseData: $responseData');
        print('   - responseData type: ${responseData.runtimeType}');
        
        print('🔵 [SMS Code Page] Proceeding with MyID verification regardless of SMS response payload');
        CustomToast.show(
          context,
          message: 'SMS код подтвержден. Запуск MyID верификации...',
          isSuccess: true,
        );
        
        await _startMyIdVerification();
        print('   - _isMyIdInProgress after _startMyIdVerification: $_isMyIdInProgress');
      } else {
        print('❌ [SMS Code Page] SMS code verification FAILED');
        final errorMessage = result?['error'] ?? 'Неверный код';
        print('   - errorMessage: $errorMessage');
        
        CustomToast.show(
          context,
          message: errorMessage,
          isSuccess: false,
        );
        
        // Clear inputs and focus first input
        _clearInputs();
      }
    } catch (e, stackTrace) {
      print('❌ [SMS Code Page] ERROR in _verifyCode');
      print('   - error: $e');
      print('   - stackTrace: $stackTrace');
      
      CustomToast.show(
        context,
        message: 'Произошла ошибка при проверке кода',
        isSuccess: false,
      );
      _clearInputs();
    } finally {
      if (mounted) {
        print('🔵 [SMS Code Page] Setting _isLoading to false');
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
    print('🔵 [SMS Code Page] _startMyIdVerification called');
    print('   - _isMyIdInProgress before: $_isMyIdInProgress');
    
    // Prevent multiple simultaneous MyID verifications
    if (_isMyIdInProgress) {
      print('⚠️ [SMS Code Page] MyID verification already in progress, skipping...');
      return;
    }

    print('🔵 [SMS Code Page] Setting _isMyIdInProgress to true');
    setState(() {
      _isMyIdInProgress = true;
    });
    print('   - _isMyIdInProgress after setState: $_isMyIdInProgress');

    try {
      // Step 1: Check camera permission first
      print('🔵 [SMS Code Page] Step 1: Checking camera permission...');
      final cameraStatus = await Permission.camera.status;
      print('   - cameraStatus: $cameraStatus');
      
      if (!cameraStatus.isGranted) {
        // Check if permission is permanently denied
        if (cameraStatus.isPermanentlyDenied) {
          print('❌ [SMS Code Page] Camera permission permanently denied, opening settings...');
          setState(() {
            _isMyIdInProgress = false;
          });
          
          // Show dialog to open settings
          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Камера разрешение требуется'),
                  content: const Text(
                    'Для работы MyID требуется доступ к камере. Пожалуйста, разрешите доступ к камере в настройках приложения.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _isMyIdInProgress = false;
                        });
                      },
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        setState(() {
                          _waitingForPermissionFromSettings = true;
                          _isMyIdInProgress = false;
                        });
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
        
        print('⚠️ [SMS Code Page] Camera permission not granted, requesting...');
        // Request camera permission
        final requestResult = await Permission.camera.request();
        print('   - requestResult: $requestResult');
        
        if (!requestResult.isGranted) {
          print('❌ [SMS Code Page] Camera permission denied');
          // Permission denied - SMS is correct but camera permission not granted
          // Navigate to home page instead of staying on SMS page
          setState(() {
            _isMyIdInProgress = false;
          });
          
          // Show better error message
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
                        setState(() {
                          _waitingForPermissionFromSettings = true;
                          _isMyIdInProgress = false;
                        });
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
        print('✅ [SMS Code Page] Camera permission granted');
        
        // Wait a bit to ensure permission is fully processed (especially on iOS)
        print('⏳ [SMS Code Page] Waiting 500ms for permission to be fully processed...');
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        print('✅ [SMS Code Page] Camera permission already granted');
      }
      
      // Step 2: Get session ID from MyID API
      print('🔵 [SMS Code Page] Step 2: Getting session ID from MyID API...');
      String sessionId = await MyIdService.getSessionId();
      print('✅ [SMS Code Page] Session ID received: $sessionId');

      // Step 3: Start MyID SDK authentication
      // Permission is already granted and processed, proceed with SDK
      print('🔵 [SMS Code Page] Step 3: Starting MyID SDK authentication...');
      
      // Check if still mounted before starting MyID SDK
      if (!mounted) {
        print('⚠️ [SMS Code Page] Widget not mounted, stopping');
        setState(() {
          _isMyIdInProgress = false;
        });
        return;
      }
      
      print('🔵 [SMS Code Page] Starting MyID SDK authentication...');
      print('   - sessionId: $sessionId');
      print('   - clientHashId: ${MyIdService.clientHashId}');
      print('   - _isMyIdInProgress: $_isMyIdInProgress');
      
      final result = await MyIdService.startAuthentication(
        sessionId: sessionId,
        clientHash: MyIdService.clientHash,
        clientHashId: MyIdService.clientHashId,
        environment: 'debug',
        entryType: 'identification',
        locale: 'russian',
      );

      print('📥 [SMS Code Page] MyID SDK result received');
      print('   - result.code: ${result.code}');
      print('   - result.image: ${result.image != null ? "present" : "null"}');
      print('   - result.comparisonValue: ${result.comparisonValue}');

      // Step 4: Handle MyID SDK result
      if (result.code != null) {
        print('✅ [SMS Code Page] MyID SDK returned code, calling backend verify...');
        
        // Step 5: Call backend MyID verify API
        await _verifyMyIdWithBackend(result.code!, result.image, result.comparisonValue);
        
      } else {
        print('⚠️ [SMS Code Page] MyID SDK did not return code (user cancelled?)');
        setState(() {
          _isMyIdInProgress = false;
        });
        print('   - _isMyIdInProgress set to false');
        
        CustomToast.show(
          context,
          message: 'MyID верификация отменена',
          isSuccess: false,
        );
      }
    } on MyIdException catch (e) {
      print('❌ [SMS Code Page] MyIdException caught in _startMyIdVerification');
      print('   - code: ${e.code}');
      print('   - message: ${e.message}');
      print('   - setting _isMyIdInProgress to false');
      
      setState(() {
        _isMyIdInProgress = false;
      });
      print('   - _isMyIdInProgress after setState: $_isMyIdInProgress');
      
      // Handle specific MyID exceptions
      if (e.code == 'CAMERA_PERMISSION_DENIED') {
        print('🔵 [SMS Code Page] Camera permission denied exception');
        // Camera permission was denied during SDK start
        // Check if we can request it again
        final cameraStatus = await Permission.camera.status;
        print('   - cameraStatus: $cameraStatus');
        
        if (cameraStatus.isPermanentlyDenied) {
          print('❌ [SMS Code Page] Camera permission permanently denied, navigating to home');
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
          print('🔄 [SMS Code Page] Camera permission can be requested, retrying...');
          // Permission can be requested - wait a bit and retry
          CustomToast.show(
            context,
            message: 'Запрос разрешения камеры...',
            isSuccess: true,
          );
          
          // Wait for permission to be granted and retry
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Check if still mounted before retrying
          if (mounted) {
            print('🔄 [SMS Code Page] Retrying _startMyIdVerification after permission request');
            await _startMyIdVerification();
          } else {
            print('⚠️ [SMS Code Page] Widget not mounted, cannot retry');
          }
        }
      } else {
        print('❌ [SMS Code Page] Other MyIdException: ${e.message}');
        // Show only the message without prefix
        CustomToast.show(
          context,
          message: e.message,
          isSuccess: false,
        );
      }
    } catch (e, stackTrace) {
      print('❌ [SMS Code Page] General exception caught in _startMyIdVerification');
      print('   - error: $e');
      print('   - error type: ${e.runtimeType}');
      print('   - stackTrace: $stackTrace');
      print('   - setting _isMyIdInProgress to false');
      
      setState(() {
        _isMyIdInProgress = false;
      });
      print('   - _isMyIdInProgress after setState: $_isMyIdInProgress');
      
      // Check if it's a PlatformException with CAMERA_PERMISSION_DENIED
      if (e is PlatformException && e.code == 'CAMERA_PERMISSION_DENIED') {
        print('🔵 [SMS Code Page] PlatformException with CAMERA_PERMISSION_DENIED');
        // Wait a bit for permission to be processed, then retry
        CustomToast.show(
          context,
          message: 'Ожидание разрешения камеры...',
          isSuccess: true,
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Check if still mounted before proceeding
        if (!mounted) {
          print('⚠️ [SMS Code Page] Widget not mounted, returning');
          return;
        }
        
        // Check permission status and retry
        final cameraStatus = await Permission.camera.status;
        print('   - cameraStatus after delay: $cameraStatus');
        
        if (cameraStatus.isGranted) {
          print('✅ [SMS Code Page] Camera permission granted, retrying...');
          // Permission granted, retry
          await _startMyIdVerification();
        } else if (cameraStatus.isPermanentlyDenied) {
          print('❌ [SMS Code Page] Camera permission permanently denied, navigating to home');
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
          print('🔄 [SMS Code Page] Requesting camera permission again...');
          // Try requesting again
          final requestResult = await Permission.camera.request();
          print('   - requestResult: $requestResult');
          
          if (requestResult.isGranted && mounted) {
            print('✅ [SMS Code Page] Camera permission granted after request, retrying...');
            await _startMyIdVerification();
          } else if (mounted) {
            print('❌ [SMS Code Page] Camera permission still denied, navigating to home');
            // Still denied - go to home page
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          }
        }
      } else {
        print('❌ [SMS Code Page] Other exception: ${e.toString()}');
        // Extract only the message part, not the full exception string
        String errorMessage = 'Неизвестная ошибка';
        if (e is MyIdException) {
          errorMessage = e.message;
        } else if (e is PlatformException) {
          errorMessage = e.message ?? e.code;
        } else {
          // Try to extract message from toString if it contains "message:"
          final errorStr = e.toString();
          if (errorStr.contains('message:')) {
            final match = RegExp(r'message:\s*([^,)]+)').firstMatch(errorStr);
            if (match != null) {
              errorMessage = match.group(1)?.trim() ?? errorStr;
            } else {
              errorMessage = errorStr;
            }
          } else {
            errorMessage = errorStr;
          }
        }
        CustomToast.show(
          context,
          message: errorMessage,
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _verifyMyIdWithBackend(String code, String? image, double? comparisonValue) async {
    print('🔵 [SMS Code Page] _verifyMyIdWithBackend called');
    print('   - code: $code');
    print('   - image: ${image != null ? "present (${image.length} chars)" : "null"}');
    print('   - comparisonValue: $comparisonValue');
    print('   - _isMyIdInProgress: $_isMyIdInProgress');
    
    try {
      // Check if still mounted
      if (!mounted) {
        print('⚠️ [SMS Code Page] Widget not mounted, stopping verification');
        setState(() {
          _isMyIdInProgress = false;
        });
        return;
      }
      
      print('🔵 [SMS Code Page] Getting access token...');
      // Get access token for the API call
      final accessToken = await MyIdService.getAccessToken();
      print('✅ [SMS Code Page] Access token received: ${accessToken.substring(0, 20)}...');
      
      print('🔵 [SMS Code Page] Calling MyID verify endpoint...');
      // Call the MyID verify endpoint
      final response = await MyIdService.verifyMyIdWithBackend(
        code: code,
        token: accessToken,
        phoneNumber: widget.phoneNumber,
      );
      
      print('📥 [SMS Code Page] MyID verify response received');
      print('   - response: $response');
      print('   - response type: ${response.runtimeType}');
      print('   - response is null: ${response == null}');
      
      if (response != null) {
        print('   - response keys: ${response.keys.toList()}');
        print('   - success: ${response['success']}');
        print('   - success type: ${response['success'].runtimeType}');
        print('   - success == true: ${response['success'] == true}');
        print('   - success == "true": ${response['success'] == "true"}');
        print('   - data: ${response['data']}');
        print('   - data type: ${response['data'].runtimeType}');
        print('   - error: ${response['error']}');
        
        // Check if data exists and has tokens
        if (response['data'] != null && response['data'] is Map) {
          final data = response['data'] as Map;
          print('   - data keys: ${data.keys.toList()}');
          if (data.containsKey('tokens')) {
            print('   - tokens found: ${data['tokens']}');
          }
          if (data.containsKey('user')) {
            print('   - user found: ${data['user']}');
          }
        }
      }
      
      // Check if still mounted after API call
      if (!mounted) {
        print('⚠️ [SMS Code Page] Widget not mounted after API call, stopping');
        setState(() {
          _isMyIdInProgress = false;
        });
        return;
      }
      
      // Check success condition more carefully
      final isSuccess = response != null && 
                       (response['success'] == true || 
                        response['success'] == 'true' ||
                        (response['success'] is bool && response['success'] == true));
      
      print('   - isSuccess calculated: $isSuccess');
      
      if (isSuccess) {
        print('✅ [SMS Code Page] MyID verification SUCCESS');
        print('   - Saving tokens and user data...');
        
        // Success - save tokens and user data
        await _saveTokensFromResponse(response);
        
        print('✅ [SMS Code Page] Tokens and user data saved');
        print('   - Setting _isMyIdInProgress to false');
        
        setState(() {
          _isMyIdInProgress = false;
        });
        
        print('   - _isMyIdInProgress after setState: $_isMyIdInProgress');
        
        // Ensure we're back on SMS page (in case SDK navigated away)
        // Wait a bit for any navigation transitions to complete
        print('⏳ [SMS Code Page] Waiting 500ms for navigation transitions...');
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) {
          print('⚠️ [SMS Code Page] Widget not mounted after delay, returning');
          return;
        }
        
        print('🔵 [SMS Code Page] Showing success toast...');
        CustomToast.show(
          context,
          message: 'MyID верификация успешна! Авторизация завершена',
          isSuccess: true,
        );
        
        // Wait a bit more to show the success message, then navigate to home
        print('⏳ [SMS Code Page] Waiting 1 second before navigation...');
        await Future.delayed(const Duration(seconds: 1));
        
        // Navigate to main layout (with bottom navigation, using named route)
        // Only navigate if still mounted
        if (mounted) {
          print('🚀 [SMS Code Page] Navigating to /home');
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
          print('✅ [SMS Code Page] Navigation completed');
        } else {
          print('⚠️ [SMS Code Page] Widget not mounted, cannot navigate');
        }
      } else {
        // Failure - check if we should retry or just show error
        final errorMessage = response?['error'] ?? 'Ошибка верификации MyID';
        print('❌ [SMS Code Page] MyID verification FAILED or response invalid');
        print('   - errorMessage: $errorMessage');
        print('   - response: $response');
        print('   - response is null: ${response == null}');
        
        // Check if response has data even though success is false
        // Sometimes backend returns data even with success=false
        bool hasValidData = false;
        if (response != null && response['data'] != null) {
          final data = response['data'];
          if (data is Map) {
            // Check if data contains tokens or user info
            if (data.containsKey('tokens') || data.containsKey('user')) {
              print('   - ⚠️ Response has data despite success=false, trying to save...');
              hasValidData = true;
              try {
                await _saveTokensFromResponse(response);
                print('   - ✅ Data saved successfully despite success=false');
                
                setState(() {
                  _isMyIdInProgress = false;
                });
                
                CustomToast.show(
                  context,
                  message: 'MyID верификация завершена',
                  isSuccess: true,
                );
                
                await Future.delayed(const Duration(milliseconds: 500));
                
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/home',
                    (route) => false,
                  );
                }
                return; // Exit early, don't retry
              } catch (e) {
                print('   - ❌ Error saving data: $e');
                hasValidData = false;
              }
            }
          }
        }
        
        if (!hasValidData) {
          // Only retry if we don't have valid data
          setState(() {
            _isMyIdInProgress = false;
          });
          
          print('   - _isMyIdInProgress set to false');
          
          CustomToast.show(
            context,
            message: 'Ошибка верификации. Повторная попытка...',
            isSuccess: false,
          );
          
          // Retry MyID verification process
          print('⏳ [SMS Code Page] Waiting 1 second before retry...');
          await Future.delayed(const Duration(seconds: 1));
          
          // Only retry if still mounted
          if (mounted) {
            print('🔄 [SMS Code Page] Retrying MyID verification...');
            await _startMyIdVerification();
          } else {
            print('⚠️ [SMS Code Page] Widget not mounted, cannot retry');
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ [SMS Code Page] ERROR in backend MyID verification');
      print('   - error: $e');
      print('   - stackTrace: $stackTrace');
      
      setState(() {
        _isMyIdInProgress = false;
      });
      
      print('   - _isMyIdInProgress set to false');
      
      CustomToast.show(
        context,
        message: 'Ошибка сервера. Повторная попытка...',
        isSuccess: false,
      );
      
      // Retry MyID verification on error
      print('⏳ [SMS Code Page] Waiting 1 second before retry after error...');
      await Future.delayed(const Duration(seconds: 1));
      
      // Only retry if still mounted
      if (mounted) {
        print('🔄 [SMS Code Page] Retrying MyID verification after error...');
        await _startMyIdVerification();
      } else {
        print('⚠️ [SMS Code Page] Widget not mounted, cannot retry after error');
      }
    }
  }

  Future<void> _saveTokensFromResponse(Map<String, dynamic> response) async {
    print('🔵 [SMS Code Page] _saveTokensFromResponse called');
    print('   - response keys: ${response.keys.toList()}');
    
    try {
      final data = response['data'];
      print('   - data type: ${data.runtimeType}');
      print('   - data: $data');
      
      if (data is Map) {
        print('   - data is Map, processing...');
        
        // Check if tokens and user are in data['data'] (nested structure)
        Map<String, dynamic>? actualData = data as Map<String, dynamic>?;
        if (data.containsKey('data') && data['data'] is Map) {
          print('   - Found nested data structure, using data["data"]');
          print('   - data["data"]: ${data['data']}');
          actualData = data['data'] as Map<String, dynamic>?;
        }
        
        // Save tokens
        if (actualData != null && actualData.containsKey('tokens') && actualData['tokens'] is Map) {
          print('   - tokens found, saving...');
          final tokens = actualData['tokens'] as Map;
          print('   - tokens keys: ${tokens.keys.toList()}');
          final prefs = await SharedPreferences.getInstance();
          
          if (tokens.containsKey('access')) {
            final accessToken = tokens['access'].toString();
            await prefs.setString('accessToken', accessToken);
            print('✅ [SMS Code Page] Access token saved: ${accessToken.substring(0, 20)}...');
          } else {
            print('⚠️ [SMS Code Page] Access token not found in tokens');
          }
          
          if (tokens.containsKey('refresh')) {
            final refreshToken = tokens['refresh'].toString();
            await prefs.setString('refreshToken', refreshToken);
            print('✅ [SMS Code Page] Refresh token saved: ${refreshToken.substring(0, 20)}...');
          } else {
            print('⚠️ [SMS Code Page] Refresh token not found in tokens');
          }
        } else {
          print('⚠️ [SMS Code Page] Tokens not found or not a Map');
          if (actualData != null) {
            print('   - actualData.containsKey("tokens"): ${actualData.containsKey('tokens')}');
            if (actualData.containsKey('tokens')) {
              print('   - actualData["tokens"] type: ${actualData['tokens'].runtimeType}');
            }
          }
        }
        
        // Save user data
        if (actualData != null && actualData.containsKey('user') && actualData['user'] is Map) {
          print('   - user data found, saving...');
          final userData = actualData['user'] as Map;
          print('   - user data keys: ${userData.keys.toList()}');
          await UserService.saveUserData(userData);
          print('✅ [SMS Code Page] User data saved');
        } else {
          print('⚠️ [SMS Code Page] User data not found or not a Map');
          if (actualData != null) {
            print('   - actualData.containsKey("user"): ${actualData.containsKey('user')}');
            if (actualData.containsKey('user')) {
              print('   - actualData["user"] type: ${actualData['user'].runtimeType}');
            }
          }
        }
      } else {
        print('⚠️ [SMS Code Page] Data is not a Map, type: ${data.runtimeType}');
      }
      
      print('✅ [SMS Code Page] _saveTokensFromResponse completed');
    } catch (e, stackTrace) {
      print('❌ [SMS Code Page] Error saving tokens from response');
      print('   - error: $e');
      print('   - stackTrace: $stackTrace');
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

    return PopScope(
      canPop: !_isMyIdInProgress, // Prevent back navigation when MyID is in progress
      onPopInvoked: (didPop) {
        if (didPop && _isMyIdInProgress) {
          // If back was pressed during MyID, show a message
          CustomToast.show(
            context,
            message: 'Пожалуйста, дождитесь завершения верификации MyID',
            isSuccess: false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: textColor,
            ),
            onPressed: _isMyIdInProgress 
                ? null // Disable back button when MyID is in progress
                : () => Navigator.of(context).pop(),
          ),
        title: Image.asset(
                          'assets/img/logo.png',
          height: 32.h,
                        ),
        centerTitle: true,
                ),
      body: Stack(
        children: [
          Padding(
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
                    return Focus(
                      onKeyEvent: (node, event) {
                        // Handle backspace when input is empty
                        if (event is KeyDownEvent && 
                            event.logicalKey == LogicalKeyboardKey.backspace &&
                            _controllers[index].text.isEmpty &&
                            index > 0) {
                          _onCodeDeleted(index);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Container(
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
                              // Handle backspace - clear current and move to previous input
                              if (index > 0) {
                                _onCodeDeleted(index);
                              }
                            }
                          },
                        ),
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
          
          // MyID Loading Overlay
          if (_isMyIdInProgress)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF1B7EFF),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'MyID верификация идёт...',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Пожалуйста, подождите',
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}