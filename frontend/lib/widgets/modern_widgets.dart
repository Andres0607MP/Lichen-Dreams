import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

class ModernCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsets padding;
  final List<Color>? gradient;
  final VoidCallback? onTap;

  const ModernCard({
    Key? key,
    required this.child,
    this.backgroundColor,
    this.borderRadius,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
           gradient: () {
              final g = gradient;
              return g != null
                  ? LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null;
            }(),
          color: gradient == null ? (backgroundColor ?? AppTheme.surfaceColor) : null,
          borderRadius: borderRadius ?? AppTheme.cardRadius,
          boxShadow: const [AppTheme.baseShadow],
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class ModernButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;
  final double width;

  const ModernButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
    this.width = double.infinity,
  }) : super(key: key);

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? AppTheme.primaryGreen;
    return SizedBox(
      width: widget.width,
      height: 56,
      child: widget.isOutlined
          ? OutlinedButton(
              onPressed: widget.isLoading ? null : widget.onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: effectiveColor, width: 2),
                shape: RoundedRectangleBorder(borderRadius: AppTheme.defaultRadius),
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.label,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: effectiveColor,
                      ),
                    ),
            )
          : ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: effectiveColor,
                shape: RoundedRectangleBorder(borderRadius: AppTheme.defaultRadius),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      widget.label,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
    );
  }
}

class ModernTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;

  const ModernTextField({
    Key? key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
  }) : super(key: key);

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.suffixIcon,
        filled: true,
        fillColor: _isFocused ? AppTheme.surfaceColor : AppTheme.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: AppTheme.inputRadius,
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTheme.inputRadius,
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTheme.inputRadius,
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
    );
  }
}

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const StatsCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      backgroundColor: backgroundColor.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textGray,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const FeatureCard({
    Key? key,
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.primaryGreen;
    return ModernCard(
      gradient: [
        effectiveColor.withOpacity(0.1),
        effectiveColor.withOpacity(0.05),
      ],
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: effectiveColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: effectiveColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textGray,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuickActionCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? badge;
  final bool showTopIndicator;
  final int entranceDelay;

  const QuickActionCard({
    Key? key,
    required this.title,
    required this.icon,
    this.onTap,
    this.color,
    this.subtitle,
    this.badge,
    this.showTopIndicator = true,
    this.entranceDelay = 0,
  }) : super(key: key);

  @override
  State<QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<QuickActionCard> with TickerProviderStateMixin {
  bool _pressed = false;
  bool _isHovering = false;
  late AnimationController _hoverController;
  late AnimationController _entranceController;
  late AnimationController _pressController;
  late AnimationController _iconController;
  late Animation<double> _hoverAnimation;
  late Animation<double> _entranceOpacity;
  late Animation<double> _entranceScale;
  late Animation<Offset> _entranceSlide;
  late Animation<double> _pressAnimation;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _hoverAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _entranceScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _pressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: widget.entranceDelay), () {
      if (mounted) {
        _entranceController.forward();
      }
    });
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _entranceController.dispose();
    _pressController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool hovering) {
    setState(() => _isHovering = hovering);
    if (hovering) {
      _hoverController.forward();
      _iconController.forward();
    } else {
      _hoverController.reverse();
      _iconController.reverse();
    }
  }

  void _onTapDown() {
    setState(() => _pressed = true);
    _pressController.forward();
    _iconController.reverse();
  }

  void _onTapUp() {
    _pressController.reverse().then((_) {
      if (mounted) {
        setState(() => _pressed = false);
        if (_isHovering) {
          _iconController.forward();
        }
      }
    });
  }

  void _onTapCancel() {
    _pressController.reverse().then((_) {
      if (mounted) {
        setState(() => _pressed = false);
        if (_isHovering) {
          _iconController.forward();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? AppTheme.primaryGreen;
    final bool hasSubtitle = widget.subtitle != null && widget.subtitle!.isNotEmpty;

    return AnimatedBuilder(
      animation: Listenable.merge([_hoverAnimation, _entranceController, _pressAnimation, _iconAnimation]),
      builder: (context, child) {
        final double hoverLift = _hoverAnimation.value * 6.0;
        final double pressScale = 1.0 - (_pressAnimation.value * 0.03);
        final double totalScale = _entranceScale.value * pressScale;
        final double entranceOffset = _entranceSlide.value.dy;

        return Opacity(
          opacity: _entranceOpacity.value,
          child: Transform.translate(
            offset: Offset(0, entranceOffset * 12 - hoverLift),
            child: Transform.scale(
              scale: totalScale,
              child: MouseRegion(
                onEnter: (_) => _onHoverChanged(true),
                onExit: (_) => _onHoverChanged(false),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTapDown: (_) => _onTapDown(),
                    onTapUp: (_) => _onTapUp(),
                    onTapCancel: _onTapCancel,
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(22),
                    splashColor: effectiveColor.withValues(alpha: 0.12),
                    highlightColor: effectiveColor.withValues(alpha: 0.06),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            effectiveColor.withValues(alpha: 0.08 + 0.04 * _hoverAnimation.value + 0.03 * _pressAnimation.value),
                            AppTheme.surfaceColor,
                            AppTheme.surfaceColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _pressed
                              ? effectiveColor.withValues(alpha: 0.4)
                              : _isHovering
                                  ? effectiveColor.withValues(alpha: 0.3)
                                  : effectiveColor.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04 + 0.03 * _hoverAnimation.value - 0.02 * _pressAnimation.value),
                            blurRadius: 12 + 8 * _hoverAnimation.value,
                            offset: Offset(0, 4 + 4 * _hoverAnimation.value),
                          ),
                          if (_isHovering)
                            BoxShadow(
                              color: effectiveColor.withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: _iconAnimation.value - (_pressAnimation.value * 0.05),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    effectiveColor.withValues(alpha: 0.2 + 0.05 * _hoverAnimation.value),
                    effectiveColor.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: effectiveColor.withValues(alpha: 0.2 + 0.1 * _pressAnimation.value),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: effectiveColor.withValues(alpha: 0.1 + 0.05 * _hoverAnimation.value),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                size: 30,
                color: effectiveColor,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: Text(
              widget.title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasSubtitle) ...[
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                widget.subtitle!,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textGray.withValues(alpha: 0.8),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (widget.badge != null) ...[
            const SizedBox(height: 8),
            widget.badge!,
          ],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeMore;

  const SectionHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.onSeeMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(
                sub,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textGray,
                ),
              ),
            ],
          ],
        ),
        if (onSeeMore != null)
          TextButton(
            onPressed: onSeeMore,
            child: Text(
              'Ver más',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    this.onAction,
    this.actionLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final actionCb = onAction;
    final actionLbl = actionLabel;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            padding: const EdgeInsets.all(24),
            child: Icon(
              icon,
              size: 48,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.textGray,
            ),
          ),
          if (actionCb != null && actionLbl != null) ...[
            const SizedBox(height: 24),
            ModernButton(
              label: actionLbl,
              onPressed: actionCb,
              width: 200,
            ),
          ],
        ],
      ),
    );
  }
}
