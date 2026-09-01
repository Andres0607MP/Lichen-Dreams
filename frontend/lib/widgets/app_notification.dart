import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

class AppNotification {
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _SnackBarWrapper(
          message: message,
          success: !isError,
        ),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        elevation: 8,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _SnackBarWrapper extends StatefulWidget {
  final String message;
  final bool success;

  const _SnackBarWrapper({
    required this.message,
    required this.success,
  });

  @override
  State<_SnackBarWrapper> createState() => _SnackBarWrapperState();
}

class _SnackBarWrapperState extends State<_SnackBarWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _exitController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.4),
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  void _onProgressComplete() {
    _exitController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: _SnackBarContent(
            message: widget.message,
            success: widget.success,
            onProgressComplete: _onProgressComplete,
          ),
        ),
      ),
    );
  }
}

class _SnackBarContent extends StatefulWidget {
  final String message;
  final bool success;
  final VoidCallback onProgressComplete;

  const _SnackBarContent({
    required this.message,
    required this.success,
    required this.onProgressComplete,
  });

  @override
  State<_SnackBarContent> createState() => _SnackBarContentState();
}

class _SnackBarContentState extends State<_SnackBarContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..forward();

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onProgressComplete();
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.success ? Icons.check_rounded : Icons.priority_high_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  widget.message,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.4,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              child: Container(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: 1.0 - _progressController.value,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.6),
                ),
                minHeight: 2.5,
              ),
            );
          },
        ),
      ],
    );
  }
}
