import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class UserService {
  /// Get current user data
  /// GET /accounts/me/
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      print('🔵 User Service - Getting current user data');
      
      // Test: Check if access token exists before API call
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      print('🔍 TEST - Access token exists: ${accessToken != null}');
      if (accessToken != null) {
        print('🔍 TEST - Token preview: ${accessToken.substring(0, 20)}...');
      }
      
      print('🔍 Making API request to: accounts/me/');
      
      // Force initialize API service to ensure interceptors are set up
      ApiService.init();
      print('🔍 API Service re-initialized');
      
      final Response response = await ApiService.request(
        url: 'accounts/me/',
        method: 'GET',
      );
      
      print('🔍 API request completed with status: ${response.statusCode}');

      final data = response.data;
      print('🔵 User API Response Status: ${response.statusCode}');
      print('🔵 User API Response Data: $data');

      if (response.statusCode == 200 && data != null) {
        // Extract user data from nested response
        final userData = data is Map && data.containsKey('data') ? data['data'] : data;
        
        // Save user data to localStorage
        await saveUserData(userData);
        
        return {
          'success': true,
          'data': userData,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get user data',
        };
      }
    } catch (e) {
      print('❌ Error getting current user: $e');
      
      String errorMessage = 'Ошибка при получении данных пользователя';
      
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          errorMessage = 'Токен авторизации недействителен';
        } else if (e.response?.statusCode == 403) {
          errorMessage = 'Доступ запрещен';
        } else if (e.response?.statusCode == 404) {
          errorMessage = 'Пользователь не найден';
        }
      }
      
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }

  /// Save user data to localStorage
  static Future<void> saveUserData(dynamic userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (userData is Map) {
        // Save complete user data as JSON string
        await prefs.setString('userInfo', userData.toString());
        
        // Save specific user fields for easy access
        if (userData.containsKey('id')) {
          await prefs.setInt('userId', userData['id'] as int);
        }
        
        if (userData.containsKey('phone_number')) {
          await prefs.setString('userPhone', userData['phone_number'].toString());
        }
        
        if (userData.containsKey('first_name')) {
          await prefs.setString('userFirstName', userData['first_name'].toString());
        }
        
        if (userData.containsKey('last_name')) {
          await prefs.setString('userLastName', userData['last_name'].toString());
        }
        
        if (userData.containsKey('email')) {
          await prefs.setString('userEmail', userData['email'].toString());
        }
        
        print('✅ User data saved to localStorage');
        print('📋 User ID: ${userData['id']}');
        print('📋 User Name: ${userData['first_name']} ${userData['last_name']}');
        print('📋 Phone: ${userData['phone_number']}');
      }
    } catch (e) {
      print('❌ Error saving user data: $e');
    }
  }

  /// Get user data from localStorage
  static Future<Map<String, dynamic>?> getCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final userId = prefs.getInt('userId');
      final userPhone = prefs.getString('userPhone');
      final userFirstName = prefs.getString('userFirstName');
      final userLastName = prefs.getString('userLastName');
      final userEmail = prefs.getString('userEmail');
      
      if (userId != null) {
        return {
          'id': userId,
          'phone_number': userPhone,
          'first_name': userFirstName,
          'last_name': userLastName,
          'email': userEmail,
        };
      }
    } catch (e) {
      print('❌ Error getting cached user data: $e');
    }
    
    return null;
  }

  /// Check if user is logged in
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

  /// Test method to check token status
  static Future<void> testTokenStatus() async {
    try {
      print('🧪 === TOKEN TEST START ===');
      
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');
      final refreshToken = prefs.getString('refreshToken');
      
      print('🔍 AccessToken exists: ${accessToken != null}');
      print('🔍 RefreshToken exists: ${refreshToken != null}');
      
      if (accessToken != null) {
        print('🔍 AccessToken preview: ${accessToken.substring(0, 30)}...');
        print('🔍 AccessToken length: ${accessToken.length}');
      }
      
      // Test SecureStorage too
      const storage = FlutterSecureStorage();
      final secureToken = await storage.read(key: 'access_token');
      print('🔍 SecureStorage token exists: ${secureToken != null}');
      
      print('🧪 === TOKEN TEST END ===');
    } catch (e) {
      print('❌ Error in token test: $e');
    }
  }

  /// Clear user data on logout
  static Future<void> clearUserData() async {
    try {
      print('🔄 Clearing user data and tokens...');
      
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userInfo');
      await prefs.remove('userId');
      await prefs.remove('userPhone');
      await prefs.remove('userFirstName');
      await prefs.remove('userLastName');
      await prefs.remove('userEmail');
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
      
      print('✅ SharedPreferences cleared');
      
      // Also clear from FlutterSecureStorage (for compatibility)
      try {
        const storage = FlutterSecureStorage();
        await storage.delete(key: 'access_token');
        print('✅ SecureStorage cleared');
      } catch (e) {
        print('❌ Error clearing SecureStorage: $e');
      }
      
      print('✅ All user data and tokens cleared');
    } catch (e) {
      print('❌ Error clearing user data: $e');
    }
  }
}