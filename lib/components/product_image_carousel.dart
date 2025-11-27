import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'product_card.dart';

class ProductImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final String? productName;
  final Color fallbackBgColor;
  final Color fallbackTextColor;

  const ProductImageCarousel({
    super.key,
    required this.imageUrls,
    this.productName,
    required this.fallbackBgColor,
    required this.fallbackTextColor,
  });

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
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
