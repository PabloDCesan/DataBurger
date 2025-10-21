import 'package:flutter/material.dart';
import 'tile_theme.dart';

class AppTheme {
  // Fondo casi negro + acento rojo/blanco, coherente con AMERICANAS
  static ThemeData get dark {
    const primaryRed = Color(0xFFE53935);
    const bg = Color(0xFF0E1320); // azul-negruzco
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: primaryRed,
        secondary: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF161C2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A3147)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryRed, width: 1.4),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          minimumSize: const Size(120, 52),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      extensions: const [
        TileStyle(
          bg: Color.fromARGB(255, 36, 61, 129),   // base (tu color)
          bgHover: Color(0xFF2A4AA0),             // un poquito más claro
          bgPress: Color(0xFF20366F),             // un poquito más oscuro
          fg: Colors.white,
          radius: 50,
          elevation: 10,
          hoverElevation: 30,
          pressElevation: 14,
          borderColor: Colors.white24,            // o Colors.white.withOpacity(0.06)
          borderWidth: 0.8,                       // borde sutil
        ),
      ],
    );
  }
}
