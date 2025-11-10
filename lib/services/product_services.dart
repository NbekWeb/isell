import 'package:dio/dio.dart';

import 'api_service.dart';

class ProductServices {
  static Future<Map<String, dynamic>> getAllProducts({
    String? name,
    int page = 1,
  }) async {
    try {
      final Response response = await ApiService.request(
        url: 'products/',
        method: 'GET',
        queryParameters: {
          if (name != null && name.isNotEmpty) 'name': name,
          'page': page,
          'page_size': 10
        },
      );

      final data = response.data;

      if (data is Map<String, dynamic>) {
        final results = data['results'] ?? [];
        final totalPages = data['total_pages'] ?? 1;
        
        return {
          'results': results is List
              ? results
                  .map<Map<String, dynamic>>(
                    (item) => Map<String, dynamic>.from(item as Map),
                  )
                  .toList()
              : <Map<String, dynamic>>[],
          'total_pages': totalPages is int ? totalPages : 1,
        };
      }
    } catch (_) {
      // ignore
    }

    return {
      'results': <Map<String, dynamic>>[],
      'total_pages': 1,
    };
  }

  static Future<Map<String, dynamic>?> getProductFilter({
    required int productId,
    String? colorName,
    String? storageName,
    String? simCardName,
  }) async {
    try {
      final Response response = await ApiService.request(
        url: 'products/$productId/filter/',
        method: 'GET',
        queryParameters: {
          if (colorName != null && colorName.isNotEmpty) 'color_name': colorName,
          if (storageName != null && storageName.isNotEmpty) 'storage_name': storageName,
          if (simCardName != null && simCardName.isNotEmpty) 'sim_card_name': simCardName,
        },
      );

      final data = response.data;

      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {
      // ignore
    }

    return null;
  }
}

