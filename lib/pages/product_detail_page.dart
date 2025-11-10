import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../components/product_card.dart';
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
  Map<String, dynamic>? _filteredProduct;

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
          _filteredProduct = result;
          _currentProduct = Map<String, dynamic>.from(result);
          debugPrint('Product keys: ${_currentProduct.keys}');
          _hydrateOptions();
          _isLoadingFilter = false;
        });
        debugPrint('Filter result: $_filteredProduct');
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
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
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
                            child: _buildProductImage(),
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
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '${_formatPriceValue(_currentProduct['price'])} сум',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 24.h),
                              _buildSectionTitle('Цвет'),
                              SizedBox(height: 12.h),
                              _buildColorSelection(),
                              SizedBox(height: 24.h),
                              _buildSectionTitle('Память'),
                              SizedBox(height: 12.h),
                              _buildStorageSelection(),
                              SizedBox(height: 24.h),
                              if (_simOptions.isNotEmpty) ...[
                                _buildSectionTitle('SIM-карта'),
                                SizedBox(height: 12.h),
                                _buildSimSelection(),
                                SizedBox(height: 24.h),
                              ],
                              _buildSectionTitle('Характеристики'),
                              SizedBox(height: 12.h),
                              _buildSpecifications(),
                              SizedBox(height: 24.h),
                              _buildSectionTitle('Общий первоначальный взнос'),
                              SizedBox(height: 12.h),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  border: Border.all(color: Colors.white, width: 1),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                                  child: Text(
                                    downPayment.toString(),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Будет распределен между товарами пропорционально их стоимости',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                              SizedBox(height: 24),
                              _buildSectionTitle('Срок рассрочки'),
                              SizedBox(height: 12),
                              _buildInstallmentPeriod(),
                              SizedBox(height: 24),
                              Text(
                                '${_formatPriceValue(_currentProduct['price'])} сум',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatMonthlyPayment(),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: const Color(0xFF2196F3),
                                ),
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
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
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
                            Icon(Icons.shopping_bag, color: Colors.white, size: 24.w),
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
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18.sp,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  Widget _buildColorSelection() {
    if (_colorOptions.isEmpty) {
      return Text(
        'Нет доступных цветов',
        style: GoogleFonts.poppins(
          fontSize: 14.sp,
          color: Colors.grey[400],
        ),
      );
    }

    return Wrap(
      spacing: 12.w,
      runSpacing: 12.h,
      children: _colorOptions.map((option) {
        final colorName = option['color_name']?.toString() ?? '';
        final isSelected = option['is_active'] == true;
        return GestureDetector(
          onTap: () => _onColorChanged(colorName),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2196F3)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected ? const Color(0xFF2196F3) : Colors.white,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              colorName,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStorageSelection() {
    if (_storageOptions.isEmpty) {
      return Text(
        'Нет доступных вариантов памяти',
        style: GoogleFonts.poppins(
          fontSize: 14.sp,
          color: Colors.grey[400],
        ),
      );
    }

    return Wrap(
      spacing: 12.w,
      runSpacing: 12.h,
      children: _storageOptions.map((option) {
        final storageName = option['storage_name']?.toString() ?? '';
        final isSelected = option['is_active'] == true;
        return GestureDetector(
          onTap: () => _onStorageChanged(storageName),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2196F3)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected ? const Color(0xFF2196F3) : Colors.white,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              storageName,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSimSelection() {
    if (_simOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12.w,
      runSpacing: 12.h,
      children: _simOptions.map((option) {
        final simName = option['sim_card_name']?.toString() ?? '';
        final isSelected = option['is_active'] == true;
        return GestureDetector(
          onTap: () => _onSimChanged(simName),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2196F3)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected ? const Color(0xFF2196F3) : Colors.white,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              simName,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpecifications() {
    final characteristics = _currentProduct['characteristics'];

    if (characteristics is! List || characteristics.isEmpty) {
      return Text(
        'Характеристики не указаны',
        style: GoogleFonts.poppins(
          fontSize: 14.sp,
          color: Colors.grey[400],
        ),
      );
    }

    return Column(
      children: characteristics.asMap().entries.map((entry) {
        final index = entry.key;
        final characteristic = entry.value as Map<String, dynamic>;
        final property = characteristic['name_property']?.toString() ?? '';
        final details = characteristic['details'];
        final valueText = (details is List && details.isNotEmpty)
            ? details
                .whereType<Map>()
                .map((detail) => detail['value']?.toString().trim() ?? '')
                .where((value) => value.isNotEmpty)
                .join(', ')
            : '-';

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    property,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: Colors.white70,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    valueText,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (index < characteristics.length - 1)
              Divider(
                color: Colors.white.withOpacity(0.1),
                thickness: 1,
                height: 16.h,
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildInstallmentPeriod() {
    return GestureDetector(
      onTap: () {
        _showSelectModal();
      },
      child: Container(
        key: _selectKey,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
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
                color: Colors.black,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectModal() {
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
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
                                  color: isSelected ? Colors.grey[200] : Colors.transparent,
                                  border: Border(
                                    top: period != periods.first
                                        ? BorderSide(color: Colors.grey[300]!, width: 1)
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Text(
                                  period,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16.sp,
                                    color: Colors.black,
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

  Widget _buildProductImage() {
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
      return ProductCardHelpers.fallbackImage(
        _currentProduct['name']?.toString(),
        const Color(0xFF1A1A1A),
        Colors.white,
        width: double.infinity,
        height: 300,
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
          errorBuilder: (_, __, ___) => ProductCardHelpers.fallbackImage(
            _currentProduct['name']?.toString(),
            const Color(0xFF1A1A1A),
            Colors.white,
            width: double.infinity,
            height: 300,
          ),
        ),
      );
    }

    return _ProductImageCarousel(
      imageUrls: imageUrls,
      productName: _currentProduct['name']?.toString(),
    );
  }

  int? _parseNumericValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.round();
    final sanitized = value.toString().replaceAll(RegExp(r'[^\d]'), '');
    if (sanitized.isEmpty) return null;
    return int.tryParse(sanitized);
  }

  String _formatPriceValue(dynamic value) {
    final amount = _parseNumericValue(value) ?? 0;
    final str = amount.toString();
    final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(regex, (match) => '${match[1]} ');
  }

  String _formatMonthlyPayment() {
    final amount = _parseNumericValue(_currentProduct['price']);
    if (amount == null || amount <= 0) {
      return 'В рассрочку';
    }
    const months = 12;
    final monthly = (amount / months).ceil();
    return 'В рассрочку ${_formatPriceValue(monthly)} сум/мес';
  }
}

class _ProductImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final String? productName;

  const _ProductImageCarousel({
    required this.imageUrls,
    this.productName,
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
                    errorBuilder: (_, __, ___) => ProductCardHelpers.fallbackImage(
                      widget.productName,
                      const Color(0xFF1A1A1A),
                      Colors.white,
                      width: double.infinity,
                      height: 300,
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

