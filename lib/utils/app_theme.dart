import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1B7A34);
  static const Color primaryLight = Color(0xFFE8F5EC);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F5);
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF555555);
  static const Color error = Color(0xFFCC0000);
  static const Color warning = Color(0xFFCC7700);
  static const Color info = Color(0xFF1A5276);
  static const Color border = Color(0xFFCCCCCC);
  static const Color white = Color(0xFFFFFFFF);
  static const Color statusSubmitted = Color(0xFF888888);
  static const Color statusAccepted = Color(0xFF1B7A34);
  static const Color statusScheduled = Color(0xFF1B7A34);
  static const Color statusPickedUp = Color(0xFFCC7700);
  static const Color statusCompleted = Color(0xFF333333);
  static const Color statusCancelled = Color(0xFFCC0000);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: AppColors.white,
      ),
    );
  }
}

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String termsPolicies = '/terms-policies';
  static const String farmerDashboard = '/farmer/farmer_dashboard.dart';
  static const String requestPickup = '/farmer/request-pickup';
  static const String requestStatus = '/farmer/request-status';
  static const String requestDetail = '/farmer/request-detail';
  static const String mapScreen = '/farmer/map';
  static const String collectionPointDetail = '/farmer/collection-point-detail';
  static const String reportIssue = '/farmer/report-issue';
  static const String notifications = '/notifications';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminRequestDetail = '/admin/request-detail';
  static const String collectionPointManagement = '/admin/collection-points';
}
