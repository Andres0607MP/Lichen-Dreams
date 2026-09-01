import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../widgets/app_theme.dart';
import '../widgets/app_notification.dart';
import '../routes/route_names.dart';

class RecoveryCodeScreen extends StatefulWidget {
  final String code;
  final String? email;

  const RecoveryCodeScreen({super.key, required this.code, this.email});

  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen>
    with TickerProviderStateMixin {
  bool _copied = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _bgController;
  late Animation<double> _bgScale;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _slideController.forward();
    });

    _bgController = AnimationController(
      duration: const Duration(milliseconds: 10000),
      vsync: this,
    );
    _bgScale = Tween<double>(begin: 1.0, end: 1.40).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeInOutCubic),
    );
    _bgController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (mounted) {
      setState(() => _copied = true);
      AppNotification.show(context, message: 'Código copiado. Guárdalo en un lugar seguro.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ScaleTransition(
              scale: _bgScale,
              child: Image.asset(
                'assets/background/liquen_003.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: AppTheme.darkGreen.withValues(alpha: 0.50)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fadeController,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(_slideController),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.92),
                          borderRadius: AppTheme.cardRadius,
                          border: Border.all(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: const [AppTheme.baseShadow],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.keyRound,
                                size: 32,
                                color: AppTheme.primaryGreen,
                              ),
                            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                            const SizedBox(height: 20),
                            Text(
                              '¡Tu cuenta está lista!',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Este es tu código de recuperación. Es la única forma de recuperar tu cuenta si pierdes acceso a tu correo.',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: _copyCode,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                                  borderRadius: AppTheme.defaultRadius,
                                  border: Border.all(
                                    color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      widget.code,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2.5,
                                        color: AppTheme.darkGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _copied ? LucideIcons.check : LucideIcons.copy,
                                          size: 15,
                                          color: AppTheme.primaryGreen,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _copied ? 'Copiado' : 'Toca para copiar',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: AppTheme.defaultRadius,
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  _WarningRow(
                                    icon: LucideIcons.triangleAlert,
                                    text: 'Guárdalo ahora. No podrás volver a verlo después.',
                                  ),
                                  SizedBox(height: 8),
                                  _WarningRow(
                                    icon: LucideIcons.userX,
                                    text: 'Se usará si pierdes acceso a tu correo o usas un correo que no es tuyo.',
                                  ),
                                  SizedBox(height: 8),
                                  _WarningRow(
                                    icon: LucideIcons.shieldAlert,
                                    text: 'Nunca lo compartas con nadie.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    AppRoutes.login,
                                    (route) => false,
                                  );
                                },
                                icon: const Icon(LucideIcons.logIn, size: 18),
                                label: const Text('Guardé mi código. Ir al inicio de sesión'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.darkGreen,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppTheme.defaultRadius,
                                  ),
                                  textStyle: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _copyCode,
                              icon: const Icon(LucideIcons.copy, size: 18),
                              label: Text(
                                'Copiar código',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _WarningRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.orange.shade800),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.orange.shade900,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}