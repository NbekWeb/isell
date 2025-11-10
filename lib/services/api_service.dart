import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/navigator_key.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://192.81.218.80:6060/api/v1/',
      ),
      connectTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(minutes: 10),
    ),
  );

  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static String? _memoryToken;

  static String? get memoryToken => _memoryToken;

  static void setMemoryToken(String? token) {
    _memoryToken = token;
  }

  static void init() {
    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            var token = await _storage.read(key: 'access_token');

            if (token == null &&
                _memoryToken != null &&
                !(options.extra['open'] == true)) {
              try {
                await _storage.write(key: 'access_token', value: _memoryToken);
                token = _memoryToken;
              } catch (e) {
                if (e.toString().contains('already exists')) {
                  try {
                    await _storage.delete(key: 'access_token');
                    await _storage.write(
                      key: 'access_token',
                      value: _memoryToken,
                    );
                    token = _memoryToken;
                  } catch (_) {
                    token = _memoryToken;
                  }
                } else {
                  token = _memoryToken;
                }
              }
            }

            if (token != null && !(options.extra['open'] == true)) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {}

          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            try {
              await _storage.delete(key: 'access_token');
            } catch (_) {}

            if (navigatorKey.currentState != null) {
              navigatorKey.currentState!.pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            }
          }

          return handler.next(e);
        },
      ),
    );
  }

  static Future<Response<T>> request<T>({
    required String url,
    bool open = false,
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    final options = Options(
      method: method,
      headers: headers,
      extra: {'open': open},
    );

    return _dio.request<T>(
      url,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  static Future<Response<T>> uploadFile<T>({
    required String url,
    bool open = false,
    String method = 'POST',
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    final token = await _storage.read(key: 'access_token');

    final options = Options(
      method: method,
      headers: {
        ...headers ?? {},
        'Content-Type': 'multipart/form-data',
        if (token != null && !open) 'Authorization': 'Bearer $token',
      },
    );

    dynamic formData;
    if (data != null) {
      formData = FormData();

      for (final entry in data.entries) {
        if (entry.value is Uint8List) {
          formData.files.add(
            MapEntry(
              entry.key,
              MultipartFile.fromBytes(entry.value, filename: 'upload.jpg'),
            ),
          );
        } else if (entry.value is String &&
            entry.value.toString().startsWith('/')) {
          final file = File(entry.value as String);
          if (await file.exists()) {
            formData.files.add(
              MapEntry(
                entry.key,
                await MultipartFile.fromFile(
                  file.path,
                  filename: file.path.split('/').last,
                ),
              ),
            );
          }
        } else if (entry.value is String &&
            entry.value.toString().startsWith('blob:')) {
          try {
            final response = await _dio.get<List<int>>(
              entry.value.toString(),
              options: Options(responseType: ResponseType.bytes),
            );

            if (response.data != null) {
              formData.files.add(
                MapEntry(
                  entry.key,
                  MultipartFile.fromBytes(
                    Uint8List.fromList(response.data!),
                    filename: 'upload.jpg',
                  ),
                ),
              );
            }
          } catch (_) {
            formData.fields.add(MapEntry(entry.key, entry.value.toString()));
          }
        } else {
          formData.fields.add(MapEntry(entry.key, entry.value.toString()));
        }
      }
    }

    return _dio.request<T>(
      url,
      data: formData,
      queryParameters: queryParameters,
      options: options,
    );
  }
}

