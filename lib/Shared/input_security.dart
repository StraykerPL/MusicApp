import 'package:flutter/services.dart';

final class InputSecurity {
  static const int maxTextLength = 120;

  static final RegExp _controlCharacters =
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final RegExp _dangerousPatterns = RegExp(
    r'(<\s*/?\s*script\b|<[^>]+>|--|/\*|\*/|;|\|\||&&|`|\$\(|\b(or|and)\b\s+\d+\s*=\s*\d+|\b(drop|delete|insert|update|alter|create|union|exec|execute)\b)',
    caseSensitive: false,
  );

  static bool isSafeUserText(String value) {
    return getValidationError(value) == null;
  }

  static String? getValidationError(String value) {
    if (value.length > maxTextLength) {
      return 'Input is too long.';
    }

    if (_controlCharacters.hasMatch(value)) {
      return 'Input contains unsupported control characters.';
    }

    if (_dangerousPatterns.hasMatch(value)) {
      return 'Input contains potentially unsafe characters or commands.';
    }

    return null;
  }
}

final class SecureTextInputFormatter extends TextInputFormatter {
  const SecureTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (InputSecurity.isSafeUserText(newValue.text)) {
      return newValue;
    }

    return oldValue;
  }
}
