import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/banner_carousel.dart';
import '../../components/product_card.dart';
import '../../components/pagination_widget.dart';
import '../../services/product_services.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = true;
  bool _isLoadingBanners = true;
  Timer? _debounce;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _fetchBanners();
  }

  void _fetchBanners() async {
    setState(() {
      _isLoadingBanners = true;
    });

    final banners = await ProductServices.getBanners();

    if (mounted) {
      setState(() {
        _banners = banners;
        _isLoadingBanners = false;
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
    final hintColor =
        isDark ? (Colors.grey[400] ?? Colors.grey) : (Colors.grey[600] ?? Colors.grey);
    final iconColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: () {
        // Hide keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
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
              _isLoadingBanners
                  ? Container(
                      margin: EdgeInsets.symmetric(horizontal: 16.w),
                      height: 180.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        color: Colors.grey[300],
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1B7EFF),
                        ),
                      ),
                    )
                  : BannerCarousel(banners: _banners),

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
      ),
    );
  }
}
