import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../components/product_card.dart';
import '../../components/pagination_widget.dart';
import '../../services/product_services.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String? selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _products = [];
  final List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  bool _isLoadingCategories = true;
  Timer? _debounce;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchProducts();
  }

  void _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    final categories = await ProductServices.getCategories();

    if (mounted) {
      setState(() {
        _categories.clear();
        _categories.addAll(categories);
        _isLoadingCategories = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _fetchProducts({String? search, int page = 1}) async {
    setState(() {
      _isLoading = true;
    });

    final categoryId = selectedCategoryId != null && selectedCategoryId!.isNotEmpty
        ? int.tryParse(selectedCategoryId!)
        : null;

    final response = await ProductServices.getAllProducts(
      name: search,
      category: categoryId,
      page: page,
    );

    final results = List<Map<String, dynamic>>.from(
      (response['results'] as List<dynamic>? ?? <dynamic>[]),
    );
    final count = response['count'] as int? ?? 0;
    final totalPages = (count / 10).ceil(); // 10 is page_size

    if (mounted) {
      setState(() {
        _products
          ..clear()
          ..addAll(results);
        _currentPage = page;
        _totalPages = totalPages;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchProducts(search: value.trim());
    });
  }

  void _onPageChanged(int page) {
    _fetchProducts(
      search: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      page: page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? (Colors.grey[400] ?? Colors.grey) : (Colors.grey[600] ?? Colors.grey);
    final iconColor = isDark ? Colors.white : Colors.black87;
    final unselectedCategoryBg = isDark ? const Color(0xFFDCDCDC) : Colors.grey[300];
    final unselectedCategoryText = isDark ? const Color(0xFF111111) : Colors.black87;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Logo
            Padding(
              padding: EdgeInsets.only(bottom: 16.h, top: 2.h),
              child: Center(
                child: Image.asset(
                  'assets/img/logo.png',
                  height: 45.h,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                height: 48.h,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: textColor, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Поиск товаров',
                    hintStyle: TextStyle(
                      color: hintColor,
                      fontSize: 14.sp,
                    ),
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(12.w),
                      child: SvgPicture.asset(
                        'assets/svg/search.svg',
                        width: 20.w,
                        height: 20.w,
                        colorFilter: ColorFilter.mode(
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 16.h),

            // Category Filters
            SizedBox(
              height: 40.h,
              child: _isLoadingCategories
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1B7EFF),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemCount: _categories.length + 1, // +1 for "Все"
                      itemBuilder: (context, index) {
                        final isAll = index == 0;
                        final category = isAll
                            ? {'id': null, 'name': 'Все'}
                            : _categories[index - 1];
                        final categoryId = isAll ? null : category['id']?.toString();
                        final categoryName = category['name']?.toString() ?? '';
                        final isSelected = selectedCategoryId == categoryId;
                        
                        return Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedCategoryId = categoryId;
                                _currentPage = 1;
                              });
                              _fetchProducts(
                                search: _searchController.text.trim().isEmpty
                                    ? null
                                    : _searchController.text.trim(),
                                page: 1,
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2196F3)
                                    : unselectedCategoryBg,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Center(
                                child: Text(
                                  categoryName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isSelected ? Colors.white : unselectedCategoryText,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            SizedBox(height: 24.h),

            // Products Grid
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _isLoading
                  ? SizedBox(
                      height: 200.h,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1B7EFF),
                        ),
                      ),
                    )
                  : _products.isEmpty
                      ? SizedBox(
                          height: 200.h,
                          child: Center(
                            child: Text(
                              'Товары не найдены',
                              style: TextStyle(
                                color: hintColor,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: 360,
                            crossAxisSpacing: 12.w,
                            mainAxisSpacing: 16.h,
                          ),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            return ProductCard(product: _products[index]);
                          },
                        ),
            ),

            SizedBox(height: 20.h),
            
            // Pagination - only show when not loading
            if (!_isLoading)
              PaginationWidget(
                currentPage: _currentPage,
                totalPages: _totalPages,
                onPageChanged: _onPageChanged,
                textColor: textColor,
                borderColor: borderColor,
                hintColor: hintColor,
              ),
          ],
        ),
      ),
      ),
    );
  }
}

