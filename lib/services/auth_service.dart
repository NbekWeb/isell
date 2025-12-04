import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  // Login - Send phone number to get SMS code
  static Future<Map<String, dynamic>?> login({
    required String phoneNumber,
  }) async {
    try {
      print('🔵 Auth Login API Request: /accounts/login/');
      print('📤 Phone number: $phoneNumber');
      
      final Response response = await ApiService.request(
        url: 'accounts/login/',
        method: 'POST',
        data: {
          'phone_number': phoneNumber,
        },
      );

      final data = response.data;
      print('🔵 Login API Response Status: ${response.statusCode}');
      print('🔵 Login API Response Data: $data');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Unexpected status code: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error in login API: $e');
      
      String errorMessage = 'Произошла ошибка при отправке кода';
      
      if (e is DioException) {
        if (e.response?.data != null) {
          final errorData = e.response!.data;
          if (errorData is Map && errorData.containsKey('error')) {
            errorMessage = errorData['error'].toString();
          } else if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'].toString();
          }
        } else if (e.response?.statusCode == 400) {
          errorMessage = 'Неверный формат номера телефона';
        } else if (e.response?.statusCode == 429) {
          errorMessage = 'Слишком много попыток. Попробуйте позже';
        } else if (e.response?.statusCode == 500) {
          errorMessage = 'Ошибка сервера. Попробуйте позже';
        }
      }
      
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }

  // Resend SMS code
  static Future<Map<String, dynamic>?> resendCode({
    required String phoneNumber,
  }) async {
    try {
      print('🔵 Auth Resend API Request: /accounts/resend/');
      print('📤 Phone number: $phoneNumber');
      
      final Response response = await ApiService.request(
        url: 'accounts/resend/',
        method: 'POST',
        data: {
          'phone_number': phoneNumber,
        },
      );

      final data = response.data;
      print('🔵 Resend API Response Status: ${response.statusCode}');
      print('🔵 Resend API Response Data: $data');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Unexpected status code: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error in resend API: $e');
      
      String errorMessage = 'Произошла ошибка при повторной отправке кода';
      
      if (e is DioException) {
        if (e.response?.data != null) {
          final errorData = e.response!.data;
          if (errorData is Map && errorData.containsKey('error')) {
            errorMessage = errorData['error'].toString();
          } else if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'].toString();
          }
        } else if (e.response?.statusCode == 400) {
          errorMessage = 'Неверный номер телефона';
        } else if (e.response?.statusCode == 429) {
          errorMessage = 'Слишком много попыток. Попробуйте позже';
        }
      }
      
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }

  // Verify SMS code and get tokens
  static Future<Map<String, dynamic>?> verifyCode({
    required String phoneNumber,
    required String code,
  }) async {
    try {
      print('🔵 Auth Verify API Request: /accounts/verify/');
      print('📤 Phone number: $phoneNumber');
      print('📤 Code: $code');
      
      final Response response = await ApiService.request(
        url: 'accounts/verify/',
        method: 'POST',
        data: {
          'phone_number': phoneNumber,
          'code': code,
        },
      );

      final data = response.data;
      print('🔵 Verify API Response Status: ${response.statusCode}');
      print('🔵 Verify API Response Data: $data');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Unexpected status code: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error in verify API: $e');
      
      String errorMessage = 'Произошла ошибка при проверке кода';
      
      if (e is DioException) {
        if (e.response?.data != null) {
          final errorData = e.response!.data;
          if (errorData is Map && errorData.containsKey('error')) {
            errorMessage = errorData['error'].toString();
          } else if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'].toString();
          }
        } else if (e.response?.statusCode == 400) {
          errorMessage = 'Неверный код или номер телефона';
        } else if (e.response?.statusCode == 404) {
          errorMessage = 'Код не найден или истек срок действия';
        } else if (e.response?.statusCode == 429) {
          errorMessage = 'Слишком много попыток. Попробуйте позже';
        }
      }
      
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  // Get access token
  static Future<String?> getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('accessToken');
    } catch (e) {
      print('❌ Error getting access token: $e');
      return null;
    }
  }

  // Logout
  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      await prefs.remove('userInfo');
      print('✅ User logged out successfully');
    } catch (e) {
      print('❌ Error during logout: $e');
    }
  }
}