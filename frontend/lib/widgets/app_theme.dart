import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF4F7A45);
  static const Color darkGreen = Color(0xFF1F3D2B);
  static const Color lightGreen = Color(0xFF6FA05A);
  static const Color accentGreen = Color(0xFF8FA878);
  static const Color backgroundColor = Color(0xFFF2F0E6);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF3A3F3C);
  static const Color textGray = Color(0xFF5A665D);
  static const Color borderColor = Color(0xFFC5D0B5);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color alertColor = Color(0xFFC25E3F);
  static const Color healthyColor = Color(0xFF4F7A45);

  static final Color primaryGreen10 = primaryGreen.withValues(alpha: 0.1);
  static final Color primaryGreen12 = primaryGreen.withValues(alpha: 0.12);
  static final Color primaryGreen30 = primaryGreen.withValues(alpha: 0.3);
  static final Color surface95 = surfaceColor.withValues(alpha: 0.95);
  static final Color surface60 = surfaceColor.withValues(alpha: 0.6);
  static final Color backgroundColor60 = backgroundColor.withValues(alpha: 0.6);
  static final Color border40 = borderColor.withValues(alpha: 0.4);
  static final Color border50 = borderColor.withValues(alpha: 0.5);
  static final Color error12 = errorColor.withValues(alpha: 0.12);
  static final Color error30 = errorColor.withValues(alpha: 0.3);
  static final Color success12 = successColor.withValues(alpha: 0.12);
  static final Color success30 = successColor.withValues(alpha: 0.3);
  static final Color shadow05 = Colors.black.withValues(alpha: 0.05);
  static final Color shadow08 = Colors.black.withValues(alpha: 0.08);
  static final Color shadow25 = Colors.black.withValues(alpha: 0.25);
  static final Color redAccent25 = Colors.redAccent.withValues(alpha: 0.25);

  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 12.0;
  static const double spaceLG = 16.0;
  static const double spaceXL = 20.0;
  static const double spaceXXL = 24.0;

  static const double radiusXS = 8.0;
  static const double radiusSM = 10.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 14.0;
  static const double radiusXL = 16.0;
  static const double radiusXXL = 20.0;
  static const double radiusFull = 28.0;

  static const BorderRadius radiusXSBorder = BorderRadius.all(Radius.circular(radiusXS));
  static const BorderRadius radiusSMBorder = BorderRadius.all(Radius.circular(radiusSM));
  static const BorderRadius radiusMDBorder = BorderRadius.all(Radius.circular(radiusMD));
  static const BorderRadius radiusLGBorder = BorderRadius.all(Radius.circular(radiusLG));
  static const BorderRadius radiusXLBorder = BorderRadius.all(Radius.circular(radiusXL));
  static const BorderRadius radiusXXLBorder = BorderRadius.all(Radius.circular(radiusXXL));
  static const BorderRadius radiusFullBorder = BorderRadius.all(Radius.circular(radiusFull));

  static final BoxShadow shadowSmall = BoxShadow(
    color: shadow05,
    blurRadius: 4,
    offset: const Offset(0, 1),
  );

  static final BoxShadow shadowMedium = BoxShadow(
    color: shadow08,
    blurRadius: 8,
    offset: const Offset(0, 2),
  );

  static final BoxShadow shadowLarge = BoxShadow(
    color: shadow08,
    blurRadius: 20,
    offset: const Offset(0, 4),
  );

  static final BoxShadow shadowButton = BoxShadow(
    color: shadow25,
    blurRadius: 6,
    offset: const Offset(0, 2),
  );

  static const BoxShadow baseShadow = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static const BorderRadius defaultRadius = BorderRadius.all(Radius.circular(radiusMD));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(radiusLG));
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(radiusXL));

  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 200);
  static const Duration animationSlow = Duration(milliseconds: 300);
  static const Duration animationSlowest = Duration(milliseconds: 400);

  static const double iconXS = 16.0;
  static const double iconSM = 18.0;
  static const double iconMD = 20.0;
  static const double iconLG = 22.0;
  static const double iconXL = 24.0;

  static const EdgeInsets inputContentPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 15);

  static ThemeData lightTheme() {
    final baseTextTheme = GoogleFonts.poppinsTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textDark,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: baseTextTheme.displayLarge?.copyWith(color: textDark),
        displayMedium: baseTextTheme.displayMedium?.copyWith(color: textDark),
        displaySmall: baseTextTheme.displaySmall?.copyWith(color: textDark),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(color: textDark),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(color: textDark),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textDark,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textGray,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textGray,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textDark,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textGray,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        contentPadding: inputContentPadding,
        labelStyle: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: textGray,
        ),
        hintStyle: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: textGray,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: spaceXL, vertical: spaceMD),
          shape: RoundedRectangleBorder(borderRadius: defaultRadius),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen, width: 2),
          padding:
              const EdgeInsets.symmetric(horizontal: spaceXL, vertical: spaceMD),
          shape: RoundedRectangleBorder(borderRadius: defaultRadius),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: primaryGreen,
          iconSize: iconLG,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
        margin: EdgeInsets.zero,
      ),
      iconTheme: IconThemeData(
        color: textDark,
        size: iconMD,
      ),
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
