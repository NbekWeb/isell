import 'dart:convert';
import 'package:dio/dio.dart';
import 'api_service.dart';

class OrderServices {
  static Future<List<Map<String, dynamic>>> getCompanyAddresses() async {
    try {
      print('🔵 Fetching company addresses from: info/company-addresses/');
      final Response response = await ApiService.request(
        url: 'info/company-addresses/',
        method: 'GET',
      );
      print('🔵 Company Addresses API Response: ${response.data}');
      final data = response.data;

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

  /// Create order
  /// POST /order/create/
  /// 
  /// Parameters:
  /// - calculationMode: 1 (simple) or 2 (complex)
  /// - For mode 1: totalAdvancePayment, tariffId, counterpartyId
  /// - For mode 2: productList (each with tariff_id and advance_payment)
  /// - productList: always required
  static Future<Map<String, dynamic>?> createOrder({
    required int calculationMode,
    double? totalAdvancePayment,
    int? tariffId,
    String? counterpartyId,
    required List<Map<String, dynamic>> productList,
  }) async {
    try {
      final data = <String, dynamic>{
        'calculation_mode': calculationMode,
        'product_list': productList,
      };

      if (calculationMode == 1) {
        // Simple mode
        if (totalAdvancePayment != null) {
          data['total_advance_payment'] = totalAdvancePayment.toInt();
        }
        if (tariffId != null) {
          data['tariff_id'] = tariffId;
        }
        if (counterpartyId != null) {
          data['counterparty_id'] = counterpartyId;
        }
      }
      // Mode 2: product_list already contains tariff_id and advance_payment for each item

      print('🔵 Create Order Request Body: $data');
      print('🔵 Request Body JSON: ${jsonEncode(data)}');
      
      final Response response = await ApiService.request(
        url: 'order/create/',
        method: 'POST',
        data: data,
      );
      
      print('📥 Create Order Response Status: ${response.statusCode}');
      print('📥 Create Order Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('❌ Error creating order: $e');
      if (e is DioException && e.response != null) {
        print('❌ Error Response Status: ${e.response?.statusCode}');
        print('❌ Error Response Data: ${e.response?.data}');
      }
      return null;
    }
  }

  /// Update order address
  /// PATCH /order/update-address/
  /// 
  /// Parameters:
  /// - orderId: Order ID (required)
  /// - companyId: Company address ID (use only one option - either companyId or user address)
  /// - address: User address string (use only one option - either companyId or user address)
  /// - latitude: Latitude (required with address)
  /// - longitude: Longitude (required with address)
  static Future<Map<String, dynamic>?> updateOrderAddress({
    required int orderId,
    int? companyId,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final data = <String, dynamic>{
        'order_id': orderId,
      };

      if (companyId != null) {
        // Use company address
        data['company_id'] = companyId;
      } else if (address != null && address.isNotEmpty) {
        // Use user address
        data['address'] = address;
        if (latitude != null && longitude != null) {
          data['latitude'] = latitude;
          data['longitude'] = longitude;
        }
      } else {
        throw Exception('Either companyId or address must be provided');
      }

      print('🔵 Update Order Address Request Body: $data');
      print('🔵 Request Body JSON: ${jsonEncode(data)}');
      
      final Response response = await ApiService.request(
        url: 'order/update-address/',
        method: 'PATCH',
        data: data,
      );
      
      print('📥 Update Order Address Response Status: ${response.statusCode}');
      print('📥 Update Order Address Response Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('❌ Error updating order address: $e');
      if (e is DioException && e.response != null) {
        print('❌ Error Response Status: ${e.response?.statusCode}');
        print('❌ Error Response Data: ${e.response?.data}');
      }
      return null;
    }
  }

  /// Get my orders (active and completed)
  /// GET /order/my-orders/
  static Future<Map<String, dynamic>?> getMyOrders() async {
    try {
      print('🔵 Fetching my orders from: order/my-orders/');
      final Response response = await ApiService.request(
        url: 'order/my-orders/',
        method: 'GET',
      );
      print('📥 My Orders API Response: ${response.data}');
      
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Error fetching my orders: $e');
      if (e is DioException && e.response != null) {
        print('❌ Error Response Status: ${e.response?.statusCode}');
        print('❌ Error Response Data: ${e.response?.data}');
      }
      return null;
    }
  }
}
