import 'package:flutter/material.dart';

/// "La Fosa Store" dark gamer theme — palette lifted from the brand logo
/// (hooded reaper, stone crypt, violet glow, bone-white lettering): near-black
/// surfaces, a violet primary accent, and a bone/cream secondary accent
/// instead of a generic neon color, so the UI reads as the same brand.
const _violet = Color(0xFF9B4DFF);
const _violetDeep = Color(0xFF6B2FBF);
const _bone = Color(0xFFE7E1CE);
const _bgBase = Color(0xFF0A0A0D);
const _bgSurface = Color(0xFF16141C);
const _bgSurfaceHigh = Color(0xFF211D2B);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _violet,
    brightness: Brightness.dark,
    secondary: _bone,
    surface: _bgSurface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: _bgBase,
    appBarTheme: AppBarTheme(
      backgroundColor: _bgBase,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: _bgSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _violet.withValues(alpha: 0.22)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _bgSurfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _violet.withValues(alpha: 0.3)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: _bgSurfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _bgSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _violet.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _violet.withValues(alpha: 0.3)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: _bone, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _violet,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _bone,
        side: const BorderSide(color: _bone),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _bone,
      foregroundColor: Colors.black,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: _bgSurface,
        foregroundColor: Colors.white70,
        selectedBackgroundColor: _violet.withValues(alpha: 0.28),
        selectedForegroundColor: _bone,
        side: BorderSide(color: _violet.withValues(alpha: 0.45)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _bgSurfaceHigh,
      labelStyle: const TextStyle(color: Colors.white),
      side: BorderSide.none,
    ),
    dividerTheme: DividerThemeData(color: _violet.withValues(alpha: 0.14)),
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: Colors.white.withValues(alpha: 0.92),
      displayColor: Colors.white,
    ),
    extensions: const [
      LaFosaColors(violet: _violet, violetDeep: _violetDeep, bone: _bone),
    ],
  );
}

/// Brand colors not modeled by [ColorScheme], exposed for widgets that want
/// the exact logo palette (e.g. a decorative glow behind the login logo).
class LaFosaColors extends ThemeExtension<LaFosaColors> {
  final Color violet;
  final Color violetDeep;
  final Color bone;

  const LaFosaColors({
    required this.violet,
    required this.violetDeep,
    required this.bone,
  });

  @override
  LaFosaColors copyWith({Color? violet, Color? violetDeep, Color? bone}) {
    return LaFosaColors(
      violet: violet ?? this.violet,
      violetDeep: violetDeep ?? this.violetDeep,
      bone: bone ?? this.bone,
    );
  }

  @override
  LaFosaColors lerp(LaFosaColors? other, double t) {
    if (other == null) return this;
    return LaFosaColors(
      violet: Color.lerp(violet, other.violet, t)!,
      violetDeep: Color.lerp(violetDeep, other.violetDeep, t)!,
      bone: Color.lerp(bone, other.bone, t)!,
    );
  }
}
