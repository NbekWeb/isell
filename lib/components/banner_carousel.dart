import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';

class BannerCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> banners;

  const BannerCarousel({
    super.key,
    required this.banners,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveIndicatorColor = isDark ? (Colors.grey[600] ?? Colors.grey) : (Colors.grey[400] ?? Colors.grey);
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: Stack(
        children: [
          // Banner Carousel
          CarouselSlider.builder(
            itemCount: widget.banners.length,
            itemBuilder: (context, index, realIndex) {
              final banner = widget.banners[index];
              final imageUrl = banner['image'] as String? ?? '';
              
              return GestureDetector(
                onTap: () async {
                  final link = banner['link'] as String?;
                  if (link != null && link.isNotEmpty) {
                    final uri = Uri.parse(link);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                child: Container(
                  margin: EdgeInsets.only(right: 10.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: 180.h,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              }
                              return Container(
                                width: double.infinity,
                                height: 180.h,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? (Colors.grey[800] ?? Colors.grey[700]!)
                                      : (Colors.grey[200] ?? Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      const Color(0xFF1B7EFF),
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 180.h,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? (Colors.grey[800] ?? Colors.grey[700]!)
                                      : (Colors.grey[200] ?? Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Icon(
                                  Icons.error_outline,
                                  color: isDark
                                      ? (Colors.grey[400] ?? Colors.grey)
                                      : (Colors.grey[600] ?? Colors.grey),
                                ),
                              );
                            },
                          )
                        : Container(
                            width: double.infinity,
                            height: 180.h,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? (Colors.grey[800] ?? Colors.grey[700]!)
                                  : (Colors.grey[200] ?? Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(
                              Icons.image_not_supported,
                              color: isDark
                                  ? (Colors.grey[400] ?? Colors.grey)
                                  : (Colors.grey[600] ?? Colors.grey),
                            ),
                          ),
                  ),
                ),
              );
            },
            options: CarouselOptions(
              height: 180.h,
              viewportFraction: 1,
              enableInfiniteScroll: widget.banners.length > 1,
              autoPlay: false,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentPage = index;
                });
              },
            ),
          ),

          // Page Indicators - positioned at bottom inside the image
          if (widget.banners.length > 1)
            Positioned(
              bottom: 12.h,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.banners.length,
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
