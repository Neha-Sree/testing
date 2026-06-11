import 'package:flutter/material.dart';

class AppTheme {
  // Color palette
  static const Color primaryPink = Color(0xFFE91E63);
  static const Color lightPink = Color(0xFFFCE4EC);
  static const Color darkPink = Color(0xFFAD1457);

  // Module-specific colors
  static const Color dietGreen = Color(0xFF4CAF50);
  static const Color dietLightGreen = Color(0xFFE8F5E8);

  static const Color hydrationBlue = Color(0xFF2196F3);
  static const Color hydrationLightBlue = Color(0xFFE3F2FD);

  static const Color fetalPurple = Color(0xFF9C27B0);
  static const Color fetalLightPurple = Color(0xFFF3E5F5);

  static const Color contractionRed = Color(0xFFF44336);
  static const Color contractionLightRed = Color(0xFFFFEBEE);

  static const Color stepsOrange = Color(0xFFFF9800);
  static const Color stepsLightOrange = Color(0xFFFFF3E0);

  // Neutral colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);

  // Text styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Color(0xFF212121),
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: Color(0xFF212121),
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF212121),
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: Color(0xFF424242),
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Color(0xFF424242),
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: Color(0xFF757575),
  );

  // Spacing
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Border radius
  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(8.0));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(12.0));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(16.0));
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(20.0));

  // Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> buttonShadow = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPink,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: Color(0xFF212121),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: headingMedium,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: mdRadius),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPink,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: mdRadius),
          padding: const EdgeInsets.symmetric(horizontal: md, vertical: sm),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryPink,
          side: const BorderSide(color: primaryPink),
          shape: RoundedRectangleBorder(borderRadius: mdRadius),
          padding: const EdgeInsets.symmetric(horizontal: md, vertical: sm),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryPink,
          shape: RoundedRectangleBorder(borderRadius: mdRadius),
          padding: const EdgeInsets.symmetric(horizontal: md, vertical: sm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: mdRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: mdRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: mdRadius,
          borderSide: const BorderSide(color: primaryPink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: mdRadius,
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: md,
          vertical: md,
        ),
      ),
    );
  }
}
