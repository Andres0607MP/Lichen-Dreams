import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../widgets/app_theme.dart';
import '../routes/route_names.dart';
import '../state/auth_state.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  String? _emailError;
  bool _isLoading = false;
  bool _emailSent = false;

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
    _emailController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  void _validateEmail() {
    setState(() {
      if (_emailController.text.isEmpty) {
        _emailError = 'El correo es obligatorio';
      } else if (!_isValidEmail(_emailController.text.trim())) {
        _emailError = 'Correo inválido';
      } else {
        _emailError = null;
      }
    });
  }

  Future<void> _sendResetRequest() async {
    _validateEmail();
    if (_emailError != null) return;

    setState(() => _isLoading = true);

    try {
      final authState = context.read<AuthState>();
      await authState.forgotPassword(_emailController.text.trim());
      if (mounted) {
        setState(() {
          _emailSent = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(LucideIcons.triangleAlert, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
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
                          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                          borderRadius: AppTheme.cardRadius,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                            width: 1,
                          ),
                          boxShadow: const [AppTheme.baseShadow],
                        ),
                        child: _emailSent ? _buildSuccessView() : _buildFormView(),
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

  Widget _buildFormView() {
    return Column(
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
            LucideIcons.lockKeyhole,
            size: 32,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '¿Olvidaste tu contraseña?',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa tu correo electrónico y te enviaremos un código para restablecer tu contraseña.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildTextField(),
        const SizedBox(height: 20),
        _buildSendButton(),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(LucideIcons.arrowLeft, size: 18),
          label: Text(
            'Volver al inicio de sesión',
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
    );
  }

  Widget _buildSuccessView() {
    return Column(
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
            LucideIcons.mailCheck,
            size: 32,
            color: AppTheme.primaryGreen,
          ),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 20),
        Text(
          'Correo enviado',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Si el correo está registrado, recibirás instrucciones para recuperar tu contraseña. Revisa tu bandeja de entrada.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacementNamed(context, AppRoutes.resetPassword);
            },
            icon: const Icon(LucideIcons.arrowRight, size: 18),
            label: const Text('Tengo un código'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkGreen,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: AppTheme.defaultRadius),
              textStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(LucideIcons.arrowLeft, size: 18),
          label: Text(
            'Volver al inicio de sesión',
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
    );
  }

  Widget _buildTextField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) {
            if (_emailError != null) _validateEmail();
          },
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            labelText: 'Correo electrónico',
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
            prefixIcon: const Icon(LucideIcons.mail, color: AppTheme.primaryGreen),
            border: OutlineInputBorder(
              borderRadius: AppTheme.inputRadius,
              borderSide: BorderSide(
                color: _emailError != null
                    ? Colors.red.shade300
                    : Theme.of(context).colorScheme.outline,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppTheme.inputRadius,
              borderSide: BorderSide(
                color: _emailError != null
                    ? Colors.red.shade300
                    : Theme.of(context).colorScheme.outline,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppTheme.inputRadius,
              borderSide: BorderSide(
                color: _emailError != null
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
        if (_emailError != null)
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
                    _emailError!,
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

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _sendResetRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.darkGreen,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: AppTheme.defaultRadius),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 4,
          shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.55),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.send, size: 20),
                  SizedBox(width: 10),
                  Text('Enviar código'),
                ],
              ),
      ),
    );
  }
}
