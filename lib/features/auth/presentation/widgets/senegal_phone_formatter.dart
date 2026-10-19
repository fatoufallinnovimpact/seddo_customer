import 'package:flutter/services.dart';

/// Formats a 9-digit Senegalese phone number as:
/// "XX XXX XX XX" (e.g. "77 123 45 12")
/// Strictly caps input at 9 raw digits. Any extra character typed is discarded.
class SenegalPhoneInputFormatter extends TextInputFormatter {
  static const int maxDigits = 9;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Extract only digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Strictly cap at 9 digits: once 9 digits are reached, ignore any further input
    final cappedDigits = digitsOnly.length > maxDigits
        ? digitsOnly.substring(0, maxDigits)
        : digitsOnly;

    final buffer = StringBuffer();
    for (int i = 0; i < cappedDigits.length; i++) {
      if (i == 2 || i == 5 || i == 7) {
        buffer.write(' ');
      }
      buffer.write(cappedDigits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
