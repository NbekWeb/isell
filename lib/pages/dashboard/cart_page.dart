import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/cart_service.dart';
import '../../services/myid_service.dart';
import '../../services/product_services.dart';
// import '../../services/api_service.dart'; // TODO: Uncomment when backend is ready
import '../../widgets/custom_toast.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();

  static void refresh(BuildContext? context) {
    if (context != null) {
      final state = context.findAncestorStateOfType<_CartPageState>();
      state?.refreshCart();
    }
  }
}

class _CartPageState extends State<CartPage>
    with RouteAware, WidgetsBindingObserver {
  List<Map<String, dynamic>> cartItems = [];
  bool _isLoading = true;
  bool _isProcessingOrder = false;
  
  // Calculation mode: true = Simple, false = Complex
  bool _isSimpleMode = true;
  
  // Tariff data
  List<Map<String, dynamic>> _tariffs = [];
  Map<String, dynamic>? _selectedGlobalTariff;
  double _globalDownPayment = 0.0;
  
  // Complex mode values (stored per item)
  Map<String, Map<String, dynamic>?> _itemTariffs = {};
  Map<String, double> _itemDownPayments = {};

  @override
  void initState() {
    super.initState();
    _loadCartItems();
    _fetchTariffs();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCartItems();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh cart when page becomes visible (when navigating back from other pages)
    // Use a small delay to avoid too frequent updates during initial build
    Future.microtask(() {
      if (mounted) {
        _loadCartItems();
      }
    });
  }

  void refreshCart() {
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    setState(() {
      _isLoading = true;
    });
    final items = await CartService.getCartItems();
    setState(() {
      cartItems = items;
      _isLoading = false;
    });
  }

  Future<void> _fetchTariffs() async {
    try {
      final tariffs = await ProductServices.getTariffs();
      setState(() {
        _tariffs = tariffs;
        // Set default tariff (prioritize "Без рассрочки", then "1 month")
        if (tariffs.isNotEmpty) {
          try {
            _selectedGlobalTariff = tariffs.firstWhere((tariff) => tariff['payments_count'] == 0);
          } catch (e) {
            try {
              _selectedGlobalTariff = tariffs.firstWhere((tariff) => tariff['payments_count'] == 1);
            } catch (e) {
              _selectedGlobalTariff = tariffs.first;
            }
          }
        }
      });
    } catch (e) {
      print('❌ Error fetching tariffs: $e');
    }
  }

  bool _isUsedProduct(Map<String, dynamic> item) {
    // Cart item-da isUsed flagini tekshirish
    final isUsed = item['isUsed'] == true;
    
    // Agar isUsed flag yo'q bo'lsa, product nomidan tekshirish (fallback)
    if (item['isUsed'] == null) {
      final productName = (item['name'] ?? '').toString().toLowerCase();
      final hasUsedPattern = productName.contains('b/u') || 
                            productName.contains('б/у') ||
                            productName.contains('б.у') ||
                            productName.contains('b.u');
      return hasUsedPattern;
    }
    
    return isUsed;
  }

  Future<void> _updateQuantity(String uniqueId, int delta) async {
    final item = cartItems.firstWhere((item) => item['uniqueId'] == uniqueId);
    final currentQuantity = item['quantity'] as int;
    final newQuantity = currentQuantity + delta;
    final isUsed = _isUsedProduct(item);

    // Ishlatilgan mahsulotlar uchun miqdorni 1 ga cheklash
    if (isUsed && newQuantity > 1) {
      CustomToast.show(
        context,
        message: 'Б/у товар можно добавить только в количестве 1 штуки',
        isSuccess: false,
      );
      return;
    }

    if (newQuantity <= 0) {
      await CartService.removeFromCart(uniqueId);
    } else {
      await CartService.updateQuantity(uniqueId, newQuantity);
    }

    await _loadCartItems();
  }

  Future<void> _removeItem(String uniqueId) async {
    await CartService.removeFromCart(uniqueId);
    await _loadCartItems();
  }

  String _formatTariffName(String name) {
    // Handle "No installment" case
    if (name.toLowerCase() == 'no installment') {
      return 'Без рассрочки';
    }
    
    // Handle month + days format like "12m (+15d)"
    if (name.contains('m') && name.contains('(') && name.contains('d)')) {
      final regex = RegExp(r'(\d+)m \(\+(\d+)d\)');
      final match = regex.firstMatch(name);
      if (match != null) {
        final months = match.group(1);
        final days = match.group(2);
        return '$months мес (+${days}д)';
      }
    }
    
    // Handle simple month format like "12m"
    if (name.contains('m') && !name.contains('(')) {
      final monthsMatch = RegExp(r'(\d+)m').firstMatch(name);
      if (monthsMatch != null) {
        final months = monthsMatch.group(1);
        return '$months мес';
      }
    }
    
    // Handle days only format like "15d"
    if (name == '15d') {
      return '15 дней';
    }
    
    // Return original name if no pattern matches
    return name;
  }

  double _calculateTotal() {
    return cartItems.fold(0.0, (sum, item) {
      final price = _parsePriceValue(item['price']);
      final quantity = item['quantity'] is int
          ? item['quantity'] as int
          : int.tryParse(item['quantity'].toString()) ?? 0;
      return sum + (price * quantity);
    });
  }

  double _parsePriceValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();

    final str = value
        .toString()
        .trim()
        .replaceAll(',', '.')
        .replaceAll(' ', '');
    if (str.isEmpty) return 0.0;

    final doubleValue = double.tryParse(str);
    if (doubleValue != null) return doubleValue;

    final sanitized = str.replaceAll(RegExp(r'[^\d.]'), '');
    if (sanitized.isEmpty) return 0.0;
    return double.tryParse(sanitized) ?? 0.0;
  }

  String _formatUsdAmount(double usdValue) {
    final isWhole = usdValue == usdValue.roundToDouble();
    final formattedValue = isWhole
        ? usdValue.round().toString()
        : usdValue.toStringAsFixed(2);
    final parts = formattedValue.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : null;
    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      if (i != 0 && (integerPart.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(integerPart[i]);
    }
    return decimalPart != null
        ? '\$${buffer.toString()}.$decimalPart'
        : '\$${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark
        ? Colors.white.withOpacity(0.1)
        : (Colors.grey[300] ?? Colors.grey);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: const CircularProgressIndicator(
                  color: Color(0xFF1B7EFF),
                ),
              )
            : cartItems.isEmpty
            ? _buildEmptyCart(isDark, textColor)
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildModeToggle(textColor, cardColor),
                    _buildCartWithItems(
                      textColor,
                      cardColor,
                      borderColor,
                      dividerColor,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildModeToggle(Color textColor, Color cardColor) {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Режим расчета',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          Row(
            children: [
              Text(
                'Простой',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: _isSimpleMode ? const Color(0xFF4E63EC) : textColor,
                ),
              ),
              SizedBox(width: 8.w),
              Switch(
                value: !_isSimpleMode, // Switch is ON for complex mode
                onChanged: (bool value) {
                  setState(() {
                    _isSimpleMode = !value;
                  });
                },
                activeColor: const Color(0xFF4E63EC),
                activeTrackColor: const Color(0xFF4E63EC).withOpacity(0.3),
              ),
              SizedBox(width: 8.w),
              Text(
                'Сложный',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: !_isSimpleMode ? const Color(0xFF4E63EC) : textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleModeCalculation(Color textColor, Color cardColor) {
    final total = _calculateTotal();
    final monthlyPayment = _calculateMonthlyPaymentFromTariff(total, _selectedGlobalTariff, _globalDownPayment);
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Общий первоначальный взнос',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          
          // Down Payment Input
          TextFormField(
            initialValue: _globalDownPayment.toString(),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '0',
              suffixText: 'сум',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _globalDownPayment = double.tryParse(value) ?? 0.0;
              });
            },
          ),
          
          SizedBox(height: 16.h),
          
          Text(
            'Будет распределен между товарами пропорционально их стоимости',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              color: textColor.withOpacity(0.7),
            ),
          ),
          
          SizedBox(height: 20.h),
          
          Text(
            'Срок рассрочки',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          
          // Tariff Dropdown
          DropdownButtonFormField<Map<String, dynamic>>(
            value: _selectedGlobalTariff,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            items: _tariffs.map((tariff) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: tariff,
                child: Text(_formatTariffName(tariff['name'] ?? '')),
              );
            }).toList(),
            onChanged: (Map<String, dynamic>? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedGlobalTariff = newValue;
                });
              }
            },
          ),
          
          SizedBox(height: 20.h),
          
          // Summary
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1B7EFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Итого',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                _buildSummaryRow('Стоимость товаров:', _formatUsdAmount(total), textColor),
                _buildSummaryRow('Первоначальный взнос:', '${_globalDownPayment.toStringAsFixed(0)} сум', textColor),
                _buildSummaryRow('Общий ежемесячный платеж:', '${monthlyPayment.toStringAsFixed(0)} сум', textColor, isHighlighted: true),
                if (_globalDownPayment > 0)
                  _buildSummaryRow('Минимальный взнос:', '${(total * 0.1).toStringAsFixed(0)} сум', textColor.withOpacity(0.7)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplexModeCalculation(Color textColor, Color cardColor) {
    // Get the first item's tariff as global for complex mode
    final firstItemId = cartItems.isNotEmpty ? cartItems.first['uniqueId'] as String : '';
    Map<String, dynamic>? globalTariff = _itemTariffs[firstItemId];
    if (globalTariff == null && _tariffs.isNotEmpty) {
      globalTariff = _tariffs.first;
      _itemTariffs[firstItemId] = globalTariff;
    }
    final globalDownPayment = _itemDownPayments[firstItemId] ?? 0.0;
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Down Payment Section
          Text(
            'Первоначальный взнос',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          TextFormField(
            initialValue: globalDownPayment == 0.0 ? '' : globalDownPayment.toStringAsFixed(0),
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            decoration: InputDecoration(
              hintText: '500000',
              hintStyle: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: const Color(0xFF4E63EC)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            ),
            onChanged: (value) {
              setState(() {
                // Apply the same down payment to all items in complex mode
                final downPayment = double.tryParse(value) ?? 0.0;
                for (final item in cartItems) {
                  final uniqueId = item['uniqueId'] as String;
                  _itemDownPayments[uniqueId] = downPayment;
                }
              });
            },
          ),
          
          SizedBox(height: 20.h),
          
          // Tariff Section
          Text(
            'Срок рассрочки',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          GestureDetector(
            onTap: () => _showTariffModal(context, firstItemId, globalTariff),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    globalTariff != null ? _formatTariffName(globalTariff['name'] ?? '') : '6 месяц',
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: textColor,
                    size: 24.sp,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color textColor, {double? fontSize, bool isHighlighted = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: fontSize ?? 14.sp,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
              color: textColor,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: fontSize ?? 14.sp,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
              color: isHighlighted ? const Color(0xFF1B7EFF) : textColor,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateMonthlyPaymentFromTariff(double total, Map<String, dynamic>? tariff, double downPayment) {
    if (tariff == null) return 0.0;
    
    final remainingAmount = total - downPayment;
    final paymentsCount = tariff['payments_count'] as int? ?? 1;
    
    // If payments_count is 0, it means "No installment" - full payment upfront
    if (paymentsCount == 0) {
      return remainingAmount; // Full amount as single payment
    }
    
    return remainingAmount / paymentsCount;
  }

  double _calculateMonthlyPayment(double total, String tariff, double downPayment) {
    final remainingAmount = total - downPayment;
    final months = int.tryParse(tariff.split(' ')[0]) ?? 6;
    return remainingAmount / months;
  }

  void _showTariffModal(BuildContext context, String uniqueId, Map<String, dynamic>? currentTariff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final backgroundColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.r),
              topRight: Radius.circular(20.r),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 8.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              
              // Header
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Выберите тариф',
                      style: GoogleFonts.poppins(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tariff List
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  itemCount: _tariffs.length,
                  itemBuilder: (context, index) {
                    final tariff = _tariffs[index];
                    final isSelected = currentTariff != null && 
                        currentTariff['id'] == tariff['id'];
                    
                    return Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected 
                              ? const Color(0xFF4E63EC) 
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w, 
                          vertical: 8.h,
                        ),
                        title: Text(
                          _formatTariffName(tariff['name'] ?? ''),
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                            color: isSelected 
                                ? const Color(0xFF4E63EC) 
                                : textColor,
                          ),
                        ),
                        subtitle: tariff['payments_count'] > 0 
                            ? Text(
                                '${tariff['payments_count']} платежей',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  color: Colors.grey[600],
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: const Color(0xFF4E63EC),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _itemTariffs[uniqueId] = tariff;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyCart(bool isDark, Color textColor) {
    final circleColor = isDark
        ? const Color(0xFF333333)
        : (Colors.grey[200] ?? Colors.grey);
    final subtitleColor = isDark
        ? textColor.withOpacity(0.7)
        : textColor.withOpacity(0.6);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 108.w,
            height: 108.w,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.lock_outline,
                size: 44.w,
                color: const Color(0xFF2196F3),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Корзина пуста',
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            'Добавьте товары из каталога',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              color: subtitleColor,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCartWithItems(
    Color textColor,
    Color cardColor,
    Color borderColor,
    Color dividerColor,
  ) {
    final total = _calculateTotal();
    final itemCount = cartItems.length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cart Items
          ...cartItems.map((item) {
            return _buildCartItem(
              item,
              textColor,
              cardColor,
              borderColor,
            );
          }),
          
          // Calculation Section
          if (_isSimpleMode) 
            _buildSimpleModeCalculation(textColor, cardColor)
          else
            _buildComplexModeCalculation(textColor, cardColor),
          
          SizedBox(height: 24.h),
          // Order Button (not fixed)
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              onPressed: _isProcessingOrder ? null : _handlePlaceOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B7EFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: _isProcessingOrder
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Оформить',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          
          SizedBox(height: 32.h), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildCartItem(
    Map<String, dynamic> item,
    Color textColor,
    Color cardColor,
    Color borderColor,
  ) {
    final uniqueId = item['uniqueId'] as String;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor.withOpacity(0.2), width: 1),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // First Row: Image, Name, Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: _buildCartImage(item['image'], backgroundColor),
                  ),
                  SizedBox(width: 12.w),
                  // Product Details
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: 40.w,
                      ), // Space for delete icon
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_variantDescription(item).isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              _variantDescription(item),
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                color: textColor.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          SizedBox(height: 4.h),
                          Text(
                            _formatUsdAmount(_parsePriceValue(item['price'])),
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              // Second Row: Quantity Control (centered)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minus Button
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: borderColor, width: 1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => _updateQuantity(uniqueId, -1),
                      icon: Icon(Icons.remove, color: textColor, size: 18.w),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // Quantity Display
                  Text(
                    '${item['quantity']}',
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // Plus Button
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: borderColor, width: 1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isUsedProduct(item) && (item['quantity'] as int) >= 1
                          ? null // Ishlatilgan mahsulot uchun o'chirish
                          : () => _updateQuantity(uniqueId, 1),
                      icon: Icon(
                        Icons.add, 
                        color: _isUsedProduct(item) && (item['quantity'] as int) >= 1
                            ? textColor.withOpacity(0.3)
                            : textColor, 
                        size: 18.w
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Delete Button - Top Right
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: () => _removeItem(uniqueId),
              icon: Icon(Icons.delete_outline, color: Colors.red, size: 24.w),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartImage(dynamic image, Color backgroundColor) {
    final imageUrl = image?.toString();

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 80.w,
        height: 80.w,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8.r),
        ),
      );
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: 80.w,
        height: 80.w,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 80.w,
          height: 80.w,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
    }

    return Image.asset(
      imageUrl,
      width: 80.w,
      height: 80.w,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: 80.w,
        height: 80.w,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
    );
  }

  String _variantDescription(Map<String, dynamic> item) {
    final parts = <String>[];
    final color = item['selectedColor']?.toString();
    final storage = item['selectedStorage']?.toString();
    final sim = item['selectedSim']?.toString();

    if (color != null && color.isNotEmpty) {
      parts.add(color);
    }
    if (storage != null && storage.isNotEmpty) {
      parts.add(storage);
    }
    if (sim != null && sim.isNotEmpty) {
      parts.add(sim);
    }

    return parts.join(' • ');
  }

  Future<void> _handlePlaceOrder() async {
    if (cartItems.isEmpty) {
      CustomToast.show(context, message: 'Корзина пуста', isSuccess: false);
      return;
    }

    if (_isProcessingOrder) {
      return;
    }

    setState(() {
      _isProcessingOrder = true;
    });

    try {
      // Step 1: Get session ID from MyID API directly
      print('🔵 Step 1: Getting session ID from MyID API...');
      String sessionId;

      // Option 1: From YOUR backend (commented out)
      // try {
      //   final response = await ApiService.request(
      //     url: 'accounts/myid/session/',
      //     method: 'POST',
      //     data: {
      //       'phone_number': '998770580502', // Optional
      //       'birth_date': '2003-05-02', // Optional
      //       'pinfl': '50205035360010', // Optional
      //       'pass_data': 'AC2190972', // Optional
      //     },
      //   );
      //   if (response.data != null &&
      //       response.data['success'] == true &&
      //       response.data['data'] != null &&
      //       response.data['data']['session_id'] != null) {
      //     sessionId = response.data['data']['session_id'] as String;
      //     print('✅ Session ID obtained from backend: $sessionId');
      //   } else {
      //     throw Exception('Session ID not found in backend response');
      //   }
      // } catch (e) {
      //   print('⚠️ Backend endpoint not available. Using direct MyID API...');
      // }

      // Option 2: Directly from MyID API (using now)
      try {
        // All parameters are optional - SDK will ask user if not provided
        sessionId = await MyIdService.getSessionId(
          // phoneNumber: '998770580502', // Optional
          // birthDate: '2003-05-02', // Optional
          // pinfl: '50205035360010', // Optional
          // passData: 'AC2190972', // Optional
        );
        print('✅ Session ID obtained from MyID API: $sessionId');
      } catch (apiError) {
        print('❌ Failed to get session ID from MyID API: $apiError');
        throw Exception('Failed to get session ID from MyID API: ${apiError.toString()}');
      }

      // Step 2: Start MyID SDK with session_id from backend
      // SDK will:
      //   1. Open camera
      //   2. Capture image (face detection, passport scan)
      //   3. Send image to MyID servers for verification
      //   4. Return code (authorization code)
      print('🚀 Step 2: Starting MyID SDK with session ID: $sessionId');
      print(
        '📸 SDK will open camera, capture image, and send to MyID servers for verification',
      );

      // Debug: Print session ID details
      print('🔍 Session ID details:');
      print('   - sessionId: $sessionId');
      print('   - sessionId length: ${sessionId.length}');
      print('   - clientHashId: ${MyIdService.clientHashId}');

      // Start SDK immediately - session expires quickly, no delay needed
      // Backend is on dev server, so use debug environment
      final result = await MyIdService.startAuthentication(
        sessionId: sessionId,
        clientHash: MyIdService.clientHash,
        clientHashId: MyIdService.clientHashId,
        environment: 'debug', // Backend is on dev server (http://192.81.218.80:6060)
        entryType: 'identification',
        locale: 'russian',
      );

      // Step 3: SDK returned code (image was captured and verified by MyID servers)
      if (result.code != null) {
        print('✅ Step 3: MyID SDK - Authentication successful');
        print('📋 Code received: ${result.code}');
        print('📸 Image: ${result.image != null ? "present" : "null"}');
        print('🔢 Comparison value: ${result.comparisonValue}');

        CustomToast.show(
          context,
          message: 'Авторизация успешна. Оформление заказа...',
          isSuccess: true,
        );

        // Step 4: Show debug page with code and access token for backend testing
        print('📤 Step 4: Navigating to debug page...');
        try {
          // Get fresh access token for backend testing
          final accessToken = await MyIdService.getAccessToken();
          
          print('✅ Access token obtained for debug page');
          print('📋 Code: ${result.code}');
          print('🔑 Access Token: ${accessToken.substring(0, 20)}...');
          
          CustomToast.show(
            context,
            message: 'Авторизация успешна. Переход к отладочной странице...',
            isSuccess: true,
          );
          
          // Show success message
          CustomToast.show(
            context,
            message: 'MyID верификация успешна!',
            isSuccess: true,
          );
          
          // TODO: When backend is ready, replace debug page with actual order processing:
          // final userData = await MyIdService.getUserDataByCode(result.code!);
          // final orderResponse = await ApiService.request(
          //   url: 'order/place/',
          //   method: 'POST',
          //   data: {
          //     'cart_items': cartItems.map(...).toList(),
          //     'user_data': userData,
          //     'myid_code': result.code,
          //     'myid_image': result.image,
          //   },
          // );
          
        } catch (e) {
          print('❌ Error getting access token: $e');
          CustomToast.show(
            context,
            message: 'Ошибка при получении токена: ${e.toString()}',
            isSuccess: false,
          );
        }
      }
    } on MyIdException catch (e) {
      String errorMessage = 'Ошибка авторизации';

      // Handle specific error codes
      switch (e.code) {
        case '102':
          errorMessage = 'Доступ к камере запрещен';
          break;
        case '103':
          errorMessage = 'Ошибка при получении данных';
          break;
        case '122':
          errorMessage = 'Пользователь заблокирован';
          break;
        case 'USER_EXITED':
          errorMessage = 'Авторизация отменена';
          break;
        default:
          errorMessage = e.message;
      }

      CustomToast.show(context, message: errorMessage, isSuccess: false);
    } catch (e) {
      CustomToast.show(
        context,
        message: 'Произошла ошибка: ${e.toString()}',
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOrder = false;
        });
      }
    }
  }
}
