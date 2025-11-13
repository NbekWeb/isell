import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../components/product_card.dart';
import '../components/product_detail_sections.dart';
import 'phone_input_page.dart';
import '../services/product_services.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailPage({
    super.key,
    required this.product,
  });

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
  final List<String> periods = ['6 месяц', '12 месяц', '18 месяц', '24 месяц'];
  final GlobalKey _selectKey = GlobalKey();
  int? _productId;


  @override
  void initState() {
    super.initState();
    _currentProduct = Map<String, dynamic>.from(widget.product);
    _productId = _parseProductId(_currentProduct['id']);
    _hydrateOptions(fromApi: false);
    _loadProductIdAndFilter();
  }

  Future<void> _loadProductIdAndFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final productIdString = prefs.getString('selected_product_id');
    final storedId = productIdString != null ? int.tryParse(productIdString) : null;
    if (storedId != null) {
      _productId = storedId;
    }

    _productId ??= _parseProductId(widget.product['id']);

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
          _currentProduct = Map<String, dynamic>.from(result);
          _hydrateOptions();
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
  }

  int? _parseProductId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  void _hydrateOptions({bool fromApi = true}) {
    final previousColorOptions = List<Map<String, dynamic>>.from(_colorOptions);
    final previousStorageOptions = List<Map<String, dynamic>>.from(_storageOptions);
    final previousSimOptions = List<Map<String, dynamic>>.from(_simOptions);

    _colorOptions = _extractOptionList(_currentProduct, 'color_list');
    _storageOptions = _extractOptionList(_currentProduct, 'storage_list');
    _simOptions = _extractOptionList(_currentProduct, 'sim_card_list');

    if (fromApi && _colorOptions.isEmpty && previousColorOptions.isNotEmpty) {
      _colorOptions = previousColorOptions;
    }
    if (fromApi && _storageOptions.isEmpty && previousStorageOptions.isNotEmpty) {
      _storageOptions = previousStorageOptions;
    }
    if (fromApi && _simOptions.isEmpty && previousSimOptions.isNotEmpty) {
      _simOptions = previousSimOptions;
    }

    if (fromApi) {
      selectedColor = _getInitialSelection(_colorOptions, 'color_name', fallback: selectedColor);
      selectedStorage = _getInitialSelection(_storageOptions, 'storage_name', fallback: selectedStorage);
      selectedSimCard = _getInitialSelection(_simOptions, 'sim_card_name', fallback: selectedSimCard);
    } else {
      selectedColor = _getInitialSelection(_colorOptions, 'color_name');
      selectedStorage = _getInitialSelection(_storageOptions, 'storage_name');
      selectedSimCard = _getInitialSelection(_simOptions, 'sim_card_name');
    }

    _markActiveOptions(_colorOptions, 'color_name', selectedColor);
    _markActiveOptions(_storageOptions, 'storage_name', selectedStorage);
    _markActiveOptions(_simOptions, 'sim_card_name', selectedSimCard);

    debugPrint('Options - Color: ${_colorOptions.length}, Storage: ${_storageOptions.length}, SIM: ${_simOptions.length}');
  }

  List<Map<String, dynamic>> _extractOptionList(Map<String, dynamic> product, String key) {
    final raw = product[key];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((option) => Map<String, dynamic>.from(option))
          .toList();
    }
    return [];
  }

  String? _getInitialSelection(List<Map<String, dynamic>> options, String key, {String? fallback}) {
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

  void _markActiveOptions(List<Map<String, dynamic>> options, String key, String? selected) {
    for (final option in options) {
      option['is_active'] = option[key]?.toString() == selected;
    }
  }

  Future<void> _onColorChanged(String color) async {
    setState(() {
      selectedColor = color;
      _markActiveOptions(_colorOptions, 'color_name', selectedColor);
    });

    if (_productId == null) {
      final prefs = await SharedPreferences.getInstance();
      final productIdString = prefs.getString('selected_product_id');
      _productId = productIdString != null ? int.tryParse(productIdString) : null;
    }

    if (_productId != null) {
      await _fetchProductFilter(_productId!);
    }
  }

  Future<void> _onStorageChanged(String storage) async {
    setState(() {
      selectedStorage = storage;
      _markActiveOptions(_storageOptions, 'storage_name', selectedStorage);
    });

    if (_productId == null) {
      final prefs = await SharedPreferences.getInstance();
      final productIdString = prefs.getString('selected_product_id');
      _productId = productIdString != null ? int.tryParse(productIdString) : null;
    }

    if (_productId != null) {
      await _fetchProductFilter(_productId!);
    }
  }

  Future<void> _onSimChanged(String sim) async {
    setState(() {
      selectedSimCard = sim;
      _markActiveOptions(_simOptions, 'sim_card_name', selectedSimCard);
    });

    if (_productId != null) {
      await _fetchProductFilter(_productId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEBEBEB);
    final fallbackBgColor = isDark ? const Color(0xFF222222) : const Color.fromRGBO(255, 255, 255, 1);
    final fallbackTextColor = isDark ? Colors.white : Colors.black87;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? (Colors.grey[400] ?? Colors.grey) : (Colors.grey[600] ?? Colors.grey);
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
                            child: _buildProductImage(fallbackBgColor, fallbackTextColor),
                          ),
                        ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                                _currentProduct['name']?.toString() ?? 'Название продукта',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                                _formatPriceValue(_currentProduct['price']),
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          ProductSectionCard(
                            backgroundColor: sectionBackground,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ProductOptionSection(
                                  title: 'Цвет',
                                  options: _buildOptionViewData(
                                    _colorOptions,
                                    'color_name',
                                  ),
                                  emptyMessage: 'Нет доступных цветов',
                                  onOptionTap: _onColorChanged,
                                  textColor: textColor,
                                  borderColor: borderColor,
                                  subtitleColor: subtitleColor,
                                ),
                                SizedBox(height: 24.h),
                                ProductOptionSection(
                                  title: 'Память',
                                  options: _buildOptionViewData(
                                    _storageOptions,
                                    'storage_name',
                                  ),
                                  emptyMessage: 'Нет доступных вариантов памяти',
                                  onOptionTap: _onStorageChanged,
                                  textColor: textColor,
                                  borderColor: borderColor,
                                  subtitleColor: subtitleColor,
                                ),
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
                          SizedBox(height: 24.h),
                          ProductSpecificationsSection(
                            title: 'Характеристики',
                            items: _buildSpecificationItems(),
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                            backgroundColor: sectionBackground,
                          ),
                          SizedBox(height: 24.h),
                          ProductFinancialSection(
                            backgroundColor: sectionBackground,
                            borderColor: borderColor,
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                            downPayment: _formatPriceValue(downPayment),
                            note:
                                'Будет распределен между товарами пропорционально их стоимости',
                            installmentSelector:
                                _buildInstallmentPeriod(textColor, borderColor),
                            totalPrice:
                                _formatPriceValue(_currentProduct['price'] ?? 0),
                            monthlyText: _formatMonthlyPayment(),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: bottomBarColor,
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PhoneInputPage(),
                            ),
                          );
                        },
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
                          'Оформить',
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoadingFilter)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1B7EFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallmentPeriod(Color textColor, Color borderColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    
    return GestureDetector(
      onTap: () {
        _showSelectModal();
      },
      child: Container(
        key: _selectKey,
        width: double.infinity,
      decoration: BoxDecoration(
        color: containerColor,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(12.r),
      ),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              installmentPeriod,
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                color: textColor,
                decoration: TextDecoration.none,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modalColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final optionSelectedColor =
        isDark ? (Colors.grey[700] ?? Colors.grey) : (Colors.grey[200] ?? Colors.grey);
    final optionBorderColor =
        isDark ? (Colors.grey[600] ?? Colors.grey) : (Colors.grey[300] ?? Colors.grey);
    final optionTextColor = isDark ? Colors.white : Colors.black87;

    final RenderBox? renderBox = _selectKey.currentContext?.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero);
    final size = renderBox?.size;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate modal height (approximate)
    final modalHeight = periods.length * (16.h * 2 + 16.h); // padding + text height
    final spaceBelow = screenHeight - (position?.dy ?? 0) - (size?.height ?? 0);
    final spaceAbove = (position?.dy ?? 0);
    
    // Determine if modal should open above or below
    final openBelow = spaceBelow >= modalHeight || spaceBelow > spaceAbove;
    final modalTop = openBelow 
        ? (position?.dy ?? 0) + (size?.height ?? 0) + 12
        : (position?.dy ?? 0) - modalHeight - 12;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        return GestureDetector(
          onTap: () {
            Navigator.of(dialogContext).pop();
          },
          child: Container(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned(
                  top: modalTop > 0 ? modalTop : 12,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: screenHeight - (modalTop > 0 ? modalTop : 12) - 20,
                      ),
                      decoration: BoxDecoration(
                        color: modalColor,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: periods.map((period) {
                            final isSelected = installmentPeriod == period;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  installmentPeriod = period;
                                });
                                Navigator.of(dialogContext).pop();
                              },
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                                decoration: BoxDecoration(
                                  color: isSelected ? optionSelectedColor : Colors.transparent,
                                  border: Border(
                                    top: period != periods.first
                                        ? BorderSide(color: optionBorderColor, width: 1)
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Text(
                                  period,
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
                                    color: optionTextColor,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductImage(Color fallbackBgColor, Color fallbackTextColor) {
    final images = _currentProduct['images'];
    List<String> imageUrls = [];
    if (images is List && images.isNotEmpty) {
      imageUrls = images.map<String>((img) {
        if (img is Map && img['image'] is String) {
          return img['image'] as String;
        }
        if (img is String) return img;
        return '';
      }).where((url) => url.isNotEmpty).toList();
    } else if (images is String && images.isNotEmpty) {
      imageUrls = [images];
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
          _currentProduct['name']?.toString(),
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
              _currentProduct['name']?.toString(),
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
      productName: _currentProduct['name']?.toString(),
      fallbackBgColor: fallbackBgColor,
      fallbackTextColor: fallbackTextColor,
    );
  }

  List<ProductOptionViewData> _buildOptionViewData(
    List<Map<String, dynamic>> options,
    String key,
  ) {
    return options
        .map((option) => ProductOptionViewData(
              label: option[key]?.toString() ?? '',
              isSelected: option['is_active'] == true,
            ))
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
              : '-';

          return SpecificationItem(
            name: name,
            value: value.isEmpty ? '-' : value,
          );
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
    final formattedValue =
        isWhole ? usdValue.round().toString() : usdValue.toStringAsFixed(2);
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

  String _formatMonthlyPayment() {
    final amount = _parseNumericValue(_currentProduct['price']);
    if (amount == null || amount <= 0) {
      return 'В рассрочку';
    }
    const months = 12;
    final monthly = amount / months;
    return 'В рассрочку ${_formatUsdAmount(monthly)} в мес';
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

