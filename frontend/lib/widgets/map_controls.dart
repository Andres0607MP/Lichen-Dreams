import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'app_theme.dart';

class MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final String? tooltip;
  final Color? iconColor;

  const MapControlButton({
    super.key,
    required this.icon,
    this.onTap,
    this.active = false,
    this.tooltip,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.primaryGreen;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? color : AppTheme.borderColor,
              width: active ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: active ? color : AppTheme.textDark,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class MapZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const MapZoomControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MapControlButton(
          icon: Icons.add_rounded,
          onTap: onZoomIn,
          tooltip: 'Acercar',
        ),
        const SizedBox(height: 8),
        MapControlButton(
          icon: Icons.remove_rounded,
          onTap: onZoomOut,
          tooltip: 'Alejar',
        ),
      ],
    );
  }
}

class MapCompass extends StatelessWidget {
  final double heading;
  final VoidCallback onResetNorth;

  const MapCompass({
    super.key,
    required this.heading,
    required this.onResetNorth,
  });

  @override
  Widget build(BuildContext context) {
    if (heading.abs() < 2) {
      return const SizedBox.shrink();
    }

    final rotation = math.pi / 180 * heading;

    return GestureDetector(
      onTap: onResetNorth,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: rotation,
          child: Icon(
            Icons.navigation_rounded,
            color: AppTheme.primaryGreen,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class MapTypeSelector extends StatelessWidget {
  final MapType currentType;
  final ValueChanged<MapType> onChanged;

  const MapTypeSelector({
    super.key,
    required this.currentType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = <_MapTypeOption>[
      _MapTypeOption(
        label: 'Normal',
        icon: Icons.map_rounded,
        type: MapType.normal,
      ),
      _MapTypeOption(
        label: 'Satélite',
        icon: Icons.satellite_rounded,
        type: MapType.satellite,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final selected = currentType == option.type;
          return GestureDetector(
            onTap: () => onChanged(option.type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryGreen.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    option.icon,
                    size: 18,
                    color: selected ? AppTheme.primaryGreen : AppTheme.textGray,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    option.label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppTheme.primaryGreen : AppTheme.textGray,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MapTypeOption {
  final String label;
  final IconData icon;
  final MapType type;

  const _MapTypeOption({
    required this.label,
    required this.icon,
    required this.type,
  });
}

class MapInfoPanel extends StatelessWidget {
  final int pointsCount;
  final bool gpsEnabled;
  final double zoom;

  const MapInfoPanel({
    super.key,
    required this.pointsCount,
    required this.gpsEnabled,
    required this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            gpsEnabled ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
            size: 16,
            color: gpsEnabled ? AppTheme.successColor : AppTheme.textGray,
          ),
          const SizedBox(width: 6),
          Text(
            'Zoom: ${zoom.toStringAsFixed(1)}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 4,
            height: 12,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$pointsCount puntos',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
