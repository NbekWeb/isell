import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'bottom_navbar.dart';
import '../pages/dashboard/home_page.dart';
import '../pages/dashboard/catalog_page.dart';
import '../pages/dashboard/cart_page.dart';
import '../pages/dashboard/agreements_page.dart';
import '../pages/dashboard/settings_page.dart';

class MainLayout extends StatefulWidget {
  final Function(ThemeMode)? onThemeUpdate;
  final int? initialIndex;
  
  const MainLayout({super.key, this.onThemeUpdate, this.initialIndex});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;
  final _cartPageKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
  }

  List<Widget> get _pages => [
    const HomePage(),
    const CatalogPage(), // Catalog page
    CartPage(key: _cartPageKey), // Cart page with key for refresh
    const AgreementsPage(), // Agreements page
    SettingsPage(onThemeUpdate: widget.onThemeUpdate), // Settings page
  ];

  @override
  Widget build(BuildContext context) {
    // Status bar is fully managed by main.dart
    // No need to set it here as it causes conflicts
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBodyBehindAppBar: false,
        body: SafeArea(
          bottom: false,
          top: true,
          maintainBottomViewPadding: true,
          child: Stack(
            children: [
              // Main content with bottom padding for navbar
              Padding(
                padding: EdgeInsets.only(bottom: 70.h),
                child: _pages[_currentIndex],
              ),
              // Fixed bottom navbar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BottomNavBar(
                key: ValueKey(_currentIndex), // Force rebuild when index changes
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                    // Refresh cart page when switching to it
                    if (index == 2) {
                      CartPage.refresh(context);
                    }
                  },
                ),
              ),
            ],
        ),
      ),
    );
  }
}
