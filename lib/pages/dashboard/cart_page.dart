import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/cart_service.dart';
import '../../services/product_services.dart';
import '../../services/api_service.dart';
import '../../services/order_services.dart';
import '../../widgets/custom_toast.dart';
import '../product_detail_page.dart';
import '../phone_input_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();

  static void refresh(BuildContext? context) {
    if (context != null) {
      final state = context.findAncestorStateOfType<_CartPageState>();
      state?.refreshCart();
    }
  }
}

class _CartPageState extends State<CartPage>
    with RouteAware, WidgetsBindingObserver {
  List<Map<String, dynamic>> cartItems = [];
  bool _isLoading = true;
  bool _isProcessingOrder = false;
  
  // Calculation mode: true = Simple, false = Complex
  bool _isSimpleMode = true;
  
  // Tariff data
  List<Map<String, dynamic>> _tariffs = [];
  Map<String, dynamic>? _selectedGlobalTariff;
  double _globalDownPayment = 0.0;
  late TextEditingController _globalDownPaymentController;
  Timer? _downPaymentDebounceTimer;
  Timer? _scheduleDebounceTimer;
  bool _isScheduleCalculating = false;
  
  // Complex mode values (stored per item)
  Map<String, Map<String, dynamic>?> _itemTariffs = {};
  Map<String, double> _itemDownPayments = {};
  Map<String, TextEditingController> _itemDownPaymentControllers = {};
  Map<String, FocusNode> _itemDownPaymentFocusNodes = {};
  
  // Storage instance
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // Payment schedule data
  Map<String, dynamic>? _paymentSchedule;
  bool _canBuy = true;
  
  // Cart tracking for changes
  int _lastCartCount = 0;
  Map<String, int> _lastCartQuantities = {};
  
  // Schedule check timer
  Timer? _checkTimer;
  int _remainingSeconds = 0;
  bool _isChecking = false;
  
  // Flag to control if schedule should be calculated on cart load
  bool _shouldCalculateOnLoad = true;

  @override
  void initState() {
    super.initState();
    _globalDownPaymentController = TextEditingController();
    _initAsync();
    WidgetsBinding.instance.addObserver(this);
    _loadLastCheckingTime();
  }
  
  Future<void> _loadLastCheckingTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckingStr = prefs.getString('lastChecking');
      if (lastCheckingStr != null) {
        final lastChecking = DateTime.parse(lastCheckingStr);
        final now = DateTime.now();
        final difference = now.difference(lastChecking);
        if (difference.inSeconds < 60) {
          if (mounted) {
            setState(() {
              _remainingSeconds = 60 - difference.inSeconds;
              _isChecking = true;
              _canBuy = false;
            });
            _startCheckTimer();
          }
        } else {
          // Timer already expired, clear the stored time
          await prefs.remove('lastChecking');
          if (mounted) {
            setState(() {
              _isChecking = false;
              _canBuy = true;
            });
          }
        }
      } else {
        // No stored time, ensure button is enabled
        if (mounted) {
          setState(() {
            _isChecking = false;
            _canBuy = true;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading last checking time: $e');
      if (mounted) {
        setState(() {
          _isChecking = false;
          _canBuy = true;
        });
      }
    }
  }
  
  void _startCheckTimer() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isChecking = false;
            _canBuy = true;
          });
          // Save that timer expired
          _saveCheckingTimeExpired();
        }
      }
    });
  }

  Future<void> _saveCheckingTimeExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastChecking');
    } catch (e) {
      print('❌ Error saving checking time expired: $e');
    }
  }

  Future<void> _saveCheckingTime() async {
    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastChecking', now.toIso8601String());
    } catch (e) {
      print('❌ Error saving checking time: $e');
    }
  }

  Future<void> _initAsync() async {
    await _fetchTariffs();
    _loadCartItems(); // _loadPaymentSchedule is called inside _loadCartItems
  }

  @override
  void dispose() {
    _downPaymentDebounceTimer?.cancel();
    _scheduleDebounceTimer?.cancel();
    _checkTimer?.cancel();
    _globalDownPaymentController.dispose();
    // Dispose all item controllers
    for (final controller in _itemDownPaymentControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _itemDownPaymentFocusNodes.values) {
      focusNode.dispose();
    }
    _itemDownPaymentControllers.clear();
    _itemDownPaymentFocusNodes.clear();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCartItems();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh cart when page becomes visible (when navigating back from other pages)
    // Use a small delay to avoid too frequent updates during initial build
    Future.microtask(() {
      if (mounted) {
        _loadCartItems();
      }
    });
  }

  void refreshCart() {
    _loadCartItems();
  }

  // Load payment schedule from storage
  Future<void> _loadPaymentSchedule() async {
    try {
      final canBuyJson = await _storage.read(key: 'can_buy');
      final savedCartCountJson = await _storage.read(key: 'saved_cart_count');
      final savedCartQuantitiesJson = await _storage.read(key: 'saved_cart_quantities');
      
      // Load saved calculation mode (simple/complex)
      final savedCalculationModeJson = await _storage.read(key: 'saved_calculation_mode');
      if (savedCalculationModeJson != null) {
        final savedMode = json.decode(savedCalculationModeJson) as bool;
        if (mounted) {
          setState(() {
            _isSimpleMode = savedMode;
          });
        }
      }
      
      // Load saved cart state
      int? savedCartCount;
      Map<String, int> savedCartQuantities = {};
      
      if (savedCartCountJson != null) {
        savedCartCount = json.decode(savedCartCountJson) as int;
      }
      
      if (savedCartQuantitiesJson != null) {
        final decoded = json.decode(savedCartQuantitiesJson) as Map;
        savedCartQuantities = decoded.map((key, value) => MapEntry(key.toString(), value as int));
      }
      
      // Check if cart or down payment has changed (only if we have saved state)
      bool hasChanged = false;
      
      if (savedCartCount != null || savedCartQuantities.isNotEmpty) {
        final currentCount = cartItems.length;
        final currentQuantities = <String, int>{};
        for (final item in cartItems) {
          final uniqueId = item['uniqueId'] as String;
          final quantity = item['quantity'] as int;
          currentQuantities[uniqueId] = quantity;
        }
        
        // Check cart count/quantities
        if (savedCartCount != null && savedCartCount != currentCount) {
          hasChanged = true;
        } else if (savedCartQuantities.isNotEmpty) {
          // Check if quantities changed
          for (final entry in currentQuantities.entries) {
            if (savedCartQuantities[entry.key] != entry.value) {
              hasChanged = true;
              break;
            }
          }
          // Check if items were removed
          for (final oldKey in savedCartQuantities.keys) {
            if (!currentQuantities.containsKey(oldKey)) {
              hasChanged = true;
              break;
            }
          }
        }
        
        // Load and restore down payment state first (restore is not a change)
        final savedGlobalDownPaymentJson = await _storage.read(key: 'saved_global_down_payment');
        final savedItemDownPaymentsJson = await _storage.read(key: 'saved_item_down_payments');
        
        if (savedGlobalDownPaymentJson != null) {
          final savedGlobalDownPayment = (json.decode(savedGlobalDownPaymentJson) as num).toDouble();
          // Restore down payment if different (this is restoration, not a change)
          if ((savedGlobalDownPayment - _globalDownPayment).abs() > 0.01) {
            _globalDownPayment = savedGlobalDownPayment;
            if (_globalDownPaymentController.text.isEmpty || 
                int.tryParse(_globalDownPaymentController.text.replaceAll(RegExp(r'[^\d]'), '')) != _globalDownPayment.toInt()) {
              _globalDownPaymentController.text = _globalDownPayment.toInt().toString();
            }
          }
        }
        
        if (savedItemDownPaymentsJson != null) {
          final decoded = json.decode(savedItemDownPaymentsJson) as Map;
          final savedItemDownPayments = decoded.map((key, value) => MapEntry(key.toString(), (value as num).toDouble()));
          
          // Restore item down payments (this is restoration, not a change)
          for (final entry in savedItemDownPayments.entries) {
            _itemDownPayments[entry.key] = entry.value;
            
            // Update controller if exists
            if (_itemDownPaymentControllers.containsKey(entry.key)) {
              final controller = _itemDownPaymentControllers[entry.key]!;
              final focusNode = _itemDownPaymentFocusNodes[entry.key]!;
              if (!focusNode.hasFocus) {
                final text = entry.value == 0 ? '' : entry.value.toInt().toString();
                if (controller.text != text) {
                  controller.text = text;
                }
              }
            }
          }
        }
        
        // Load and restore tariff state (restore is not a change)
        final savedGlobalTariffIdJson = await _storage.read(key: 'saved_global_tariff_id');
        final savedItemTariffIdsJson = await _storage.read(key: 'saved_item_tariff_ids');
        
        if (savedGlobalTariffIdJson != null && _tariffs.isNotEmpty) {
          final savedGlobalTariffId = json.decode(savedGlobalTariffIdJson) as int;
          final currentTariffId = _selectedGlobalTariff?['id'] as int?;
          if (currentTariffId != savedGlobalTariffId) {
            // Restore global tariff
            try {
              final tariff = _tariffs.firstWhere(
                (t) => t['id'] == savedGlobalTariffId,
              );
              _selectedGlobalTariff = tariff;
            } catch (e) {
              // Tariff not found, use first one
              if (_tariffs.isNotEmpty) {
                _selectedGlobalTariff = _tariffs.first;
              }
            }
          }
        }
        
        if (savedItemTariffIdsJson != null && _tariffs.isNotEmpty) {
          final decoded = json.decode(savedItemTariffIdsJson) as Map;
          final savedItemTariffIds = decoded.map((key, value) => MapEntry(key.toString(), value as int));
          
          // Restore item tariffs
          for (final entry in savedItemTariffIds.entries) {
            try {
              final tariff = _tariffs.firstWhere(
                (t) => t['id'] == entry.value,
              );
              _itemTariffs[entry.key] = tariff;
            } catch (e) {
              // Tariff not found, use first one
              if (_tariffs.isNotEmpty) {
                _itemTariffs[entry.key] = _tariffs.first;
              }
            }
          }
        }
        
        // Now check if down payment or tariff actually changed (after restoration)
        final savedGlobalDownPaymentJson2 = await _storage.read(key: 'saved_global_down_payment');
        final savedItemDownPaymentsJson2 = await _storage.read(key: 'saved_item_down_payments');
        
        if (savedGlobalDownPaymentJson2 != null) {
          final savedGlobalDownPayment = (json.decode(savedGlobalDownPaymentJson2) as num).toDouble();
          if ((savedGlobalDownPayment - _globalDownPayment).abs() > 0.01) {
            hasChanged = true;
          }
        }
        
        if (savedItemDownPaymentsJson2 != null && !hasChanged) {
          final decoded = json.decode(savedItemDownPaymentsJson2) as Map;
          final savedItemDownPayments = decoded.map((key, value) => MapEntry(key.toString(), (value as num).toDouble()));
          
          // Check if item down payments changed
          if (savedItemDownPayments.length != _itemDownPayments.length) {
            hasChanged = true;
          } else {
            for (final entry in _itemDownPayments.entries) {
              final savedValue = savedItemDownPayments[entry.key] ?? 0.0;
              if ((savedValue - entry.value).abs() > 0.01) {
                hasChanged = true;
                break;
              }
            }
          }
        }
        
        // Check if tariff changed (after restoration)
        final savedGlobalTariffIdJson2 = await _storage.read(key: 'saved_global_tariff_id');
        final savedItemTariffIdsJson2 = await _storage.read(key: 'saved_item_tariff_ids');
        
        if (savedGlobalTariffIdJson2 != null && _tariffs.isNotEmpty && !hasChanged) {
          final savedGlobalTariffId = json.decode(savedGlobalTariffIdJson2) as int;
          final currentTariffId = _selectedGlobalTariff?['id'] as int?;
          if (currentTariffId != savedGlobalTariffId) {
            hasChanged = true;
          }
        }
        
        if (savedItemTariffIdsJson2 != null && _tariffs.isNotEmpty && !hasChanged) {
          final decoded = json.decode(savedItemTariffIdsJson2) as Map;
          final savedItemTariffIds = decoded.map((key, value) => MapEntry(key.toString(), value as int));
          
          // Check if item tariffs changed
          for (final entry in savedItemTariffIds.entries) {
            final currentTariff = _itemTariffs[entry.key];
            final currentTariffId = currentTariff?['id'] as int?;
            if (currentTariffId != entry.value) {
              hasChanged = true;
              break;
            }
          }
        }
        
        // If cart or down payment changed, clear payment schedule
        if (hasChanged) {
          print('🔄 Cart or down payment changed since last save, clearing payment schedule');
          await _clearPaymentSchedule();
        } else {
          // Don't load schedule from storage - it will be loaded from API on mounted
          // Only load can_buy and checking state if exists (from calculate-schedule API)
          if (canBuyJson != null) {
            _canBuy = json.decode(canBuyJson) as bool;
          }
          // Load checking state if exists
          await _loadLastCheckingTime();
        }
      } else {
        // No saved cart state, but still load saved choices
        // Load saved calculation mode
        final savedCalculationModeJson = await _storage.read(key: 'saved_calculation_mode');
        if (savedCalculationModeJson != null) {
          final savedMode = json.decode(savedCalculationModeJson) as bool;
          if (mounted) {
            setState(() {
              _isSimpleMode = savedMode;
            });
          }
        }
        
        // Load and restore down payment state
        final savedGlobalDownPaymentJson = await _storage.read(key: 'saved_global_down_payment');
        final savedItemDownPaymentsJson = await _storage.read(key: 'saved_item_down_payments');
        
        if (savedGlobalDownPaymentJson != null) {
          final savedGlobalDownPayment = (json.decode(savedGlobalDownPaymentJson) as num).toDouble();
          _globalDownPayment = savedGlobalDownPayment;
          if (_globalDownPaymentController.text.isEmpty || 
              int.tryParse(_globalDownPaymentController.text.replaceAll(RegExp(r'[^\d]'), '')) != _globalDownPayment.toInt()) {
            _globalDownPaymentController.text = _globalDownPayment.toInt().toString();
          }
        }
        
        if (savedItemDownPaymentsJson != null) {
          final decoded = json.decode(savedItemDownPaymentsJson) as Map;
          final savedItemDownPayments = decoded.map((key, value) => MapEntry(key.toString(), (value as num).toDouble()));
          
          for (final entry in savedItemDownPayments.entries) {
            _itemDownPayments[entry.key] = entry.value;
            
            // Update controller if exists
            if (_itemDownPaymentControllers.containsKey(entry.key)) {
              final controller = _itemDownPaymentControllers[entry.key]!;
              final focusNode = _itemDownPaymentFocusNodes[entry.key]!;
              if (!focusNode.hasFocus) {
                final text = entry.value == 0 ? '' : entry.value.toInt().toString();
                if (controller.text != text) {
                  controller.text = text;
                }
              }
            }
          }
        }
        
        // Load and restore tariff state
        final savedGlobalTariffIdJson = await _storage.read(key: 'saved_global_tariff_id');
        final savedItemTariffIdsJson = await _storage.read(key: 'saved_item_tariff_ids');
        
        if (savedGlobalTariffIdJson != null && _tariffs.isNotEmpty) {
          final savedGlobalTariffId = json.decode(savedGlobalTariffIdJson) as int;
          try {
            final tariff = _tariffs.firstWhere(
              (t) => t['id'] == savedGlobalTariffId,
            );
            _selectedGlobalTariff = tariff;
          } catch (e) {
            // Tariff not found, use first one
            if (_tariffs.isNotEmpty) {
              _selectedGlobalTariff = _tariffs.first;
            }
          }
        }
        
        if (savedItemTariffIdsJson != null && _tariffs.isNotEmpty) {
          final decoded = json.decode(savedItemTariffIdsJson) as Map;
          final savedItemTariffIds = decoded.map((key, value) => MapEntry(key.toString(), value as int));
          
          for (final entry in savedItemTariffIds.entries) {
            try {
              final tariff = _tariffs.firstWhere(
                (t) => t['id'] == entry.value,
              );
              _itemTariffs[entry.key] = tariff;
            } catch (e) {
              // Tariff not found, use first one
              if (_tariffs.isNotEmpty) {
                _itemTariffs[entry.key] = _tariffs.first;
              }
            }
          }
        }
        
        // Only load can_buy and checking state if exists (from calculate-schedule API)
        if (canBuyJson != null) {
          _canBuy = json.decode(canBuyJson) as bool;
        }
        // Load checking state if exists
        await _loadLastCheckingTime();
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Error loading payment schedule: $e');
    }
  }

  // Save payment schedule to storage
  Future<void> _savePaymentSchedule(Map<String, dynamic> schedule) async {
    try {
      await _storage.write(key: 'payment_schedule', value: json.encode(schedule));
      
      // Save current cart state
      final currentCount = cartItems.length;
      final currentQuantities = <String, int>{};
      for (final item in cartItems) {
        final uniqueId = item['uniqueId'] as String;
        final quantity = item['quantity'] as int;
        currentQuantities[uniqueId] = quantity;
      }
      await _storage.write(key: 'saved_cart_count', value: json.encode(currentCount));
      await _storage.write(key: 'saved_cart_quantities', value: json.encode(currentQuantities));
      
      // Save down payment state
      await _storage.write(key: 'saved_global_down_payment', value: json.encode(_globalDownPayment));
      final savedItemDownPayments = <String, double>{};
      for (final entry in _itemDownPayments.entries) {
        savedItemDownPayments[entry.key] = entry.value;
      }
      await _storage.write(key: 'saved_item_down_payments', value: json.encode(savedItemDownPayments));
      
      // Save tariff state
      if (_selectedGlobalTariff != null) {
        await _storage.write(key: 'saved_global_tariff_id', value: json.encode(_selectedGlobalTariff!['id']));
      }
      final savedItemTariffs = <String, int>{};
      for (final entry in _itemTariffs.entries) {
        if (entry.value != null) {
          savedItemTariffs[entry.key] = entry.value!['id'] as int;
        }
      }
      await _storage.write(key: 'saved_item_tariff_ids', value: json.encode(savedItemTariffs));
      
      // Save calculation mode (simple/complex)
      await _storage.write(key: 'saved_calculation_mode', value: json.encode(_isSimpleMode));
      
      // Check ability to order and status
      final abilityToOrder = schedule['ability_to_order'] as bool? ?? false;
      final status = schedule['status'] as String?;
      
      _canBuy = abilityToOrder && (status == 'approved' || status == null);
      await _storage.write(key: 'can_buy', value: json.encode(_canBuy));
      
      // Show modal if can't buy (but only if not processing order - to avoid showing modal after order creation)
      if (!_canBuy && !_isProcessingOrder) {
        if (mounted) {
          if (_isChecking) {
            _showCheckingModal();
          } else {
            _showAdminCheckModal();
          }
        }
      }
      
      _paymentSchedule = schedule;
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Error saving payment schedule: $e');
    }
  }

  // Clear payment schedule from storage
  Future<void> _clearPaymentSchedule() async {
    try {
      await _storage.delete(key: 'payment_schedule');
      await _storage.delete(key: 'can_buy');
      // Clear saved down payment and tariff data
      await _storage.delete(key: 'saved_global_down_payment');
      await _storage.delete(key: 'saved_global_tariff_id');
      await _storage.delete(key: 'saved_item_down_payments');
      await _storage.delete(key: 'saved_item_tariff_ids');
      // Don't delete saved_cart_count and saved_cart_quantities here
      // They will be updated when new schedule is saved
      
      _paymentSchedule = null;
      _canBuy = true;
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Error clearing payment schedule: $e');
    }
  }

  // Check for cart changes
  Future<void> _checkCartChanges(List<Map<String, dynamic>> newItems) async {
    final newCount = newItems.length;
    final newQuantities = <String, int>{};
    
    for (final item in newItems) {
      final uniqueId = item['uniqueId'] as String;
      final quantity = item['quantity'] as int;
      newQuantities[uniqueId] = quantity;
    }
    
    // Load saved cart state from storage if not initialized
    if (_lastCartCount == 0 && _lastCartQuantities.isEmpty) {
      try {
        final savedCartCountJson = await _storage.read(key: 'saved_cart_count');
        final savedCartQuantitiesJson = await _storage.read(key: 'saved_cart_quantities');
        
        if (savedCartCountJson != null) {
          _lastCartCount = json.decode(savedCartCountJson) as int;
        }
        
        if (savedCartQuantitiesJson != null) {
          final decoded = json.decode(savedCartQuantitiesJson) as Map;
          _lastCartQuantities = decoded.map((key, value) => MapEntry(key.toString(), value as int));
        }
      } catch (e) {
        print('⚠️ Error loading saved cart state: $e');
      }
    }
    
    // Check if cart count changed or quantities changed
    bool hasChanges = false;
    
    if (_lastCartCount != newCount) {
      hasChanges = true;
      print('🔄 Cart count changed: $_lastCartCount -> $newCount');
    } else {
      // Check if quantities changed
      for (final entry in newQuantities.entries) {
        if (_lastCartQuantities[entry.key] != entry.value) {
          hasChanges = true;
          print('🔄 Cart quantity changed for ${entry.key}: ${_lastCartQuantities[entry.key]} -> ${entry.value}');
          break;
        }
      }
      
      // Check if items were removed
      for (final oldKey in _lastCartQuantities.keys) {
        if (!newQuantities.containsKey(oldKey)) {
          hasChanges = true;
          print('🔄 Cart item removed: $oldKey');
          break;
        }
      }
    }
    
    if (hasChanges) {
      print('🔄 Cart changes detected, clearing payment schedule and stopping timer');
      await _clearPaymentSchedule();
      
      // Stop timer and reset checking state
      _checkTimer?.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastChecking');
      
      if (mounted) {
        setState(() {
          _isChecking = false;
          _canBuy = true;
          _remainingSeconds = 0;
        });
      }
    }
    
    _lastCartCount = newCount;
    _lastCartQuantities = newQuantities;
  }

  Future<void> _loadCartItems() async {
    setState(() {
      _isLoading = true;
    });
    final items = await CartService.getCartItems();
    
    // Check for cart changes
    await _checkCartChanges(items);
    
    setState(() {
      cartItems = items;
      _isLoading = false;
    });
    
    // Ensure tariffs are loaded before loading payment schedule
    if (_tariffs.isEmpty) {
      await _fetchTariffs();
    }
    
    // Load payment schedule after cart items and tariffs are loaded
    await _loadPaymentSchedule();
    
    // Call schedule simple API if products exist and mounted, and flag is set
    if (mounted && cartItems.isNotEmpty && _shouldCalculateOnLoad) {
      _calculateScheduleSimple();
    }
    // Reset flag after first load
    _shouldCalculateOnLoad = false;
  }

  Future<void> _fetchTariffs() async {
    try {
      final tariffs = await ProductServices.getTariffs();
      setState(() {
        _tariffs = tariffs;
        // Set default tariff to first one from response
        if (tariffs.isNotEmpty) {
              _selectedGlobalTariff = tariffs.first;
        }
      });
    } catch (e) {
      print('❌ Error fetching tariffs: $e');
    }
  }

  bool _isUsedProduct(Map<String, dynamic> item) {
    // Cart item-da isUsed flagini tekshirish
    final isUsed = item['isUsed'] == true;
    
    // Agar isUsed flag yo'q bo'lsa, product nomidan tekshirish (fallback)
    if (item['isUsed'] == null) {
      final productName = (item['name'] ?? '').toString().toLowerCase();
      final hasUsedPattern = productName.contains('b/u') || 
                            productName.contains('б/у') ||
                            productName.contains('б.у') ||
                            productName.contains('b.u');
      return hasUsedPattern;
    }
    
    return isUsed;
  }

  Future<void> _updateQuantity(String uniqueId, int delta) async {
    final item = cartItems.firstWhere((item) => item['uniqueId'] == uniqueId);
    final currentQuantity = item['quantity'] as int;
    final newQuantity = currentQuantity + delta;
    final isUsed = _isUsedProduct(item);

    // Ishlatilgan mahsulotlar uchun miqdorni 1 ga cheklash
    // Agar miqdor allaqachon 1 bo'lsa va + bosilsa, toast ko'rsatish
    if (isUsed && currentQuantity >= 1 && delta > 0) {
      CustomToast.show(
        context,
        message: 'Б/у товар можно добавить только в количестве 1 штуки',
        isSuccess: false,
      );
      return;
    }
    
    // Agar b/u mahsulot bo'lsa va newQuantity > 1 bo'lsa ham cheklash
    if (isUsed && newQuantity > 1) {
      CustomToast.show(
        context,
        message: 'Б/у товар можно добавить только в количестве 1 штуки',
        isSuccess: false,
      );
      return;
    }

    if (newQuantity <= 0) {
      await CartService.removeFromCart(uniqueId);
    } else {
      await CartService.updateQuantity(uniqueId, newQuantity);
    }

    // Prevent automatic calculation in _loadCartItems
    _shouldCalculateOnLoad = false;
    await _loadCartItems();
    
    // Trigger schedule calculation with debounce when quantity changes
    if (mounted && cartItems.isNotEmpty) {
      _scheduleCalculateDebounced();
    }
  }

  Future<void> _removeItem(String uniqueId) async {
    // Prevent automatic calculation in _loadCartItems
    _shouldCalculateOnLoad = false;
    
    // Dispose controller and focus node for removed item
    _itemDownPaymentControllers[uniqueId]?.dispose();
    _itemDownPaymentFocusNodes[uniqueId]?.dispose();
    _itemDownPaymentControllers.remove(uniqueId);
    _itemDownPaymentFocusNodes.remove(uniqueId);
    
    // Remove item-specific data (down payment and tariff)
    _itemDownPayments.remove(uniqueId);
    _itemTariffs.remove(uniqueId);
    
    // Update storage - remove item from saved data
    final savedItemDownPayments = <String, double>{};
    for (final entry in _itemDownPayments.entries) {
      savedItemDownPayments[entry.key] = entry.value;
    }
    await _storage.write(key: 'saved_item_down_payments', value: json.encode(savedItemDownPayments));
    
    final savedItemTariffs = <String, int>{};
    for (final entry in _itemTariffs.entries) {
      if (entry.value != null) {
        savedItemTariffs[entry.key] = entry.value!['id'] as int;
      }
    }
    await _storage.write(key: 'saved_item_tariff_ids', value: json.encode(savedItemTariffs));
    
    await CartService.removeFromCart(uniqueId);
    await _loadCartItems();
    
    // Trigger schedule calculation with debounce when item is removed
    if (mounted && cartItems.isNotEmpty) {
      _scheduleCalculateDebounced();
    } else if (mounted) {
      // Clear schedule if cart is empty
      setState(() {
        _paymentSchedule = null;
      });
    }
  }


  double _calculateTotal() {
    return cartItems.fold(0.0, (sum, item) {
      final price = _parsePriceValue(item['price']);
      final quantity = item['quantity'] is int
          ? item['quantity'] as int
          : int.tryParse(item['quantity'].toString()) ?? 0;
      return sum + (price * quantity);
    });
  }

  double _calculateTotalAmount() {
    // Calculate total: if payment schedule exists, use total_advance_payment + sum of monthly payments
    // Otherwise, use calculated total from cart items
    if (_paymentSchedule != null) {
      final totalAdvancePayment = (_paymentSchedule!['total_advance_payment'] as num?)?.toDouble() ?? 
          (_isSimpleMode ? _globalDownPayment : (_itemDownPayments.values.fold<double>(0.0, (sum, value) => sum + value)));
      final monthlyPayments = _paymentSchedule!['monthly_payments'] as List? ?? [];
      double monthlyPaymentsSum = 0.0;
      for (final payment in monthlyPayments) {
        if (payment is Map && payment['payment'] != null) {
          monthlyPaymentsSum += (payment['payment'] as num).toDouble();
        }
      }
      return totalAdvancePayment + monthlyPaymentsSum;
    } else {
      return _calculateTotal();
    }
  }

  double _calculateAdvancePayment() {
    if (_isSimpleMode) {
      return _globalDownPayment;
    } else {
      // Complex mode: sum of all item down payments
      return _itemDownPayments.values.fold(0.0, (sum, value) => sum + value);
    }
  }

  double _calculateMonthlyPayment() {
    if (!_isSimpleMode || _selectedGlobalTariff == null) return 0.0;
    final total = _calculateTotalAmount();
    final advancePayment = _calculateAdvancePayment();
    return _calculateMonthlyPaymentFromTariff(total, _selectedGlobalTariff, advancePayment);
  }

  double _parsePriceValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();

    final str = value
        .toString()
        .trim()
        .replaceAll(',', '.')
        .replaceAll(' ', '');
    if (str.isEmpty) return 0.0;

    final doubleValue = double.tryParse(str);
    if (doubleValue != null) return doubleValue;

    final sanitized = str.replaceAll(RegExp(r'[^\d.]'), '');
    if (sanitized.isEmpty) return 0.0;
    return double.tryParse(sanitized) ?? 0.0;
  }

  // Calculate total monthly payments sum
  double _calculateTotalMonthlyPayments(List monthlyPayments) {
    double total = 0.0;
    for (final payment in monthlyPayments) {
      if (payment is Map && payment['payment'] != null) {
        final amount = payment['payment'];
        if (amount is num) {
          total += amount.toDouble();
        } else if (amount is String) {
          total += double.tryParse(amount) ?? 0.0;
        }
      }
    }
    return total;
  }

  String _formatUsdAmount(double usdValue) {
    final isWhole = usdValue == usdValue.roundToDouble();
    final formattedValue = isWhole
        ? usdValue.round().toString()
        : usdValue.toStringAsFixed(2);
    final parts = formattedValue.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : null;
    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      if (i != 0 && (integerPart.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(integerPart[i]);
    }
    return decimalPart != null
        ? '\$${buffer.toString()}.$decimalPart'
        : '\$${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final borderColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark
        ? Colors.white.withOpacity(0.1)
        : (Colors.grey[300] ?? Colors.grey);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: const CircularProgressIndicator(
                  color: Color(0xFF1B7EFF),
                ),
              )
            : cartItems.isEmpty
            ? _buildEmptyCart(isDark, textColor)
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildModeToggle(textColor, cardColor),
                    _buildCartWithItems(
                      textColor,
                      cardColor,
                      borderColor,
                      dividerColor,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildModeToggle(Color textColor, Color cardColor) {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Режим расчета',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          Row(
            children: [
              Text(
                'Простой',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: _isSimpleMode ? const Color(0xFF4E63EC) : textColor,
                ),
              ),
              SizedBox(width: 8.w),
              Switch(
                value: !_isSimpleMode, // Switch is ON for complex mode
                onChanged: (bool value) async {
                  setState(() {
                    _isSimpleMode = !value;
                  });
                  
                  // Save calculation mode to storage
                  await _storage.write(key: 'saved_calculation_mode', value: json.encode(_isSimpleMode));
                  
                  // Trigger schedule calculation with debounce when mode changes
                  // Works for both simple and complex modes
                  if (cartItems.isNotEmpty) {
                    _scheduleCalculateDebounced();
                  }
                },
                activeColor: const Color(0xFF4E63EC),
                activeTrackColor: const Color(0xFF4E63EC).withOpacity(0.3),
              ),
              SizedBox(width: 8.w),
              Text(
                'Сложный',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: !_isSimpleMode ? const Color(0xFF4E63EC) : textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleModeCalculation(Color textColor, Color cardColor) {
    // Calculate total: if payment schedule exists, use total_advance_payment + sum of monthly payments
    // Otherwise, use calculated total from cart items
    double total;
    if (_paymentSchedule != null) {
      // Simple API doesn't return total_advance_payment, so use _globalDownPayment
      final totalAdvancePayment = (_paymentSchedule!['total_advance_payment'] as num?)?.toDouble() ?? _globalDownPayment;
      final monthlyPayments = _paymentSchedule!['monthly_payments'] as List? ?? [];
      double monthlyPaymentsSum = 0.0;
      for (final payment in monthlyPayments) {
        if (payment is Map && payment['payment'] != null) {
          monthlyPaymentsSum += (payment['payment'] as num).toDouble();
        }
      }
      total = totalAdvancePayment + monthlyPaymentsSum;
    } else {
      total = _calculateTotal();
    }
    final monthlyPayment = _calculateMonthlyPaymentFromTariff(total, _selectedGlobalTariff, _globalDownPayment);
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Общий первоначальный взнос',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          

          Builder(
            builder: (context) {
              final isNoInstallment = _selectedGlobalTariff != null && 
                  (_selectedGlobalTariff!['payments_count'] == 0 || 
                   _selectedGlobalTariff!['name']?.toString().toLowerCase() == 'no installment' ||
                   (_selectedGlobalTariff!['coefficient'] as num?)?.toDouble() == 1.0);
              
              return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.transparent,
                  border: Border.all(
                    color: isNoInstallment 
                        ? textColor.withOpacity(0.3) 
                        : textColor, 
                    width: 1
                  ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: TextFormField(
                  enabled: !isNoInstallment,
              controller: _globalDownPaymentController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                    color: isNoInstallment 
                        ? textColor.withOpacity(0.5) 
                        : textColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                hintText: '0',
                hintStyle: GoogleFonts.poppins(
                  color: textColor.withOpacity(0.5),
                  fontSize: 16.sp,
                ),
                prefixText: '\$',
                prefixStyle: GoogleFonts.poppins(
                      color: isNoInstallment 
                          ? textColor.withOpacity(0.5) 
                          : textColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTapOutside: (event) {
                // Close keyboard when tapping outside
                FocusScope.of(context).unfocus();
              },
              onChanged: (value) {
                    if (isNoInstallment) return;
                
                // Stop checking timer if down payment changes
                _checkTimer?.cancel();
                final prefs = SharedPreferences.getInstance();
                prefs.then((p) => p.remove('lastChecking'));
                if (mounted) {
                  setState(() {
                    _isChecking = false;
                    _canBuy = true;
                    _remainingSeconds = 0;
                  });
                }
                
                // Cancel previous timer
                _downPaymentDebounceTimer?.cancel();
                
                // Get total to validate against
                final total = _calculateTotal();
                
                // Start debounce timer
                _downPaymentDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
                  if (!mounted) return;
                  
                  final cleanValue = _globalDownPaymentController.text.replaceAll(RegExp(r'[^\d]'), '');
                final intValue = cleanValue.isEmpty ? 0 : int.tryParse(cleanValue) ?? 0;
                  
                  // Clamp down payment to not exceed total
                  final clampedValue = intValue.clamp(0, total.toInt());
                  
                  // Update field if value was clamped (only if different from what user typed)
                  if (clampedValue != intValue) {
                    final newText = clampedValue == 0 ? '' : clampedValue.toString();
                    _globalDownPaymentController.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: newText.length),
                    );
                    
                    // Show toast message
                    CustomToast.show(
                      context,
                      message: 'Первоначальный взнос не может превышать общую сумму',
                      isSuccess: false,
                    );
                  }
                  
                  // Update state only after debounce
                  if (_globalDownPayment != clampedValue.toDouble()) {
                setState(() {
                      _globalDownPayment = clampedValue.toDouble();
                    });
                    
                    // Save down payment to storage
                    await _storage.write(key: 'saved_global_down_payment', value: json.encode(_globalDownPayment));
                    
                    // Trigger schedule calculation with debounce when down payment changes
                    if (cartItems.isNotEmpty) {
                      _scheduleCalculateDebounced();
                    }
                  }
                });
              },
            ),
              );
            },
          ),
          
          SizedBox(height: 16.h),
          
          Text(
            'Будет распределен между товарами пропорционально их стоимости',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              color: textColor.withOpacity(0.7),
            ),
          ),
          
          SizedBox(height: 20.h),
          
          Text(
            'Срок рассрочки',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          
          // Tariff Selector
          GestureDetector(
            onTap: () {
              _showGlobalTariffModal();
            },
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: textColor, width: 1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getSelectedTariffName(),
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      color: textColor,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: textColor,
                  ),
                ],
              ),
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildItogoSection(Color textColor, Color cardColor) {
    // Calculate total
    double total;
    if (_paymentSchedule != null) {
      final totalAdvancePayment = (_paymentSchedule!['total_advance_payment'] as num?)?.toDouble() ?? 
          (_isSimpleMode ? _globalDownPayment : (_itemDownPayments.values.isNotEmpty ? _itemDownPayments.values.first : 0.0));
      final monthlyPayments = _paymentSchedule!['monthly_payments'] as List? ?? [];
      double monthlyPaymentsSum = 0.0;
      for (final payment in monthlyPayments) {
        if (payment is Map && payment['payment'] != null) {
          monthlyPaymentsSum += (payment['payment'] as num).toDouble();
        }
      }
      total = totalAdvancePayment + monthlyPaymentsSum;
    } else {
      total = _calculateTotal();
    }
    
    // Calculate advance payment
    double advancePayment;
    if (_isSimpleMode) {
      advancePayment = _globalDownPayment;
    } else {
      // Complex mode: sum of all item down payments
      advancePayment = _itemDownPayments.values.fold(0.0, (sum, value) => sum + value);
    }
    
    // Calculate monthly payment (only for simple mode)
    double? monthlyPayment;
    if (_isSimpleMode && _selectedGlobalTariff != null) {
      monthlyPayment = _calculateMonthlyPaymentFromTariff(total, _selectedGlobalTariff, advancePayment);
    }
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Итого',
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 12.h),
          _buildSummaryRow('Общая сумма:', _formatUsdAmount(total), textColor),
          _buildSummaryRow('Первоначальный взнос:', _formatUsdAmount(advancePayment), textColor),
          // Show "В рассрочку" only for simple mode
          if (_isSimpleMode && monthlyPayment != null && monthlyPayment > 0) ...[
            SizedBox(height: 8.h),
            Text(
              'В рассрочку ${_formatUsdAmount(monthlyPayment)} в месяц',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B7EFF),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color textColor, {double? fontSize, bool isHighlighted = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: fontSize ?? 14.sp,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
              color: textColor,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: fontSize ?? 14.sp,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
              color: isHighlighted ? const Color(0xFF1B7EFF) : textColor,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateMonthlyPaymentFromTariff(double total, Map<String, dynamic>? tariff, double downPayment) {
    if (tariff == null) return 0.0;
    
    final remainingAmount = total - downPayment;
    final paymentsCount = tariff['payments_count'] as int? ?? 1;
    
    // If payments_count is 0, it means "No installment" - full payment upfront
    if (paymentsCount == 0) {
      return remainingAmount; // Full amount as single payment
    }
    
    return remainingAmount / paymentsCount;
  }



  Widget _buildEmptyCart(bool isDark, Color textColor) {
    final circleColor = isDark
        ? const Color(0xFF333333)
        : (Colors.grey[200] ?? Colors.grey);
    final subtitleColor = isDark
        ? textColor.withOpacity(0.7)
        : textColor.withOpacity(0.6);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 108.w,
            height: 108.w,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.lock_outline,
                size: 44.w,
                color: const Color(0xFF2196F3),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'Корзина пуста',
            style: GoogleFonts.poppins(
              fontSize: 20.sp,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            'Добавьте товары из каталога',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              color: subtitleColor,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCartWithItems(
    Color textColor,
    Color cardColor,
    Color borderColor,
    Color dividerColor,
  ) {
    final total = _calculateTotal();
    final itemCount = cartItems.length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cart Items
          ...cartItems.map((item) {
            return _buildCartItem(
              item,
              textColor,
              cardColor,
              borderColor,
            );
          }),
          
          // Payment Schedule Card
          if (_paymentSchedule != null)
            _buildPaymentScheduleCard(textColor, cardColor),
          
          // Calculation Section - only for simple mode
          if (_isSimpleMode) 
            _buildSimpleModeCalculation(textColor, cardColor),
          
          
          SizedBox(height: 24.h),
          // Order Button (not fixed)
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: Opacity(
              opacity: (_canBuy && !_isChecking) ? 1.0 : 0.6,
            child: ElevatedButton(
                onPressed: (_isProcessingOrder) 
                    ? null
                    : (_isChecking ? _handleCheckOrder : _handlePlaceOrder),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B7EFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: _isProcessingOrder
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _isChecking ? 'Проверить' : 'Оформить',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
          
          SizedBox(height: 32.h), // Bottom padding
        ],
      ),
    );
  }

  Map<String, dynamic> _buildProductFromCartItem(Map<String, dynamic> item) {
    // Cart item'dan product ma'lumotlarini yig'ish
    // Convert product_id to int
    final productId = item['id'] is int 
        ? item['id'] 
        : int.tryParse(item['id'].toString()) ?? item['id'];
    
    final product = {
      'product_id': productId,
      'product_name': item['name'],
      'price': item['price'],
      'image': item['image'],
      'variations': [
        {
          'color': item['selectedColor'],
          'storage': item['selectedStorage'],
          'sim': item['selectedSim'],
          'price': item['price'],
          'image': item['image'],
        }
      ],
    };
    return product;
  }

  Future<void> _navigateToProductDetail(Map<String, dynamic> item) async {
    final product = _buildProductFromCartItem(item);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(product: product),
      ),
    );
    // Cart'ni yangilash
    await _loadCartItems();
  }

  Widget _buildCartItem(
    Map<String, dynamic> item,
    Color textColor,
    Color cardColor,
    Color borderColor,
  ) {
    final uniqueId = item['uniqueId'] as String;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor.withOpacity(0.2), width: 1),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // First Row: Image, Name, Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image - clickable
                  GestureDetector(
                    onTap: () => _navigateToProductDetail(item),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: _buildCartImage(item['image'], backgroundColor),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Product Details
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: 40.w,
                      ), // Space for delete icon
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Name - clickable
                          GestureDetector(
                            onTap: () => _navigateToProductDetail(item),
                            child: Text(
                              item['name'],
                              style: GoogleFonts.poppins(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_variantDescription(item).isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              _variantDescription(item),
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                color: textColor.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          SizedBox(height: 4.h),
                          Text(
                            _formatUsdAmount(_parsePriceValue(item['price'])),
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              // Second Row: Quantity Control (centered)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minus Button
                    GestureDetector(
                      onTap: () => _updateQuantity(uniqueId, -1),
                      child: Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: borderColor, width: 1),
                      shape: BoxShape.circle,
                    ),
                        child: Icon(Icons.remove, color: textColor, size: 18.w),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // Quantity Display
                  Text(
                    '${item['quantity']}',
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // Plus Button
                    GestureDetector(
                      onTap: () => _updateQuantity(uniqueId, 1),
                      child: Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: borderColor, width: 1),
                      shape: BoxShape.circle,
                    ),
                        child: Icon(
                        Icons.add, 
                          color: textColor,
                          size: 18.w,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Complex Mode Fields
              if (!_isSimpleMode) ...[
                SizedBox(height: 16.h),
                _buildComplexModeItemFields(item, textColor, borderColor),
              ],
            ],
          ),
          // Delete Button - Top Right
          Positioned(
            top: 0,
            right: 0,
              child: GestureDetector(
                onTap: () => _removeItem(uniqueId),
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  child: Icon(Icons.delete_outline, color: Colors.red, size: 24.w),
                ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartImage(dynamic image, Color backgroundColor) {
    final imageUrl = image?.toString();

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 80.w,
        height: 80.w,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8.r),
        ),
      );
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        width: 80.w,
        height: 80.w,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 80.w,
          height: 80.w,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
    }

    return Image.asset(
      imageUrl,
      width: 80.w,
      height: 80.w,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: 80.w,
        height: 80.w,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
    );
  }

  String _variantDescription(Map<String, dynamic> item) {
    final parts = <String>[];
    final color = item['selectedColor']?.toString();
    final storage = item['selectedStorage']?.toString();
    final sim = item['selectedSim']?.toString();

    if (color != null && color.isNotEmpty) {
      parts.add(color);
    }
    if (storage != null && storage.isNotEmpty) {
      parts.add(storage);
    }
    if (sim != null && sim.isNotEmpty) {
      parts.add(sim);
    }

    return parts.join(' • ');
  }

  // Check order status (for "Проверить" button)
  Future<void> _handleCheckOrder() async {
    if (_isProcessingOrder) return;
    
    // If checking, show modal first
    if (_isChecking) {
      _showCheckingModal();
      return;
    }
    
    setState(() {
      _isProcessingOrder = true;
    });

    try {
      // Call schedule API again to check status
      Map<String, dynamic>? result;
      
      if (_isSimpleMode) {
        final tariffId = _selectedGlobalTariff?['id'];
        if (tariffId == null) {
          setState(() {
            _isProcessingOrder = false;
          });
          return;
        }

        final productList = <Map<String, dynamic>>[];
        for (final item in cartItems) {
          final productId = item['id'] is int 
              ? item['id'] 
              : int.tryParse(item['id'].toString()) ?? item['id'];
          final quantity = item['quantity'] is int 
              ? item['quantity'] 
              : int.tryParse(item['quantity'].toString()) ?? item['quantity'];
          
          final productItem = <String, dynamic>{
            'product_id': productId,
            'quantity': quantity,
          };
          if (item['variation_id'] != null) {
            final variationId = item['variation_id'] is int 
                ? item['variation_id'] 
                : int.tryParse(item['variation_id'].toString());
            if (variationId != null) {
              productItem['variation_id'] = variationId;
            }
          }
          productList.add(productItem);
        }

        result = await ProductServices.calculateSchedule(
          calculationMode: 1,
          tariffId: int.tryParse(tariffId.toString()),
          totalAdvancePayment: _globalDownPayment,
          productList: productList,
        );
      } else {
        final productList = <Map<String, dynamic>>[];
        for (final item in cartItems) {
          final uniqueId = item['uniqueId'] as String;
          final tariff = _itemTariffs[uniqueId];
          final downPayment = _itemDownPayments[uniqueId] ?? 0.0;
          
          if (tariff == null) {
            setState(() {
              _isProcessingOrder = false;
            });
            return;
          }

          final productId = item['id'] is int 
              ? item['id'] 
              : int.tryParse(item['id'].toString()) ?? item['id'];
          final quantity = item['quantity'] is int 
              ? item['quantity'] 
              : int.tryParse(item['quantity'].toString()) ?? item['quantity'];
          final tariffId = tariff['id'] is int 
              ? tariff['id'] 
              : int.tryParse(tariff['id'].toString()) ?? tariff['id'];
          final advancePayment = downPayment is int 
              ? downPayment 
              : downPayment.toInt();
          
          final productItem = <String, dynamic>{
            'product_id': productId,
            'quantity': quantity,
            'tariff_id': tariffId,
            'advance_payment': advancePayment,
          };
          if (item['variation_id'] != null) {
            final variationId = item['variation_id'] is int 
                ? item['variation_id'] 
                : int.tryParse(item['variation_id'].toString());
            if (variationId != null) {
              productItem['variation_id'] = variationId;
            }
          }
          productList.add(productItem);
        }

        result = await ProductServices.calculateSchedule(
          calculationMode: 2,
          productList: productList,
        );
      }

      if (result != null) {
        final abilityToOrder = result['ability_to_order'] as bool? ?? true;
        final status = result['status']?.toString() ?? '';
        
        // Special case: status is "Accepted" but ability_to_order is false
        // Show error toast about minimum contribution
        if (status.toLowerCase() == 'accepted' && !abilityToOrder) {
          final minimumContribution = result['minimum_contribution'];
          String minimumContributionText = '15';
          
          if (minimumContribution != null) {
            final numValue = minimumContribution is num 
                ? minimumContribution 
                : (double.tryParse(minimumContribution.toString()) ?? 15.0);
            
            // Format: remove .0 if it's a whole number
            if (numValue % 1 == 0) {
              minimumContributionText = numValue.toInt().toString();
            } else {
              minimumContributionText = numValue.toString();
            }
          }
          
          CustomToast.show(
            context,
            message: 'Минимальный первоначальный взнос должен быть не менее $minimumContributionText',
            isSuccess: false,
          );
          
          setState(() {
            _canBuy = false;
          });
          
          await _savePaymentSchedule(result);
          return;
        }
        
        // Special case: status is "Denied" or "Denied by client"
        final statusLower = status.toLowerCase();
        if (statusLower == 'denied' || statusLower == 'denied by client') {
          setState(() {
            _canBuy = false;
          });
          
          await _savePaymentSchedule(result);
          
          // Show denied modal
          _showDeniedModal();
          return;
        }
        
        if (abilityToOrder && status.toLowerCase() == 'accepted') {
          // Accepted - clear checking state and allow order
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('lastChecking');
          
          setState(() {
            _isChecking = false;
            _canBuy = true;
            _remainingSeconds = 0;
          });
          
          _checkTimer?.cancel();
          
          // Close modal if open
          if (mounted) {
            Navigator.of(context).pop();
          }
          
          // Save schedule and proceed
          await _savePaymentSchedule(result);
          
          CustomToast.show(
            context,
            message: 'Заказ подтвержден! Теперь вы можете оформить заказ.',
            isSuccess: true,
          );
        } else {
          // Still not accepted - update timer
          final now = DateTime.now();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('lastChecking', now.toIso8601String());
          
          setState(() {
            _isChecking = true;
            _remainingSeconds = 60;
            _canBuy = false;
          });
          
          _startCheckTimer();
          
          await _savePaymentSchedule(result);
          
          // Show modal after checking
          _showCheckingModal();
        }
      }
    } catch (e) {
      print('❌ Error checking order: $e');
      CustomToast.show(
        context,
        message: 'Ошибка при проверке заказа',
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOrder = false;
        });
      }
    }
  }

  Future<void> _handlePlaceOrder() async {
    if (cartItems.isEmpty) {
      CustomToast.show(context, message: 'Корзина пуста', isSuccess: false);
      return;
    }

    if (_isProcessingOrder) {
      return;
    }

    // Check if user can buy
    if (!_canBuy) {
      // If checking, show modal instead of toast
      if (_isChecking) {
        _showCheckingModal();
      } else {
        _showAdminCheckModal();
      }
      return;
    }

    setState(() {
      _isProcessingOrder = true;
    });

    try {
      // Step 1: Check if access token exists
      print('🔵 Step 1: Checking access token...');
      String? accessToken;
      
      try {
        final prefs = await SharedPreferences.getInstance();
        accessToken = prefs.getString('accessToken');
        
        // Fallback to secure storage if not found in SharedPreferences
        if (accessToken == null) {
          accessToken = await _storage.read(key: 'access_token');
        }
        
        // Use memory token as last resort
        if (accessToken == null && ApiService.memoryToken != null) {
          accessToken = ApiService.memoryToken;
        }
      } catch (e) {
        print('❌ Error checking access token: $e');
      }

      if (accessToken == null) {
        print('❌ No access token found, redirecting to login');
        
        // Navigate directly to login page
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const PhoneInputPage(),
            ),
            (route) => false,
          );
        }
        return;
      }

      print('✅ Access token found, proceeding with order...');

      // Step 2: Call payment schedule calculation API
      print('🔵 Step 2: Calling payment schedule calculation API...');
      
      Map<String, dynamic>? result;
      
      if (_isSimpleMode) {
        // Simple mode (calculation_mode = 1)
        print('📤 Simple mode - sending calculation_mode: 1');
        
        final tariffId = _selectedGlobalTariff?['id'];
        if (tariffId == null) {
        CustomToast.show(
          context,
            message: 'Выберите срок рассрочки',
            isSuccess: false,
        );
          return;
        }

        // Create product list for simple mode (without tariff_id and advance_payment)
        final productList = <Map<String, dynamic>>[];
        for (final item in cartItems) {
          // Convert product_id to int
          final productId = item['id'] is int 
              ? item['id'] 
              : int.tryParse(item['id'].toString()) ?? item['id'];
          
          // Convert quantity to int
          final quantity = item['quantity'] is int 
              ? item['quantity'] 
              : int.tryParse(item['quantity'].toString()) ?? item['quantity'];
          
          final productItem = <String, dynamic>{
            'product_id': productId,
            'quantity': quantity,
          };
          // Add variation_id only if it exists and is not null
          if (item['variation_id'] != null) {
            final variationId = item['variation_id'] is int 
                ? item['variation_id'] 
                : int.tryParse(item['variation_id'].toString());
            if (variationId != null) {
              productItem['variation_id'] = variationId;
            }
          }
          productList.add(productItem);
        }

        result = await ProductServices.calculateSchedule(
          calculationMode: 1,
          tariffId: int.tryParse(tariffId.toString()),
          totalAdvancePayment: _globalDownPayment,
          productList: productList,
        );
        
        print('📥 Simple mode API response: $result');
        
      } else {
        // Complex mode (calculation_mode = 2)
        print('📤 Complex mode - sending calculation_mode: 2');
        
        final productList = <Map<String, dynamic>>[];
        
        for (final item in cartItems) {
          final uniqueId = item['uniqueId'] as String;
          final tariff = _itemTariffs[uniqueId];
          final downPayment = _itemDownPayments[uniqueId] ?? 0.0;
          
          if (tariff == null) {
          CustomToast.show(
            context,
              message: 'Выберите срок рассрочки для всех товаров',
              isSuccess: false,
            );
            return;
          }

          // Convert product_id to int
          final productId = item['id'] is int 
              ? item['id'] 
              : int.tryParse(item['id'].toString()) ?? item['id'];
          
          // Convert quantity to int
          final quantity = item['quantity'] is int 
              ? item['quantity'] 
              : int.tryParse(item['quantity'].toString()) ?? item['quantity'];
          
          // Convert tariff_id to int
          final tariffId = tariff['id'] is int 
              ? tariff['id'] 
              : int.tryParse(tariff['id'].toString()) ?? tariff['id'];
          
          // Convert advance_payment to int
          final advancePayment = downPayment is int 
              ? downPayment 
              : downPayment.toInt();
          
          final productItem = <String, dynamic>{
            'product_id': productId,
            'quantity': quantity,
            'tariff_id': tariffId,
            'advance_payment': advancePayment,
          };
          // Add variation_id only if it exists and is not null
          if (item['variation_id'] != null) {
            final variationId = item['variation_id'] is int 
                ? item['variation_id'] 
                : int.tryParse(item['variation_id'].toString());
            if (variationId != null) {
              productItem['variation_id'] = variationId;
            }
          }
          productList.add(productItem);
        }

        result = await ProductServices.calculateSchedule(
          calculationMode: 2,
          productList: productList,
        );
        
        print('📥 Complex mode API response: $result');
      }

      // Step 3: Handle the response
      if (result != null) {
        print('✅ Payment schedule calculation successful!');
        print('📋 Response details: $result');
        
        // Check ability_to_order and status
        final abilityToOrder = result['ability_to_order'] as bool? ?? true;
        final status = result['status']?.toString() ?? '';
        
        // Special case: status is "Accepted" but ability_to_order is false
        // Show error toast about minimum contribution
        if (status.toLowerCase() == 'accepted' && !abilityToOrder) {
          final minimumContribution = result['minimum_contribution'];
          String minimumContributionText = '15';
          
          if (minimumContribution != null) {
            final numValue = minimumContribution is num 
                ? minimumContribution 
                : (double.tryParse(minimumContribution.toString()) ?? 15.0);
            
            // Format: remove .0 if it's a whole number
            if (numValue % 1 == 0) {
              minimumContributionText = numValue.toInt().toString();
            } else {
              minimumContributionText = numValue.toString();
            }
          }
          
          CustomToast.show(
            context,
            message: 'Минимальный первоначальный взнос должен быть не менее $minimumContributionText',
            isSuccess: false,
          );
          
          setState(() {
            _canBuy = false;
          });
          
          return;
        }
        
        // Special case: status is "Denied" or "Denied by client"
        final statusLower = status.toLowerCase();
        if (statusLower == 'denied' || statusLower == 'denied by client') {
          setState(() {
            _canBuy = false;
          });
          
          // Show denied modal
          _showDeniedModal();
          return;
        }
        
        // If not accepted, save checking time and start timer
        if (!abilityToOrder || status.toLowerCase() != 'accepted') {
          final now = DateTime.now();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('lastChecking', now.toIso8601String());
          
          setState(() {
            _isChecking = true;
            _remainingSeconds = 60;
            _canBuy = false;
          });
          
          _startCheckTimer();
          
          // Show modal dialog
          _showCheckingModal();
        } else {
          // Accepted - create order immediately
          // Get counterparty_id from result
          final counterpartyId = result['counterparty_id']?.toString();
          
          // Prepare product list for order creation (same as schedule calculation)
          List<Map<String, dynamic>> orderProductList;
          
          if (_isSimpleMode) {
            // Simple mode - create product list without tariff_id and advance_payment
            orderProductList = <Map<String, dynamic>>[];
            for (final item in cartItems) {
              final productId = item['id'] is int 
                  ? item['id'] 
                  : int.tryParse(item['id'].toString()) ?? item['id'];
              final quantity = item['quantity'] is int 
                  ? item['quantity'] 
                  : int.tryParse(item['quantity'].toString()) ?? item['quantity'];
              
              final productItem = <String, dynamic>{
                'product_id': productId,
                'quantity': quantity,
              };
              if (item['variation_id'] != null) {
                final variationId = item['variation_id'] is int 
                    ? item['variation_id'] 
                    : int.tryParse(item['variation_id'].toString());
                if (variationId != null) {
                  productItem['variation_id'] = variationId;
                }
              }
              orderProductList.add(productItem);
            }
            
            // Create order with mode 1
            final orderResult = await OrderServices.createOrder(
              calculationMode: 1,
              totalAdvancePayment: _globalDownPayment,
              tariffId: int.tryParse(_selectedGlobalTariff?['id'].toString() ?? ''),
              counterpartyId: counterpartyId,
              productList: orderProductList,
            );
            
            if (orderResult != null) {
              // Order created successfully
              // Get order ID from response
              final orderId = orderResult['id'] ?? orderResult['order_id'];
              
              // Stop timer and clear checking state
              _checkTimer?.cancel();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('lastChecking');
              
              // Save order ID and delivery status to localStorage
              if (orderId != null) {
                await prefs.setInt('lastOrderedId', orderId is int ? orderId : int.tryParse(orderId.toString()) ?? 0);
              }
              await prefs.setBool('notEnteredDelivery', true);
              
              // Clear cart after successful order
              await CartService.clearCart();
              
              // Clear payment schedule and state
              await _clearPaymentSchedule();
              
              // Clear down payment and tariff selections
              _globalDownPayment = 0.0;
              _globalDownPaymentController.clear();
              _selectedGlobalTariff = null;
              _itemDownPayments.clear();
              _itemTariffs.clear();
              
              // Update state before loading cart items
              setState(() {
                _canBuy = true;
                _isChecking = false;
                _remainingSeconds = 0;
                _isProcessingOrder = false;
              });
              
              // Load cart items (will be empty now)
              // Note: _loadCartItems will call _loadPaymentSchedule, but since we cleared storage,
              // it won't restore old values
              await _loadCartItems();
              
              // Ensure state is still cleared after loading (in case _loadPaymentSchedule tried to restore)
              if (mounted) {
                setState(() {
                  _globalDownPayment = 0.0;
                  if (_globalDownPaymentController.text.isNotEmpty) {
                    _globalDownPaymentController.clear();
                  }
                  _selectedGlobalTariff = null;
                  _itemDownPayments.clear();
                  _itemTariffs.clear();
                });
              }
              
              if (mounted) {
                // Navigate to order address page
                Navigator.of(context).pushNamed('/order-address');
              }
            } else {
              // Order creation failed
          await _savePaymentSchedule(result);
              setState(() {
                _canBuy = true;
                _isChecking = false;
                _isProcessingOrder = false;
              });
              if (mounted) {
                CustomToast.show(
                  context,
                  message: 'Ошибка при создании заказа. Попробуйте снова.',
                  isSuccess: false,
                );
              }
            }
          } else {
            // Complex mode - use product list with tariff_id and advance_payment
            orderProductList = <Map<String, dynamic>>[];
            for (final item in cartItems) {
              final uniqueId = item['uniqueId'] as String;
              final tariff = _itemTariffs[uniqueId];
              final downPayment = _itemDownPayments[uniqueId] ?? 0.0;
              
              final productId = item['id'] is int 
                  ? item['id'] 
                  : int.tryParse(item['id'].toString()) ?? item['id'];
              final quantity = item['quantity'] is int 
                  ? item['quantity'] 
                  : int.tryParse(item['quantity'].toString()) ?? item['quantity'];
              final tariffId = tariff?['id'] != null
                  ? (tariff!['id'] is int 
                      ? tariff['id'] as int
                      : int.tryParse(tariff['id'].toString()))
                  : null;
              final advancePayment = downPayment is int 
                  ? downPayment 
                  : downPayment.toInt();
              
              final productItem = <String, dynamic>{
                'product_id': productId,
                'quantity': quantity,
                'tariff_id': tariffId,
                'advance_payment': advancePayment,
              };
              if (item['variation_id'] != null) {
                final variationId = item['variation_id'] is int 
                    ? item['variation_id'] 
                    : int.tryParse(item['variation_id'].toString());
                if (variationId != null) {
                  productItem['variation_id'] = variationId;
                }
              }
              orderProductList.add(productItem);
            }
            
            // Create order with mode 2
            final orderResult = await OrderServices.createOrder(
              calculationMode: 2,
              productList: orderProductList,
            );
            
            if (orderResult != null) {
              // Order created successfully
              // Get order ID from response
              final orderId = orderResult['id'] ?? orderResult['order_id'];
              
              // Stop timer and clear checking state
              _checkTimer?.cancel();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('lastChecking');
              
              // Save order ID and delivery status to localStorage
              if (orderId != null) {
                await prefs.setInt('lastOrderedId', orderId is int ? orderId : int.tryParse(orderId.toString()) ?? 0);
              }
              await prefs.setBool('notEnteredDelivery', true);
              
              // Clear cart after successful order
              await CartService.clearCart();
              
              // Clear payment schedule and state
              await _clearPaymentSchedule();
              
              // Clear down payment and tariff selections
              _globalDownPayment = 0.0;
              _globalDownPaymentController.clear();
              _selectedGlobalTariff = null;
              _itemDownPayments.clear();
              _itemTariffs.clear();
              
              // Update state before loading cart items
          setState(() {
            _canBuy = true;
            _isChecking = false;
                _remainingSeconds = 0;
                _isProcessingOrder = false;
          });
          
              // Load cart items (will be empty now)
              // Note: _loadCartItems will call _loadPaymentSchedule, but since we cleared storage,
              // it won't restore old values
              await _loadCartItems();
              
              // Ensure state is still cleared after loading (in case _loadPaymentSchedule tried to restore)
              if (mounted) {
                setState(() {
                  _globalDownPayment = 0.0;
                  if (_globalDownPaymentController.text.isNotEmpty) {
                    _globalDownPaymentController.clear();
                  }
                  _selectedGlobalTariff = null;
                  _itemDownPayments.clear();
                  _itemTariffs.clear();
                });
              }
              
              if (mounted) {
                // Navigate to order address page
                Navigator.of(context).pushNamed('/order-address');
              }
            } else {
              // Order creation failed
              await _savePaymentSchedule(result);
              setState(() {
                _canBuy = true;
                _isChecking = false;
                _isProcessingOrder = false;
              });
              if (mounted) {
          CustomToast.show(
            context,
                  message: 'Ошибка при создании заказа. Попробуйте снова.',
                  isSuccess: false,
          );
              }
            }
          }
        }
        
        // Save payment schedule to local storage (for checking case)
        if (!abilityToOrder || status.toLowerCase() != 'accepted') {
          await _savePaymentSchedule(result);
        }
        
      } else {
        print('❌ Payment schedule calculation failed');
        setState(() {
          _canBuy = true; // Allow retry
          _isChecking = false;
        });
        CustomToast.show(
          context,
          message: 'Ошибка при расчете графика платежей',
          isSuccess: false,
        );
      }

    } catch (e) {
      print('❌ Error in _handlePlaceOrder: $e');
      setState(() {
        _canBuy = true; // Allow retry on error
        _isChecking = false;
      });
      CustomToast.show(
        context,
        message: 'Произошла ошибка: ${e.toString()}',
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOrder = false;
        });
      }
    }
  }

  Widget _buildComplexModeItemFields(Map<String, dynamic> item, Color textColor, Color borderColor) {
    final uniqueId = item['uniqueId'] as String;
    final currentDownPayment = _itemDownPayments[uniqueId] ?? 0.0;
    var currentTariff = _itemTariffs[uniqueId];
    
    // Set default tariff to first one from response if not set
    if (currentTariff == null && _tariffs.isNotEmpty) {
      currentTariff = _tariffs.first;
      _itemTariffs[uniqueId] = currentTariff;
    }
    
    // Get or create controller for this specific item
    if (!_itemDownPaymentControllers.containsKey(uniqueId)) {
      _itemDownPaymentControllers[uniqueId] = TextEditingController(
        text: currentDownPayment == 0 ? '' : currentDownPayment.toInt().toString(),
      );
      _itemDownPaymentFocusNodes[uniqueId] = FocusNode();
    }
    
    final controller = _itemDownPaymentControllers[uniqueId]!;
    final focusNode = _itemDownPaymentFocusNodes[uniqueId]!;
    
    // Sync controller text with current value if not focused
    if (!focusNode.hasFocus) {
      final currentText = currentDownPayment == 0 ? '' : currentDownPayment.toInt().toString();
      if (controller.text != currentText) {
        controller.text = currentText;
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Down Payment Field
        Text(
          'Первоначальный взнос',
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        SizedBox(height: 8.h),
        Builder(
          builder: (context) {

            final isNoInstallment = currentTariff != null && 
                (currentTariff['payments_count'] == 0 || 
                 currentTariff['name']?.toString().toLowerCase() == 'no installment' ||
                 (currentTariff['coefficient'] as num?)?.toDouble() == 1.0);
            
            return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.transparent,
                border: Border.all(
                  color: isNoInstallment 
                      ? borderColor.withOpacity(0.3) 
                      : borderColor, 
                  width: 1
                ),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: TextFormField(
                enabled: !isNoInstallment,
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                  color: isNoInstallment 
                      ? textColor.withOpacity(0.5) 
                      : textColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
              hintText: '0',
              hintStyle: GoogleFonts.poppins(
                color: textColor.withOpacity(0.5),
                fontSize: 14.sp,
              ),
              prefixText: '\$',
              prefixStyle: GoogleFonts.poppins(
                    color: isNoInstallment 
                        ? textColor.withOpacity(0.5) 
                        : textColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTapOutside: (event) {
              // Close keyboard when tapping outside
              FocusScope.of(context).unfocus();
            },
            onChanged: (value) {
                  if (isNoInstallment) return;
              final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
              final intValue = cleanValue.isEmpty ? 0 : int.tryParse(cleanValue) ?? 0;
              
              // Get total item price (price * quantity)
              final productPrice = (_parsePriceValue(item['price']) ?? 0);
              final quantity = item['quantity'] as int? ?? 1;
              final totalItemPrice = (productPrice * quantity).toInt();
              final clampedValue = intValue.clamp(0, totalItemPrice);
              
              setState(() {
                _itemDownPayments[uniqueId] = clampedValue.toDouble();
              });
              
              // Save item down payments to storage
              final savedItemDownPayments = <String, double>{};
              for (final entry in _itemDownPayments.entries) {
                savedItemDownPayments[entry.key] = entry.value;
              }
              _storage.write(key: 'saved_item_down_payments', value: json.encode(savedItemDownPayments));
              
              // Update controller if value was clamped
              if (clampedValue != intValue) {
                final newText = clampedValue == 0 ? '' : clampedValue.toString();
                controller.value = controller.value.copyWith(
                  text: newText,
                  selection: TextSelection.collapsed(offset: newText.length),
                );
              }
            },
          ),
            );
          },
        ),
        
        SizedBox(height: 16.h),
        
        // Tariff Selection
        Text(
          'Срок рассрочки',
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: () => _showItemTariffModal(uniqueId, currentTariff),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: borderColor, width: 1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currentTariff != null 
                      ? (currentTariff['name'] ?? '')
                      : 'Выберите срок',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: textColor,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: textColor,
                  size: 20.w,
                ),
              ],
            ),
          ),
        ),
        
      ],
    );
  }

  void _showItemTariffModal(String uniqueId, Map<String, dynamic>? currentTariff) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modalColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final optionTextColor = isDark ? Colors.white : Colors.black87;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext dialogContext) {
        return GestureDetector(
          onTap: () {
            Navigator.of(dialogContext).pop();
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping inside modal
                child: Container(
                  width: screenWidth * 0.8,
                  constraints: BoxConstraints(
                    maxHeight: screenHeight * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: modalColor,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Срок рассрочки',
                              style: GoogleFonts.poppins(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                                color: optionTextColor,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(dialogContext).pop(),
                              child: Icon(
                                Icons.close,
                                color: optionTextColor,
                                size: 24.w,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Scrollable tariff list
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: _tariffs.map((tariff) {
                              final isSelected = currentTariff != null && 
                                  currentTariff['id'] == tariff['id'];
                              
                              return GestureDetector(
                                onTap: () async {
                                  // Stop timer if tariff changes
                                  _checkTimer?.cancel();
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.remove('lastChecking');
                                  
                                  setState(() {
                                    _itemTariffs[uniqueId] = tariff;
                                    _isChecking = false;
                                    _canBuy = true;
                                    _remainingSeconds = 0;
                                  });
                                  
                                  // Save item tariffs to storage
                                  final savedItemTariffs = <String, int>{};
                                  for (final entry in _itemTariffs.entries) {
                                    if (entry.value != null) {
                                      savedItemTariffs[entry.key] = entry.value!['id'] as int;
                                    }
                                  }
                                  _storage.write(key: 'saved_item_tariff_ids', value: json.encode(savedItemTariffs));
                                  
                                  Navigator.of(dialogContext).pop();
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? (isDark ? Colors.green.withOpacity(0.1) : Colors.green.withOpacity(0.05))
                                        : Colors.transparent,
                                    border: Border(
                                      bottom: tariff != _tariffs.last
                                          ? BorderSide(
                                              color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                                              width: 0.5,
                                            )
                                          : BorderSide.none,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tariff['name'] ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16.sp,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: isSelected ? Colors.green : optionTextColor,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 24.w,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _calculateSchedule() async {
    try {
      if (_isSimpleMode) {
        // Simple mode (Mode 1)
        final tariffId = _selectedGlobalTariff?['id'];
        if (tariffId == null) {
          CustomToast.show(
            context,
            message: 'Выберите срок рассрочки',
            isSuccess: false,
          );
          return;
        }

        final result = await ProductServices.calculateSchedule(
          calculationMode: 1,
          tariffId: int.tryParse(tariffId.toString()),
          totalAdvancePayment: _globalDownPayment,
        );

        if (result != null) {
          print('✅ Simple mode calculation result: $result');
          // Handle the result here
        } else {
          CustomToast.show(
            context,
            message: 'Ошибка при расчете графика',
            isSuccess: false,
          );
        }
      } else {
        // Complex mode (Mode 2)
        final productList = <Map<String, dynamic>>[];
        
        for (final item in cartItems) {
          final uniqueId = item['uniqueId'] as String;
          final tariff = _itemTariffs[uniqueId];
          final downPayment = _itemDownPayments[uniqueId] ?? 0.0;
          
          if (tariff == null) {
            CustomToast.show(
              context,
              message: 'Выберите срок рассрочки для всех товаров',
              isSuccess: false,
            );
            return;
          }

          // Convert product_id to int
          final productId = item['id'] is int 
              ? item['id'] 
              : int.tryParse(item['id'].toString()) ?? item['id'];
          
          // Convert quantity to int
          final quantity = item['quantity'] is int 
              ? item['quantity'] 
              : int.tryParse(item['quantity'].toString()) ?? item['quantity'];
          
          // Convert tariff_id to int
          final tariffId = tariff['id'] is int 
              ? tariff['id'] 
              : int.tryParse(tariff['id'].toString()) ?? tariff['id'];
          
          // Convert advance_payment to int
          final advancePayment = downPayment is int 
              ? downPayment 
              : downPayment.toInt();
          
          final productItem = <String, dynamic>{
            'product_id': productId,
            'quantity': quantity,
            'tariff_id': tariffId,
            'advance_payment': advancePayment,
          };
          // Add variation_id only if it exists and is not null
          if (item['variation_id'] != null) {
            final variationId = item['variation_id'] is int 
                ? item['variation_id'] 
                : int.tryParse(item['variation_id'].toString());
            if (variationId != null) {
              productItem['variation_id'] = variationId;
            }
          }
          productList.add(productItem);
        }

        final result = await ProductServices.calculateSchedule(
          calculationMode: 2,
          productList: productList,
        );

        if (result != null) {
          print('✅ Complex mode calculation result: $result');
          // Handle the result here
        } else {
          CustomToast.show(
            context,
            message: 'Ошибка при расчете графика',
            isSuccess: false,
          );
        }
      }
    } catch (e) {
      print('❌ Error in _calculateSchedule: $e');
      CustomToast.show(
        context,
        message: 'Произошла ошибка: ${e.toString()}',
        isSuccess: false,
      );
    }
  }

  // Calculate schedule simple with debounce
  void _scheduleCalculateDebounced() {
    _scheduleDebounceTimer?.cancel();
    _scheduleDebounceTimer = Timer(const Duration(seconds: 3), () {
      _calculateScheduleSimple();
    });
  }

  Future<void> _calculateScheduleSimple() async {
    if (_isScheduleCalculating) return;
    if (cartItems.isEmpty) return;

    try {
      _isScheduleCalculating = true;
      
      if (_isSimpleMode) {
        // Simple mode (Mode 1)
        final tariffId = _selectedGlobalTariff?['id'];
        if (tariffId == null) {
          _isScheduleCalculating = false;
          return;
        }

        // Create product list for simple mode
        final productList = <Map<String, dynamic>>[];
        for (final item in cartItems) {
          final productId = item['id'] is int 
              ? item['id'] 
              : int.tryParse(item['id'].toString()) ?? item['id'];
          final quantity = item['quantity'] is int 
              ? item['quantity'] 
              : int.tryParse(item['quantity'].toString()) ?? item['quantity'];
          
          final productItem = <String, dynamic>{
            'product_id': productId,
            'quantity': quantity,
          };
          if (item['variation_id'] != null) {
            final variationId = item['variation_id'] is int 
                ? item['variation_id'] 
                : int.tryParse(item['variation_id'].toString());
            if (variationId != null) {
              productItem['variation_id'] = variationId;
            }
          }
          productList.add(productItem);
        }

        final result = await ProductServices.calculateScheduleSimple(
          calculationMode: 1,
          tariffId: int.tryParse(tariffId.toString()),
          totalAdvancePayment: _globalDownPayment,
          productList: productList,
        );

        if (result != null && mounted) {
          // Update payment schedule with monthly_payments from simple API
          // Don't save schedule to storage - it will be loaded from API on each mount
          setState(() {
            _paymentSchedule = {
              'monthly_payments': result['monthly_payments'] ?? [],
              'product_list': result['product_list'] ?? [],
            };
          });
          
          print('✅ Simple mode schedule simple result: ${result['monthly_payments']?.length} payments');
        }
      } else {
        // Complex mode (Mode 2)
        final productList = <Map<String, dynamic>>[];
        
        for (final item in cartItems) {
          final uniqueId = item['uniqueId'] as String;
          final tariff = _itemTariffs[uniqueId];
          final downPayment = _itemDownPayments[uniqueId] ?? 0.0;
          
          if (tariff == null) {
            _isScheduleCalculating = false;
            return;
          }

          final productId = item['id'] is int 
              ? item['id'] 
              : int.tryParse(item['id'].toString()) ?? item['id'];
          final quantity = item['quantity'] is int 
              ? item['quantity'] 
              : int.tryParse(item['quantity'].toString()) ?? item['quantity'];
          final tariffId = tariff['id'] is int 
              ? tariff['id'] 
              : int.tryParse(tariff['id'].toString()) ?? tariff['id'];
          final advancePayment = downPayment is int 
              ? downPayment 
              : downPayment.toInt();
          
          final productItem = <String, dynamic>{
            'product_id': productId,
            'quantity': quantity,
            'tariff_id': tariffId,
            'advance_payment': advancePayment,
          };
          if (item['variation_id'] != null) {
            final variationId = item['variation_id'] is int 
                ? item['variation_id'] 
                : int.tryParse(item['variation_id'].toString());
            if (variationId != null) {
              productItem['variation_id'] = variationId;
            }
          }
          productList.add(productItem);
        }

        final result = await ProductServices.calculateScheduleSimple(
          calculationMode: 2,
          productList: productList,
        );

        if (result != null && mounted) {
          // Update payment schedule with monthly_payments from simple API
          // Don't save schedule to storage - it will be loaded from API on each mount
          setState(() {
            _paymentSchedule = {
              'monthly_payments': result['monthly_payments'] ?? [],
              'product_list': result['product_list'] ?? [],
            };
          });
          
          print('✅ Complex mode schedule simple result: ${result['monthly_payments']?.length} payments');
        }
      }
    } catch (e) {
      print('❌ Error in _calculateScheduleSimple: $e');
    } finally {
      _isScheduleCalculating = false;
    }
  }

  String _getSelectedTariffName() {
    if (_selectedGlobalTariff == null || _tariffs.isEmpty) {
      return 'Выберите срок';
    }
    
    return _selectedGlobalTariff!['name'] ?? '';
  }

  void _showGlobalTariffModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modalColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final optionTextColor = isDark ? Colors.white : Colors.black87;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext dialogContext) {
        return GestureDetector(
          onTap: () {
            Navigator.of(dialogContext).pop();
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping inside modal
                child: Container(
                  width: screenWidth * 0.8,
                  constraints: BoxConstraints(
                    maxHeight: screenHeight * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: modalColor,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Срок рассрочки',
                              style: GoogleFonts.poppins(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                                color: optionTextColor,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(dialogContext).pop(),
                              child: Icon(
                                Icons.close,
                                color: optionTextColor,
                                size: 24.w,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Scrollable tariff list
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: _tariffs.map((tariff) {
                              final isSelected = _selectedGlobalTariff == tariff;
                              
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedGlobalTariff = tariff;
                                  });
                                  
                                  // Save tariff to storage
                                  if (tariff != null) {
                                    _storage.write(key: 'saved_global_tariff_id', value: json.encode(tariff['id']));
                                  }
                                  
                                  Navigator.of(dialogContext).pop();
                                  
                                  // Trigger schedule calculation with debounce when tariff changes
                                  // Wait for modal to close first
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    if (mounted && cartItems.isNotEmpty) {
                                      _scheduleCalculateDebounced();
                                    }
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? (isDark ? Colors.green.withOpacity(0.1) : Colors.green.withOpacity(0.05))
                                        : Colors.transparent,
                                    border: Border(
                                      bottom: tariff != _tariffs.last
                                          ? BorderSide(
                                              color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                                              width: 0.5,
                                            )
                                          : BorderSide.none,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tariff['name'] ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16.sp,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: isSelected ? Colors.green : optionTextColor,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 24.w,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentScheduleCard(Color textColor, Color cardColor) {
    if (_paymentSchedule == null) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthlyPayments = _paymentSchedule!['monthly_payments'] as List? ?? [];
    // Simple API doesn't return these fields, so use defaults or calculate
    final totalEveryMonthPayment = _paymentSchedule!['total_every_month_payment'] ?? 0;
    final totalProductsPrice = _paymentSchedule!['total_products_price'] ?? _calculateTotal();
    final totalAdvancePayment = _paymentSchedule!['total_advance_payment'] ?? _globalDownPayment;
    
    // Table colors for light/dark theme
    final tableBgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final tableTextColor = isDark ? Colors.white : Colors.black87;
    final tableBorderColor = isDark ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.3);
    
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'График платежей',
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 16.h),
          
          // Payment schedule table
          Container(
            decoration: BoxDecoration(
              color: tableBgColor,
              borderRadius: BorderRadius.circular(16.r),
            ),
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Месяц',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: tableTextColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Дата',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: tableTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Сумма',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: tableTextColor,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16.h),
                
                // Payment rows
                ...monthlyPayments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final payment = entry.value as Map<String, dynamic>;
                  final number = payment['number'] ?? (index + 1);
                  final date = payment['date'] ?? '';
                  final amount = payment['payment'] ?? 0;
                  
                  return Container(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: tableBorderColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            '$number',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: tableTextColor,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            date.toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: tableTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            _formatUsdAmount((amount is num ? amount.toDouble() : double.tryParse(amount.toString()) ?? 0.0)),
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: tableTextColor,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          
          SizedBox(height: 16.h),
          
          // Total summary - separate container
          Container(
            // padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Итого к доплате:',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      _formatUsdAmount(_calculateTotalMonthlyPayments(monthlyPayments)),
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1B7EFF),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // Первоначальный взнос
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Первоначальный взнос:',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    Text(
                      _formatUsdAmount(_calculateAdvancePayment()),
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                // В рассрочку - only for simple mode
                if (_isSimpleMode) ...[
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'В рассрочку:',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _formatUsdAmount(_calculateMonthlyPayment()),
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'в месяц',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w400,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showCheckingModal() {
    if (!_isChecking) return; // Don't show if not checking
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    
    showDialog(
      context: context,
      barrierDismissible: true, // Allow closing by tapping outside
      builder: (context) => _CheckingModalDialog(
        remainingSeconds: _remainingSeconds,
        onTimerUpdate: () {
          if (mounted) {
            setState(() {});
          }
        },
        textColor: textColor,
        cardColor: cardColor,
      ),
    ).then((_) {
      // When modal is closed, check if we should show it again when button is pressed
      // This is handled in _handlePlaceOrder
    });
  }

  void _showAdminCheckModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    
    // Start checking timer (60 seconds)
    setState(() {
      _isChecking = true;
      _remainingSeconds = 60;
    });
    
    // Save checking time
    _saveCheckingTime();
    
    // Start timer
    _startCheckTimer();
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AdminCheckModalDialog(
        remainingSeconds: _remainingSeconds,
        onTimerUpdate: () {
          if (mounted) {
            setState(() {});
          }
        },
        textColor: textColor,
        cardColor: cardColor,
      ),
    ).then((_) {
      // When modal is closed
    });
  }

  void _showDeniedModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    
    showDialog(
      context: context,
      barrierDismissible: true, // Allow closing by tapping outside
      builder: (context) => _DeniedModalDialog(
        textColor: textColor,
        cardColor: cardColor,
      ),
    );
  }
}

class _CheckingModalDialog extends StatefulWidget {
  final int remainingSeconds;
  final VoidCallback onTimerUpdate;
  final Color textColor;
  final Color cardColor;

  const _CheckingModalDialog({
    required this.remainingSeconds,
    required this.onTimerUpdate,
    required this.textColor,
    required this.cardColor,
  });

  @override
  State<_CheckingModalDialog> createState() => _CheckingModalDialogState();
}

class _CheckingModalDialogState extends State<_CheckingModalDialog> {
  late int _currentSeconds;
  Timer? _modalTimer;

  @override
  void initState() {
    super.initState();
    _currentSeconds = widget.remainingSeconds;
    _startModalTimer();
  }

  @override
  void didUpdateWidget(_CheckingModalDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remainingSeconds != widget.remainingSeconds) {
      _currentSeconds = widget.remainingSeconds;
    }
  }

  void _startModalTimer() {
    _modalTimer?.cancel();
    if (_currentSeconds > 0) {
      _modalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_currentSeconds > 0) {
          setState(() {
            _currentSeconds--;
          });
          widget.onTimerUpdate();
        } else {
          timer.cancel();
          // Close modal when timer reaches 0
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _modalTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _currentSeconds ~/ 60;
    final seconds = _currentSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return AlertDialog(
      backgroundColor: widget.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      title: Text(
        'Проверка заказа',
        style: GoogleFonts.poppins(
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
          color: widget.textColor,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ваша заявка рассматривается',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              color: widget.textColor,
            ),
          ),
          SizedBox(height: 16.h),
          if (_currentSeconds > 0) ...[
            Text(
              'Попробуйте снова через:',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: widget.textColor.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFF1B7EFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer,
                    color: const Color(0xFF1B7EFF),
                    size: 24.w,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    timeString,
                    style: GoogleFonts.poppins(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1B7EFF),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Вы можете попробовать снова.',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: const Color(0xFF1B7EFF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'Понятно',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B7EFF),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeniedModalDialog extends StatelessWidget {
  final Color textColor;
  final Color cardColor;

  const _DeniedModalDialog({
    required this.textColor,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'К сожалению, вы не можете приобрести у нас товары в рассрочку',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Попробуйте снова через 1 месяц',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'Понятно',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B7EFF),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminCheckModalDialog extends StatefulWidget {
  final int remainingSeconds;
  final VoidCallback onTimerUpdate;
  final Color textColor;
  final Color cardColor;

  const _AdminCheckModalDialog({
    required this.remainingSeconds,
    required this.onTimerUpdate,
    required this.textColor,
    required this.cardColor,
  });

  @override
  State<_AdminCheckModalDialog> createState() => _AdminCheckModalDialogState();
}

class _AdminCheckModalDialogState extends State<_AdminCheckModalDialog> {
  late int _currentSeconds;
  Timer? _modalTimer;

  @override
  void initState() {
    super.initState();
    _currentSeconds = widget.remainingSeconds;
    _startModalTimer();
  }

  @override
  void didUpdateWidget(_AdminCheckModalDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remainingSeconds != widget.remainingSeconds) {
      _currentSeconds = widget.remainingSeconds;
    }
  }

  void _startModalTimer() {
    _modalTimer?.cancel();
    if (_currentSeconds > 0) {
      _modalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_currentSeconds > 0) {
          setState(() {
            _currentSeconds--;
          });
          widget.onTimerUpdate();
        } else {
          timer.cancel();
          // Close modal when timer reaches 0
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _modalTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _currentSeconds ~/ 60;
    final seconds = _currentSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return AlertDialog(
      backgroundColor: widget.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      title: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.orange,
            size: 24.w,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Проверка заказа',
              style: GoogleFonts.poppins(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: widget.textColor,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ваша заявка рассматривается',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              color: widget.textColor,
            ),
          ),
          SizedBox(height: 16.h),
          if (_currentSeconds > 0) ...[
            Text(
              'Попробуйте снова через:',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: widget.textColor.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFF1B7EFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer,
                    color: const Color(0xFF1B7EFF),
                    size: 24.w,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    timeString,
                    style: GoogleFonts.poppins(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1B7EFF),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Вы можете попробовать снова.',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: const Color(0xFF1B7EFF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'Понятно',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B7EFF),
            ),
          ),
        ),
      ],
    );
  }
}

