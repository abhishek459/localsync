import 'package:flutter/material.dart';

/// A utility class for holding the app's core color palette.
///
/// This class is not meant to be instantiated.
abstract final class AppColors {
  /// The seed color for the entire app's color scheme.
  /// `ColorScheme.fromSeed` will generate all other colors from this.
  static const Color primarySeed = Colors.green;

  /// The semantic color for errors.
  static const Color errorRed = Colors.redAccent;
}

/// A utility class for holding the app's theme data.
///
/// This class is not meant to be instantiated.
abstract final class AppTheme {
  /// Centralized "soft" border radius for components.
  static final _borderRadius = BorderRadius.circular(12.0);

  /// Builds the theme data for a given brightness.
  static ThemeData _buildTheme(Brightness brightness) {
    /// Generate the entire M3 color palette from the seed.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primarySeed,
      brightness: brightness,
      error: AppColors.errorRed,
    );

    /// Get the default M3 typography for a consistent platform.
    final typography = Typography.material2021(colorScheme: colorScheme);

    // Select the base text theme (black for light, white for dark)
    final defaultTextTheme = brightness == Brightness.light
        ? typography.black
        : typography.white;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'SourceSans3',
      fontFamilyFallback: const [
        // 1. Apple Platforms (iOS/macOS)
        // These specific names target the hidden system font
        '.AppleSystemUIFont',

        // 2. Windows
        'Segoe UI',
        'Arial',

        // 3. Android
        'Roboto',

        // 4. Linux (Ubuntu/Debian)
        'Ubuntu',
        'Cantarell',
        'Noto Sans',

        // 5. Web / Generic Safety
        'sans-serif',
      ],
      textTheme: defaultTextTheme,

      /// Theme for AppBar
      appBarTheme: AppBarTheme(
        elevation: 0.0,
        scrolledUnderElevation: 3,
        backgroundColor: colorScheme.surface,
      ),

      /// Theme for TextFields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: _borderRadius,
          borderSide: BorderSide.none, // Use a clean, borderless look
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _borderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _borderRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _borderRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 2.0),
        ),
      ),

      /// Component Style: Apply soft, rounded corners
      cardTheme: CardThemeData(
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: _borderRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: _borderRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: _borderRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: _borderRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
      ),

      /// Theme M3 navigation components
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: RoundedRectangleBorder(borderRadius: _borderRadius),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        // Use the theme's colors for icons
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onSecondaryContainer);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorShape: RoundedRectangleBorder(borderRadius: _borderRadius),
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_borderRadius.topLeft.x),
          ),
        ),
      ),
    );
  }

  /// The app's theme for light mode.
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  /// The app's theme for dark mode.
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
}
