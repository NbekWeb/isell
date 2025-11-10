import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/banner_carousel.dart';
import '../../components/product_card.dart';
import '../../services/product_services.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  Timer? _debounce;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
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

    final response = await ProductServices.getAllProducts(
      name: search,
      page: page,
    );

    final results = List<Map<String, dynamic>>.from(
      (response['results'] as List<dynamic>? ?? <dynamic>[]),
    );
    final totalPages = response['total_pages'] as int;

    debugPrint(
      'Fetched ${results.length} products (page $page of $totalPages)${search != null ? ' for search: $search' : ''}',
    );

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

  List<Widget> _buildPaginationButtons(Color textColor, Color borderColor, Color hintColor) {
    final tokens = _buildPaginationSequence();
    final List<Widget> buttons = [];

    for (final token in tokens) {
      if (token is int) {
        buttons.add(_buildPageButton(token, textColor, borderColor));
      } else {
        buttons.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              '...',
              style: TextStyle(color: hintColor, fontSize: 14.sp),
            ),
          ),
        );
      }
    }

    return buttons;
  }

  List<dynamic> _buildPaginationSequence() {
    if (_totalPages <= 5) {
      return List<int>.generate(_totalPages, (index) => index + 1);
    }

    final List<dynamic> sequence = <dynamic>[1];

    int start;
    int end;

    if (_currentPage <= 3) {
      start = 2;
      end = 4;
    } else if (_currentPage == 4) {
      start = 4;
      end = math.min(_totalPages - 1, 5);
    } else if (_currentPage >= _totalPages - 2) {
      start = math.max(2, _totalPages - 3);
      end = _totalPages - 1;
    } else {
      start = _currentPage - 1;
      end = _currentPage + 1;
    }

    start = math.max(2, start);
    end = math.min(_totalPages - 1, end);

    if (start <= end) {
      if (start > 2) {
        sequence.add('ellipsis');
      }
      for (int i = start; i <= end; i++) {
        sequence.add(i);
      }
      if (end < _totalPages - 1) {
        sequence.add('ellipsis');
      }
    } else {
      sequence.add('ellipsis');
    }

    sequence.add(_totalPages);

    return sequence;
  }

  Widget _buildPageButton(int pageNumber, Color textColor, Color borderColor) {
    final isActive = pageNumber == _currentPage;
    return GestureDetector(
      onTap: () => _fetchProducts(
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        page: pageNumber,
      ),
      child: Container(
        width: 32.w,
        height: 32.w,
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2196F3)
              : Colors.transparent,
          border: Border.all(
            color: isActive
                ? const Color(0xFF2196F3)
                : borderColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Center(
          child: Text(
            '$pageNumber',
            style: TextStyle(
              color: isActive ? Colors.white : textColor,
              fontSize: 14.sp,
              fontWeight: isActive
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark ? Colors.white : Colors.black87;
    final hintColor =
        isDark ? (Colors.grey[400] ?? Colors.grey) : (Colors.grey[600] ?? Colors.grey);
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: iconColor),
                              onPressed: () {
                                _searchController.clear();
                                _fetchProducts();
                              },
                            )
                          : null,
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

              // Banner Carousel
              const BannerCarousel(),

              SizedBox(height: 24.h),

              // Popular Products Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  'Популярные товары',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: _isLoading
                    ? SizedBox(
                        height: 200.h,
                        child: const Center(child: CircularProgressIndicator()),
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
              
              // Pagination
              if (_totalPages > 1)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Previous button
                      IconButton(
                        onPressed: _currentPage > 1
                            ? () => _fetchProducts(
                                  search: _searchController.text.trim().isEmpty
                                      ? null
                                      : _searchController.text.trim(),
                                  page: _currentPage - 1,
                                )
                            : null,
                        icon: Icon(
                          Icons.chevron_left,
                          color: _currentPage > 1 ? textColor : hintColor,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Page numbers
                      ..._buildPaginationButtons(textColor, borderColor, hintColor),
                      SizedBox(width: 12.w),
                      // Next button
                      IconButton(
                        onPressed: _currentPage < _totalPages
                            ? () => _fetchProducts(
                                  search: _searchController.text.trim().isEmpty
                                      ? null
                                      : _searchController.text.trim(),
                                  page: _currentPage + 1,
                                )
                            : null,
                        icon: Icon(
                          Icons.chevron_right,
                          color: _currentPage < _totalPages ? textColor : hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
