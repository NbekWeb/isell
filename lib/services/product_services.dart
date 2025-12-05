import 'dart:convert';
import 'package:dio/dio.dart';

import 'api_service.dart';

class ProductServices {
  static Future<Map<String, dynamic>> getAllProducts({
    String? name,
    int? category,
    int page = 1,
  }) async {
    try {
      final Response response = await ApiService.request(
        url: 'product/',
        method: 'GET',
        queryParameters: {
          if (name != null && name.isNotEmpty) 'name': name,
          if (category != null) 'category': category,
          'page': page,
          'page_size': 10,
        },
      );

      final data = response.data;

      if (data is Map<String, dynamic>) {
        final results = data['results'] ?? [];
        final count = data['count'] ?? 0;
        final next = data['next'];
        final previous = data['previous'];

        return {
          'results': results is List
              ? results
                    .map<Map<String, dynamic>>(
                      (item) => Map<String, dynamic>.from(item as Map),
                    )
                    .toList()
              : <Map<String, dynamic>>[],
          'count': count is int ? count : 0,
          'next': next,
          'previous': previous,
          'has_next': next != null,
          'has_previous': previous != null,
        };
      }
    } catch (_) {
      // ignore
    }

    return {
      'results': <Map<String, dynamic>>[],
      'count': 0,
      'next': null,
      'previous': null,
      'has_next': false,
      'has_previous': false,
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
        url: 'product/$productId',
        method: 'GET',
        queryParameters: {
          if (colorName != null && colorName.isNotEmpty)
            'color_name': colorName,
          if (storageName != null && storageName.isNotEmpty)
            'storage_name': storageName,
          if (simCardName != null && simCardName.isNotEmpty)
            'sim_card_name': simCardName,
        },
      );

      final data = response.data;
      print('🔵 Product Filter API Response Data: ${data}');

      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {
      // ignore
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>> getBanners() async {
    try {
      print('🔵 Fetching banners from API...');
      final Response response = await ApiService.request(
        url: 'info/banners/',
        method: 'GET',
      );

      print('📥 Banner API Response Status: ${response.statusCode}');
      print('📥 Banner API Response Data: ${response.data}');

      final data = response.data;

      if (data is List) {
        final allBanners = data
            .map<Map<String, dynamic>>(
              (item) => Map<String, dynamic>.from(item as Map),
            )
            .toList();

        for (var banner in allBanners) {
          print(
            '   - Banner ID: ${banner['id']}, is_active: ${banner['is_active']}, image: ${banner['image']}',
          );
        }

        final banners = allBanners
            .where((banner) => banner['is_active'] == true)
            .toList();

        print('✅ Active banners: ${banners.length}');

        // Sort banners: if all orders are 0, sort by id; otherwise sort by order
        final allOrdersZero = banners.every(
          (b) => (b['order'] as int? ?? 0) == 0,
        );

        if (allOrdersZero) {
          banners.sort(
            (a, b) => (a['id'] as int? ?? 0).compareTo(b['id'] as int? ?? 0),
          );
        } else {
          banners.sort((a, b) {
            final orderA = a['order'] as int? ?? 0;
            final orderB = b['order'] as int? ?? 0;
            if (orderA == 0) return 1; // Put 0 orders at the end
            if (orderB == 0) return -1;
            return orderA.compareTo(orderB);
          });
        }

        print('✅ Returning ${banners.length} banners');
        return banners;
      } else {
        print('❌ Banner data is not a List, type: ${data.runtimeType}');
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching banners: $e');
      print('❌ Stack trace: $stackTrace');
    }

    print('⚠️ Returning empty banner list');
    return <Map<String, dynamic>>[];
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final Response response = await ApiService.request(
        url: 'product/categories/',
        method: 'GET',
      );

      final data = response.data;
      print('🔵 Categories API Response Data: ${data}');

      // Handle new structure with results array
      if (data is Map<String, dynamic> && data['results'] is List) {
        final results = data['results'] as List;
        return results
            .map<Map<String, dynamic>>(
              (item) => Map<String, dynamic>.from(item as Map),
            )
            .toList();
      }

      // Fallback to old structure (direct list)
      if (data is List) {
        return data
            .map<Map<String, dynamic>>(
              (item) => Map<String, dynamic>.from(item as Map),
            )
            .toList();
      }
    } catch (_) {
      // ignore
    }

    return <Map<String, dynamic>>[];
  }

  static Future<List<Map<String, dynamic>>> getTariffs() async {
    try {
      final Response response = await ApiService.request(
        url: 'product/tariffs/',
        method: 'GET',
      );

      final data = response.data;
      if (data is List) {
        // Filter only active tariffs and maintain API order
        final activeTariffs = data
            .where((tariff) => tariff['is_active'] == true)
            .map<Map<String, dynamic>>(
              (item) => Map<String, dynamic>.from(item as Map),
            )
            .toList();

        // Return tariffs in the same order as API (no sorting)
        return activeTariffs;
      }
    } catch (e) {
      print('❌ Error fetching tariffs: $e');
    }

    return <Map<String, dynamic>>[];
  }

  static Future<dynamic> calculateMonthlyPayment({
    required String productId,
    required int advancePayment,
    required int tariffId,
    int? variationId,
  }) async {
    try {
      final queryParams = {
        'advance_payment': advancePayment,
        'tariff': tariffId,
        'product_id': productId,
      };

      // Add variation_id only if it's provided
      if (variationId != null) {
        queryParams['variation_id'] = variationId;
      }

      print(
        '🔵 Calculate API Request: product/$productId/calculate/ with params: $queryParams',
      );

      final Response response = await ApiService.request(
        url: 'product/$productId/calculate/',
        method: 'GET',
        queryParameters: queryParams,
      );

      final data = response.data;
      print('🔵 Calculate API Response: ${data}');

      // Handle both List and Map responses
      if (data is List || data is Map<String, dynamic>) {
        return data;
      }
    } catch (e) {
      print('❌ Error calculating monthly payment for tariff $tariffId: $e');
      // Return a fallback response to prevent UI issues
      return null;
    }

    return null;
  }

  static Future<Map<String, dynamic>?> calculateSchedule({
    required int calculationMode,
    int? tariffId,
    double? totalAdvancePayment,
    List<Map<String, dynamic>>? productList,
  }) async {
    try {
      final data = <String, dynamic>{'calculation_mode': calculationMode};

      if (calculationMode == 1) {
        if (tariffId != null) data['tariff_id'] = tariffId;
        // Convert double to int for total_advance_payment
        if (totalAdvancePayment != null) {
          data['total_advance_payment'] = totalAdvancePayment.toInt();
        }

        // Add product_list for simple mode but without tariff_id and advance_payment
        if (productList != null) {
          final simpleProductList = productList.map((item) {
            final Map<String, dynamic> simpleItem = {
              'product_id': item['product_id'],
              'quantity': item['quantity'],
            };
            // Add variation_id if it exists
            if (item['variation_id'] != null) {
              simpleItem['variation_id'] = item['variation_id'];
            }
            return simpleItem;
          }).toList();
          data['product_list'] = simpleProductList;
        }
      } else if (calculationMode == 2) {
        if (productList != null) data['product_list'] = productList;
      }

      print('🔵 Calculate Schedule Request Body: $data');
      print('🔵 Request Body JSON: ${jsonEncode(data)}');
      
      final Response response = await ApiService.request(
        url: 'product/calculate-schedule/',
        method: 'POST',
        data: data,
      );
      
      print('📥 Calculate Schedule Response Status: ${response.statusCode}');
      print('📥 Calculate Schedule Response Data: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('❌ Error calculating schedule: $e');

     

      return null;
    }
  }

  static Future<Map<String, dynamic>?> calculateScheduleSimple({
    required int calculationMode,
    int? tariffId,
    double? totalAdvancePayment,
    List<Map<String, dynamic>>? productList,
  }) async {
    try {
      final data = <String, dynamic>{'calculation_mode': calculationMode};

      if (calculationMode == 1) {
        if (tariffId != null) data['tariff_id'] = tariffId;
        // Convert double to int for total_advance_payment
        if (totalAdvancePayment != null) {
          data['total_advance_payment'] = totalAdvancePayment.toInt();
        }

        // Add product_list for simple mode but without tariff_id and advance_payment
        if (productList != null) {
          final simpleProductList = productList.map((item) {
            final Map<String, dynamic> simpleItem = {
              'product_id': item['product_id'],
              'quantity': item['quantity'],
            };
            // Add variation_id if it exists
            if (item['variation_id'] != null) {
              simpleItem['variation_id'] = item['variation_id'];
            }
            return simpleItem;
          }).toList();
          data['product_list'] = simpleProductList;
        }
      } else if (calculationMode == 2) {
        if (productList != null) data['product_list'] = productList;
      }

      print('🔵 Calculate Schedule Simple Request Body: $data');
      print('🔵 Request Body JSON: ${jsonEncode(data)}');
      
      final Response response = await ApiService.request(
        url: 'product/calculate-schedule-simple/',
        method: 'POST',
        data: data,
      );
      
      print('📥 Calculate Schedule Simple Response Status: ${response.statusCode}');
      print('📥 Calculate Schedule Simple Response Data: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('❌ Error calculating schedule simple: $e');
      return null;
    }
  }
}
