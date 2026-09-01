import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../routes/route_names.dart';
import '../widgets/app_theme.dart';
import '../widgets/page_transitions.dart';
import '../widgets/google_sign_in_button.dart';
import '../state/auth_state.dart';
import '../state/profile_state.dart';
import '../state/dashboard_state.dart';
import '../state/history_state.dart';
import '../state/map_state.dart';
import '../state/articles_state.dart';
import '../state/notifications_state.dart';
import '../state/analysis_state.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _googleLoading = false;

  String? _emailError;
  String? _passwordError;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _bgController;
  late Animation<double> _bgScale;
  late AnimationController _cardController;
  late Animation<double> _cardScale;
  late AnimationController _vectorController;

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

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    );
    _cardScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutBack),
    );
    _cardController.forward();

    _vectorController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _bgController.dispose();
    _cardController.dispose();
    _vectorController.dispose();
    super.dispose();
  }

  void _goToDashboard() {
    if (!mounted) return;
    context.read<ProfileState>().reset();
    context.read<DashboardState>().reset();
    context.read<HistoryState>().reset();
    context.read<ArticlesState>().reset();
    context.read<NotificationsState>().reset();
    context.read<AnalysisState>().reset();
    context.read<MapState>().reset();
    Navigator.pushReplacementNamed(context, AppRoutes.loading);
  }

  void _validateAllFields() {
    setState(() {
      if (_emailController.text.isEmpty) {
        _emailError = 'El correo es obligatorio';
      } else if (!RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      ).hasMatch(_emailController.text)) {
        _emailError = 'Correo inválido';
      } else {
        _emailError = null;
      }

      if (_passwordController.text.isEmpty) {
        _passwordError = 'La contraseña es obligatoria';
      } else if (_passwordController.text.length < 6) {
        _passwordError = 'Mínimo 6 caracteres';
      } else {
        _passwordError = null;
      }
    });
  }

  bool get _isFormValid {
    return _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _emailError == null &&
        _passwordError == null;
  }

  void _showLoginError(String error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.triangleAlert, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(error)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleGoogleLogin() async {
    if (_googleLoading) return;
    final authState = context.read<AuthState>();
    setState(() => _googleLoading = true);
    try {
      final success = await authState.loginWithGoogle();
      if (success && mounted) {
        _goToDashboard();
      }
      // Si success == false, el usuario canceló Google Sign-In:
      // simplemente se permanece en la pantalla de login.
    } catch (e) {
      if (mounted) {
        _showLoginError(e.toString());
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

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
                child: ScaleTransition(
                  scale: _cardScale,
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
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                            borderRadius: AppTheme.cardRadius,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                              width: 1,
                            ),
                            boxShadow: const [AppTheme.baseShadow],
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _LichensVectors(controller: _vectorController),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _AnimatedLogo(),
                                  const SizedBox(height: 20),
                                  _AnimatedTitle(),
                                  const SizedBox(height: 24),
                                  _AnimatedField(
                                    delay: const Duration(milliseconds: 200),
                                    child: _buildTextField(
                                      controller: _emailController,
                                      label: 'Correo electrónico',
                                      icon: LucideIcons.mail,
                                      keyboardType: TextInputType.emailAddress,
                                      onChanged: (_) => _validateAllFields(),
                                      errorText: _emailError,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _AnimatedField(
                                    delay: const Duration(milliseconds: 280),
                                    child: _buildTextField(
                                      controller: _passwordController,
                                      label: 'Contraseña',
                                      icon: LucideIcons.lock,
                                      obscureText: _obscurePassword,
                                      onChanged: (_) => _validateAllFields(),
                                      errorText: _passwordError,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? LucideIcons.eyeOff
                                              : LucideIcons.eye,
                                          color: AppTheme.primaryGreen,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _AnimatedField(
                                    delay: const Duration(milliseconds: 360),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.pushNamed(context, AppRoutes.forgotPassword);
                                        },
                                        child: Text(
                                          '¿Olvidaste tu contraseña?',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryGreen
                                                .withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _AnimatedField(
                                    delay: const Duration(milliseconds: 440),
                                    child: _LoginButton(
                                      loading: authState.loading,
                                      enabled: _isFormValid,
                                       onPressed: () async {
                                         final email = _emailController.text
                                             .trim();
                                         final password =
                                             _passwordController.text;

                                         try {
                                           final success = await authState.login(email, password);
                                           if (success && mounted) {
                                             _goToDashboard();
                                           }
                                         } catch (e) {
                                           if (mounted) {
                                             _showLoginError(e.toString());
                                           }
                                         }
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                   _AnimatedField(
                                     delay: const Duration(milliseconds: 480),
                                     child: GoogleSignInButton(
                                       loading: _googleLoading,
                                       onPressed: _handleGoogleLogin,
                                       label: 'Iniciar con Google',
                                     ),
                                   ),
                                   const SizedBox(height: 18),
                                    _AnimatedField(
                                      delay: const Duration(milliseconds: 520),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              height: 1,
                                              color: Theme.of(context).colorScheme.outlineVariant,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            child: Text(
                                              '¿Nuevo aquí?',
                                             style: GoogleFonts.poppins(
                                               fontSize: 12,
                                               fontWeight: FontWeight.w600,
                                               color: Theme.of(context).colorScheme.onSurfaceVariant,
                                             ),
                                           ),
                                         ),
                                         Expanded(
                                           child: Container(
                                             height: 1,
                                             color: Theme.of(context).colorScheme.outlineVariant,
                                           ),
                                         ),
                                       ],
                                     ),
                                   ),
                                  const SizedBox(height: 18),
                                  _AnimatedField(
                                    delay: const Duration(milliseconds: 600),
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                        context,
                                        LichenDreamsPageRoute(page: const RegisterScreen()),
                                      );
                                      },
                                      icon: const Icon(
                                        LucideIcons.userPlus,
                                        size: 20,
                                      ),
                                      label: const Text('Crear una cuenta'),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryGreen
                                            .withValues(alpha: 0.32),
                                        side: BorderSide(
                                          color: AppTheme.primaryGreen,
                                          width: 2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: AppTheme.defaultRadius,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                          horizontal: 24,
                                        ),
                                        foregroundColor: AppTheme.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,

           style: GoogleFonts.poppins(
             fontSize: 14,
             fontWeight: FontWeight.w500,
             color: Theme.of(context).colorScheme.onSurface,
           ),

           decoration: InputDecoration(
             labelText: label,

             floatingLabelBehavior: FloatingLabelBehavior.auto,

             floatingLabelStyle: GoogleFonts.poppins(
               color: AppTheme.primaryGreen,
               fontSize: 13,
               fontWeight: FontWeight.w600,
             ),

             labelStyle: GoogleFonts.poppins(
               color: Theme.of(context).colorScheme.onSurfaceVariant,
               fontSize: 14,
               fontWeight: FontWeight.w500,
             ),

             prefixIcon: Icon(icon, color: AppTheme.primaryGreen),

             suffixIcon: suffixIcon,

             border: OutlineInputBorder(
               borderRadius: AppTheme.inputRadius,
               borderSide: BorderSide(
                 color: errorText != null
                     ? Colors.red.shade300
                     : Theme.of(context).colorScheme.outline,
                 width: 1.5,
               ),
             ),

             enabledBorder: OutlineInputBorder(
               borderRadius: AppTheme.inputRadius,
               borderSide: BorderSide(
                 color: errorText != null
                     ? Colors.red.shade300
                     : Theme.of(context).colorScheme.outline,
                 width: 1.5,
               ),
             ),

             focusedBorder: OutlineInputBorder(
               borderRadius: AppTheme.inputRadius,
               borderSide: BorderSide(
                 color: errorText != null
                     ? Colors.red.shade400
                     : AppTheme.primaryGreen,
                 width: 2,
               ),
             ),

             errorBorder: OutlineInputBorder(
               borderRadius: AppTheme.inputRadius,
               borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
             ),

             focusedErrorBorder: OutlineInputBorder(
               borderRadius: AppTheme.inputRadius,
               borderSide: BorderSide(color: Colors.red.shade400, width: 2),
             ),

             filled: true,

             fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),

            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
        ),

        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 16),
            child: Row(
              children: [
                Icon(
                  LucideIcons.triangleAlert,
                  size: 16,
                  color: Colors.red.shade500,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    errorText,
                    softWrap: true,
                    style: GoogleFonts.poppins(
                      color: Colors.red.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LichensVectors extends StatelessWidget {
  final AnimationController controller;
  const _LichensVectors({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final progress = controller.value;
          return CustomPaint(painter: _LichenVectorPainter(progress));
        },
      ),
    );
  }
}

class _LichenVectorPainter extends CustomPainter {
  final double progress;
  _LichenVectorPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final breathe = 1.0 + 0.03 * math.sin(progress * math.pi * 2);

    _drawFoliose(
      canvas,
      Offset(size.width * 0.10, size.height * 0.18),
      72 * breathe,
      54 * breathe,
      0.0,
    );
    _drawFoliose(
      canvas,
      Offset(size.width * 0.90, size.height * 0.82),
      58 * breathe,
      44 * breathe,
      2.2,
    );
    _drawFoliose(
      canvas,
      Offset(size.width * 0.08, size.height * 0.78),
      34 * breathe,
      26 * breathe,
      4.8,
    );
    _drawFoliose(
      canvas,
      Offset(size.width * 0.92, size.height * 0.22),
      30 * breathe,
      22 * breathe,
      1.4,
    );
    _drawFoliose(
      canvas,
      Offset(size.width * 0.78, size.height * 0.12),
      18 * breathe,
      13 * breathe,
      5.7,
    );
    _drawFoliose(
      canvas,
      Offset(size.width * 0.22, size.height * 0.88),
      22 * breathe,
      16 * breathe,
      3.1,
    );

    _drawCrustose(
      canvas,
      Offset(size.width * 0.92, size.height * 0.10),
      28 * breathe,
      20 * breathe,
      3.6,
    );
    _drawCrustose(
      canvas,
      Offset(size.width * 0.06, size.height * 0.14),
      16 * breathe,
      12 * breathe,
      5.4,
    );
    _drawCrustose(
      canvas,
      Offset(size.width * 0.88, size.height * 0.90),
      12 * breathe,
      9 * breathe,
      0.9,
    );
    _drawCrustose(
      canvas,
      Offset(size.width * 0.14, size.height * 0.90),
      10 * breathe,
      8 * breathe,
      4.2,
    );
    _drawCrustose(
      canvas,
      Offset(size.width * 0.95, size.height * 0.38),
      14 * breathe,
      10 * breathe,
      1.8,
    );

    _drawFruticose(
      canvas,
      Offset(size.width * 0.12, size.height * 0.20),
      Offset(size.width * 0.06, size.height * 0.08),
      0.7,
    );
    _drawFruticose(
      canvas,
      Offset(size.width * 0.88, size.height * 0.80),
      Offset(size.width * 0.94, size.height * 0.90),
      2.6,
    );
    _drawFruticose(
      canvas,
      Offset(size.width * 0.08, size.height * 0.74),
      Offset(size.width * 0.02, size.height * 0.82),
      4.3,
    );
    _drawFruticose(
      canvas,
      Offset(size.width * 0.92, size.height * 0.18),
      Offset(size.width * 0.97, size.height * 0.12),
      5.9,
    );
    _drawFruticose(
      canvas,
      Offset(size.width * 0.18, size.height * 0.10),
      Offset(size.width * 0.14, size.height * 0.04),
      3.4,
    );
    _drawFruticose(
      canvas,
      Offset(size.width * 0.82, size.height * 0.92),
      Offset(size.width * 0.86, size.height * 0.96),
      6.7,
    );

    _drawMicroTexture(canvas, size);
    _drawApothecia(canvas, size);
  }

  void _drawFoliose(
    Canvas canvas,
    Offset center,
    double w,
    double h,
    double phase,
  ) {
    final paint = Paint()
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final points = <Offset>[
      Offset(center.dx - w * 0.48, center.dy - h * 0.22),
      Offset(center.dx - w * 0.18, center.dy - h * 0.62),
      Offset(center.dx + w * 0.18, center.dy - h * 0.58),
      Offset(center.dx + w * 0.52, center.dy - h * 0.18),
      Offset(center.dx + w * 0.44, center.dy + h * 0.18),
      Offset(center.dx + w * 0.16, center.dy + h * 0.56),
      Offset(center.dx - w * 0.22, center.dy + 0.48),
      Offset(center.dx - w * 0.50, center.dy + h * 0.08),
    ];

    final path = _smoothClosedPath(points);
    canvas.drawPath(path, paint);
  }

  void _drawCrustose(
    Canvas canvas,
    Offset center,
    double w,
    double h,
    double phase,
  ) {
    final paint = Paint()
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final points = <Offset>[
      Offset(center.dx - w * 0.42, center.dy - h * 0.18),
      Offset(center.dx - w * 0.08, center.dy - h * 0.48),
      Offset(center.dx + w * 0.22, center.dy - h * 0.32),
      Offset(center.dx + w * 0.44, center.dy - h * 0.04),
      Offset(center.dx + w * 0.32, center.dy + h * 0.28),
      Offset(center.dx + w * 0.04, center.dy + h * 0.42),
      Offset(center.dx - w * 0.28, center.dy + h * 0.22),
      Offset(center.dx - w * 0.44, center.dy - h * 0.06),
    ];

    final path = _smoothClosedPath(points);
    canvas.drawPath(path, paint);
  }

  void _drawFruticose(Canvas canvas, Offset from, Offset to, double phase) {
    final paint = Paint()
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final mid = Offset(
      (from.dx + to.dx) / 2 + 6 * math.sin(progress * 3 * math.pi + phase),
      (from.dy + to.dy) / 2 + 6 * math.cos(progress * 3 * math.pi + phase),
    );
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy),
      paint,
    );
  }

  void _drawMicroTexture(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final microDots = <Offset>[
      Offset(size.width * 0.12, size.height * 0.10),
      Offset(size.width * 0.18, size.height * 0.14),
      Offset(size.width * 0.88, size.height * 0.88),
      Offset(size.width * 0.92, size.height * 0.84),
      Offset(size.width * 0.10, size.height * 0.80),
      Offset(size.width * 0.14, size.height * 0.84),
      Offset(size.width * 0.90, size.height * 0.14),
      Offset(size.width * 0.86, size.height * 0.18),
      Offset(size.width * 0.50, size.height * 0.08),
      Offset(size.width * 0.52, size.height * 0.12),
      Offset(size.width * 0.48, size.height * 0.92),
      Offset(size.width * 0.52, size.height * 0.88),
    ];

    for (final dot in microDots) {
      canvas.drawCircle(dot, 1.2, paint);
    }
  }

  void _drawApothecia(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    final apothecia = <Offset>[
      Offset(size.width * 0.16, size.height * 0.24),
      Offset(size.width * 0.84, size.height * 0.78),
      Offset(size.width * 0.20, size.height * 0.82),
      Offset(size.width * 0.80, size.height * 0.16),
      Offset(size.width * 0.50, size.height * 0.92),
      Offset(size.width * 0.50, size.height * 0.06),
    ];

    for (var i = 0; i < apothecia.length; i++) {
      final p = apothecia[i];
      final pulse = 1.0 + 0.12 * math.sin(progress * 2 * math.pi + i * 1.1);
      final radius = (1.4 + (i % 2) * 0.6) * pulse;
      canvas.drawCircle(p, radius, paint);
    }
  }

  Path _smoothClosedPath(List<Offset> points) {
    if (points.length < 3) return Path();

    final path = Path();
    final mid01 = Offset(
      (points.last.dx + points.first.dx) / 2,
      (points.last.dy + points.first.dy) / 2,
    );
    path.moveTo(mid01.dx, mid01.dy);

    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final mid = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_LichenVectorPainter oldDelegate) => true;
}

class _AnimatedLogo extends StatefulWidget {
  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late AnimationController _breatheController;
  late Animation<double> _breatheScale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    _controller.forward();

    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _breatheScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOutSine),
    );
    _breatheController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: ScaleTransition(
        scale: _breatheScale,
        child: Container(
          width: 95,
          height: 95,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.15),
            border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Image.asset('assets/logo/logo.png', fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _AnimatedTitle extends StatelessWidget {
  const _AnimatedTitle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          Text(
            'Lichen Dreams',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lee el aire, entiende tu entorno',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedField extends StatelessWidget {
  final Duration delay;
  final Widget child;

  const _AnimatedField({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: Transform.scale(scale: 0.98 + 0.02 * value, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

class _LoginButton extends StatefulWidget {
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _LoginButton({
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _scale = Tween<double>(
      begin: 1,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: ElevatedButton(
          onPressed: widget.loading || !widget.enabled
              ? null
              : widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.darkGreen,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: AppTheme.defaultRadius),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            elevation: 4,
            shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.55),
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(LucideIcons.logIn, size: 20),
                    SizedBox(width: 10),
                    Text('Iniciar sesión'),
                  ],
                ),
        ),
      ),
    );
  }
}
