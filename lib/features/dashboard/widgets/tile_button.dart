import 'package:flutter/material.dart';
import '../../../core/tile_theme.dart';

class TileButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  const TileButton({super.key, required this.icon, required this.label, this.subtitle, this.onTap});

  @override
  State<TileButton> createState() => _TileButtonState();
}

class _TileButtonState extends State<TileButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tile = Theme.of(context).extension<TileStyle>()!;
    final elev = _pressed ? tile.pressElevation : (_hover ? tile.hoverElevation : tile.elevation);
    final bgColor = _pressed ? (tile.bgPress ?? tile.bg) : (_hover ? (tile.bgHover ?? tile.bg) : tile.bg);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() { _hover = false; _pressed = false; }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..translate(0.0, _pressed ? -1.0 : (_hover ? -0.5 : 0.0)),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(tile.radius),
            border: (tile.borderWidth > 0 && tile.borderColor != null)
                ? Border.all(color: tile.borderColor!, width: tile.borderWidth)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: elev,
                spreadRadius: 0.5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 44, color: tile.fg),
              const SizedBox(height: 12),
              Text(widget.label, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tile.fg)),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 6),
                Opacity(
                  opacity: 0.85,
                  child: Text(widget.subtitle!, textAlign: TextAlign.center, style: TextStyle(color: tile.fg)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
