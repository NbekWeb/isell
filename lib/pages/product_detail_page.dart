import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../components/product_card.dart';
import '../components/product_detail_sections.dart';
import '../services/product_services.dart';
import '../services/cart_service.dart';
import '../widgets/custom_toast.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Map<String, dynamic> _currentProduct;
  String? selectedColor;
  String? selectedStorage;
  String? selectedSimCard;
  int downPayment = 0;
  String installmentPeriod = '6 месяц';
  bool _isLoadingFilter = false;

  List<Map<String, dynamic>> _colorOptions = [];
  List<Map<String, dynamic>> _storageOptions = [];
  List<Map<String, dynamic>> _simOptions = [];
  List<Map<String, dynamic>> _tariffs = [];
  String? _selectedTariffId;
  int? _productId;
  int _cartQuantity = 0;
  String? _cartUniqueId;
  Timer? _calculateDebounce;

  @override
  void initState() {
    super.initState();
    _currentProduct = Map<String, dynamic>.from(widget.product);
    _productId = _parseProductId(_currentProduct['product_id']);
    
    _hydrateOptions(fromApi: false);
    _loadProductIdAndFilter();
    _fetchTariffs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCartState();
    });
  }

  @override
  void dispose() {
    _calculateDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadProductIdAndFilter() async {
    // Always use the product ID from the widget, not from SharedPreferences
    _productId = _parseProductId(widget.product['product_id']);
    
    // Clear any stored product_id to prevent conflicts
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_product_id');

    if (_productId != null) {
      await _fetchProductFilter(_productId!);
    }
  }

  Future<void> _fetchProductFilter(int productId) async {
    setState(() {
      _isLoadingFilter = true;
    });

    try {
      final result = await ProductServices.getProductFilter(
        productId: productId,
        colorName: selectedColor,
        storageName: selectedStorage,
        simCardName: selectedSimCard,
      );

      if (result != null && mounted) {
        setState(() {
          // Preserve the original product_id and verify API response consistency
          final originalProductId = _currentProduct['product_id'];
          final resultProductId = result['product_id'] ?? result['id'];
          
          // Only update if the API returned data for the correct product
          if (originalProductId != null &&
              resultProductId != null &&
              originalProductId.toString() == resultProductId.toString()) {
            _currentProduct = Map<String, dynamic>.from(result);
            _currentProduct['product_id'] = originalProductId;
            _hydrateOptions();
          } else {
            // Still update options if they exist in the response
            if (result['filter_options'] != null) {
              _currentProduct['filter_options'] = result['filter_options'];
              _hydrateOptions();
            }
          }
          _isLoadingFilter = false;
        });
      } else {
        setState(() {
          _isLoadingFilter = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFilter = false;
        });
      }
    }

    await _syncCartState();
  }

  Future<void> _fetchTariffs() async {
    try {
      final tariffs = await ProductServices.getTariffs();
      if (mounted) {
        setState(() {
          _tariffs = tariffs;
          // Set default tariff (try to find a simple one that works with backend)
          if (_tariffs.isNotEmpty) {
            Map<String, dynamic>? defaultTariff;
            
            // Try to find "No installment" first (most likely to work)
            try {
              defaultTariff = _tariffs.firstWhere(
                (t) =>
                    t['name'] == 'No installment' || t['payments_count'] == 0,
              );
            } catch (e) {
              // Not found, try simple monthly tariffs without offset days
              try {
                defaultTariff = _tariffs.firstWhere(
                  (t) =>
                      t['payments_count'] == 1 &&
                      (t['offset_days'] == null || t['offset_days'] == 0),
            );
              } catch (e) {
                // If still not found, use the last tariff (likely to be "No installment")
                defaultTariff = _tariffs.last;
              }
            }
            
            _selectedTariffId = defaultTariff['id'].toString();
          
          }
        });
        
        // Trigger initial calculation
        _calculateMonthlyPaymentWithDebounce();
      }
    } catch (e) {
      print('❌ Error fetching tariffs: $e');
    }
  }

  void _calculateMonthlyPaymentWithDebounce() {
    _calculateDebounce?.cancel();
    _calculateDebounce = Timer(const Duration(milliseconds: 500), () {
      _calculateMonthlyPayment();
    });
  }

  Future<void> _calculateMonthlyPayment() async {
    final productId = _currentProductIdAsString();
    if (productId == null || _selectedTariffId == null) {
      return;
    }

    final tariffId = int.tryParse(_selectedTariffId!);
    if (tariffId == null) {
      return;
    }

    try {
      final variationId = _getCurrentVariationId();
      
      await ProductServices.calculateMonthlyPayment(
        productId: productId,
        advancePayment: downPayment,
        tariffId: tariffId,
        variationId: variationId,
      );
    } catch (e) {
      print('❌ Error calculating monthly payment: $e');
    }
  }

  Future<void> _syncCartState() async {
    final productId = _currentProductIdAsString();
    if (productId == null) {
      if (_cartQuantity != 0 || _cartUniqueId != null) {
        if (!mounted) return;
        setState(() {
          _cartQuantity = 0;
          _cartUniqueId = null;
        });
      }
      return;
    }

    final items = await CartService.getCartItems();
    Map<String, dynamic>? matchedItem;
    final targetColor = selectedColor ?? '';
    final targetStorage = selectedStorage ?? '';
    final targetSim = selectedSimCard ?? '';

    for (final rawItem in items) {
      final item = Map<String, dynamic>.from(rawItem);
      final itemId = item['id']?.toString();
      if (itemId != productId) continue;

      final itemColor = item['selectedColor']?.toString() ?? '';
      final itemStorage = item['selectedStorage']?.toString() ?? '';
      final itemSim = item['selectedSim']?.toString() ?? '';

      if (itemColor == targetColor &&
          itemStorage == targetStorage &&
          itemSim == targetSim) {
        matchedItem = item;
        break;
      }
    }

    final newQuantity = _extractQuantityFromItem(matchedItem);
    final newUniqueId = matchedItem != null
        ? matchedItem['uniqueId']?.toString()
        : null;

    if (!mounted) return;

    if (_cartQuantity != newQuantity || _cartUniqueId != newUniqueId) {
      setState(() {
        _cartQuantity = newQuantity;
        _cartUniqueId = newUniqueId;
      });
    }
  }

  int _extractQuantityFromItem(Map<String, dynamic>? item) {
    if (item == null) return 0;
    final quantity = item['quantity'];
    if (quantity is int) return quantity;
    if (quantity is num) return quantity.toInt();
    if (quantity is String) return int.tryParse(quantity) ?? 0;
    return 0;
  }

  String? _currentProductIdAsString() {
    final idValue = _currentProduct['product_id'];
    final originalId = widget.product['product_id'];
    
    // Always prefer the original product ID from the widget
    if (originalId != null) {
      return originalId.toString();
    }
    
    if (idValue == null) return null;
    return idValue.toString();
  }

  int? _parseProductId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  void _hydrateOptions({bool fromApi = true}) {
    final previousColorOptions = List<Map<String, dynamic>>.from(_colorOptions);
    final previousStorageOptions = List<Map<String, dynamic>>.from(
      _storageOptions,
    );
    final previousSimOptions = List<Map<String, dynamic>>.from(_simOptions);

    _colorOptions = _extractOptionList(_currentProduct, 'color_list');
    _storageOptions = _extractOptionList(_currentProduct, 'storage_list');
    _simOptions = _extractOptionList(_currentProduct, 'sim_card_list');

    if (fromApi && _colorOptions.isEmpty && previousColorOptions.isNotEmpty) {
      _colorOptions = previousColorOptions;
    }
    if (fromApi &&
        _storageOptions.isEmpty &&
        previousStorageOptions.isNotEmpty) {
      _storageOptions = previousStorageOptions;
    }
    if (fromApi && _simOptions.isEmpty && previousSimOptions.isNotEmpty) {
      _simOptions = previousSimOptions;
    }

    if (fromApi) {
      selectedColor = _getInitialSelection(
        _colorOptions,
        'color_name',
        fallback: selectedColor,
      );
      selectedStorage = _getInitialSelection(
        _storageOptions,
        'storage_name',
        fallback: selectedStorage,
      );
      selectedSimCard = _getInitialSelection(
        _simOptions,
        'sim_card_name',
        fallback: selectedSimCard,
      );
    } else {
      // For initial load, use default variation parameters
      final defaultParams = _getDefaultVariationParams();
      selectedColor =
          defaultParams['color'] ??
          _getInitialSelection(_colorOptions, 'color_name');
      selectedStorage =
          defaultParams['storage'] ??
          _getInitialSelection(_storageOptions, 'storage_name');
      selectedSimCard =
          defaultParams['sim'] ??
          _getInitialSelection(_simOptions, 'sim_card_name');
    }

    _markActiveOptions(_colorOptions, 'color_name', selectedColor);
    _markActiveOptions(_storageOptions, 'storage_name', selectedStorage);
    _markActiveOptions(_simOptions, 'sim_card_name', selectedSimCard);

    debugPrint(
      'Options - Color: ${_colorOptions.length}, Storage: ${_storageOptions.length}, SIM: ${_simOptions.length}',
    );
  }

  List<Map<String, dynamic>> _extractOptionList(
    Map<String, dynamic> product,
    String key,
  ) {
    // First check the new structure under filter_options
    final filterOptions = product['filter_options'];
    if (filterOptions is Map<String, dynamic>) {
      final raw = filterOptions[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((option) => Map<String, dynamic>.from(option))
            .toList();
      }
    }
    
    // Fallback to old structure (direct key)
    final raw = product[key];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((option) => Map<String, dynamic>.from(option))
          .toList();
    }
    return [];
  }

  String? _getInitialSelection(
    List<Map<String, dynamic>> options,
    String key, {
    String? fallback,
  }) {
    if (options.isEmpty) return fallback;

    if (fallback != null && fallback.isNotEmpty) {
      final exists = options.any((opt) => opt[key]?.toString() == fallback);
      if (!exists) {
        fallback = null;
      }
    }

    final active = options.firstWhere(
      (opt) => opt['is_active'] == true && opt[key] != null,
      orElse: () => {},
    );
    if (active.isNotEmpty) {
      return active[key]?.toString();
    }
    return fallback ?? options.first[key]?.toString();
  }

  void _markActiveOptions(
    List<Map<String, dynamic>> options,
    String key,
    String? selected,
  ) {
    for (final option in options) {
      option['is_active'] = option[key]?.toString() == selected;
    }
  }

  Map<String, String?> _getDefaultVariationParams() {
    final variations = _currentProduct['variations'];
    if (variations is! List || variations.isEmpty) {
      return {'color': null, 'storage': null, 'sim': null};
    }

    // Find default variation (is_default: true)
    Map<String, dynamic>? defaultVariation;
    for (final variation in variations) {
      if (variation['is_default'] == true) {
        defaultVariation = variation;
        break;
      }
    }

    // If no default variation found, use first one
    defaultVariation ??= variations.first;

    return {
      'color': defaultVariation?['color']?.toString(),
      'storage': defaultVariation?['storage']?.toString(),
      'sim': defaultVariation?['sim']?.toString(),
    };
  }

  Future<void> _onColorChanged(String color) async {
    setState(() {
      selectedColor = color;
      _markActiveOptions(_colorOptions, 'color_name', selectedColor);
    });

    // Always use the original product ID from the widget
    _productId = _parseProductId(widget.product['product_id']);

    if (_productId != null) {
      await _fetchProductFilter(_productId!);
    } else {
      await _syncCartState();
    }
    
    _calculateMonthlyPaymentWithDebounce();
  }

  Future<void> _onStorageChanged(String storage) async {
    setState(() {
      selectedStorage = storage;
      _markActiveOptions(_storageOptions, 'storage_name', selectedStorage);
    });

    // Always use the original product ID from the widget
    _productId = _parseProductId(widget.product['product_id']);

    if (_productId != null) {
      await _fetchProductFilter(_productId!);
    } else {
      await _syncCartState();
    }
    
    _calculateMonthlyPaymentWithDebounce();
  }

  Future<void> _onSimChanged(String sim) async {
    setState(() {
      selectedSimCard = sim;
      _markActiveOptions(_simOptions, 'sim_card_name', selectedSimCard);
    });

    // Always use the original product ID from the widget
    _productId = _parseProductId(widget.product['product_id']);

    if (_productId != null) {
      await _fetchProductFilter(_productId!);
    } else {
      await _syncCartState();
    }
    
    _calculateMonthlyPaymentWithDebounce();
  }

  Future<void> _navigateToCart() async {
    if (!mounted) return;
    
    // Navigate to MainLayout (named route) and open Cart tab (index 2)
    Navigator.of(context).pushReplacementNamed(
      '/home',
      arguments: 2, // Cart page index
    );
    
    if (!mounted) return;
    await _syncCartState();
  }

  Future<void> _handleAddToCart() async {
    final isUsed = _isUsedProduct(_currentProduct);
    final productData = {
      'id': _currentProduct['product_id'],
      'name': _getProductName(_currentProduct),
      'price': _getProductPrice(_currentProduct),
      'image': _resolvePrimaryImage(),
      'selectedColor': selectedColor,
      'selectedStorage': selectedStorage,
      'selectedSim': selectedSimCard,
      'uniqueId': CartService.generateId(),
      'quantity': 1,
      'isUsed': isUsed,
    };

    try {
      await CartService.addToCart(productData);
      await _syncCartState();
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Товар добавлен в корзину',
        isSuccess: true,
      );
      await _navigateToCart();
    } catch (_) {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Не удалось добавить товар. Попробуйте ещё раз.',
        isSuccess: false,
      );
    }
  }

  Future<void> _changeCartQuantity(int delta) async {
    if (delta == 0) return;

    final uniqueId = _cartUniqueId;
    final isUsed = _isUsedProduct(_currentProduct);
    
    if (uniqueId == null) {
      if (delta > 0) {
        await _handleAddToCart();
      }
      return;
    }

    final newQuantity = _cartQuantity + delta;
    
    debugPrint(
      '🔍 _changeCartQuantity: isUsed=$isUsed, currentQuantity=$_cartQuantity, delta=$delta, newQuantity=$newQuantity',
    );
    
    // Ishlatilgan mahsulotlar uchun miqdorni 1 ga cheklash
    // Agar miqdor allaqachon 1 bo'lsa va + bosilsa, toast ko'rsatish
    if (isUsed && _cartQuantity >= 1 && delta > 0) {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Б/у товар можно добавить только в количестве 1 штуки',
        isSuccess: false,
      );
      return;
    }

    try {
      if (newQuantity <= 0) {
        await CartService.removeFromCart(uniqueId);
        await _syncCartState();
        if (!mounted) return;
        CustomToast.show(
          context,
          message: 'Товар удалён из корзины',
          isSuccess: true,
        );
      } else {
        await CartService.updateQuantity(uniqueId, newQuantity);
        await _syncCartState();
      }
    } catch (_) {
      await _syncCartState();
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Не удалось обновить корзину. Попробуйте ещё раз.',
        isSuccess: false,
      );
    }
  }

  Widget _buildQuantitySelector() {
    const accentColor = Color(0xFF2196F3);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        color: accentColor,
        child: Row(
          children: [
            _buildQuantityControlButton(
              icon: Icons.remove,
              onTap: () => _changeCartQuantity(-1),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$_cartQuantity',
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            _buildQuantityControlButton(
              icon: Icons.add,
              onTap: () => _changeCartQuantity(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControlButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 56.w,
      height: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Icon(icon, color: Colors.white, size: 24.w),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    if (_cartQuantity > 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 50.h, child: _buildQuantitySelector()),
          SizedBox(height: 12.h),
          SizedBox(
            height: 48.h,
            child: OutlinedButton(
              onPressed: _navigateToCart,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2196F3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Перейти в корзину',
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2196F3),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: _handleAddToCart,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/svg/bag.svg',
              width: 24.w,
              height: 24.w,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'Добавить в корзину',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFEBEBEB);
    final fallbackBgColor = isDark
        ? const Color(0xFF222222)
        : const Color.fromRGBO(255, 255, 255, 1);
    final fallbackTextColor = isDark ? Colors.white : Colors.black87;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark
        ? (Colors.grey[400] ?? Colors.grey)
        : (Colors.grey[600] ?? Colors.grey);
    final borderColor = isDark ? Colors.white : Colors.black87;
    final sectionBackground = isDark ? const Color(0xFF222222) : Colors.white;
    final bottomBarColor = sectionBackground;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                            child: _buildProductImage(
                              fallbackBgColor,
                              fallbackTextColor,
                            ),
                          ),
                        ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                                _getProductName(_currentProduct),
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                                _formatPriceValue(
                                  _getProductPrice(_currentProduct),
                                ),
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                              if (_colorOptions.isNotEmpty ||
                                  _storageOptions.isNotEmpty ||
                                  _simOptions.isNotEmpty) ...[
                          SizedBox(height: 24.h),
                                Container(
                                  margin: EdgeInsets.only(bottom: 24.h),
                                  child: ProductSectionCard(
                            backgroundColor: sectionBackground,
                            child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                              children: [
                                  if (_colorOptions.isNotEmpty) ...[
                                ProductOptionSection(
                                  title: 'Цвет',
                                  options: _buildOptionViewData(
                                    _colorOptions,
                                    'color_name',
                                  ),
                                            emptyMessage:
                                                'Нет доступных цветов',
                                  onOptionTap: _onColorChanged,
                                  textColor: textColor,
                                  borderColor: borderColor,
                                  subtitleColor: subtitleColor,
                                ),
                                  ],
                                  if (_storageOptions.isNotEmpty) ...[
                                SizedBox(height: 24.h),
                                ProductOptionSection(
                                  title: 'Память',
                                  options: _buildOptionViewData(
                                    _storageOptions,
                                    'storage_name',
                                  ),
                                            emptyMessage:
                                                'Нет доступных вариантов памяти',
                                  onOptionTap: _onStorageChanged,
                                  textColor: textColor,
                                  borderColor: borderColor,
                                  subtitleColor: subtitleColor,
                                ),
                                  ],
                                if (_simOptions.isNotEmpty) ...[
                                  SizedBox(height: 24.h),
                                  ProductOptionSection(
                                    title: 'SIM-карта',
                                    options: _buildOptionViewData(
                                      _simOptions,
                                      'sim_card_name',
                                    ),
                                            emptyMessage:
                                                'Нет доступных вариантов SIM-карт',
                                    onOptionTap: _onSimChanged,
                                    textColor: textColor,
                                    borderColor: borderColor,
                                    subtitleColor: subtitleColor,
                                  ),
                                ],
                              ],
                                    ),
                            ),
                          ),
                          ],
                          if (_buildSpecificationItems().isNotEmpty) ...[
                          ProductSpecificationsSection(
                            title: 'Характеристики',
                            items: _buildSpecificationItems(),
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                            backgroundColor: sectionBackground,
                          ),
                          SizedBox(height: 24.h),
                              ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(color: bottomBarColor),
                  child: SafeArea(top: false, child: _buildBottomAction()),
                ),
              ],
            ),
            if (_isLoadingFilter)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1B7EFF)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(Color fallbackBgColor, Color fallbackTextColor) {
    List<String> imageUrls = _getCurrentVariationImages();
    
    // If no variation images found, fallback to product level image
    if (imageUrls.isEmpty) {
      if (_currentProduct['image'] is String &&
          _currentProduct['image'].isNotEmpty) {
        imageUrls.add(_currentProduct['image'] as String);
      }
    }

    // Fallback to old structure if still no images
    if (imageUrls.isEmpty) {
      final images = _currentProduct['images'];
      if (images is List && images.isNotEmpty) {
        imageUrls = images
            .map<String>((img) {
          if (img is Map && img['image'] is String) {
            return img['image'] as String;
          }
          if (img is String) return img;
          return '';
            })
            .where((url) => url.isNotEmpty)
            .toList();
      } else if (images is String && images.isNotEmpty) {
        imageUrls = [images];
      }
    }

    if (imageUrls.isEmpty) {
      return Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          color: fallbackBgColor,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: ProductCardHelpers.fallbackImage(
          _getProductName(_currentProduct),
          fallbackBgColor,
          fallbackTextColor,
          width: double.infinity,
          height: 300,
        ),
      );
    }

    if (imageUrls.length == 1) {
      final url = imageUrls.first;
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Image.network(
          url,
          width: double.infinity,
          height: 300,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF1B7EFF),
                  ),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              color: fallbackBgColor,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: ProductCardHelpers.fallbackImage(
              _getProductName(_currentProduct),
              fallbackBgColor,
              fallbackTextColor,
              width: double.infinity,
              height: 300,
            ),
          ),
        ),
      );
    }

    return _ProductImageCarousel(
      imageUrls: imageUrls,
      productName: _getProductName(_currentProduct),
      fallbackBgColor: fallbackBgColor,
      fallbackTextColor: fallbackTextColor,
    );
  }

  List<ProductOptionViewData> _buildOptionViewData(
    List<Map<String, dynamic>> options,
    String key,
  ) {
    return options
        .map(
          (option) => ProductOptionViewData(
              label: option[key]?.toString() ?? '',
              isSelected: option['is_active'] == true,
          ),
        )
        .where((option) => option.label.isNotEmpty)
        .toList();
  }

  List<SpecificationItem> _buildSpecificationItems() {
    final characteristics = _currentProduct['characteristics'];
    if (characteristics is! List) return [];

    return characteristics
        .whereType<Map>()
        .map((characteristic) {
          final name = characteristic['name_property']?.toString() ?? '';
          if (name.isEmpty) return null;

          final details = characteristic['details'];
          final value = (details is List && details.isNotEmpty)
              ? details
                  .whereType<Map>()
                  .map((detail) => detail['value']?.toString().trim() ?? '')
                  .where((value) => value.isNotEmpty)
                  .join(', ')
              : '';

          // Faqat qiymati bo'lgan xususiyatlarni qaytarish
          if (value.isEmpty || value == '-') return null;

          return SpecificationItem(name: name, value: value);
        })
        .whereType<SpecificationItem>()
        .toList();
  }

double? _parseNumericValue(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();

  final str = value.toString().trim().replaceAll(',', '.');
  if (str.isEmpty) return null;

  final doubleValue = double.tryParse(str);
  if (doubleValue != null) return doubleValue;

  final sanitized = str.replaceAll(RegExp(r'[^\d]'), '');
  if (sanitized.isEmpty) return null;
  final parsedInt = int.tryParse(sanitized);
  return parsedInt?.toDouble();
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

  String _formatPriceValue(dynamic value) {
    final amount = _parseNumericValue(value);
    if (amount == null) return _formatUsdAmount(0);
    return _formatUsdAmount(amount);
  }

  String? _resolvePrimaryImage() {
    // Check direct image field first (new structure)
    if (_currentProduct['image'] is String &&
        _currentProduct['image'].isNotEmpty) {
      return _currentProduct['image'] as String;
    }

    // Check variations for images
    final variations = _currentProduct['variations'];
    if (variations is List && variations.isNotEmpty) {
      for (final variation in variations) {
        if (variation['image'] is String && variation['image'].isNotEmpty) {
          return variation['image'] as String;
        }
      }
    }

    // Fallback to old structure
    final images = _currentProduct['images'];
    if (images is List && images.isNotEmpty) {
      for (final image in images) {
        if (image is Map &&
            image['image'] is String &&
            (image['image'] as String).isNotEmpty) {
          return image['image'] as String;
        }
        if (image is String && image.isNotEmpty) {
          return image;
        }
      }
    } else if (images is Map &&
        images['image'] is String &&
        (images['image'] as String).isNotEmpty) {
      return images['image'] as String;
    } else if (images is String && images.isNotEmpty) {
      return images;
    }
    return null;
  }

  String _getProductName(Map<String, dynamic> product) {
    return product['product_name']?.toString() ??
           product['name']?.toString() ?? 
           'Название продукта';
  }

  bool _isUsedProduct(Map<String, dynamic> product) {
    // API dan kelayotgan 'used' fieldini tekshirish
    // used: 1 = ishlatilgan (б/у)
    // used: 2 = yangi
    final used = product['used'];
    final isUsed = used == 1;
    debugPrint(
      '🔍 _isUsedProduct: used=$used, isUsed=$isUsed, productName=${_getProductName(product)}',
    );
    return isUsed;
  }

  dynamic _getProductPrice(Map<String, dynamic> product) {
    // Get price from current selected variation first
    final currentVariation = _findCurrentVariation();
    
    if (currentVariation != null && currentVariation['price'] != null) {
      final price = currentVariation['price'];
      return price;
    }

    // If product price is not null, use it
    if (product['price'] != null) {
      return product['price'];
    }

    // If product price is null, get price from default variation
    final variations = product['variations'];
    if (variations is List && variations.isNotEmpty) {
      // Find default variation (is_default: true)
      final defaultVariation = variations.firstWhere(
        (v) => v['is_default'] == true,
        orElse: () => variations.first,
      );
      
      if (defaultVariation['price'] != null) {
        return defaultVariation['price'];
      }
    }

    return 0;
  }

  int? _getCurrentVariationId() {
    final currentVariation = _findCurrentVariation();
    if (currentVariation == null) {
      return null;
    }

    final variationId = currentVariation['variation_id'];
    if (variationId is String) {
      return int.tryParse(variationId);
    } else if (variationId is int) {
      return variationId;
    }

    return null;
  }

  List<String> _getCurrentVariationImages() {
    final variations = _currentProduct['variations'];
    if (variations is! List || variations.isEmpty) {
      return [];
    }

    // Find current selected variation
    final currentVariation = _findCurrentVariation();
    if (currentVariation != null &&
        currentVariation['image'] is String &&
        currentVariation['image'].isNotEmpty) {
      final imageUrl = currentVariation['image'] as String;
      return [imageUrl];
    }
    
    // If no current variation found, collect all variation images
    final imageUrls = <String>[];
    for (final variation in variations) {
      if (variation['image'] is String && variation['image'].isNotEmpty) {
        final imageUrl = variation['image'] as String;
        if (!imageUrls.contains(imageUrl)) {
          imageUrls.add(imageUrl);
        }
      }
    }

    return imageUrls;
  }

  Map<String, dynamic>? _findCurrentVariation() {
    final variations = _currentProduct['variations'];
    if (variations is! List || variations.isEmpty) {
      return null;
    }

    // Try to find exact match first
    for (final variation in variations) {
      final variationColor = variation['color']?.toString() ?? '';
      final variationStorage = variation['storage']?.toString() ?? '';
      final variationSim = variation['sim']?.toString() ?? '';
      
      final matchesColor =
          selectedColor == null || selectedColor == variationColor;
      final matchesStorage =
          selectedStorage == null || selectedStorage == variationStorage;
      final matchesSim =
          selectedSimCard == null || selectedSimCard == variationSim;
      
      if (matchesColor && matchesStorage && matchesSim) {
        return variation;
      }
    }

    // If no exact match, try partial matches with priority: Color > Storage > SIM
    Map<String, dynamic>? bestMatch;
    int bestScore = 0;
    
    for (final variation in variations) {
      final variationColor = variation['color']?.toString() ?? '';
      final variationStorage = variation['storage']?.toString() ?? '';
      final variationSim = variation['sim']?.toString() ?? '';
      
      int score = 0;
      if (selectedColor != null && selectedColor == variationColor) score += 3;
      if (selectedStorage != null && selectedStorage == variationStorage)
        score += 2;
      if (selectedSimCard != null && selectedSimCard == variationSim)
        score += 1;
      
      if (score > bestScore) {
        bestScore = score;
        bestMatch = variation;
      }
    }

    if (bestMatch != null) {
      return bestMatch;
    }

    // If no partial match, try to find default variation
    for (final variation in variations) {
      if (variation['is_default'] == true) {
        return variation;
      }
    }

    // If still no match, use first variation
    return variations.first;
  }
}

class _ProductImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final String? productName;
  final Color fallbackBgColor;
  final Color fallbackTextColor;

  const _ProductImageCarousel({
    required this.imageUrls,
    this.productName,
    required this.fallbackBgColor,
    required this.fallbackTextColor,
  });

  @override
  State<_ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<_ProductImageCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Colors.white.withOpacity(0.4);

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CarouselSlider(
          options: CarouselOptions(
            viewportFraction: 1,
            height: 300,
            onPageChanged: (index, reason) {
              setState(() {
                _current = index;
              });
            },
          ),
          items: widget.imageUrls.map((url) {
            return Builder(
              builder: (_) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Image.network(
                    url,
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return Container(
                        width: double.infinity,
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF1B7EFF),
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        color: widget.fallbackBgColor,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: ProductCardHelpers.fallbackImage(
                        widget.productName,
                        widget.fallbackBgColor,
                        widget.fallbackTextColor,
                        width: double.infinity,
                        height: 300,
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
        Positioned(
          bottom: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.imageUrls.asMap().entries.map((entry) {
              final isActive = _current == entry.key;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 12 : 8,
                height: isActive ? 12 : 8,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF1B7EFF) : inactiveColor,
                  shape: BoxShape.circle,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
