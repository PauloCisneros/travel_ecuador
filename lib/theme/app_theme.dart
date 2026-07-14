import 'package:flutter/material.dart';

/// Paleta de la app — Travel Ecuador.
///
/// Naranja como acento principal (el "sol" sobre la línea ecuatorial),
/// con neutros cálidos en vez de grises fríos genéricos.
class AppColors {
  AppColors._();

  static const Color sol = Color(0xFFFF5A1F);       // Naranja primario
  static const Color solOscuro = Color(0xFFE44A12);  // Naranja pressed/hover
  static const Color solClaro = Color(0xFFFFE4D6);   // Naranja tenue (fondos, badges)

  static const Color tinta = Color(0xFF1A1F16);      // Texto principal
  static const Color musgo = Color(0xFF767066);      // Texto secundario / iconos
  static const Color musgoClaro = Color(0xFFA6A099); // Texto terciario / hints

  static const Color lienzo = Color(0xFFFBF9F6);     // Fondo principal
  static const Color lienzoAlterno = Color(0xFFF3F0EA); // Fondo secundario (chips, inputs)
  static const Color niebla = Color(0xFFE8E3DC);     // Bordes / dividers

  static const Color error = Color(0xFFD64545);
  static const Color exito = Color(0xFF2E7D5B);
}

/// Tema global de la app. Se registra una sola vez en `main.dart`:
///
/// ```dart
/// MaterialApp(
///   theme: AppTheme.light,
///   ...
/// )
/// ```
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.sol,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.sol,
      onPrimary: Colors.white,
      surface: AppColors.lienzo,
      onSurface: AppColors.tinta,
      outline: AppColors.niebla,
      error: AppColors.error,
      onError: Colors.white,
      surfaceContainerHigh: Colors.white,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lienzo,
      canvasColor: Colors.white,
      primaryColor: AppColors.sol,

      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: AppColors.tinta,
          height: 1.15,
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.tinta,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.tinta,
        ),
        bodyLarge: const TextStyle(
          color: AppColors.tinta,
          height: 1.4,
        ),
        bodyMedium: const TextStyle(
          color: AppColors.musgo,
          height: 1.4,
        ),
        labelLarge: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lienzo,
        foregroundColor: AppColors.tinta,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.tinta,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),

      // Inputs minimalistas: línea inferior en vez de caja completa.
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        labelStyle: const TextStyle(color: AppColors.musgo, fontSize: 15),
        floatingLabelStyle: const TextStyle(
          color: AppColors.sol,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: AppColors.musgoClaro),
        iconColor: AppColors.musgo,
        prefixIconColor: AppColors.musgo,
        suffixIconColor: AppColors.musgo,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.niebla, width: 1),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.sol, width: 2),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.sol,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.sol.withValues(alpha: 0.4),
          minimumSize: const Size(double.infinity, 54),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(
            AppColors.solOscuro.withValues(alpha: 0.15),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.sol,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.tinta,
          side: const BorderSide(color: AppColors.niebla),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      iconTheme: const IconThemeData(color: AppColors.musgo),

      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.niebla),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.niebla,
        thickness: 1,
        space: 1,
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.tinta,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.sol,
        unselectedItemColor: AppColors.musgoClaro,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // FAB: mismo naranja que un filtro/chip seleccionado, para que
      // "Nuevo lugar" se lea como la acción principal de la pantalla.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.sol,
        foregroundColor: Colors.white,
        extendedTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Chips: usados en categorías rápidas, filtros activos y bottom sheets.
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(Colors.white),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lienzoAlterno,
        selectedColor: AppColors.sol,
        disabledColor: AppColors.niebla,
        labelStyle: const TextStyle(
          color: AppColors.tinta,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: AppColors.niebla),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        showCheckmark: false,
        deleteIconColor: AppColors.musgo,
      ),

      // Badge: usado para indicar cuántos filtros extra están activos.
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.sol,
        textColor: Colors.white,
      ),
    );
  }
}