import 'package:flutter/material.dart';

import '../routes/route_names.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final ApiService _api = ApiService();
  bool _loading = false;
  late AnimationController _animationController;
  late AnimationController _fadeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  // Variables de validación en tiempo real
  String? _emailError;
  String? _passwordError;

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
    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _api.dispose();
    _animationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
  }

  // ============= VALIDACIÓN CRUZADA GLOBAL EN TIEMPO REAL =============

  /// Valida TODOS los campos cuando cualquiera cambia
  void _validateAllFields() {
    setState(() {
      // Validar email
      if (_emailController.text.isEmpty) {
        _emailError = 'El correo es obligatorio';
      } else if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(_emailController.text)) {
        _emailError = 'Correo inválido';
      } else {
        _emailError = null;
      }

      // Validar contraseña
      if (_passwordController.text.isEmpty) {
        _passwordError = 'La contraseña es obligatoria';
      } else if (_passwordController.text.length < 6) {
        _passwordError = 'Mínimo 6 caracteres';
      } else {
        _passwordError = null;
      }
    });
  }

  /// Verificar si el formulario es válido
  bool get _isFormValid {
    return _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _emailError == null &&
        _passwordError == null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo blanco sólido
          Container(
            color: Colors.white,
          ),
          
          // Orbes decorativos verdes
          Positioned(
            top: -80,
            left: -60,
            child: _orb(300),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: _orb(250),
          ),
          Positioned(
            top: 150,
            right: -50,
            child: _orb(180),
          ),
          
          // Contenido principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
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
                        // Logo animado
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 90,
                                height: 90,
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
                                  Icons.eco_rounded,
                                  size: 55,
                                  color: Color(0xFF2F7D32),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 40),

                        // Título con espaciado de letra animado
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: -10, end: 1.5),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Text(
                              'Lichen Dreams',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2F7D32),
                                letterSpacing: value,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.1),
                                    offset: const Offset(0, 4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Subtítulo
                        Text(
                          'Lee el aire, entiende tu entorno',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 56),

                        // Tarjeta de formulario
                        Container(
                          padding: const EdgeInsets.all(32),
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
                              // Campo de correo
                              _buildAnimatedTextField(
                                index: 0,
                                controller: _emailController,
                                label: 'Correo electrónico',
                                icon: Icons.email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                onChanged: (_) => _validateAllFields(),
                                errorText: _emailError,
                              ),
                              const SizedBox(height: 24),

                              // Campo de contraseña
                              _buildAnimatedTextField(
                                index: 1,
                                controller: _passwordController,
                                label: 'Contraseña',
                                icon: Icons.lock_rounded,
                                obscureText: _obscurePassword,
                                onChanged: (_) => _validateAllFields(),
                                errorText: _passwordError,
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
                              const SizedBox(height: 12),

                              // Enlace de contraseña olvidada
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {},
                                  child: Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: TextStyle(
                                      color: const Color(0xFF2F7D32).withOpacity(0.7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Botón de inicio de sesión
                              _buildAnimatedLoginButton(),
                              const SizedBox(height: 20),

                              // Divisor
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
                                      '¿Nuevo aquí?',
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

                              // Botón de registro
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, AppRoutes.register);
                                },
                                icon: const Icon(Icons.person_add_rounded, size: 20),
                                label: const Text('Crear una cuenta'),
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
                        const SizedBox(height: 32),

                        // Pie de página
                        Text(
                          '🌿 Protegiendo la biodiversidad 🌿',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
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

  /// Widget privado que genera orbes decorativos verdes con gradient radial
  Widget _orb(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFF2F7D32).withOpacity(0.15),
            const Color(0xFF2F7D32).withOpacity(0.05),
          ],
          stops: const [0.0, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F7D32).withOpacity(0.1),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
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
    ValueChanged<String>? onChanged,
    String? errorText,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 150)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, color: const Color(0xFF2F7D32)),
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red.shade300 : const Color(0xFFE1E9DD),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red.shade300 : const Color(0xFFE1E9DD),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.red.shade400 : const Color(0xFF2F7D32),
                  width: 2.5,
                ),
              ),
              labelStyle: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 18,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Colors.red.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    errorText,
                    style: TextStyle(
                      color: Colors.red.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLoginButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
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
            onTap: _loading || !_isFormValid
                ? null
                : () async {
                    final email = _emailController.text.trim();
                    final password = _passwordController.text;

                    setState(() => _loading = true);
                    try {
                      await _api.login(email, password);
                      _goToDashboard();
                    } catch (error) {
                      final message = error is ApiException
                          ? error.message
                          : 'Error: ${error.toString()}';
                      _showErrorMessage(message);
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
                    const Icon(Icons.login_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    _loading ? 'Conectando...' : 'Iniciar sesión',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _isFormValid && !_loading
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
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

