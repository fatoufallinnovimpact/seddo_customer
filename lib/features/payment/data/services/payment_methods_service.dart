import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:seddo/core/network/api_client.dart';
import 'package:seddo/core/utils/api_endpoints.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized service to manage payment methods:
/// - Persists selected method locally (default: 'CASH')
/// - Communicates with backend endpoints:
///   * GET /v1/payment-methods
///   * PUT /v1/payment-methods/selected
/// - Exposes a reactive [selectedCodeNotifier] so UI updates instantly across the app.
class PaymentMethodsService {
  static final PaymentMethodsService _instance = PaymentMethodsService._internal();
  static const String prefKeySelectedPaymentMethod = 'selected_payment_method_code';

  final Dio _dio;
  final ValueNotifier<String> selectedCodeNotifier = ValueNotifier<String>('CASH');
  bool _isInitialized = false;

  factory PaymentMethodsService({Dio? dio}) {
    if (dio != null) return PaymentMethodsService._internal(dio: dio);
    return _instance;
  }

  PaymentMethodsService._internal({Dio? dio}) : _dio = dio ?? ApiClient().dio {
    init();
  }

  /// Current selected payment code: 'CASH', 'WAVE', or 'ORANGE_MONEY'
  String get currentCode => selectedCodeNotifier.value;

  /// Normalize any backend payment method string to 'CASH', 'WAVE', or 'ORANGE_MONEY'
  static String normalizeCode(String? raw) {
    if (raw == null) return 'CASH';
    final upper = raw.toUpperCase().trim();
    if (upper == 'OM' || upper.contains('ORANGE')) return 'ORANGE_MONEY';
    if (upper.contains('WAVE')) return 'WAVE';
    if (upper.contains('CASH') || upper.contains('ESPECE')) return 'CASH';
    return upper;
  }

  /// Update the current selected code if [raw] maps to a valid payment method
  void updateCodeIfValid(String? raw) {
    if (raw == null || raw.trim().isEmpty) return;
    final code = normalizeCode(raw);
    if (code == 'CASH' || code == 'WAVE' || code == 'ORANGE_MONEY') {
      if (selectedCodeNotifier.value != code) {
        _updateLocalCode(code);
      }
    }
  }

  /// Human-friendly display label for the code
  static String getLabelForCode(String code) {
    switch (normalizeCode(code)) {
      case 'WAVE':
        return 'Wave';
      case 'ORANGE_MONEY':
        return 'Orange Money';
      case 'CASH':
      default:
        return 'Espèces';
    }
  }

  /// Asset icon path for the code
  static String getAssetForCode(String code) {
    switch (normalizeCode(code)) {
      case 'WAVE':
        return 'assets/images/images.png';
      case 'ORANGE_MONEY':
        return 'assets/images/unnamed.png';
      case 'CASH':
      default:
        return 'assets/images/cash_banknotes.png';
    }
  }

  /// Initialize from local storage, then refresh from API if online
  Future<String> init() async {
    if (_isInitialized) return selectedCodeNotifier.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefKeySelectedPaymentMethod);
      if (saved != null && saved.isNotEmpty) {
        selectedCodeNotifier.value = saved.toUpperCase();
      } else {
        selectedCodeNotifier.value = 'CASH';
      }
      _isInitialized = true;
    } catch (_) {
      selectedCodeNotifier.value = 'CASH';
    }

    // Refresh asynchronously from backend without blocking
    refreshFromBackend().ignore();
    return selectedCodeNotifier.value;
  }

  /// Fetch payment methods list from GET /v1/payment-methods
  Future<List<Map<String, dynamic>>> fetchPaymentMethods() async {
    try {
      final response = await _dio.get(ApiEndpoints.paymentMethods);
      if (response.statusCode == 200) {
        List<dynamic>? rawList;

        if (response.data is List) {
          rawList = response.data as List;
        } else if (response.data is Map) {
          final map = response.data as Map;
          if (map['paymentMethods'] is List) {
            rawList = map['paymentMethods'] as List;
          } else if (map['payment_methods'] is List) {
            rawList = map['payment_methods'] as List;
          } else if (map['methods'] is List) {
            rawList = map['methods'] as List;
          } else if (map['data'] is List) {
            rawList = map['data'] as List;
          }

          // Direct selected payment code from map response
          final directSelected = map['selected'] ??
              map['selectedCode'] ??
              map['selectedMethod'] ??
              map['defaultPaymentMethod'] ??
              map['default_payment_method'] ??
              map['paymentMethod'] ??
              map['payment_method'] ??
              map['code'];
          if (directSelected != null && directSelected.toString().isNotEmpty) {
            updateCodeIfValid(directSelected.toString());
          }
        }

        if (rawList != null) {
          final list = List<Map<String, dynamic>>.from(
            rawList.map((e) => Map<String, dynamic>.from(e as Map)),
          );

          // Find which one is marked selected
          for (final item in list) {
            final isSelected = item['selected'] == true ||
                item['isSelected'] == true ||
                item['is_selected'] == true ||
                item['default'] == true ||
                item['isDefault'] == true ||
                item['is_default'] == true;
            final rawCode = (item['code'] ??
                    item['id'] ??
                    item['type'] ??
                    item['method'] ??
                    item['paymentMethod'] ??
                    item['payment_method'])
                ?.toString();
            if (isSelected && rawCode != null && rawCode.isNotEmpty) {
              updateCodeIfValid(rawCode);
              break;
            }
          }
          return list;
        }
      }
    } catch (e) {
      debugPrint('[PaymentMethodsService] Error fetching payment methods: $e');
    }
    return [];
  }

  /// Asynchronously refresh selected method from backend
  Future<void> refreshFromBackend() async {
    try {
      await fetchPaymentMethods();
    } catch (_) {}
  }

  /// Select payment method via PUT /v1/payment-methods/selected
  /// Backend expects { "code": "ORANGE_MONEY" | "WAVE" | "CASH" }
  Future<bool> selectPaymentMethod(String code) async {
    final normalizedCode = code.toUpperCase().trim();
    if (normalizedCode != 'CASH' &&
        normalizedCode != 'WAVE' &&
        normalizedCode != 'ORANGE_MONEY') {
      debugPrint('[PaymentMethodsService] Invalid payment code: $code');
      return false;
    }

    // Optimistically update local state & SharedPreferences
    await _updateLocalCode(normalizedCode);

    try {
      final response = await _dio.put(
        ApiEndpoints.selectPaymentMethod,
        data: {'code': normalizedCode},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('[PaymentMethodsService] ✅ Payment method saved to backend: $normalizedCode');
        return true;
      }
    } catch (e) {
      debugPrint('[PaymentMethodsService] ⚠️ Backend update failed (offline/error), cached locally: $e');
    }
    // Return true because local cache succeeded even if backend is temporarily unreachable
    return true;
  }

  Future<void> _updateLocalCode(String code) async {
    selectedCodeNotifier.value = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKeySelectedPaymentMethod, code);
    } catch (_) {}
  }
}
