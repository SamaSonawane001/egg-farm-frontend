import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens: shadcn/ui "stone" neutrals + Tailwind emerald/amber accents,
/// a warm cream + forest-green + yolk colour combination, Inter body + Poppins headings.
class AppColors {
  static const primary = Color(0xFF047857); // emerald-700
  static const primaryDark = Color(0xFF34D399); // emerald-400
  static const yolk = Color(0xFFF59E0B); // amber-500
  static const cream = Color(0xFFFFFBEB); // amber-50
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final bg = dark ? const Color(0xFF0C0A09) : const Color(0xFFFAFAF9);
  final card = dark ? const Color(0xFF1C1917) : Colors.white;
  final border = dark ? const Color(0xFF292524) : const Color(0xFFE7E5E4);
  final fg = dark ? const Color(0xFFFAFAF9) : const Color(0xFF1C1917);

  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: b).copyWith(
    primary: dark ? AppColors.primaryDark : AppColors.primary,
    onPrimary: dark ? const Color(0xFF052E16) : Colors.white,
    secondary: AppColors.yolk,
    surface: card,
    onSurface: fg,
    outline: border,
    error: AppColors.danger,
  );

  final base = ThemeData(brightness: b).textTheme;
  final body = GoogleFonts.interTextTheme(base).apply(bodyColor: fg, displayColor: fg);
  TextStyle? head(TextStyle? s, FontWeight w) => GoogleFonts.poppins(textStyle: s, fontWeight: w, color: fg);
  final text = body.copyWith(
    headlineMedium: head(body.headlineMedium, FontWeight.w700),
    headlineSmall: head(body.headlineSmall, FontWeight.w700),
    titleLarge: head(body.titleLarge, FontWeight.w600),
    titleMedium: head(body.titleMedium, FontWeight.w600),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: text,
    dividerColor: border,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      indicatorColor: scheme.primary.withOpacity(.14),
      labelTextStyle: WidgetStatePropertyAll(GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
