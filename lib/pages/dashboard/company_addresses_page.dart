import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../services/order_services.dart';

class CompanyAddressesPage extends StatefulWidget {
  const CompanyAddressesPage({super.key});

  @override
  State<CompanyAddressesPage> createState() => _CompanyAddressesPageState();
}

class _CompanyAddressesPageState extends State<CompanyAddressesPage> {
  final PageController _pageController = PageController();
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  YandexMapController? _mapController;
  final List<PlacemarkMapObject> _placemarks = [];

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchAddresses() async {
    setState(() {
      _isLoading = true;
    });

    final addresses = await OrderServices.getCompanyAddresses();

    if (mounted) {
      setState(() {
        _addresses = addresses;
        _isLoading = false;
      });
      
      // Create placemarks for all addresses
      await _createPlacemarks();
      
      // Move to first address on map
      if (_addresses.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _moveToAddress(0);
        });
      }
    }
  }

  Future<Uint8List> _getBytesFromAsset(String path, int width) async {
    final ByteData data = await rootBundle.load(path);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ByteData? byteData = await fi.image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _createPlacemarks() async {
    _placemarks.clear();
    
    // Load icon once for all placemarks
    Uint8List? iconData;
    try {
      iconData = await _getBytesFromAsset('assets/img/logo.png', 200);
    } catch (e) {
      // If icon not found, use default (no icon)
      debugPrint('Logo icon not found: $e');
    }
    
    for (int i = 0; i < _addresses.length; i++) {
      final address = _addresses[i];
      final lat = double.tryParse(address['latitude']?.toString() ?? '0') ?? 0.0;
      final lng = double.tryParse(address['longitude']?.toString() ?? '0') ?? 0.0;
      
      _placemarks.add(
        PlacemarkMapObject(
          mapId: MapObjectId('address_$i'),
          point: Point(latitude: lat, longitude: lng),
          opacity: 1.0,
          icon: iconData != null
              ? PlacemarkIcon.single(
                  PlacemarkIconStyle(
                    image: BitmapDescriptor.fromBytes(iconData),
                    scale: 1.0,
                  ),
                )
              : null,
        ),
      );
    }
    
    setState(() {}); // Update UI with placemarks
  }

  void _moveToAddress(int index) {
    if (index >= 0 && index < _addresses.length && _mapController != null) {
      final address = _addresses[index];
      final lat = double.tryParse(address['latitude']?.toString() ?? '0') ?? 0.0;
      final lng = double.tryParse(address['longitude']?.toString() ?? '0') ?? 0.0;
      
      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(latitude: lat, longitude: lng),
            zoom: 15.0,
          ),
        ),
        animation: const MapAnimation(
          type: MapAnimationType.smooth,
          duration: 0.5,
        ),
      );
    }
  }

  Future<void> _openInNavigator() async {
    if (_addresses.isEmpty || _currentIndex >= _addresses.length) return;
    
    final address = _addresses[_currentIndex];
    final lat = double.tryParse(address['latitude']?.toString() ?? '0') ?? 0.0;
    final lng = double.tryParse(address['longitude']?.toString() ?? '0') ?? 0.0;
    
    // Try Yandex Navigator first, then fallback to Yandex Maps web
    final yandexNaviUrl = Uri.parse('yandexnavi://build_route?lat_to=$lat&lon_to=$lng');
    final yandexMapsUrl = Uri.parse('https://yandex.ru/maps/?pt=$lng,$lat&z=15&l=map');
    
    try {
      // Try to open Yandex Navigator
      if (await canLaunchUrl(yandexNaviUrl)) {
        await launchUrl(yandexNaviUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to Yandex Maps web
        await launchUrl(yandexMapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // If both fail, try web version
      try {
        await launchUrl(yandexMapsUrl, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Failed to open navigator: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? (Colors.grey[400] ?? Colors.grey) : (Colors.grey[600] ?? Colors.grey);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Адреса',
          style: GoogleFonts.poppins(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1B7EFF),
              ),
            )
          : _addresses.isEmpty
              ? Center(
                  child: Text(
                    'Адреса не найдены',
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      color: subtitleColor,
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Address Info - above map
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                      child: SizedBox(
                        height: 60.h,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentIndex = index;
                            });
                            _moveToAddress(index);
                          },
                          itemCount: _addresses.length,
                          itemBuilder: (context, index) {
                            final address = _addresses[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  address['name']?.toString() ?? '',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  address['address']?.toString() ?? '',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.sp,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    
                    // Dots indicator
                    if (_addresses.length > 1)
                      SizedBox(
                        height: 8.h,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _addresses.length,
                            (index) => Container(
                              width: 8,
                              height: 8,
                              margin: EdgeInsets.symmetric(horizontal: 4.w),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentIndex == index
                                    ? const Color(0xFF1B7EFF)
                                    : (isDark ? Colors.grey[600] : Colors.grey[400]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                 
                    
                    // Map
                    SizedBox(
                      height: 400,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 16, left: 16, right: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: YandexMap(
                            mapType: MapType.map,
                            mapObjects: _placemarks,
                            onMapCreated: (YandexMapController controller) {
                              _mapController = controller;
                              if (_addresses.isNotEmpty) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _moveToAddress(0);
                                });
                              }
                            },
                            onMapTap: (Point point) {},
                          ),
                        ),
                      ),
                    ),
                    
                    // Open in Navigator Button
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _addresses.isEmpty ? null : _openInNavigator,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B7EFF),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'Открыть в навигаторе',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
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
