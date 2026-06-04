import 'package:flutter/material.dart';

import '../routes/route_names.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const routeName = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;
  late AnimationController _animationController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _apiService.dispose();
    _animationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade400 : Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2F7D32),
              const Color(0xFF1B5E20),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0, end: 1).animate(
                  CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeOut,
                  )),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Logo
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.4),
                                    Colors.white.withOpacity(0.1),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.2),
                                    blurRadius: 25,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_add_rounded,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // Title
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: -10, end: 1.5),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Text(
                            'Crear Cuenta',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: value,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        'Únete a la comunidad de observadores',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Form Card
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Name field
                            _buildAnimatedTextField(
                              index: 0,
                              controller: _nameController,
                              label: 'Nombre completo',
                              icon: Icons.person_rounded,
                            ),
                            const SizedBox(height: 18),

                            // Email field
                            _buildAnimatedTextField(
                              index: 1,
                              controller: _emailController,
                              label: 'Correo electrónico',
                              icon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 18),

                            // Password field
                            _buildAnimatedTextField(
                              index: 2,
                              controller: _passwordController,
                              label: 'Contraseña',
                              icon: Icons.lock_rounded,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: const Color(0xFF2F7D32),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Confirm password field
                            _buildAnimatedTextField(
                              index: 3,
                              controller: _confirmPasswordController,
                              label: 'Confirmar contraseña',
                              icon: Icons.lock_person_rounded,
                              obscureText: _obscureConfirmPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: const Color(0xFF2F7D32),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Create account button
                            _buildAnimatedRegisterButton(),
                            const SizedBox(height: 20),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'Ya tienes cuenta',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Sign in button
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.login_rounded, size: 20),
                              label: const Text('Inicia sesión'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF2F7D32),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 24,
                                ),
                                foregroundColor: const Color(0xFF2F7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Footer
                      Text(
                        'Protegiendo lichen, preservando aire limpio',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
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
    );
  }

  Widget _buildAnimatedTextField({
    required int index,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 120)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF2F7D32)),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFE1E9DD),
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFE1E9DD),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFF2F7D32),
              width: 2.5,
            ),
          ),
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget _buildAnimatedRegisterButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2F7D32), Color(0xFF1B5E20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2F7D32).withOpacity(0.35),
              blurRadius: 15,
              offset: const Offset(0, 6),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    final fullName = _nameController.text.trim();
                    final email = _emailController.text.trim();
                    final password = _passwordController.text;
                    final confirm = _confirmPasswordController.text;

                    if (fullName.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
                      _showMessage('Completa todos los campos', isError: true);
                      return;
                    }

                    if (password != confirm) {
                      _showMessage('Las contraseñas no coinciden', isError: true);
                      return;
                    }

                    if (password.length < 6) {
                      _showMessage('La contraseña debe tener al menos 6 caracteres', isError: true);
                      return;
                    }

                    setState(() => _loading = true);
                    try {
                      await _apiService.register(fullName, email, password);
                      messenger.showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.white),
                              SizedBox(width: 12),
                              Text('¡Cuenta creada! Inicia sesión ahora'),
                            ],
                          ),
                          backgroundColor: Colors.green.shade400,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                      if (!mounted) return;
                      Future.delayed(const Duration(seconds: 1), () {
                        if (mounted) navigator.pushReplacementNamed(AppRoutes.login);
                      });
                    } catch (error) {
                      if (!mounted) return;
                      final message = error is ApiException ? error.message : 'Error al crear la cuenta';
                      _showMessage(message, isError: true);
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_loading)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.9),
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    _loading ? 'Creando cuenta...' : 'Crear cuenta',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
