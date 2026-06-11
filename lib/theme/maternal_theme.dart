import 'package:flutter/material.dart';

class MaternalTheme {
  // Primary Pink Pastel Palette
  static const Color primaryPink = Color(0xFFE91E63);
  static const Color lightPink = Color(0xFFFCE4EC);
  static const Color lighterPink = Color(0xFFFFF0F5);
  static const Color darkPink = Color(0xFFAD1457);
  static const Color pastelPink = Color(0xFFFFB6C1);
  static const Color babyPink = Color(0xFFFFE0EC);

  // Soft Pastel Colors
  static const Color lavender = Color(0xFFE6E6FA);
  static const Color mint = Color(0xFFE8F5E8);
  static const Color peach = Color(0xFFFFDAB9);
  static const Color skyBlue = Color(0xFFE0F2FE);
  static const Color lemon = Color(0xFFFFF9C4);

  // Module-specific Colors
  static const Color hydrationBlue = Color(0xFF64B5F6);
  static const Color stepsOrange = Color(0xFFFFB74D);
  static const Color weightPurple = Color(0xFFBA68C8);
  static const Color bloodRed = Color(0xFFEF5350);
  static const Color dietGreen = Color(0xFF81C784);
  static const Color contractionCoral = Color(0xFFFF7043);
  static const Color kickTeal = Color(0xFF4DB6AC);
  static const Color symptomAmber = Color(0xFFFFB300);
  static const Color medicineIndigo = Color(0xFF7986CB);

  // Alert Colors
  static const Color criticalRed = Color(0xFFD32F2F);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color successGreen = Color(0xFF388E3C);
  static const Color infoBlue = Color(0xFF1976D2);
  static const Color error = Color(0xFFD32F2F);

  // Neutral Colors
  static const Color background = Color(0xFFFFF8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFBDBDBD);

  // Typography
  static const TextStyle headingLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.25,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.3,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.normal,
    color: textLight,
  );

  // Spacing
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // Border Radius (Extra rounded for cute design)
  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(12.0));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(16.0));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(20.0));
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(24.0));
  static const BorderRadius xxlRadius = BorderRadius.all(Radius.circular(32.0));

  // Shadows (Soft and subtle)
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> buttonShadow = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPink,
        brightness: Brightness.light,
        primary: primaryPink,
        secondary: pastelPink,
        surface: surface,
        error: criticalRed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: headingMedium,
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: lgRadius),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPink,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: mdRadius),
          padding: const EdgeInsets.symmetric(horizontal: lg, vertical: md),
          textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryPink,
          side: const BorderSide(color: primaryPink, width: 2),
          shape: RoundedRectangleBorder(borderRadius: mdRadius),
          padding: const EdgeInsets.symmetric(horizontal: lg, vertical: md),
          textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryPink,
          shape: RoundedRectangleBorder(borderRadius: mdRadius),
          padding: const EdgeInsets.symmetric(horizontal: md, vertical: sm),
          textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: lgRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: lgRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: lgRadius,
          borderSide: const BorderSide(color: primaryPink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: lgRadius,
          borderSide: const BorderSide(color: criticalRed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: md,
          vertical: md,
        ),
        hintStyle: bodyMedium.copyWith(color: textLight),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primaryPink,
        unselectedItemColor: const Color(0xFFAAAAAA),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.1),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: const Color(0x1FE91E63),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryPink, size: 24);
          }
          return const IconThemeData(color: Color(0xFF9E9E9E), size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryPink);
          }
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFF9E9E9E));
        }),
        elevation: 0,
        height: 64,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryPink,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: xlRadius),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryPink,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: mdRadius),
          textStyle: bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF5F5F5),
        selectedColor: const Color(0xFFFCE4EC),
        labelStyle: bodySmall.copyWith(fontWeight: FontWeight.w500, color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryPink,
        linearTrackColor: Color(0xFFE0E0E0),
        circularTrackColor: Color(0xFFE0E0E0),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF0E4F4),
        space: 1,
        thickness: 1,
      ),
    );
  }

  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPink, pastelPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surface, Color(0xFFFFF8FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
