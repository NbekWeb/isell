import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:carousel_slider/carousel_slider.dart';

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveIndicatorColor = isDark ? (Colors.grey[600] ?? Colors.grey) : (Colors.grey[400] ?? Colors.grey);
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: Stack(
        children: [
          // Banner Carousel
          CarouselSlider.builder(
            itemCount: 3,
            itemBuilder: (context, index, realIndex) {
              return Container(
                margin: EdgeInsets.only(right: 10.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  image: const DecorationImage(
                    image: AssetImage('assets/img/banner.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
            options: CarouselOptions(
              height: 180.h,
              viewportFraction: 1,
              enableInfiniteScroll: true,
              autoPlay: false,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentPage = index;
                });
              },
            ),
          ),

          // Page Indicators - positioned at bottom inside the image
          Positioned(
            bottom: 12.h,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Container(
                  width: 12,
                  height: 12,
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? const Color(0xFF1B7EFF)
                        : inactiveIndicatorColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
