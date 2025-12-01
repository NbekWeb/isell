import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/order_services.dart';
import '../../components/product_card.dart';
import '../../widgets/custom_toast.dart';
import 'agreement_detail_page.dart';

class AgreementsPage extends StatefulWidget {
  const AgreementsPage({super.key});

  @override
  State<AgreementsPage> createState() => _AgreementsPageState();
}

class _AgreementsPageState extends State<AgreementsPage> {
  int _selectedTab = 0; // 0 = Active, 1 = Completed
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeSales = [];
  List<Map<String, dynamic>> _completedSales = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await OrderServices.getMyOrders();
      if (response != null) {
        setState(() {
          _activeSales = (response['active_sales'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e))
                  .toList() ??
              [];
          _completedSales = (response['completed_sales'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e))
                  .toList() ??
              [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading orders: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Ошибка загрузки договоров',
          isSuccess: false,
        );
      }
    }
  }

  String _formatSum(dynamic value) {
    if (value == null) return '\$0';
    final numValue = value is num ? value : double.tryParse(value.toString()) ?? 0;
    final formatted = numValue.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '\$$formatted';
  }

  String? _getProductImageUrl(Map<String, dynamic> sale) {
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
                // Get base URL from ApiService
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

  String _getProductName(Map<String, dynamic> sale) {
    final product = sale['product'] as Map<String, dynamic>?;
    return product?['name']?.toString() ?? 'Без названия';
  }

  String _getContractDate(Map<String, dynamic> sale) {
    // Try to get date from first transaction
    final transactions = sale['transactions'] as List?;
    if (transactions != null && transactions.isNotEmpty) {
      final firstTransaction = transactions[0] as Map<String, dynamic>?;
      if (firstTransaction != null && firstTransaction['date'] != null) {
        return firstTransaction['date'].toString();
      }
    }
    
    // Try fact_planned_transactions
    final factPlanned = sale['fact_planned_transactions'] as List?;
    if (factPlanned != null && factPlanned.isNotEmpty) {
      final first = factPlanned[0] as Map<String, dynamic>?;
      if (first != null && first['date'] != null) {
        return first['date'].toString();
      }
    }
    
    return DateTime.now().toString().split(' ')[0];
  }

  String _getContractId(Map<String, dynamic> sale, int index) {
    // Try to get ID from variation_list
    final variationList = sale['variation_list'] as List?;
    if (variationList != null && variationList.isNotEmpty) {
      final firstVariation = variationList[0] as Map<String, dynamic>?;
      if (firstVariation != null && firstVariation['id'] != null) {
        return '#RACT-${firstVariation['id']}';
      }
    }
    return '#RACT-${index + 1}';
  }

  double _getProgressPercentage(Map<String, dynamic> sale) {
    final total = (sale['total'] as num?)?.toDouble() ?? 0.0;
    final paid = (sale['paid'] as num?)?.toDouble() ?? 0.0;
    if (total == 0) return 0.0;
    return (paid / total * 100).clamp(0.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final fallbackBgColor = isDark ? const Color(0xFF222222) : Colors.grey[200]!;
    final fallbackTextColor = isDark ? Colors.white : Colors.black87;
    final cardBorderColor = isDark ? const Color(0xFF333333) : const Color(0xFFF4F5F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFF1B7EFF),
                ),
              )
            : (_selectedTab == 0 ? _activeSales : _completedSales).isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 108.w,
                          height: 108.w,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF333333)
                                : Colors.grey[200]!,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.description_outlined,
                              size: 44.w,
                              color: const Color(0xFF2196F3),
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          'Договор нет',
                          style: GoogleFonts.poppins(
                            fontSize: 20.sp,
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                  
                    // Tabs
                    SliverToBoxAdapter(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 0;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 0
                                        ? cardColor
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Text(
                                    'Активные (${_activeSales.length})',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedTab == 0
                                          ? const Color(0xFF1B7EFF)
                                          : textColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 1;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 1
                                        ? cardColor
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Text(
                                    'Завершённые (${_completedSales.length})',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedTab == 1
                                          ? const Color(0xFF1B7EFF)
                                          : textColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Content
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final sale = _selectedTab == 0
                                ? _activeSales[index]
                                : _completedSales[index];
                            final isCompleted = _selectedTab == 1;
                            final contractDate = _getContractDate(sale);
                            final contractId = _getContractId(sale, index);
                            final productName = _getProductName(sale);
                            final imageUrl = _getProductImageUrl(sale);
                            final hasImage = imageUrl != null;
                            final total = sale['total'] ?? 0;
                            final paid = sale['paid'] ?? 0;
                            final remainder = sale['remainder'] ?? 0;
                            final debet = sale['debet_0'] ?? 0;
                            final progress = _getProgressPercentage(sale);

                            return Container(
                              margin: EdgeInsets.only(bottom: 16.h),
                              decoration: BoxDecoration(
                                color: cardColor,
                                border: Border.all(
                                  color: cardBorderColor,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Padding(
                                    padding: EdgeInsets.all(16.w),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Договор от ${_formatDate(contractDate)}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14.sp,
                                                color: textColor.withOpacity(0.7),
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              contractId,
                                              style: GoogleFonts.poppins(
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                            vertical: 6.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isCompleted
                                                ? const Color(0xFFFFEDED)
                                                : const Color(0xFFDCFCE7),
                                            borderRadius:
                                                BorderRadius.circular(8.r),
                                          ),
                                          child: Text(
                                            isCompleted
                                                ? 'Завершено'
                                                : 'Активный',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                              color: isCompleted
                                                  ? const Color(0xFFFF0000)
                                                  : const Color(0xFF23734B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Product Image
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20.h),
                                    child: Center(
                                      child: SizedBox(
                                        height: 300.h,
                                        child: hasImage
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(16.r),
                                                child: Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) =>
                                                      ProductCardHelpers
                                                          .fallbackImage(
                                                    productName,
                                                    fallbackBgColor,
                                                    fallbackTextColor,
                                                    height: 300.h,
                                                  ),
                                                ),
                                              )
                                            : ProductCardHelpers.fallbackImage(
                                                productName,
                                                fallbackBgColor,
                                                fallbackTextColor,
                                                height: 200.h,
                                              ),
                                      ),
                                    ),
                                  ),

                                  // Financial Info
                                  Padding(
                                    padding: EdgeInsets.all(16.w),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Общая сумма va Оплачено tagma tag
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Общая сумма',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14.sp,
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                Text(
                                                  _formatSum(total),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: textColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8.h),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Оплачено',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14.sp,
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                Text(
                                                  _formatSum(paid),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 16.h),
                                        Container(
                                          height: 1,
                                          color: isDark
                                              ? Colors.white.withOpacity(0.1)
                                              : Colors.grey[300],
                                        ),
                                        SizedBox(height: 16.h),
                                        _buildInfoRow(
                                          'Остаток',
                                          _formatSum(remainder),
                                          Colors.orange,
                                        ),
                                        SizedBox(height: 8.h),
                                        _buildInfoRow(
                                          'Задолженность',
                                          _formatSum(debet),
                                          textColor,
                                        ),
                                        SizedBox(height: 16.h),

                                        // Progress
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Прогресс оплаты',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14.sp,
                                                color: textColor,
                                              ),
                                            ),
                                            Text(
                                              '${progress.toStringAsFixed(0)}%',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8.h),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4.r),
                                          child: LinearProgressIndicator(
                                            value: progress / 100,
                                            minHeight: 8.h,
                                            backgroundColor: isDark
                                                ? Colors.grey[800]
                                                : Colors.grey[300],
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Details Button
                                  Padding(
                                    padding: EdgeInsets.all(16.w),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 50.h,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  AgreementDetailPage(
                                                sale: sale,
                                                isCompleted: isCompleted,
                                              ),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF1B7EFF),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12.r),
                                          ),
                                        ),
                                        child: Text(
                                          'Подробно',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: _selectedTab == 0
                              ? _activeSales.length
                              : _completedSales.length,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
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
}
