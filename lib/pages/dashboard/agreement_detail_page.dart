import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../components/product_card.dart';

class AgreementDetailPage extends StatelessWidget {
  final Map<String, dynamic> sale;
  final bool isCompleted;

  const AgreementDetailPage({
    super.key,
    required this.sale,
    required this.isCompleted,
  });

  String _formatSum(dynamic value) {
    if (value == null) return '\$0';
    final numValue = value is num ? value : double.tryParse(value.toString()) ?? 0;
    final formatted = numValue.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '\$$formatted';
  }

  String? _getProductImageUrl() {
    // Check variation_list for images
    final variationList = sale['variation_list'] as List?;
    if (variationList != null && variationList.isNotEmpty) {
      final firstVariation = variationList[0] as Map<String, dynamic>?;
      if (firstVariation != null) {
        final productDetails = firstVariation['product_details'] as Map<String, dynamic>?;
        if (productDetails != null) {
          final images = productDetails['images'] as List?;
          if (images != null && images.isNotEmpty) {
            final firstImage = images[0] as Map<String, dynamic>?;
            if (firstImage != null && firstImage['image'] != null) {
              final imagePath = firstImage['image'].toString();
              if (imagePath.isNotEmpty) {
                final baseUrl = const String.fromEnvironment(
                  'API_BASE_URL',
                  defaultValue: 'http://192.81.218.80:6060',
                );
                return '$baseUrl$imagePath';
              }
            }
          }
        }
      }
    }
    
    // Check product image
    final product = sale['product'] as Map<String, dynamic>?;
    if (product != null && product['image'] != null) {
      final imagePath = product['image'].toString();
      if (imagePath.isNotEmpty) {
        final baseUrl = const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://192.81.218.80:6060',
        );
        return '$baseUrl$imagePath';
      }
    }
    
    return null;
  }

  String _getProductName() {
    final product = sale['product'] as Map<String, dynamic>?;
    return product?['name']?.toString() ?? 'Без названия';
  }

  String _formatDate(String dateStr) {
    try {
      // Parse date in format "01/09/2025"
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = parts[0].padLeft(2, '0');
        final month = parts[1].padLeft(2, '0');
        final year = parts[2];
        return '$day.$month.$year';
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final fallbackBgColor = isDark ? const Color(0xFF222222) : Colors.grey[200]!;
    final fallbackTextColor = isDark ? Colors.white : Colors.black87;
    
    final factPlannedTransactions = sale['fact_planned_transactions'] as List? ?? [];
    final total = sale['total'] ?? 0;
    final paid = sale['paid'] ?? 0;
    final remainder = sale['remainder'] ?? 0;
    final debet = sale['debet_0'] ?? 0;
    final imageUrl = _getProductImageUrl();
    final hasImage = imageUrl != null;
    final productName = _getProductName();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'Детали договора ',
          style: GoogleFonts.poppins(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              height: 330.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: hasImage
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            ProductCardHelpers.fallbackImage(
                          productName,
                          fallbackBgColor,
                          fallbackTextColor,
                          height: 330.h,
                        ),
                      )
                    : ProductCardHelpers.fallbackImage(
                        productName,
                        fallbackBgColor,
                        fallbackTextColor,
                        height: 330.h,
                      ),
              ),
            ),

            SizedBox(height: 24.h),

            // Product Name
            Text(
              productName,
              style: GoogleFonts.poppins(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),

            SizedBox(height: 24.h),

            // Financial Summary
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Финансовая информация',
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildInfoRow('Общая сумма', _formatSum(total), textColor, context),
                  SizedBox(height: 12.h),
                  _buildInfoRow('Оплачено', _formatSum(paid), Colors.green, context),
                  SizedBox(height: 12.h),
                  _buildInfoRow('Остаток', _formatSum(remainder), Colors.orange, context),
                  SizedBox(height: 12.h),
                  _buildInfoRow('Задолженность', _formatSum(debet), textColor, context),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Payment Schedule Table
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'График платежей',
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  
                  // Table
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      children: [
                        // Header
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Месяц',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Дата',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Сумма',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 16.h),
                        
                        // Rows
                        ...factPlannedTransactions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final transaction = entry.value as Map<String, dynamic>;
                          final date = transaction['date']?.toString() ?? '';
                          final amount = transaction['amount'] ?? 0;
                          final isPaid = transaction['is_paid'] == true;
                          
                          return Container(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                    children: [
                                      if (isPaid)
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 20.w,
                                        )
                                      else
                                        SizedBox(width: 20.w),
                                      SizedBox(width: 8.w),
                                      Text(
                                        '${index + 1}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14.sp,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatDate(date),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      color: textColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (amount != 0 && amount != 0.0)
                                        Text(
                                          _formatSum(amount),
                                          style: GoogleFonts.poppins(
                                            fontSize: 14.sp,
                                            fontWeight: isPaid
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: isPaid ? Colors.green : textColor,
                                          ),
                                        ),
                                      if (isPaid || amount == 0 || amount == 0.0) ...[
                                        if (amount != 0 && amount != 0.0) SizedBox(width: 8.w),
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 20.w,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

