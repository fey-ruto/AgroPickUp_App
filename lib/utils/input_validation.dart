class InputValidation {
  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _passwordUppercase = RegExp(r'[A-Z]');
  static final RegExp _passwordLowercase = RegExp(r'[a-z]');
  static final RegExp _passwordDigit = RegExp(r'\d');
  static final RegExp _passwordSpecial =
      RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\/]');
  static final RegExp _driverIdPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9\s\-_/]{0,39}$',
  );
  static final RegExp _operatingHoursPattern =
      RegExp(r'^\d{1,2}:\d{2}\s?-\s?\d{1,2}:\d{2}$');

  static String normalizeText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static String? requiredText(
    String? value, {
    required String fieldName,
    int? maxLength,
  }) {
    final text = normalizeText(value);
    if (text.isEmpty) {
      return 'Please enter $fieldName.';
    }
    if (maxLength != null && text.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters.';
    }
    return null;
  }

  static String? optionalText(
    String? value, {
    required String fieldName,
    int maxLength = 1000,
  }) {
    final text = normalizeText(value);
    if (text.isEmpty) return null;
    if (text.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters.';
    }
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Please enter your email address.';
    }
    if (!_emailPattern.hasMatch(text)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Please enter a password.';
    }
    if (text.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (!_passwordUppercase.hasMatch(text)) {
      return 'Password must include at least one uppercase letter.';
    }
    if (!_passwordLowercase.hasMatch(text)) {
      return 'Password must include at least one lowercase letter.';
    }
    if (!_passwordDigit.hasMatch(text)) {
      return 'Password must include at least one number.';
    }
    if (!_passwordSpecial.hasMatch(text)) {
      return 'Password must include at least one special character.';
    }
    return null;
  }

  static String? tenDigitPhone(String? value,
      {String fieldName = 'Phone number'}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Please enter your $fieldName.';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(text)) {
      return '$fieldName must be exactly 10 digits.';
    }
    return null;
  }

  static String? optionalTenDigitPhone(
    String? value, {
    String fieldName = 'Phone number',
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^\d{10}$').hasMatch(text)) {
      return '$fieldName must be exactly 10 digits.';
    }
    return null;
  }

  static String? driverId(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > 40) {
      return 'Driver ID cannot exceed 40 characters.';
    }
    if (!_driverIdPattern.hasMatch(text)) {
      return 'Driver ID can only include letters, numbers, spaces, hyphens, underscores, and slashes.';
    }
    return null;
  }

  static String? operatingHours(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!_operatingHoursPattern.hasMatch(text)) {
      return 'Use the format HH:MM - HH:MM.';
    }
    return null;
  }
}
