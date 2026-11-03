import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF087F68);
  static const primaryDark = Color(0xFF42D3A5);
  static const yolk = Color(0xFFE9A93B);
  static const cream = Color(0xFFF2F8F5);
  static const danger = Color(0xFFE06B72);
  static const info = Color(0xFF5B8DEF);
  static const success = Color(0xFF2FAE82);
  static const warning = Color(0xFFD59A38);
  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF162235);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? AppColors.darkBackground : const Color(0xFFF4F7F6);
  final surface = dark ? AppColors.darkSurface : Colors.white;
  final elevatedSurface =
      dark ? const Color(0xFF1C2A3E) : const Color(0xFFFAFCFB);
  final border = dark ? const Color(0xFF334155) : const Color(0xFFDDE7E3);
  final foreground = dark ? const Color(0xFFF1F5F9) : const Color(0xFF172B27);
  final muted = dark ? const Color(0xFF9AAABD) : const Color(0xFF64748B);
  final primary = dark ? AppColors.primaryDark : AppColors.primary;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  ).copyWith(
    primary: primary,
    onPrimary: dark ? const Color(0xFF06251D) : Colors.white,
    secondary: AppColors.yolk,
    onSecondary: const Color(0xFF30210A),
    tertiary: AppColors.info,
    surface: surface,
    onSurface: foreground,
    surfaceContainerHighest: elevatedSurface,
    onSurfaceVariant: muted,
    outline: border,
    outlineVariant: border.withValues(alpha: dark ? .72 : .8),
    error: AppColors.danger,
    onError: Colors.white,
    shadow: dark ? Colors.black : const Color(0xFF193B31),
  );

  final baseText = GoogleFonts.interTextTheme(
    ThemeData(brightness: brightness).textTheme,
  ).apply(bodyColor: foreground, displayColor: foreground);
  TextStyle? heading(TextStyle? style, FontWeight weight) =>
      GoogleFonts.poppins(
          textStyle: style, fontWeight: weight, color: foreground);
  final textTheme = baseText.copyWith(
    headlineLarge: heading(baseText.headlineLarge, FontWeight.w700),
    headlineMedium: heading(baseText.headlineMedium, FontWeight.w700),
    headlineSmall: heading(baseText.headlineSmall, FontWeight.w700),
    titleLarge: heading(baseText.titleLarge, FontWeight.w600),
    titleMedium: heading(baseText.titleMedium, FontWeight.w600),
    bodySmall: baseText.bodySmall?.copyWith(color: muted),
    labelSmall: baseText.labelSmall?.copyWith(color: muted),
  );

  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(color: border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: surface,
    cardColor: surface,
    textTheme: textTheme,
    dividerColor: border,
    hintColor: muted,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: primary.withValues(alpha: .35),
        disabledForegroundColor: scheme.onPrimary.withValues(alpha: .75),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: elevatedSurface,
        foregroundColor: foreground,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border),
        ),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        backgroundColor: surface.withValues(alpha: dark ? .45 : .7),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: elevatedSurface.withValues(alpha: dark ? .68 : .72),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      hintStyle: TextStyle(color: muted),
      labelStyle: TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: dark ? 12 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: elevatedSurface,
      selectedColor: primary.withValues(alpha: .15),
      disabledColor: elevatedSurface.withValues(alpha: .5),
      side: BorderSide(color: border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w500),
      secondaryLabelStyle:
          TextStyle(color: primary, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: primary.withValues(alpha: .14),
      indicatorShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : muted,
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      indicatorColor: primary.withValues(alpha: .14),
      selectedIconTheme: IconThemeData(color: primary),
      unselectedIconTheme: IconThemeData(color: muted),
      selectedLabelTextStyle:
          TextStyle(color: primary, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: muted),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF26364C) : const Color(0xFF183B32),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
  );
}
