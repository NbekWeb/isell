import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class MyIdService {
  static const MethodChannel _channel = MethodChannel('com.isell.myid');
  
  // MyID API credentials
  static const String _myIdApiBaseUrl = 'https://api.devmyid.uz';
  static const String _clientId = 'isell_sdk-0cnI1vDHIIqviRG8dazTki3ZdDHYS1B1iVTHiLaR';
  static const String _clientSecret = '9BVl7IpGc48adw3k69lScOJjKQGyGt2lNeJ88wEFQLK5m9cDf8GjGKP9oEpuj1eGLlVjX5PNirHcYEHawwoicJ5fUyHGMHZYD3K5';
  static const String _clientHashId = '7a727145-23da-4d42-8f3b-cdd032635a41';
  static const String _clientHash = '''MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsFW3jedThVNXeYv6DFQ4
3NBBf5kO0yivQrZQ/GKqz64DxhDOj6li+bfGBa9np35W09RoqLYd2r8eIRYK43lx
YTS+dA3KJxR1R6ZaoCEEQgkc9EjbfNmmsz/TWyD+WT82F7m8fccD/dyzOF8OEFJr
sQlX+X/7iOtcSY+2vK9zGLR+tGig0m+WWhG7DUDyzOp8HWEcBx9arzlBsyvYuP6F
fOnR03eaLfHD8wuGC6I3W5POwtD1oSM6Xxwu+SZkkdVU6dADcL8CIP37AIV7K+JY
VEqExBsRrrJR7vINTPl+Oof1bDqnaIIjdOZRN7FAcJgQFRfvbXf7koYfx8GuyH5V
NwIDAQAB''';
  
  // Public getters for SDK credentials
  static String get clientHash => _clientHash;
  static String get clientHashId => _clientHashId;
  
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _myIdApiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));
  
  /// Get Access Token from MyID API
  /// POST https://api.devmyid.uz/api/v1/auth/clients/access-token
  static Future<String> getAccessToken() async {
    try {
      final url = '$_myIdApiBaseUrl/api/v1/auth/clients/access-token';
      print('🔵 MyID API - Getting Access Token');
      print('📍 URL: $url');
      print('📤 Request Data: {client_id: $_clientId, client_secret: ***hidden***}');
      
      final response = await _dio.post(
        '/api/v1/auth/clients/access-token',
        data: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('📥 Access Token Response Status: ${response.statusCode}');
      print('📥 Access Token Response Data: ${response.data}');
      
      if (response.data != null && response.data['access_token'] != null) {
        final accessToken = response.data['access_token'] as String;
        print('✅ Access Token received: ${accessToken.substring(0, 20)}...');
        return accessToken;
      }
      
      throw Exception('Access token not found in response');
    } catch (e) {
      print('❌ Access Token Error: $e');
      if (e is DioException && e.response != null) {
        print('❌ Error Response Status: ${e.response?.statusCode}');
        print('❌ Error Response Data: ${e.response?.data}');
      }
      throw Exception('Failed to get access token: ${e.toString()}');
    }
  }
  
  /// Get session ID from MyID API
  /// POST https://api.devmyid.uz/api/v1/sdk/sessions
  /// 
  /// Parameters:
  /// - phoneNumber: Optional phone number in format 998901234567
  /// - birthDate: Optional birth date in format YYYY-MM-DD
  /// - isResident: Optional, default is true
  /// - passData: Optional passport data (use either passData or pinfl)
  /// - pinfl: Optional 14-digit PINFL (use either passData or pinfl)
  static Future<String> getSessionId({
    String? phoneNumber,
    String? birthDate,
    bool? isResident,
    String? passData,
    String? pinfl,
  }) async {
    try {
      // Step 1: Get access token
      final accessToken = await getAccessToken();
      
      // Step 2: Create session
      final requestData = <String, dynamic>{
        'client_hash_id': _clientHashId, // Required for SDK session validation
      };
      if (phoneNumber != null) requestData['phone_number'] = phoneNumber;
      if (birthDate != null) requestData['birth_date'] = birthDate;
      if (isResident != null) requestData['is_resident'] = isResident;
      if (passData != null) requestData['pass_data'] = passData;
      if (pinfl != null) requestData['pinfl'] = pinfl;
      
      final url = '$_myIdApiBaseUrl/api/v1/sdk/sessions';
      print('🔵 MyID API - Creating Session');
      print('📍 URL: $url');
      print('📤 Request Data: $requestData');
      print('🔑 Authorization: Bearer ${accessToken.substring(0, 20)}...');
      
      final response = await _dio.post(
        '/api/v1/sdk/sessions',
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      
      print('📥 Session Response Status: ${response.statusCode}');
      print('📥 Session Response Data: ${response.data}');
      
      if (response.data != null && response.data['session_id'] != null) {
        final sessionId = response.data['session_id'] as String;
        print('✅ Session ID received: $sessionId');
        return sessionId;
      }
      
      throw Exception('Session ID not found in response');
    } catch (e) {
      print('❌ Session Error: $e');
      if (e is DioException && e.response != null) {
        print('❌ Error Response Status: ${e.response?.statusCode}');
        print('❌ Error Response Data: ${e.response?.data}');
      }
      throw Exception('Failed to get session ID: ${e.toString()}');
    }
  }

  /// Get user data from MyID API using code
  /// GET https://api.devmyid.uz/api/v1/sdk/data?code={code}
  /// 
  /// Returns user data including:
  /// - first_name, last_name, middle_name
  /// - birth_date
  /// - pinfl
  /// - passport_series, passport_number
  /// - phone_number
  /// - and other user information
  /// 
  /// Get user data from MyID API using code (for frontend testing)
  /// GET https://api.devmyid.uz/api/v1/sdk/data?code={code}
  /// 
  /// Returns user data including:
  /// - first_name, last_name, middle_name
  /// - birth_date
  /// - pinfl
  /// - passport_series, passport_number
  /// - phone_number
  /// - and other user information
  static Future<Map<String, dynamic>> getUserDataByCode(String code) async {
    try {
      // Step 1: Get access token
      final accessToken = await getAccessToken();
      
      final url = '$_myIdApiBaseUrl/api/v1/sdk/data';
      print('🔵 MyID API - Getting User Data by Code (Frontend Test)');
      print('📍 URL: $url');
      print('📤 Code: $code');
      print('🔑 Authorization: Bearer ${accessToken.substring(0, 20)}...');
      
      final response = await _dio.get(
        '/api/v1/sdk/data',
        queryParameters: {'code': code},
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      
      print('📥 User Data Response Status: ${response.statusCode}');
      print('📥 User Data Response: ${response.data}');
      
      if (response.data != null) {
        print('✅ User Data received successfully');
        print('👤 User Information:');
        final userData = response.data as Map<String, dynamic>;
        print('   - Name: ${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}');
        print('   - PINFL: ${userData['pinfl'] ?? ''}');
        print('   - Phone: ${userData['phone_number'] ?? ''}');
        print('   - Passport: ${userData['passport_series'] ?? ''}${userData['passport_number'] ?? ''}');
        print('   - Birth Date: ${userData['birth_date'] ?? ''}');
        return userData;
      }
      
      throw Exception('User data not found in response');
    } catch (e) {
      print('❌ Get User Data Error: $e');
      if (e is DioException && e.response != null) {
        print('❌ Error Response Status: ${e.response?.statusCode}');
        print('❌ Error Response Data: ${e.response?.data}');
      }
      throw Exception('Failed to get user data: ${e.toString()}');
    }
  }

 
  static Future<MyIdResult> startAuthentication({
    required String sessionId,
    required String clientHash,
    required String clientHashId,
    String environment = 'debug',
    String entryType = 'identification',
    int minAge = 16,
    String residency = 'resident',
    String locale = 'uzbek',
    String cameraShape = 'circle',
    bool showErrorScreen = true,
  }) async {
    try {
      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : 'Android';
      print('🔵 MyID SDK - Starting Authentication on $platform');
      print('📤 Sending to $platform:');
      print('   - sessionId: $sessionId');
      print('   - clientHashId: $clientHashId');
      print('   - clientHash: ${clientHash.substring(0, 50)}...');
      print('   - environment: $environment');
      print('   - entryType: $entryType');
      print('   - locale: $locale');
      
      print('🔵 [MyIdService] Invoking startMyId method channel...');
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'startMyId',
        {
          'sessionId': sessionId,
          'clientHash': clientHash,
          'clientHashId': clientHashId,
          'environment': environment,
          'entryType': entryType,
          'minAge': minAge,
          'residency': residency,
          'locale': locale,
          'cameraShape': cameraShape,
          'showErrorScreen': showErrorScreen,
        },
      );

      print('📥 [MyIdService] MyID SDK Response received');
      print('   - result: $result');
      print('   - result type: ${result.runtimeType}');
      print('   - result is null: ${result == null}');

      if (result == null) {
        print('❌ [MyIdService] MyID SDK - No result returned');
        throw MyIdException(
          code: 'UNKNOWN_ERROR',
          message: 'No result returned from MyID',
        );
      }

      print('   - result keys: ${result.keys.toList()}');
      print('   - result["success"]: ${result['success']}');
      print('   - result["success"] type: ${result['success'].runtimeType}');
      print('   - result["success"] == true: ${result['success'] == true}');
      print('   - result["code"]: ${result['code']}');
      print('   - result["message"]: ${result['message']}');
      print('   - result["image"]: ${result['image'] != null ? "present" : "null"}');

      // Helper function to safely convert code to String
      String? safeCodeToString(dynamic code) {
        if (code == null) return null;
        if (code is String) return code;
        if (code is int) return code.toString();
        return code.toString();
      }

      // Helper function to safely convert message to String
      String? safeMessageToString(dynamic message) {
        if (message == null) return null;
        if (message is String) return message;
        return message.toString();
      }

      if (result['success'] == true) {
        print('✅ [MyIdService] MyID SDK - Success');
        print('   - code: ${result['code']}');
        print('   - image: ${result['image'] != null ? "present" : "null"}');
        final myIdResult = MyIdResult(
          code: safeCodeToString(result['code']),
          image: result['image'] as String?,
          comparisonValue: result['comparisonValue'] as double?,
        );
        print('✅ [MyIdService] MyIdResult created and returning');
        return myIdResult;
      } else {
        print('❌ [MyIdService] MyID SDK - Error or User Exited');
        print('   - code: ${result['code']}');
        print('   - message: ${result['message']}');
        throw MyIdException(
          code: safeCodeToString(result['code']) ?? 'UNKNOWN_ERROR',
          message: safeMessageToString(result['message']) ?? 'Unknown error occurred',
        );
      }
    } on PlatformException catch (e) {
      print('❌ MyID SDK - Platform Exception');
      print('   - code: ${e.code}');
      print('   - message: ${e.message}');
      print('   - details: ${e.details}');
      throw MyIdException(
        code: e.code,
        message: e.message ?? 'Platform error occurred',
      );
    } catch (e) {
      print('❌ MyID SDK - General Exception: $e');
      throw MyIdException(
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
      );
    }
  }

  
  static Future<Map<String, dynamic>?> verifyMyIdWithBackend({
    required String code,
    required String token,
    String? phoneNumber,
  }) async {
    try {
      print('🔵 MyID Backend Verify API Request: /accounts/myid/verify/');
      print('📤 Code: $code');
      print('📤 Token: ${token.substring(0, 20)}...');
      print('📤 Phone: $phoneNumber');
      
      // Import ApiService for backend calls
      final dio = Dio();
      
      final response = await dio.get(
        'http://192.81.218.80:6060/api/v1/accounts/myid/verify/',
        queryParameters: {
          'code': code,
          'token': token,
          if (phoneNumber != null) 'phone_number': phoneNumber,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      final data = response.data;
      print('🔵 MyID Backend Verify Response Status: ${response.statusCode}');
      print('🔵 MyID Backend Verify Response Data: $data');
      print('🔵 MyID Backend Verify Response Data Type: ${data.runtimeType}');
      
      if (data != null && data is Map) {
        print('🔵 MyID Backend Verify Response Data Keys: ${data.keys.toList()}');
        if (data.containsKey('success')) {
          print('🔵 MyID Backend Verify Response Data success: ${data['success']}');
        }
        if (data.containsKey('tokens')) {
          print('🔵 MyID Backend Verify Response Data has tokens');
        }
        if (data.containsKey('user')) {
          print('🔵 MyID Backend Verify Response Data has user');
        }
      }

      if (response.statusCode == 200) {
        // Check if data itself has success field
        bool backendSuccess = true;
        if (data != null && data is Map && data.containsKey('success')) {
          backendSuccess = data['success'] == true || data['success'] == 'true';
          print('🔵 MyID Backend Verify - Data has success field: ${data['success']}, backendSuccess: $backendSuccess');
        }
        
        return {
          'success': backendSuccess,
          'data': data,
        };
      } else {
        print('❌ MyID Backend Verify - Unexpected status code: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Unexpected status code: ${response.statusCode}',
          'data': data, // Still return data in case it has useful info
        };
      }
    } catch (e) {
      print('❌ Error in MyID backend verify: $e');
      
      String errorMessage = 'Ошибка при верификации MyID';
      
      if (e is DioException) {
        if (e.response?.data != null) {
          final errorData = e.response!.data;
          if (errorData is Map && errorData.containsKey('error')) {
            errorMessage = errorData['error'].toString();
          } else if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'].toString();
          }
        }
      }
      
      return {
        'success': false,
        'error': errorMessage,
      };
    }
  }
}

class MyIdResult {
  final String? code;
  final String? image; // Base64 encoded image
  final double? comparisonValue;

  MyIdResult({
    this.code,
    this.image,
    this.comparisonValue,
  });
}

class MyIdException implements Exception {
  final String code;
  final String message;

  MyIdException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'MyIdException(code: $code, message: $message)';
}

