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

  static const Color historialPrimary = Color(0xFF6B8E5A);
  static const Color historialSecondary = Color(0xFF8FA878);
  static const Color historialIcon = Color(0xFF4A6B3A);

  static const Color mapaPrimary = Color(0xFF4A6FA5);
  static const Color mapaSecondary = Color(0xFF6B8FC5);
  static const Color mapaIcon = Color(0xFF3A5A8D);

  static const Color liquenpediaPrimary = Color(0xFF2E6B4F);
  static const Color liquenpediaSecondary = Color(0xFF4A8B6A);
  static const Color liquenpediaIcon = Color(0xFF1E5A3F);

  static const Color especiesPrimary = Color(0xFFB86A5A);
  static const Color especiesSecondary = Color(0xFFD48A7A);
  static const Color especiesIcon = Color(0xFF8A4A3A);

  static const Color infoColor = Color(0xFF5A6B7A);
  static const Color warningEnvironmental = Color(0xFFB8A43E);
  static const Color dangerEnvironmental = Color(0xFFA85A4A);

  static const Color articleHealthy = Color(0xFF2E6B4F);
  static const Color articleModerate = Color(0xFFB8A43E);
  static const Color articleCritical = Color(0xFFA85A4A);
  static const Color articleDefault = Color(0xFF6B8E5A);

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

  static ThemeData darkTheme() {
    const darkBackground = Color(0xFF0D1117);
    const darkSurface = Color(0xFF161B22);
    const darkSurfaceElevated = Color(0xFF1C2128);
    const darkSurfaceHigh = Color(0xFF21262D);
    const darkText = Color(0xFFE6EDF3);
    const darkTextSecondary = Color(0xFF8B949E);
    const darkTextMuted = Color(0xFF6E7681);
    const darkBorder = Color(0xFF30363D);
    const darkBorderSubtle = Color(0xFF21262D);
    const darkGreen = Color(0xFF3FB950);
    const darkGreenMuted = Color(0xFF238636);

    final baseTextTheme = GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: darkGreen,
        onPrimary: Colors.white,
        primaryContainer: darkGreenMuted,
        onPrimaryContainer: darkText,
        secondary: const Color(0xFF58A6FF),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFF1F6FEB),
        onSecondaryContainer: darkText,
        tertiary: const Color(0xFFBC8CFF),
        onTertiary: Colors.white,
        error: const Color(0xFFF85149),
        onError: Colors.white,
        errorContainer: const Color(0xFFDA3633),
        onErrorContainer: darkText,
        surface: darkSurface,
        onSurface: darkText,
        surfaceContainerHighest: darkSurfaceHigh,
        surfaceContainerHigh: darkSurfaceElevated,
        surfaceContainer: darkSurface,
        surfaceContainerLow: darkBackground,
        surfaceContainerLowest: darkBackground,
        onSurfaceVariant: darkTextSecondary,
        outline: darkBorder,
        outlineVariant: darkBorderSubtle,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: darkText,
        onInverseSurface: darkSurface,
        inversePrimary: darkGreenMuted,
        surfaceTint: darkGreen,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: darkSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: darkText,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
        iconTheme: const IconThemeData(color: darkText),
      ),
      textTheme: TextTheme(
        displayLarge: baseTextTheme.displayLarge?.copyWith(color: darkText),
        displayMedium: baseTextTheme.displayMedium?.copyWith(color: darkText),
        displaySmall: baseTextTheme.displaySmall?.copyWith(color: darkText),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(color: darkText),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(color: darkText),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: darkText,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: darkTextSecondary,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: darkTextMuted,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: darkTextSecondary,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: darkTextMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: darkGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: Color(0xFFF85149)),
        ),
        contentPadding: inputContentPadding,
        labelStyle: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: darkTextSecondary,
        ),
        hintStyle: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: darkTextMuted,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: spaceXL, vertical: spaceMD),
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
          foregroundColor: darkGreen,
          side: const BorderSide(color: darkGreen, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: spaceXL, vertical: spaceMD),
          shape: RoundedRectangleBorder(borderRadius: defaultRadius),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkGreen,
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: darkText,
          iconSize: iconLG,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: const BorderSide(color: darkBorderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radiusXLBorder),
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(color: darkText),
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(color: darkTextSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: darkGreenMuted,
        labelTextStyle: WidgetStateProperty.all(
          baseTextTheme.labelSmall?.copyWith(color: darkText),
        ),
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(color: darkTextSecondary),
        ),
      ),
      iconTheme: const IconThemeData(
        color: darkTextSecondary,
        size: iconMD,
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: darkSurfaceHigh,
        textColor: darkText,
        iconColor: darkTextSecondary,
        shape: RoundedRectangleBorder(borderRadius: radiusMDBorder),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceHigh,
        selectedColor: darkGreenMuted,
        labelStyle: baseTextTheme.labelSmall?.copyWith(color: darkText),
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(borderRadius: radiusFullBorder),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurfaceHigh,
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(color: darkText),
        shape: RoundedRectangleBorder(borderRadius: radiusMDBorder),
        behavior: SnackBarBehavior.floating,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: darkSurfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radiusMDBorder),
        textStyle: baseTextTheme.bodyMedium?.copyWith(color: darkText),
      ),
    );
  }
}
