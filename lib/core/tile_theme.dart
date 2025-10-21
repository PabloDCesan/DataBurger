import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble; // para interpolar doubles

class TileStyle extends ThemeExtension<TileStyle> {
  final Color bg;           // base
  final Color? bgHover;     // hover (opcional)
  final Color? bgPress;     // press (opcional)
  final Color fg;           // texto/ícono
  final double radius;      // radio bordes
  final double elevation;   // relieve base
  final double hoverElevation;
  final double pressElevation;
  final Color? borderColor; // borde sutil opcional
  final double borderWidth;

  const TileStyle({
    required this.bg,
    required this.fg,
    this.bgHover,
    this.bgPress,
    this.radius = 18,
    this.elevation = 6,
    this.hoverElevation = 10,
    this.pressElevation = 14,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  TileStyle copyWith({
    Color? bg,
    Color? bgHover,
    Color? bgPress,
    Color? fg,
    double? radius,
    double? elevation,
    double? hoverElevation,
    double? pressElevation,
    Color? borderColor,
    double? borderWidth,
  }) {
    return TileStyle(
      bg: bg ?? this.bg,
      bgHover: bgHover ?? this.bgHover,
      bgPress: bgPress ?? this.bgPress,
      fg: fg ?? this.fg,
      radius: radius ?? this.radius,
      elevation: elevation ?? this.elevation,
      hoverElevation: hoverElevation ?? this.hoverElevation,
      pressElevation: pressElevation ?? this.pressElevation,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
    );
  }

  @override
  TileStyle lerp(ThemeExtension<TileStyle>? other, double t) {
    if (other is! TileStyle) return this;

    return TileStyle(
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      bgHover: Color.lerp(bgHover, other.bgHover, t),
      bgPress: Color.lerp(bgPress, other.bgPress, t),
      fg: Color.lerp(fg, other.fg, t) ?? fg,
      radius: lerpDouble(radius, other.radius, t) ?? radius,
      elevation: lerpDouble(elevation, other.elevation, t) ?? elevation,
      hoverElevation: lerpDouble(hoverElevation, other.hoverElevation, t) ?? hoverElevation,
      pressElevation: lerpDouble(pressElevation, other.pressElevation, t) ?? pressElevation,
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t) ?? borderWidth,
    );
  }
}
