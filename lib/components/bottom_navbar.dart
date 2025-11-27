import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/cart_service.dart';

class BottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCartCount();
  }

  Future<void> _loadCartCount() async {
    final count = await CartService.getCartCount();
    if (mounted) {
      setState(() {
        _cartCount = count;
      });
    }
  }

  @override
  void didUpdateWidget(BottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadCartCount();
  }

  @override
  Widget build(BuildContext context) {
    // Reload cart count when widget rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCartCount();
    });
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 0 + bottomPadding,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
          _buildNavItem(
            svgPath: 'assets/svg/home.svg',
            label: 'Главная',
            index: 0,
            isActive: widget.currentIndex == 0,
            onTap: () => widget.onTap(0),
          ),
          _buildNavItem(
            svgPath: 'assets/svg/search.svg',
            label: 'Каталог',
            index: 1,
            isActive: widget.currentIndex == 1,
            onTap: () => widget.onTap(1),
          ),
          _buildCartNavItem(
            label: 'Корзина',
            index: 2,
            isActive: widget.currentIndex == 2,
            cartCount: _cartCount,
            onTap: () => widget.onTap(2),
          ),
          _buildNavItem(
            svgPath: 'assets/svg/doc.svg',
            label: 'Договоры',
            index: 3,
            isActive: widget.currentIndex == 3,
            onTap: () => widget.onTap(3),
          ),
          _buildNavItem(
            svgPath: 'assets/svg/settings.svg',
            label: 'Настройки',
            index: 4,
            isActive: widget.currentIndex == 4,
            onTap: () => widget.onTap(4),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String svgPath,
    required String label,
    required int index,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? Colors.white : Colors.black87;
    final color = isActive ? const Color(0xFF2196F3) : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            svgPath,
            width: 27,
            height: 27,
            colorFilter: ColorFilter.mode(
              color,
              BlendMode.srcIn,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartNavItem({
    required String label,
    required int index,
    required bool isActive,
    required int cartCount,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? Colors.white : Colors.black87;
    final color = isActive ? const Color(0xFF2196F3) : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/svg/cart.svg',
            width: 27,
            height: 27,
            colorFilter: ColorFilter.mode(
              color,
              BlendMode.srcIn,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
