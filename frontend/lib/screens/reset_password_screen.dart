import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../widgets/app_theme.dart';
import '../routes/route_names.dart';
import '../state/auth_state.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _passwordReset = false;

  String? _tokenError;
  String? _passwordError;
  String? _confirmPasswordError;

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
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  bool _isValidToken(String token) {
    return token.length == 6 && RegExp(r'^[0-9]{6}$').hasMatch(token);
  }

  bool _isValidPassword(String password) {
    return password.length >= 6 && password.contains(RegExp(r'[^a-zA-Z0-9]'));
  }

  void _validateFields() {
    setState(() {
      if (_tokenController.text.isEmpty) {
        _tokenError = 'El código es obligatorio';
      } else if (!_isValidToken(_tokenController.text.trim())) {
        _tokenError = 'El código debe tener 6 dígitos numéricos';
      } else {
        _tokenError = null;
      }

      if (_passwordController.text.isEmpty) {
        _passwordError = 'La contraseña es obligatoria';
      } else if (!_isValidPassword(_passwordController.text)) {
        _passwordError = 'Mínimo 6 caracteres y un carácter especial';
      } else {
        _passwordError = null;
      }

      if (_confirmPasswordController.text.isEmpty) {
        _confirmPasswordError = 'Confirma la contraseña';
      } else if (_passwordController.text != _confirmPasswordController.text) {
        _confirmPasswordError = 'Las contraseñas no coinciden';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  Future<void> _resetPassword() async {
    _validateFields();
    if (_tokenError != null || _passwordError != null || _confirmPasswordError != null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authState = context.read<AuthState>();
      await authState.resetPassword(
        _tokenController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        setState(() {
          _passwordReset = true;
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
                        child: _passwordReset ? _buildSuccessView() : _buildFormView(),
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
          'Restablecer contraseña',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa el código de 6 dígitos que recibiste por correo y tu nueva contraseña.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildTokenField(),
        const SizedBox(height: 16),
        _buildPasswordField(
          controller: _passwordController,
          label: 'Nueva contraseña',
          obscureText: _obscurePassword,
          errorText: _passwordError,
          onToggleVisibility: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          onChanged: (_) {
            if (_passwordError != null) _validateFields();
          },
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          controller: _confirmPasswordController,
          label: 'Confirmar contraseña',
          obscureText: _obscureConfirmPassword,
          errorText: _confirmPasswordError,
          onToggleVisibility: () {
            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
          },
          onChanged: (_) {
            if (_confirmPasswordError != null) _validateFields();
          },
        ),
        const SizedBox(height: 20),
        _buildResetButton(),
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
            LucideIcons.check,
            size: 32,
            color: AppTheme.primaryGreen,
          ),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 20),
        Text(
          'Contraseña actualizada',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Tu contraseña ha sido actualizada exitosamente. Ahora puedes iniciar sesión con tu nueva contraseña.',
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
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            },
            icon: const Icon(LucideIcons.logIn, size: 18),
            label: const Text('Iniciar sesión'),
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
      ],
    );
  }

  Widget _buildTokenField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _tokenController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          onChanged: (_) {
            if (_tokenError != null) _validateFields();
          },
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 8,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: 'Código de recuperación',
            counterText: '',
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
            prefixIcon: const Icon(LucideIcons.shieldCheck, color: AppTheme.primaryGreen),
            border: OutlineInputBorder(
              borderRadius: AppTheme.inputRadius,
              borderSide: BorderSide(
                color: _tokenError != null
                    ? Colors.red.shade300
                    : Theme.of(context).colorScheme.outline,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppTheme.inputRadius,
              borderSide: BorderSide(
                color: _tokenError != null
                    ? Colors.red.shade300
                    : Theme.of(context).colorScheme.outline,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppTheme.inputRadius,
              borderSide: BorderSide(
                color: _tokenError != null
                    ? Colors.red.shade400
                    : AppTheme.primaryGreen,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
        ),
        if (_tokenError != null)
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
                    _tokenError!,
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required String? errorText,
    required VoidCallback onToggleVisibility,
    required ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
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
            prefixIcon: const Icon(LucideIcons.lock, color: AppTheme.primaryGreen),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? LucideIcons.eyeOff : LucideIcons.eye,
                color: AppTheme.primaryGreen,
              ),
              onPressed: onToggleVisibility,
            ),
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

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _resetPassword,
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
                  Icon(LucideIcons.check, size: 20),
                  SizedBox(width: 10),
                  Text('Restablecer contraseña'),
                ],
              ),
      ),
    );
  }
}
