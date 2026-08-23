import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_theme.dart';

class LichenBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const LichenBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<LichenBottomNav> createState() => _LichenBottomNavState();
}

class _LichenBottomNavState extends State<LichenBottomNav> {
  static const int _tabCount = 5;

  int? _dragIndex;
  double _trackWidth = 0;

  int _indexFromX(double dx) {
    if (_trackWidth <= 0) return widget.currentIndex;
    final tabWidth = _trackWidth / _tabCount;
    if (tabWidth <= 0) return widget.currentIndex;
    return (dx / tabWidth).floor().clamp(0, _tabCount - 1);
  }

  void _onDragStart(DragStartDetails details) {
    if (_trackWidth <= 0) return;
    final index = _indexFromX(details.localPosition.dx);
    setState(() {
      _dragIndex = index;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_trackWidth <= 0) return;
    final index = _indexFromX(details.localPosition.dx);
    if (index != _dragIndex) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _dragIndex = index;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final finalIndex = _dragIndex ?? widget.currentIndex;
    setState(() {
      _dragIndex = null;
    });
    if (finalIndex != widget.currentIndex) {
      HapticFeedback.lightImpact();
      widget.onTap(finalIndex);
    }
  }

  void _onDragCancel() {
    setState(() {
      _dragIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    final activeIndex = _dragIndex ?? widget.currentIndex;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLG,
        vertical: 12,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.radiusXXLBorder,
        boxShadow: [AppTheme.shadowLarge],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                  widthFactor: 1.0,
                  alignment: Alignment(
                    ((activeIndex * 2) - (_tabCount - 1)) / (_tabCount - 1),
                    0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1 / _tabCount,
                    heightFactor: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: AppTheme.radiusXXLBorder,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Inicio',
                index: 0,
                isSmallScreen: isSmallScreen,
                activeIndex: activeIndex,
              ),
              _buildNavItem(
                icon: Icons.camera_alt_rounded,
                label: 'Análisis',
                index: 1,
                isSmallScreen: isSmallScreen,
                activeIndex: activeIndex,
              ),
              _buildNavItem(
                icon: Icons.map_rounded,
                label: 'Mapa',
                index: 2,
                isSmallScreen: isSmallScreen,
                activeIndex: activeIndex,
              ),
              _buildNavItem(
                icon: Icons.history_rounded,
                label: 'Historial',
                index: 3,
                isSmallScreen: isSmallScreen,
                activeIndex: activeIndex,
              ),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Perfil',
                index: 4,
                isSmallScreen: isSmallScreen,
                activeIndex: activeIndex,
              ),
            ],
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _trackWidth = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  onHorizontalDragCancel: _onDragCancel,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSmallScreen,
    required int activeIndex,
  }) {
    final isSelected = activeIndex == index;
    final fontSize = isSmallScreen ? 10.0 : 11.0;
    final iconSize = isSelected
        ? (isSmallScreen ? AppTheme.iconMD : AppTheme.iconXL)
        : (isSmallScreen ? AppTheme.iconSM : AppTheme.iconLG);

    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          button: true,
          selected: isSelected,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onTap(index);
              },
              borderRadius: AppTheme.radiusXXLBorder,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: AppTheme.spaceXS,
                ),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: AppTheme.radiusXXLBorder,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: iconSize,
                      color: isSelected ? Colors.white : AppTheme.textGray,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : AppTheme.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
