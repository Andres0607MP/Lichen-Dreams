import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final hasTooltip = tooltip != null && tooltip!.isNotEmpty;

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null ? null : () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        borderRadius: AppTheme.radiusMDBorder,
        child: AnimatedContainer(
          duration: AppTheme.animationNormal,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppTheme.radiusMDBorder,
            border: Border.all(
              color: active ? color : AppTheme.borderColor,
              width: active ? 2 : 1,
            ),
            boxShadow: [AppTheme.shadowMedium],
          ),
          child: Icon(
            icon,
            color: active ? color : Theme.of(context).colorScheme.onSurface,
            size: AppTheme.iconLG,
          ),
        ),
      ),
    );

    if (hasTooltip) {
      button = Tooltip(
        message: tooltip!,
        child: Semantics(
          label: tooltip!,
          button: true,
          child: button,
        ),
      );
    }

    return button;
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
        const SizedBox(height: AppTheme.spaceSM),
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

    return Tooltip(
      message: 'Restablecer norte',
      child: Semantics(
        label: 'Restablecer norte',
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onResetNorth();
            },
            borderRadius: AppTheme.radiusFullBorder,
            child: AnimatedContainer(
              duration: AppTheme.animationFast,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderColor, width: 1),
                boxShadow: [AppTheme.shadowMedium],
              ),
              child: Transform.rotate(
                angle: rotation,
                child: Icon(
                  Icons.navigation_rounded,
                  color: AppTheme.primaryGreen,
                  size: AppTheme.iconLG,
                ),
              ),
            ),
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
    final textTheme = Theme.of(context).textTheme;
    final options = <_MapTypeOption>[
      const _MapTypeOption(
        label: 'Normal',
        icon: Icons.map_rounded,
        type: MapType.normal,
      ),
      const _MapTypeOption(
        label: 'Satélite',
        icon: Icons.satellite_rounded,
        type: MapType.satellite,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSM, vertical: AppTheme.spaceXS),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppTheme.radiusMDBorder,
        border: Border.all(color: AppTheme.borderColor, width: 1),
          boxShadow: [AppTheme.shadowMedium],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final selected = currentType == option.type;
          return Tooltip(
            message: option.label,
            child: Semantics(
              label: option.label,
              button: true,
              selected: selected,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onChanged(option.type);
                  },
                  borderRadius: AppTheme.radiusXSBorder,
                  child: AnimatedContainer(
                    duration: AppTheme.animationNormal,
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSM, vertical: AppTheme.spaceXS),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primaryGreen12 : Colors.transparent,
                      borderRadius: AppTheme.radiusXSBorder,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          option.icon,
                          size: AppTheme.iconSM,
                          color: selected ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppTheme.spaceXS),
                        Text(
                          option.label,
                          style: (selected ? textTheme.labelMedium : textTheme.bodySmall)?.copyWith(
                            color: selected ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD, vertical: AppTheme.spaceXS),
      decoration: BoxDecoration(
        color: AppTheme.surface95,
        borderRadius: AppTheme.radiusSMBorder,
        border: Border.all(color: AppTheme.border40),
        boxShadow: [AppTheme.shadowSmall],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            gpsEnabled ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
            size: AppTheme.iconSM,
            color: gpsEnabled ? AppTheme.successColor : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppTheme.spaceXS),
          Text(
            'Zoom: ${zoom.toStringAsFixed(1)}',
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Container(
            width: 4,
            height: 12,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Text(
            '$pointsCount puntos',
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
